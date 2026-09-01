#!/usr/bin/env bash
# Is .git, .env or a debug surface served in production?
#
# Costs a handful of requests and catches what is most embarrassing to miss.
# Only run this against a host you own or are authorized to test.
#
# Usage: ./exposed-paths.sh https://your-app.example
set -uo pipefail
[ $# -lt 1 ] && { sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 64; }
BASE="${1%/}"; FAIL=0

PATHS=(.git/config .git/HEAD .env .env.local .env.production
       config.json credentials.json .DS_Store
       server-status debug __debug__ actuator/env
       graphql .well-known/security.txt backup.sql dump.sql)

for p in "${PATHS[@]}"; do
  read -r code len < <(curl -sS -o /dev/null -w '%{http_code} %{size_download}' \
                       --max-time 10 "$BASE/$p" 2>/dev/null || echo "000 0")
  if [[ "$code" =~ ^2 ]] && [ "$len" -gt 0 ]; then
    printf '  \033[31mEXPOSED\033[0m  %-28s HTTP %s, %s bytes\n' "$p" "$code" "$len"; FAIL=1
  else
    printf '  ok       %-28s HTTP %s\n' "$p" "$code"
  fi
done

echo
if [ $FAIL -eq 1 ]; then
  echo "FINDING: paths above are reachable. .git exposes full source and history;"
  echo ".env exposes live credentials — rotate anything found before fixing serving rules."
  exit 1
fi
echo "None of the probed paths are served."
