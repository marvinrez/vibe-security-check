#!/usr/bin/env bash
# Is there a secret anywhere in git history?
#
# Removing a secret from a file leaves it in history. Anyone who clones gets it.
# Prefers gitleaks/trufflehog when installed (they verify liveness); falls back to
# a grep over every blob so the check still runs with nothing installed.
#
# Usage: ./history-secrets.sh [repo-dir]     (default: .)
set -uo pipefail
cd "${1:-.}" || exit 64
git rev-parse --git-dir >/dev/null 2>&1 || { echo "not a git repository"; exit 64; }

if command -v gitleaks >/dev/null 2>&1; then
  echo "using gitleaks"; gitleaks detect --no-banner --redact -v; exit $?
fi
if command -v trufflehog >/dev/null 2>&1; then
  echo "using trufflehog (verifies whether keys are live)"
  trufflehog git "file://$PWD" --only-verified; exit $?
fi

echo "gitleaks/trufflehog not installed — falling back to a history grep."
echo "Install one of them for verified results: https://github.com/gitleaks/gitleaks"
echo
PATTERNS='sk-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|AIza[0-9A-Za-z_-]{35}|-----BEGIN [A-Z ]*PRIVATE KEY-----|password\s*=\s*["'"'"'][^"'"'"']{8,}'
HITS=$(git rev-list --all --objects \
  | git cat-file --batch-check='%(objecttype) %(objectname) %(rest)' 2>/dev/null \
  | awk '$1=="blob"{print $2" "$3}' \
  | while read -r sha path; do
      git cat-file blob "$sha" 2>/dev/null | grep -IEl "$PATTERNS" >/dev/null 2>&1 && echo "  $path (blob $sha)"
    done | sort -u)

if [ -n "$HITS" ]; then
  echo "FINDING: secret-shaped content in history:"; echo "$HITS"
  echo
  echo "Revoke first — treat every match as compromised. Rewriting history does"
  echo "not un-leak anything that was already cloned or indexed."
  exit 1
fi
echo "No secret-shaped content found in history."
