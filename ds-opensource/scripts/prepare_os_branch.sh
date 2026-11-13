#!/usr/bin/env bash
# Build a local open-source branch: upstream base + the source branch's tree minus excluded paths.
# Nothing is committed or pushed; the result is left staged for review.
#
# Usage: prepare_os_branch.sh --src <dev-branch> [--base <upstream-commit>] [--name <os-branch>]
set -euo pipefail

SRC=""; BASE=""; NAME=""
EXCLUDE="$(cd "$(dirname "$0")/.." && pwd)/references/exclude-paths.txt"
while [ $# -gt 0 ]; do
  case "$1" in
    --src) SRC="$2"; shift 2;;
    --base) BASE="$2"; shift 2;;
    --name) NAME="$2"; shift 2;;
    --exclude) EXCLUDE="$2"; shift 2;;
    *) echo "unknown arg $1" >&2; exit 2;;
  esac
done
[ -n "$SRC" ] || { echo "usage: prepare_os_branch.sh --src <dev-branch> [--base <commit>] [--name <branch>]" >&2; exit 2; }

[ -z "$(git status --porcelain --untracked-files=no)" ] || { echo "ERROR: working tree not clean" >&2; exit 2; }
test -f "$(git rev-parse --git-dir)/MERGE_HEAD" && { echo "ERROR: merge in progress" >&2; exit 2; }

[ -n "$BASE" ] || BASE=$(git merge-base "$SRC" upstream/master)
VER=$(git show "$SRC:version.txt" | tr -d '[:space:]')
[ -n "$NAME" ] || NAME="ds-v${VER}-os"
git rev-parse --verify --quiet "refs/heads/$NAME" >/dev/null && { echo "ERROR: branch $NAME exists; pick --name or delete it after review" >&2; exit 2; }

echo "source: $SRC @ $(git rev-parse --short "$SRC")"
echo "base:   $(git log -1 --format='%h %s' "$BASE")"
echo "branch: $NAME   version: $VER"

git checkout -q -b "$NAME" "$BASE"
# Take the whole source tree (adds, modifications and deletions relative to base).
git read-tree -u --reset "$SRC"

mapfile -t PATHS < <(grep -v -E '^\s*(#|$)' "$EXCLUDE")
REMOVED=()
for p in "${PATHS[@]}"; do
  if git ls-files --error-unmatch -- "$p" >/dev/null 2>&1; then
    git rm -r -q --cached -- "$p" && rm -rf -- "$p"
    REMOVED+=("$p")
  fi
done

echo "removed (${#REMOVED[@]}):"; printf '  %s\n' "${REMOVED[@]+"${REMOVED[@]}"}"
echo "staged vs base:"; git diff --cached --shortstat "$BASE"
echo
echo "next: scan_sensitive.sh --base $(git rev-parse --short "$BASE") --ref INDEX"
echo "nothing committed. to abandon: git checkout -f <previous-branch> && git branch -D $NAME"
