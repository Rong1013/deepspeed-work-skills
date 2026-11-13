#!/usr/bin/env bash
# Scan content that would be published for internal/sensitive information.
#
# Usage:
#   scan_sensitive.sh --base <upstream-commit> [--ref INDEX|<ref>] [--history] [--patterns FILE]
#
# Default mode scans only lines ADDED relative to the upstream base (what DAS contributes),
# so upstream content does not drown the report. --history additionally scans every patch in
# <base>..<ref>, which is required before publishing with history preserved.
# Exit code 1 if anything matched.
set -uo pipefail

BASE=""; REF=INDEX; HISTORY=0
PATTERNS="$(cd "$(dirname "$0")" && pwd)/sensitive-patterns.txt"
while [ $# -gt 0 ]; do
  case "$1" in
    --base) BASE="$2"; shift 2;;
    --ref) REF="$2"; shift 2;;
    --history) HISTORY=1; shift;;
    --patterns) PATTERNS="$2"; shift 2;;
    *) echo "unknown arg $1" >&2; exit 2;;
  esac
done
[ -n "$BASE" ] || { echo "usage: scan_sensitive.sh --base <upstream-commit> [--ref INDEX|<ref>] [--history]" >&2; exit 2; }

RX=$(grep -v -E '^\s*(#|$)' "$PATTERNS" | paste -sd'|' -)
HITS=0

scan_diff() {  # stdin: unified diff; prints file:line-ish context for added lines that match
  awk -v rx="$RX" '
    /^\+\+\+ b\// { file = substr($0, 7); next }
    /^@@/ { split($3, a, ","); line = substr(a[1], 2) - 1; next }
    /^\+/ { line++; s = substr($0, 2); if (s ~ rx) { printf "%s:%d: %s\n", file, line, s; n++ } next }
    /^ / { line++ }
    END { exit (n > 0) }'
}

echo "== tree scan: lines added in $REF relative to $(git rev-parse --short "$BASE")"
if [ "$REF" = INDEX ]; then
  git diff --cached -U0 --no-color "$BASE" | scan_diff || HITS=1
else
  git diff -U0 --no-color "$BASE" "$REF" | scan_diff || HITS=1
fi

echo "== file names that should never be published"
NAMES_REF=$([ "$REF" = INDEX ] && git write-tree || echo "$REF")
git ls-tree -r --name-only "$NAMES_REF" | grep -E '(^|/)(\.env|\.netrc|id_rsa|.*\.pem|.*\.key|.*\.log|tmp\.txt|\.gitlab-ci\.yml)$' && HITS=1 || echo "none"

if [ "$HISTORY" = 1 ]; then
  [ "$REF" = INDEX ] && { echo "--history needs a branch ref" >&2; exit 2; }
  echo "== history scan: every commit in $(git rev-parse --short "$BASE")..$REF"
  for c in $(git rev-list --no-merges "$BASE..$REF"); do
    out=$(git show -U0 --no-color --format= "$c" | scan_diff) || { echo "-- $(git log -1 --format='%h %an <%ae> %s' "$c")"; echo "$out"; HITS=1; }
  done
  echo "== author emails in history"
  git log --format='%ae' "$BASE..$REF" | sort | uniq -c | sort -rn
fi

echo "result: $([ $HITS = 0 ] && echo CLEAN || echo 'MATCHES FOUND - review each')"
exit $HITS
