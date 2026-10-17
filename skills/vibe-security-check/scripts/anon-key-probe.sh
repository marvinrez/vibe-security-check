#!/usr/bin/env bash
# Can an anonymous client read or write the database?
#
# Supabase ships the public anon key in your frontend by design and grants the
# anon role every table in the public schema, so Row Level Security is the only
# gate. With RLS on, a command that has no policy is refused. The holes are RLS
# left off, a policy such as USING (true), and a policy granted to a wider role
# than meant. This asks the API directly, as the anon key, with no session.
#
# PostgREST filters rather than refuses. A locked table answers a read with 200
# and no rows, and answers an update or delete with 204 whether a policy stopped
# it or it matched nothing. So a read counts as open only when rows come back,
# an insert is judged by the error code in the response, and update and delete
# are not probed at all: no request can tell those apart. Check them in SQL with
# the query in references/data-stores.md.
#
# A request that does not complete, that the server fails on, or that gets an
# answer that is not an access decision is reported as inconclusive. None of
# those is a refusal, and a wrong URL must not read as a locked database.
#
# Only run this against a project you own or are authorized to test. The insert
# probe sends a real write: on an open table it creates an empty row.
#
# Usage: ./anon-key-probe.sh <project-url> <anon-key> <table> [...tables]
# Example: ./anon-key-probe.sh https://abc.supabase.co eyJhbG... todos profiles
# Exit:  0 no rows read, every insert refused · 1 something is open · 2 incomplete
set -uo pipefail

