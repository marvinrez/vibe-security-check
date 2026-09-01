#!/usr/bin/env bash
# Run the scripts and check what they actually do.
#
# Linting and `bash -n` catch syntax and dead code. They do not catch a probe that
# reports "refused" when the host was simply unreachable, or one that flags every
# path on a host that answers 200 for all of them. Those are behaviours, so they
# need the scripts to be executed.
#
# No network: the two host probes run against a local stand-in (fake-host.py).
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

# A key shape the scanners look for, assembled here so no secret-shaped string is
# ever committed to this repository.
FAKE_KEY="sk-$(printf 'a%.0s' $(seq 1 30))"

echo "bundle-secrets.sh"
mkdir -p "$WORK/dirty/dist" "$WORK/clean/dist"
printf 'const k="%s";\n' "$FAKE_KEY" > "$WORK/dirty/dist/app.js"
printf 'const k=1;\n'                > "$WORK/clean/dist/app.js"
(cd "$WORK/dirty" && "$SCRIPTS/bundle-secrets.sh" >/dev/null 2>&1); check "flags a key in the build" 1 "$?"
(cd "$WORK/clean" && "$SCRIPTS/bundle-secrets.sh" >/dev/null 2>&1); check "passes a clean build"    0 "$?"

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

echo "exposed-paths.sh"
serve static 18731
serve spa    18732
out=$("$SCRIPTS/exposed-paths.sh" http://127.0.0.1:18731 2>&1); check "flags a served .env on a plain file host" 1 "$?"
grep -q 'EXPOSED.*\.env' <<<"$out" || { echo "  FAIL  .env was not the path it flagged"; exit 1; }
printf '  ok    names .env as the finding\n'; PASS=$((PASS + 1))
n=$(grep -c EXPOSED <<<"$out")
[ "$n" -eq 1 ] || { echo "  FAIL  flagged $n paths on a host serving exactly one"; exit 1; }
printf '  ok    flags only the path that is served\n'; PASS=$((PASS + 1))

out=$("$SCRIPTS/exposed-paths.sh" http://127.0.0.1:18732 2>&1); check "passes a single-page-app catch-all host" 0 "$?"
grep -q EXPOSED <<<"$out" && { echo "  FAIL  a catch-all 200 was reported as a finding"; exit 1; }
printf '  ok    treats the catch-all as the catch-all\n'; PASS=$((PASS + 1))

"$SCRIPTS/exposed-paths.sh" http://127.0.0.1:9 >/dev/null 2>&1; check "reports incomplete, not clean, on an unreachable host" 2 "$?"

echo "anon-key-probe.sh"
serve db-open   18733
serve db-locked 18734
"$SCRIPTS/anon-key-probe.sh" http://127.0.0.1:18733 anon-key todos >/dev/null 2>&1; check "flags a database open to the anon key" 1 "$?"
"$SCRIPTS/anon-key-probe.sh" http://127.0.0.1:18734 anon-key todos >/dev/null 2>&1; check "passes a database that refuses it"    0 "$?"
"$SCRIPTS/anon-key-probe.sh" http://127.0.0.1:9     anon-key todos >/dev/null 2>&1; check "reports incomplete, not clean, on an unreachable host" 2 "$?"
serve db-400 18735
"$SCRIPTS/anon-key-probe.sh" http://127.0.0.1:18735 anon-key todos >/dev/null 2>&1; check "does not read a malformed-request 400 as a refusal"        2 "$?"

echo
echo "$PASS checks passed."
