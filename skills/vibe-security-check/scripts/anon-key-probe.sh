#!/usr/bin/env bash
# Can an anonymous client read or write the database?
#
# Supabase and Firebase ship tables reachable with the public anon key that lives
# in your frontend by design. Row Level Security "on" with no policy, or with only
# a SELECT policy, still leaves writes open. This probes all four commands.
#
# A request that does not complete, or that the server fails on, is reported as an
# error. It is never counted as a refusal — an unreachable host must not read as a
# locked one.
#
# Only run this against a project you own or are authorized to test. The insert,
# update and delete probes send real writes.
#
# Usage: ./anon-key-probe.sh <project-url> <anon-key> <table> [...tables]
# Example: ./anon-key-probe.sh https://abc.supabase.co eyJhbG... todos profiles
# Exit:  0 everything refused · 1 something is open · 2 result incomplete
set -uo pipefail

[ $# -lt 3 ] && { sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 64; }

URL="${1%/}"; KEY="$2"; shift 2
FAIL=0
UNREACHED=0

probe() { # method path label [body]
  local code
  code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 10 -X "$1" \
    -H "apikey: $KEY" -H "Authorization: Bearer $KEY" \
    -H "Content-Type: application/json" -H "Prefer: return=minimal" \
    ${4:+--data "$4"} "$URL/rest/v1/$2" 2>/dev/null) || code="000"

  if [ "$code" = "000" ]; then
    # No response at all: a wrong URL, DNS, or the network. Proves nothing.
    printf '  ERROR  %-6s %s  (no response)\n' "$1" "$3"; UNREACHED=1
  elif [[ "$code" =~ ^5 ]]; then
    # The server failed before deciding. Also proves nothing about access.
    printf '  ERROR  %-6s %s  (HTTP %s)\n' "$1" "$3" "$code"; UNREACHED=1
  elif [[ "$code" =~ ^2 ]]; then
    # 2xx means the anonymous client got through.
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
if [ $UNREACHED -eq 1 ]; then
  echo "Could not complete every probe — see ERROR above. Nothing here shows the"
  echo "database is locked down; check the project URL, the key and the network."
  exit 2
fi
echo "All probed commands refused the anonymous key."