[ $# -lt 3 ] && { sed -n '2,/^set /p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; exit 64; }

URL="${1%/}"; KEY="$2"; shift 2
FAIL=0
UNREACHED=0
UNTESTED=0
EMPTY=0

jwt_role() { # jwt -> its role claim, empty when it has none
  local p="${1#*.}"; p="${p%%.*}"
  p=$(printf '%s' "$p" | tr '_-' '/+')
  while [ $(( ${#p} % 4 )) -ne 0 ]; do p="$p="; done
  printf '%s' "$p" | base64 -d 2>/dev/null | tr -d '\n' |
    sed -n 's/.*"role"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'
}

# A key that bypasses the policies proves nothing about them, and the insert
# probe would write with full access. Stop before sending anything.
AUTH=()
case "$KEY" in
  sb_secret_*)
    echo "That is a secret key (sb_secret_...), not the public one. It bypasses every"
    echo "policy, so a probe with it proves nothing and writes with full access."
    echo "Use the publishable key (sb_publishable_...) or the legacy anon key."
    exit 64 ;;
  eyJ*)
    ROLE=$(jwt_role "$KEY")
    if [ "$ROLE" = service_role ] || [ "$ROLE" = supabase_admin ]; then
      echo "That key's role is $ROLE. It bypasses every policy, so a probe with it"
      echo "proves nothing and writes with full access. Use the anon key."
      exit 64
    fi
    if [ -n "$ROLE" ] && [ "$ROLE" != anon ]; then
      echo "note: this key's role is '$ROLE', not anon — the results describe that role."
      echo
    fi
    # Legacy keys are JWTs and go in both headers, as the client libraries send them.
    AUTH=(-H "Authorization: Bearer $KEY") ;;
esac
# Publishable keys are not JWTs and travel in the apikey header only.

BODY=$(mktemp)
trap 'rm -f "$BODY"' EXIT

request() { # method path [body] -> sets CODE, and ERR to the error code in the body
  : >"$BODY"
  CODE=$(curl -sS -o "$BODY" -w '%{http_code}' --max-time 10 -X "$1" \
    -H "apikey: $KEY" ${AUTH[@]+"${AUTH[@]}"} \
    -H "Content-Type: application/json" -H "Prefer: return=minimal" \
    ${3:+--data "$3"} "$URL/rest/v1/$2" 2>/dev/null) || CODE="000"
  ERR=$(tr -d '\n' <"$BODY" | sed -n 's/.*"code"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
}

compact() { tr -d ' \t\r\n' <"$BODY"; }

report() { # verdict command detail
  if [ "$1" = OPEN ]; then printf '  \033[31mOPEN\033[0m   %-6s %s\n' "$2" "$3"
  else printf '  %-6s %-6s %s\n' "$1" "$2" "$3"; fi
}

unreached() { # command
  if [ "$CODE" = "000" ]; then report ERROR "$1" "(no response)"
  else report ERROR "$1" "(HTTP $CODE)"; fi
  UNREACHED=1
}

probe_read() { # table
  request GET "$1?select=*&limit=1"
  if [ "$CODE" = "000" ] || [[ "$CODE" =~ ^5 ]]; then
    # No response, or the server failed before deciding. Proves nothing.
    unreached read
  elif [[ "$CODE" =~ ^2 ]] && [ "$(compact | head -c 1)" != "[" ]; then
    # A 2xx that is not a JSON array came from something other than the
    # database API, most often the app's own host serving index.html.
    report "?" read "(HTTP $CODE, not a database response — is this the project URL?)"
    UNTESTED=1
  elif [[ "$CODE" =~ ^2 ]] && [ "$(compact)" != "[]" ]; then
    report OPEN read "(HTTP $CODE, rows returned)"; FAIL=1
  elif [[ "$CODE" =~ ^2 ]]; then
    # RLS hides rows rather than refusing the query, so an empty answer is what
    # a locked table and an empty table both look like.
    report none read "(HTTP $CODE, no rows — refused by policy, or the table is empty)"
    EMPTY=1
  elif [ "$ERR" = "42501" ] || [ "$CODE" = "401" ] || [ "$CODE" = "403" ]; then
    report ok read "(HTTP $CODE, permission denied)"
  else
    # A table the API does not expose (404, 42P01), a malformed request and the
    # like never reached an access decision.
    report "?" read "(HTTP $CODE${ERR:+, $ERR} — no access decision, read not tested)"
    UNTESTED=1
  fi
}

probe_insert() { # table
  request POST "$1" '{}'
  if [ "$CODE" = "000" ] || [[ "$CODE" =~ ^5 ]]; then
    unreached insert
  elif [[ "$CODE" =~ ^2 ]] && [ "$(compact | head -c 1)" = "<" ]; then
    report "?" insert "(HTTP $CODE, not a database response — is this the project URL?)"
    UNTESTED=1
  elif [[ "$CODE" =~ ^2 ]]; then
    report OPEN insert "(HTTP $CODE, an empty row was written — delete it)"; FAIL=1
  elif [ "$ERR" = "42501" ]; then
    report ok insert "(HTTP $CODE, refused: no grant, or no policy lets it through)"
  elif [[ "$ERR" =~ ^23 ]]; then
    # Postgres checks RLS before constraints, so an integrity error means the
    # empty row got past the access check and only failed on a missing value.
    report OPEN insert "(HTTP $CODE, $ERR — passed the access check, then failed a constraint)"
    FAIL=1
  elif [ "$CODE" = "401" ] || [ "$CODE" = "403" ]; then
    report ok insert "(HTTP $CODE)"
  else
    report "?" insert "(HTTP $CODE${ERR:+, $ERR} — no access decision, insert not tested)"
    UNTESTED=1
  fi
}

for t in "$@"; do
  echo "table: $t"
  probe_read "$t"
  probe_insert "$t"
  echo
done

echo "update and delete were not probed. PostgREST answers both with 204 whether a"
echo "policy refused them or they matched nothing, so no request can tell. Check the"
echo "policies in SQL instead; the query is in references/data-stores.md."
echo

if [ $FAIL -eq 1 ]; then
  echo "FINDING: the anon key, with no session, read rows from or wrote to a table above."
  echo "With RLS on, a command that has no policy is refused, so the fix is to turn RLS"
  echo "on and narrow or drop the policy that let this through, not to add more:"
  echo "  ALTER TABLE public.<t> ENABLE ROW LEVEL SECURITY;"
  echo "  SELECT cmd, roles, qual, with_check FROM pg_policies WHERE tablename = '<t>';"
  echo "A table that is public by design, such as a catalogue, can stay readable. Its"
  echo "inserts should not be open."
  exit 1
fi
if [ $UNREACHED -eq 1 ]; then
  echo "Could not complete every probe — see ERROR above. Nothing here shows the"
  echo "database is locked down; check the project URL, the key and the network."
  exit 2
fi
if [ $UNTESTED -eq 1 ]; then
  echo "Some probes got an answer that is not an access decision — see ? above. Check"
  echo "the table name, and that the URL is the project's API rather than the app."
  echo "Until then, access to those tables is untested, not refused."
  exit 2
fi
echo "No table returned rows to the anon key, and every insert was refused."
if [ $EMPTY -eq 1 ]; then
  echo "A table with no rows reads the same whether it is locked or empty. For those,"
  echo "only the insert result says anything."
fi
