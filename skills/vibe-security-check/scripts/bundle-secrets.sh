#!/usr/bin/env bash
# Did any secret get inlined into the shipped frontend?
#
# Anything prefixed NEXT_PUBLIC_, VITE_, EXPO_PUBLIC_ or REACT_APP_ is compiled
# into the bundle as plain text. Mobile bundles decompile just as easily. Look in
# the BUILD, not the source — the source is not what ships.
#
# Usage: ./bundle-secrets.sh [build-dir ...]     (default: dist build .next out public)
set -uo pipefail

DIRS=("${@:-}"); [ -z "${DIRS[0]:-}" ] && DIRS=(dist build .next out public)

HITS=$(mktemp)
trap 'rm -f "$HITS"' EXIT

# provider key shapes + long JWTs; deliberately narrow to keep noise down
PATTERNS='sk-[A-Za-z0-9_-]{20,}|sk-ant-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|glpat-[A-Za-z0-9_-]{20}|AIza[0-9A-Za-z_-]{35}|xox[baprs]-[0-9A-Za-z-]{10,}|eyJ[A-Za-z0-9_-]{30,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}|-----BEGIN [A-Z ]*PRIVATE KEY-----'

for d in "${DIRS[@]}"; do
  [ -d "$d" ] || continue
  echo "scanning $d/"
  grep -rIEol "$PATTERNS" "$d" 2>/dev/null | head -50 >>"$HITS"
done

if [ -s "$HITS" ]; then
  echo
  echo "FINDING: secret-shaped strings in the shipped bundle:"
  sed 's/^/  /' "$HITS"
  echo
  echo "Rotate the key first — it is already public. Then move it server-side and"
  echo "have the browser call your own route instead of the provider directly."
  exit 1
fi
echo "No secret-shaped strings found. Note this proves nothing about keys the"
echo "platform injects at deploy time — check the deployed bundle too."
