#!/usr/bin/env bash
# Can an anonymous client read or write the database?
#
# Supabase and Firebase ship tables reachable with the public anon key that lives
# in your frontend by design. Row Level Security "on" with no policy, or with only
# a SELECT policy, still leaves writes open. This probes all four commands.
#
# Usage: ./anon-key-probe.sh <project-url> <anon-key> <table> [...tables]
# Example: ./anon-key-probe.sh https://abc.supabase.co eyJhbG... todos profiles
set -uo pipefail

[ $# -lt 3 ] && { sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 64; }

URL="${1%/}"; KEY="$2"; shift 2
FAIL=0

probe() { # method path label expect_block
  local code
  code=$(curl -sS -o /dev/null -w '%{http_code}' -X "$1" \
    -H "apikey: $KEY" -H "Authorization: Bearer $KEY" \
    -H "Content-Type: application/json" -H "Prefer: return=minimal" \
    ${4:+--data "$4"} "$URL/rest/v1/$2" 2>/dev/null) || code="000"
  # 2xx means the anonymous client got through. 40x means it was refused.
  if [[ "$code" =~ ^2 ]]; then
    printf '  \033[31mOPEN\033[0m   %-6s %s  (HTTP %s)\n' "$1" "$3" "$code"; FAIL=1
  else
    printf '  ok     %-6s %s  (HTTP %s)\n' "$1" "$3" "$code"
  fi
}

for t in "$@"; do
  echo "table: $t"
  probe GET    "$t?select=*&limit=1" "read"
  probe POST   "$t"                  "insert" '{}'
  probe PATCH  "$t?id=eq.0"          "update" '{}'
  probe DELETE "$t?id=eq.0"          "delete"
  echo
done

if [ $FAIL -eq 1 ]; then
  echo "FINDING: at least one command is reachable with the anon key and no session."
  echo "Enable RLS and write a policy per command:"
  echo "  ALTER TABLE public.<t> ENABLE ROW LEVEL SECURITY;"
  echo "  CREATE POLICY \"select own\" ON public.<t> FOR SELECT TO authenticated"
  echo "    USING ((select auth.uid()) = user_id);   -- repeat for INSERT/UPDATE/DELETE"
  exit 1
fi
echo "All probed commands refused the anonymous key."
