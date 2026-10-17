#!/usr/bin/env bash
# Run the scripts and check what they actually do.
#
# Linting and `bash -n` catch syntax and dead code. They do not catch a probe that
# reports "refused" when the host was simply unreachable, or one that flags every
# path on a host that answers 200 for all of them. Those are behaviours, so they
# need the scripts to be executed.
#
# No network: the two host probes run against a local stand-in (fake-host.py),
# whose database mode replays what a real PostgREST answered.
#
# Usage: ./run.sh          (from anywhere; exits non-zero on the first failure)
set -uo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
SCRIPTS=$(dirname "$HERE")
WORK=$(mktemp -d)
PIDS=()
PASS=0

cleanup() {
  for pid in ${PIDS[@]+"${PIDS[@]}"}; do kill "$pid" 2>/dev/null; done
  rm -rf "$WORK"
}
trap cleanup EXIT

check() { # description expected_exit actual_exit
  if [ "$2" = "$3" ]; then
    printf '  ok    %s\n' "$1"; PASS=$((PASS + 1))
  else
    printf '  FAIL  %s (expected exit %s, got %s)\n' "$1" "$2" "$3"; exit 1
  fi
}

expect() { # description command-output pattern -> the output must match
  if grep -qE "$3" <<<"$2"; then
    printf '  ok    %s\n' "$1"; PASS=$((PASS + 1))
  else
    printf '  FAIL  %s (no line matching /%s/)\n' "$1" "$3"; exit 1
  fi
}

serve() { # mode port -> starts a stand-in host and waits for it to answer
  python3 "$HERE/fake-host.py" "$1" "$2" &
  PIDS+=($!)
  disown          # so the shell does not print a job notice when we kill it
  for _ in $(seq 1 50); do
    curl -sS -o /dev/null --max-time 1 "http://127.0.0.1:$2/" 2>/dev/null && return 0
    sleep 0.2
  done
  echo "  FAIL  stand-in host '$1' never came up on port $2"; exit 1
}

# Key shapes the scanners look for, assembled here so no secret-shaped string is
# ever committed to this repository.
FAKE_KEY="sk-$(printf 'a%.0s' $(seq 1 30))"
STRIPE_KEY="sk_""live_$(printf 'b%.0s' $(seq 1 30))"
SB_SECRET="sb_""secret_$(printf 'c%.0s' $(seq 1 30))"
b64url() { printf '%s' "$1" | base64 | tr -d '\n=' | tr '+/' '-_'; }
jwt() { # role -> a JWT carrying it; nothing here checks the signature
  printf '%s.%s.%s' "$(b64url '{"alg":"HS256","typ":"JWT"}')" \
    "$(b64url "{\"iss\":\"supabase\",\"ref\":\"testprojectref000000\",\"role\":\"$1\"}")" \
    "signature-not-checked-by-anything-here-0123456789"
}
ANON_KEY=$(jwt anon)
SERVICE_KEY=$(jwt service_role)

echo "bundle-secrets.sh"
build() { # name content -> a project with that content in dist/app.js
  mkdir -p "$WORK/$1/dist"; printf '%s\n' "$2" > "$WORK/$1/dist/app.js"
}
build dirty    "const k=\"$FAKE_KEY\";"
build clean    'const k=1;'
build anon     "createClient(\"https://x.supabase.co\",\"$ANON_KEY\");"
build service  "createClient(\"https://x.supabase.co\",\"$SERVICE_KEY\");"
build stripe   "const stripe=new Stripe(\"$STRIPE_KEY\");const db=\"$SB_SECRET\";"
build words    'const s="disk-usage-warning-threshold-exceeded";'
mkdir -p "$WORK/hermes/dist" "$WORK/nobuild"
{ printf 'HBC\0\0\0\037'; printf 'const k="%s";' "$FAKE_KEY"; } > "$WORK/hermes/dist/index.android.bundle"
scan() { (cd "$WORK/$1" && shift && "$SCRIPTS/bundle-secrets.sh" "$@" >/dev/null 2>&1); }
scan dirty;   check "flags a key in the build"                                  1 "$?"
scan clean;   check "passes a clean build"                                      0 "$?"
scan anon;    check "does not flag the Supabase anon key, which is public"      0 "$?"
scan service; check "flags a service_role key"                                  1 "$?"
scan stripe;  check "flags a Stripe secret key and a Supabase secret key"       1 "$?"
scan words;   check "does not read a word ending in 'sk-' as a key"             0 "$?"
scan hermes;  check "finds a key inside binary bytecode"                        1 "$?"
scan nobuild; check "reports incomplete, not clean, when there is no build"     2 "$?"
scan clean dist-typo; check "reports incomplete for a directory that does not exist" 2 "$?"

echo "history-secrets.sh"
for state in dirty clean; do
  repo="$WORK/repo-$state"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config user.email test@example.invalid
  git -C "$repo" config user.name "test"
  if [ "$state" = dirty ]; then printf 'KEY=%s\n' "$FAKE_KEY" > "$repo/config.js"
  else printf 'KEY=lookup()\n' > "$repo/config.js"; fi
  git -C "$repo" add -A && git -C "$repo" commit -qm "commit"
  # The secret is removed from the file but stays in history — the whole point.
  printf 'KEY=lookup()\n' > "$repo/config.js"
  git -C "$repo" commit -qam "remove the key" >/dev/null 2>&1 || true
done
"$SCRIPTS/history-secrets.sh" "$WORK/repo-dirty" >/dev/null 2>&1; check "finds a key removed from a file but kept in history" 1 "$?"
"$SCRIPTS/history-secrets.sh" "$WORK/repo-clean" >/dev/null 2>&1; check "passes a clean history"                             0 "$?"
"$SCRIPTS/history-secrets.sh" "$WORK"            >/dev/null 2>&1; check "refuses a directory that is not a repository"      64 "$?"

