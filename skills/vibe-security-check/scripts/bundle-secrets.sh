#!/usr/bin/env bash
# Did any secret get inlined into the shipped frontend?
#
# Anything prefixed NEXT_PUBLIC_, VITE_, EXPO_PUBLIC_ or REACT_APP_ is compiled
# into the bundle as plain text. Mobile bundles decompile just as easily. Look in
# the BUILD, not the source — the source is not what ships. For a mobile app,
# unzip the .apk or .ipa and point this at the result; Hermes bytecode is read as
# bytes, so the strings in it are found.
#
# Two kinds of key are public by design and are not findings: the Supabase anon
# key (a JWT whose role is anon) and publishable keys, which these patterns do
# not match. Every other JWT is one — a service_role key bypasses every access
# rule. A Google API key (AIza...) is reported too: Firebase and Maps keys are
# meant to ship, but any of them can call every API enabled on its project,
# Gemini included, unless it is restricted.
#
# A clean result has to mean a build was read, so a directory that does not
# exist, or scanning nothing at all, is reported as incomplete.
#
# Usage: ./bundle-secrets.sh [build-dir ...]     (default: dist build .next out public)
# Exit:  0 nothing found · 1 secret found · 2 nothing was scanned
set -uo pipefail

EXPLICIT=1
DIRS=("$@"); [ $# -eq 0 ] && { DIRS=(dist build .next out public); EXPLICIT=0; }

HITS=$(mktemp)
trap 'rm -f "$HITS"' EXIT

# Provider key shapes, plus long JWTs. Deliberately narrow to keep noise down,
# and anchored so a word ending in "sk" followed by a hyphen is not a key.
TOKENS='sk-[A-Za-z0-9_-]{20,}|[sr]k_(live|test)_[A-Za-z0-9]{20,}|sb_secret_[A-Za-z0-9_-]{20,}|whsec_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{50,}|glpat-[A-Za-z0-9_-]{20}|xox[baprs]-[0-9A-Za-z-]{10,}|AIza[0-9A-Za-z_-]{35}|eyJ[A-Za-z0-9_-]{30,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}'
PATTERNS="(^|[^A-Za-z0-9_-])($TOKENS)|-----BEGIN [A-Z ]*PRIVATE KEY-----"

jwt_role() { # jwt -> its role claim, empty when it has none
  local p="${1#*.}"; p="${p%%.*}"
  p=$(printf '%s' "$p" | tr '_-' '/+')
  while [ $(( ${#p} % 4 )) -ne 0 ]; do p="$p="; done
  printf '%s' "$p" | base64 -d 2>/dev/null | tr -d '\n' |
    sed -n 's/.*"role"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'
}

kind() { # match -> what it is
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
    AIza*)               echo "Google API key — check its API restrictions; unrestricted, it can call Gemini" ;;
    -----BEGIN*)         echo "private key" ;;
    eyJ*)
      local role; role=$(jwt_role "$1")
      if [ "$role" = service_role ]; then echo "Supabase service_role key — bypasses every access rule"
      else echo "JWT (role: ${role:-none})"; fi ;;
  esac
}

SCANNED=0
MISSING=0
PUBLIC=""
for d in "${DIRS[@]}"; do
  if [ ! -d "$d" ]; then
    [ $EXPLICIT -eq 1 ] && { echo "not a directory: $d"; MISSING=1; }
    continue
  fi
  echo "scanning $d/"
  SCANNED=$((SCANNED + 1))
  # .next/cache is the build cache, not something the browser receives.
  EXCLUDE=(); case "$d" in *.next|*.next/) EXCLUDE=(--exclude-dir=cache) ;; esac
  # -a reads binary files as text, which is what finds strings in Hermes bytecode.
  while IFS= read -r line; do
    file="${line%%:*}"; match="${line#*:}"
    match="${match#[^A-Za-z0-9_-]}"            # drop the boundary character
    if [ "${match#eyJ}" != "$match" ] && [ "$(jwt_role "$match")" = anon ]; then
      PUBLIC="$PUBLIC$file"$'\n'
      continue
    fi
    printf '  %s  %s  (%s…)\n' "$file" "$(kind "$match")" "${match:0:10}" >>"$HITS"
  done < <(grep -rEoaH ${EXCLUDE[@]+"${EXCLUDE[@]}"} -e "$PATTERNS" "$d" 2>/dev/null)
done

if [ -n "$PUBLIC" ]; then
  echo
  echo "note: the Supabase anon key is in the bundle, which is by design — the access"
  echo "rules behind it are the control, so test them with anon-key-probe.sh:"
  printf '%s' "$PUBLIC" | sort -u | sed 's/^/  /'
fi

if [ -s "$HITS" ]; then
  echo
  echo "FINDING: secret-shaped strings in the shipped bundle:"
  sort -u "$HITS"
  echo
  echo "Rotate the key first — it is already public. Then move it server-side and"
  echo "have the browser call your own route instead of the provider directly."
  if grep -q "Google API key" "$HITS"; then
    echo "A Google key that has to ship (Firebase, Maps) stays, restricted at the"
    echo "provider to your domains and to the APIs it needs; rotate it if it was not."
  fi
  exit 1
fi
if [ $SCANNED -eq 0 ] || [ $MISSING -eq 1 ]; then
  echo
  [ $SCANNED -eq 0 ] && echo "Nothing was scanned: none of ${DIRS[*]} is a directory here."
  echo "Build first, or pass the build output directory. This result is incomplete, not clean."
  exit 2
fi
echo "No secret-shaped strings found. Note this proves nothing about keys the"
echo "platform injects at deploy time — check the deployed bundle too."
