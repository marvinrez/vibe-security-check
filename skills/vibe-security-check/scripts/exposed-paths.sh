#!/usr/bin/env bash
# Is .git, .env or a debug surface served in production?
#
# Costs a handful of requests and catches what is most embarrassing to miss.
#
# A host serving a single-page app answers 200 with index.html for every unknown
# path, so a 200 on its own proves nothing. This first requests a path that cannot
# exist, and treats any response identical to that one as the catch-all rather
# than a finding.
#
# A host that cannot be reached is reported as an error, never as a clean result.
#
# Only run this against a host you own or are authorized to test.
#
# Usage: ./exposed-paths.sh https://your-app.example
# Exit:  0 nothing served · 1 something served · 2 result incomplete
set -uo pipefail
[ $# -lt 1 ] && { sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 64; }
BASE="${1%/}"; FAIL=0; UNREACHED=0

BODY=$(mktemp)
trap 'rm -f "$BODY"' EXIT

fetch() { # path -> "<http_code> <bytes> <checksum>"
  local code
  code=$(curl -sS -o "$BODY" -w '%{http_code}' --max-time 10 "$BASE/$1" 2>/dev/null) || code=000
  printf '%s %s %s\n' "$code" "$(wc -c <"$BODY" | tr -d ' ')" "$(cksum <"$BODY" | awk '{print $1}')"
}

# A path no deployment serves. Whatever comes back is this host's catch-all.
read -r BASE_CODE _ BASE_SUM <<<"$(fetch "vibe-check-$$-$RANDOM-does-not-exist")"

if [ "$BASE_CODE" = "000" ]; then
  echo "Could not reach $BASE — the baseline request did not complete."
  echo "Nothing was proven either way. Check the URL, the network and any VPN."
  exit 2
fi

if [[ "$BASE_CODE" =~ ^2 ]]; then
  echo "note: this host answers HTTP $BASE_CODE for a path that cannot exist, so it"
  echo "      serves a catch-all. Responses identical to it are that catch-all and"
  echo "      are reported as ok."
  echo
fi

PATHS=(.git/config .git/HEAD .env .env.local .env.production
       config.json credentials.json .DS_Store
       server-status debug __debug__ actuator/env
       graphql .well-known/security.txt backup.sql dump.sql)

for p in "${PATHS[@]}"; do
  read -r code len sum <<<"$(fetch "$p")"
  if [ "$code" = "000" ]; then
    printf '  ERROR    %-28s no response\n' "$p"; UNREACHED=$((UNREACHED + 1))
  elif [[ "$code" =~ ^5 ]]; then
    printf '  ERROR    %-28s HTTP %s\n' "$p" "$code"; UNREACHED=$((UNREACHED + 1))
  elif [[ "$code" =~ ^2 ]] && [ "$len" -gt 0 ] && [ "$sum" != "$BASE_SUM" ]; then
    printf '  \033[31mEXPOSED\033[0m  %-28s HTTP %s, %s bytes\n' "$p" "$code" "$len"; FAIL=1
  else
    printf '  ok       %-28s HTTP %s\n' "$p" "$code"
  fi
done

echo
if [ "$UNREACHED" -eq "${#PATHS[@]}" ]; then
  echo "Could not reach $BASE — every request failed. Nothing was proven."
  exit 2
fi
if [ $FAIL -eq 1 ]; then
  echo "FINDING: paths above are reachable. .git exposes full source and history;"
  echo ".env exposes live credentials — rotate anything found before fixing serving rules."
  exit 1
fi
if [ "$UNREACHED" -gt 0 ]; then
  echo "$UNREACHED path(s) could not be checked — see ERROR above."
  echo "The rest are not served. This result is incomplete, not clean."
  exit 2
fi
echo "None of the probed paths are served."