# A .env committed and then untracked, carrying the keys that matter most here.
repo="$WORK/repo-env"; mkdir -p "$repo"; git -C "$repo" init -q
git -C "$repo" config user.email test@example.invalid; git -C "$repo" config user.name test
printf 'SUPABASE_SERVICE_ROLE_KEY=%s\nDATABASE_URL=postgresql://postgres:Tr0ub4dor-horse-battery@db.example.invalid:5432/postgres\n' \
  "$SERVICE_KEY" > "$repo/.env"
git -C "$repo" add -A && git -C "$repo" commit -qm "env"
git -C "$repo" rm -q --cached .env && git -C "$repo" commit -qm "untrack env"
out=$("$SCRIPTS/history-secrets.sh" "$repo" 2>&1); check "finds a committed .env after it was untracked" 1 "$?"
expect "names the service_role key in it"   "$out" 'service_role'
expect "names the database password in it"  "$out" 'URL with a password'

# The shape of a real Supabase app: anon key in source, placeholders in the example.
repo="$WORK/repo-app"; mkdir -p "$repo/src"; git -C "$repo" init -q
git -C "$repo" config user.email test@example.invalid; git -C "$repo" config user.name test
printf 'export const supabase = createClient(URL, "%s");\n' "$ANON_KEY" > "$repo/src/client.ts"
printf 'OPENAI_API_KEY=your-openai-key-here\nDATABASE_URL=postgresql://postgres:password@localhost:5432/app\n' > "$repo/.env.example"
git -C "$repo" add -A && git -C "$repo" commit -qm "app"
"$SCRIPTS/history-secrets.sh" "$repo" >/dev/null 2>&1; check "passes the anon key in source and placeholders in .env.example" 0 "$?"

echo "exposed-paths.sh"
serve static      18731
serve spa         18732
serve nonce       18733
serve redirect    18734
serve authwall    18735
serve securitytxt 18736
out=$("$SCRIPTS/exposed-paths.sh" http://127.0.0.1:18731 2>&1); check "flags a served .env on a plain file host" 1 "$?"
grep -q 'EXPOSED.*\.env' <<<"$out" || { echo "  FAIL  .env was not the path it flagged"; exit 1; }
printf '  ok    names .env as the finding\n'; PASS=$((PASS + 1))
n=$(grep -c EXPOSED <<<"$out")
[ "$n" -eq 1 ] || { echo "  FAIL  flagged $n paths on a host serving exactly one"; exit 1; }
printf '  ok    flags only the path that is served\n'; PASS=$((PASS + 1))

out=$("$SCRIPTS/exposed-paths.sh" http://127.0.0.1:18732 2>&1); check "passes a single-page-app catch-all host" 0 "$?"
grep -q EXPOSED <<<"$out" && { echo "  FAIL  a catch-all 200 was reported as a finding"; exit 1; }
printf '  ok    treats the catch-all as the catch-all\n'; PASS=$((PASS + 1))

out=$("$SCRIPTS/exposed-paths.sh" http://127.0.0.1:18733 2>&1); check "flags a .env on a catch-all host whose page changes per request" 1 "$?"
n=$(grep -c EXPOSED <<<"$out")
[ "$n" -eq 1 ] || { echo "  FAIL  flagged $n paths where only .env is served"; exit 1; }
printf '  ok    does not flag the catch-all just because its nonce changed\n'; PASS=$((PASS + 1))

"$SCRIPTS/exposed-paths.sh" http://127.0.0.1:18734 >/dev/null 2>&1; check "reports incomplete, not clean, on a host that redirects everything" 2 "$?"
"$SCRIPTS/exposed-paths.sh" http://127.0.0.1:18735 >/dev/null 2>&1; check "reports incomplete, not clean, behind a login wall"               2 "$?"
"$SCRIPTS/exposed-paths.sh" http://127.0.0.1:18736 >/dev/null 2>&1; check "does not flag a published security.txt"                           0 "$?"
"$SCRIPTS/exposed-paths.sh" http://127.0.0.1:9     >/dev/null 2>&1; check "reports incomplete, not clean, on an unreachable host"            2 "$?"

echo "anon-key-probe.sh"
serve pgrst 18737
probe() { "$SCRIPTS/anon-key-probe.sh" "$1" "$2" "$3" >/dev/null 2>&1; }
DB=http://127.0.0.1:18737
probe $DB "$ANON_KEY" rls_off;    check "flags a table with RLS turned off"                          1 "$?"
probe $DB "$ANON_KEY" using_true; check "flags a USING (true) policy"                                1 "$?"
probe $DB "$ANON_KEY" anon_read;  check "flags a table the anon role can read"                       1 "$?"
probe $DB "$ANON_KEY" no_policy;  check "passes RLS on with no policy, which refuses everything"      0 "$?"
probe $DB "$ANON_KEY" no_grant;   check "passes a table the anon role has no grant on"               0 "$?"
probe $DB "$ANON_KEY" missing;    check "reports incomplete on a table the API does not expose"      2 "$?"
probe http://127.0.0.1:18732 "$ANON_KEY" todos; check "reports incomplete when the URL is the app, not the API" 2 "$?"
probe http://127.0.0.1:9 "$ANON_KEY" todos;     check "reports incomplete, not clean, on an unreachable host"  2 "$?"
probe http://127.0.0.1:9 "$SERVICE_KEY" todos;  check "refuses a service_role key before sending anything"     64 "$?"
probe http://127.0.0.1:9 "$SB_SECRET" todos;    check "refuses a secret key before sending anything"           64 "$?"

echo
echo "$PASS checks passed."
