#!/usr/bin/env bash
# Is .git, .env or a debug surface served in production?
#
# Costs a handful of requests and catches what is most embarrassing to miss.
#
# A host serving a single-page app answers 200 with index.html for every unknown
# path, so a 200 on its own proves nothing. This first requests a path that cannot
# exist. A response identical to that one is the catch-all; on a catch-all host, a
# response that differs only counts when it looks like what the path really holds
# (a .git/HEAD that starts with "ref:", a .env made of KEY=value lines), because
# an index.html carrying a fresh nonce differs on every request.
#
# A host that cannot be reached is reported as an error, never as a clean result.
# So is one that redirects every request or sits behind a login: nothing behind
# the redirect or the wall was tested.
#
# Only run this against a host you own or are authorized to test.
#
# Usage: ./exposed-paths.sh https://your-app.example
# Exit:  0 nothing served · 1 something served · 2 result incomplete
set -uo pipefail
[ $# -lt 1 ] && { sed -n '2,/^set /p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; exit 64; }
BASE="${1%/}"; FAIL=0; UNREACHED=0; CATCHALL=0; WALL=0

BODY=$(mktemp)
trap 'rm -f "$BODY"' EXIT

fetch() { # path -> "<http_code> <bytes> <checksum> <redirect target>"
  local out
  : >"$BODY"
  out=$(curl -sS -o "$BODY" -w '%{http_code} %{redirect_url}' --max-time 10 "$BASE/$1" 2>/dev/null) || out=000
  printf '%s %s %s %s\n' "${out%% *}" "$(wc -c <"$BODY" | tr -d ' ')" \
    "$(cksum <"$BODY" | awk '{print $1}')" "$(printf '%s' "$out" | cut -s -d' ' -f2)"
}

looks_like() { # path -> does the body just fetched look like what that path holds?
  case "$1" in
    .git/config)                   grep -aq '^\[core\]' "$BODY" ;;
    .git/HEAD)                     grep -aEq '^(ref: refs/|[0-9a-f]{40})' "$BODY" ;;
    .env|.env.*)                   grep -aEq '^[A-Za-z_][A-Za-z0-9_]*=' "$BODY" ;;
    config.json|credentials.json)  [ "$(tr -d ' \t\r\n' <"$BODY" | head -c 1)" = "{" ] ;;
    .DS_Store)                     grep -aq 'Bud1' "$BODY" ;;
    server-status)                 grep -aEiq 'server uptime|total accesses|apache server status' "$BODY" ;;
    debug|__debug__)               grep -aEiq 'traceback|werkzeug|djdt|debug toolbar' "$BODY" ;;
    actuator/env)                  grep -aEq 'propertySources|activeProfiles' "$BODY" ;;
    graphql)                       grep -aEiq '"errors"|"data"|graphiql|apollo' "$BODY" ;;
    *.sql)                         grep -aEiq 'create table|insert into|database dump' "$BODY" ;;
    *)                             return 1 ;;
  esac
}

# A path no deployment serves. Whatever comes back is this host's catch-all.
read -r BASE_CODE _ BASE_SUM BASE_TO <<<"$(fetch "vibe-check-$$-$RANDOM-does-not-exist")"

if [ "$BASE_CODE" = "000" ]; then
  echo "Could not reach $BASE — the baseline request did not complete."
  echo "Nothing was proven either way. Check the URL, the network and any VPN."
  exit 2
fi

if [[ "$BASE_CODE" =~ ^2 ]]; then
  CATCHALL=1
  echo "note: this host answers HTTP $BASE_CODE for a path that cannot exist, so it"
  echo "      serves a catch-all. Responses identical to it, or that do not look like"
  echo "      the file asked for, are that catch-all and are reported as ok."
  echo
elif [[ "$BASE_CODE" =~ ^3 ]] || [ "$BASE_CODE" = "401" ] || [ "$BASE_CODE" = "407" ]; then
  WALL=1
  if [[ "$BASE_CODE" =~ ^3 ]]; then
    echo "note: this host redirects a path that cannot exist (HTTP $BASE_CODE${BASE_TO:+ to $BASE_TO})."
  else
    echo "note: this host asks for credentials (HTTP $BASE_CODE) on a path that cannot exist."
  fi
  echo "      Anything served without that is still a finding; anything behind it was not tested."
  echo
fi

PATHS=(.git/config .git/HEAD .env .env.local .env.production
       config.json credentials.json .DS_Store
       server-status debug __debug__ actuator/env
       graphql backup.sql dump.sql)

for p in "${PATHS[@]}"; do
  read -r code len sum _ <<<"$(fetch "$p")"
  if [ "$code" = "000" ]; then
    printf '  ERROR    %-28s no response\n' "$p"; UNREACHED=$((UNREACHED + 1))
  elif [[ "$code" =~ ^5 ]]; then
    printf '  ERROR    %-28s HTTP %s\n' "$p" "$code"; UNREACHED=$((UNREACHED + 1))
  elif [[ "$code" =~ ^2 ]] && [ "$len" -gt 0 ] && [ "$sum" != "$BASE_SUM" ] &&
       { [ $CATCHALL -eq 0 ] || looks_like "$p"; }; then
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
if [ $WALL -eq 1 ]; then
  echo "Nothing was served without credentials, but every path got the same redirect or"
  echo "login wall, so none of them was really tested. Re-run against the address the"
  echo "redirect leads to, or against a deployment without the wall."
  exit 2
fi
if [ "$UNREACHED" -gt 0 ]; then
  echo "$UNREACHED path(s) could not be checked — see ERROR above."
  echo "The rest are not served. This result is incomplete, not clean."
  exit 2
fi
echo "None of the probed paths are served."
