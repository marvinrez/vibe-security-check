#!/usr/bin/env bash
# Is there a secret anywhere in git history?
#
# Removing a secret from a file leaves it in history. Anyone who clones gets it.
# Prefers gitleaks or trufflehog when installed (trufflehog also checks whether a
# key is still live); falls back to a scan of every blob so the check still runs
# with nothing installed.
#
# The fallback looks for provider key shapes, JWTs other than the Supabase anon
# key, URLs carrying a password, secret-named variables set to a value, and any
# .env file that was ever committed. Placeholders in example files
# (.env.example and the like) are not findings; real key shapes in them are.
#
# Usage: ./history-secrets.sh [repo-dir]     (default: .)
# Exit:  0 nothing found · 1 secret found · 2 the scanner failed · 64 not a repository
set -uo pipefail
cd "${1:-.}" || exit 64
git rev-parse --git-dir >/dev/null 2>&1 || { echo "not a git repository"; exit 64; }

if command -v gitleaks >/dev/null 2>&1; then
  echo "using gitleaks"; gitleaks detect --no-banner --redact -v; exit $?
fi
if command -v trufflehog >/dev/null 2>&1; then
  echo "using trufflehog (verifies whether keys are live)"
  # Without --fail trufflehog exits 0 whatever it finds. With it, 183 means
  # results and 1 means the scan itself failed.
  trufflehog git "file://$PWD" --only-verified --fail
  case $? in 0) exit 0 ;; 183) exit 1 ;; *) exit 2 ;; esac
fi

echo "gitleaks/trufflehog not installed — falling back to a history grep."
echo "Install one of them for verified results: https://github.com/gitleaks/gitleaks"
echo

TOKENS='sk-[A-Za-z0-9_-]{20,}|[sr]k_(live|test)_[A-Za-z0-9]{20,}|sb_secret_[A-Za-z0-9_-]{20,}|whsec_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{50,}|glpat-[A-Za-z0-9_-]{20}|xox[baprs]-[0-9A-Za-z-]{10,}|AIza[0-9A-Za-z_-]{35}|eyJ[A-Za-z0-9_-]{30,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}'
URLPW="[a-z][a-z0-9+.-]*://[^:/@[:space:]\"']+:[^@/[:space:]\"']{6,}@[^/[:space:]\"']+"
QUOTED="([Pp]ass(word|wd)|PASS(WORD|WD))[[:space:]]*[:=][[:space:]]*[\"'][^\"']{8,}[\"']"
ASSIGN='^[A-Z0-9_]*(PASSWORD|PASSWD|SECRET|TOKEN|API_KEY|PRIVATE_KEY)[A-Z0-9_]*=[^[:space:]]{8,}'
PATTERNS="(^|[^A-Za-z0-9_-])($TOKENS)|-----BEGIN [A-Z ]*PRIVATE KEY-----|$URLPW|$QUOTED|$ASSIGN"

jwt_role() { # jwt -> its role claim, empty when it has none
  local p="${1#*.}"; p="${p%%.*}"
  p=$(printf '%s' "$p" | tr '_-' '/+')
  while [ $(( ${#p} % 4 )) -ne 0 ]; do p="$p="; done
  printf '%s' "$p" | base64 -d 2>/dev/null | tr -d '\n' |
    sed -n 's/.*"role"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'
}

token_kind() { # token -> what it is; nothing for the public anon key
  case "$1" in
    sk-ant-*)            echo "Anthropic API key" ;;
    sk-*)                echo "OpenAI-style secret key" ;;
    sk_*|rk_*)           echo "Stripe secret key" ;;
    sb_secret_*)         echo "Supabase secret key" ;;
    whsec_*)             echo "webhook signing secret" ;;
    AKIA*)               echo "AWS access key id" ;;
    ghp_*|github_pat_*)  echo "GitHub token" ;;
    glpat-*)             echo "GitLab token" ;;
    xox*)                echo "Slack token" ;;
    AIza*)               echo "Google API key" ;;
    -----BEGIN*)         echo "private key" ;;
    eyJ*)
      local role; role=$(jwt_role "$1")
      case "$role" in
        anon) ;;
        service_role) echo "Supabase service_role key" ;;
        *) echo "JWT (role: ${role:-none})" ;;
      esac ;;
  esac
}

placeholder() { # value -> is it a stand-in rather than a secret?
  case "$1" in
    '$'*|'<'*|'{'*|'%'*|your*|YOUR*|change*|CHANGE*|xxx*|XXX*|example*|EXAMPLE*|replace*|REPLACE*) return 0 ;;
    password|postgres|pass|secret|test|root|admin) return 0 ;;
  esac
  return 1
}

classify() { # path match -> a kind, or nothing when the match is not a finding
  local path="$1" m="$2" example=0 v
  case "$path" in *.example|*.sample|*.template|*.dist|*example*|*sample*) example=1 ;; esac
  m="${m#[^A-Za-z0-9_-]}"                     # drop the boundary character
  case "$m" in
    *://*)
      v="${m#*://}"; v="${v#*:}"; v="${v%%@*}"
      [ $example -eq 1 ] || placeholder "$v" || echo "URL with a password" ;;
    *=*|*:*)
      v="${m#*[:=]}"; v="${v#"${v%%[![:space:]]*}"}"; v="${v#[\"\']}"; v="${v%[\"\']}"
      if [ -n "$(token_kind "$v")" ]; then token_kind "$v"
      elif [ "${v#eyJ}" != "$v" ]; then :           # the anon key, assigned to a variable
      elif [ $example -eq 0 ] && ! placeholder "$v"; then echo "secret-named variable set to a value"
      fi ;;
    *) token_kind "$m" ;;
  esac
}

HITS=$(git rev-list --all --objects \
  | git cat-file --batch-check='%(objecttype) %(objectname) %(rest)' 2>/dev/null \
  | awk '$1=="blob"{ sha=$2; $1=""; $2=""; sub(/^  /, ""); print sha" "$0 }' \
  | while read -r sha path; do
      case "$path" in
        .env|*/.env|.env.*|*/.env.*)
          case "$path" in
            *.example|*.sample|*.template|*.dist) ;;
            *) echo "  $path (blob ${sha:0:7}): a .env file was committed" ;;
          esac ;;
      esac
      git cat-file blob "$sha" 2>/dev/null | grep -IEo "$PATTERNS" 2>/dev/null \
        | while IFS= read -r m; do
            k=$(classify "$path" "$m")
            [ -n "$k" ] && echo "  $path (blob ${sha:0:7}): $k"
          done
    done | sort -u)

if [ -n "$HITS" ]; then
  echo "FINDING: secret-shaped content in history:"; echo "$HITS"
  echo
  echo "Revoke first — treat every match as compromised. Rewriting history does"
  echo "not un-leak anything that was already cloned or indexed."
  exit 1
fi
echo "No secret-shaped content found in history."
