#!/usr/bin/env bash
# Read-only pre-merge report for merging an upstream DeepSpeed ref into the current branch.
# Usage: merge_preflight.sh <upstream-ref>   (e.g. upstream/master, v0.20.0)
set -euo pipefail

REF="${1:?usage: merge_preflight.sh <upstream-ref>}"

git rev-parse --show-toplevel >/dev/null
test -f setup.py -a -d deepspeed || { echo "ERROR: not at DeepSpeed repo root" >&2; exit 2; }

if ! git remote get-url upstream >/dev/null 2>&1; then
  echo "WARN: remote 'upstream' missing. Add with:"
  echo "  git remote add upstream https://github.com/deepspeedai/DeepSpeed.git"
fi
git fetch upstream --tags --quiet || echo "WARN: fetch upstream failed (network?)"

git rev-parse --verify --quiet "$REF^{commit}" >/dev/null || { echo "ERROR: unknown ref $REF" >&2; exit 2; }

echo "== branch";        git status -sb | head -1
echo "== latest upstream tags"; git tag -l 'v*' --sort=-v:refname | head -3

echo "== working tree"
dirty=$(git status --porcelain --untracked-files=no | wc -l)
echo "tracked changes: $dirty"

if [ -f "$(git rev-parse --git-dir)/MERGE_HEAD" ]; then
  mh=$(cat "$(git rev-parse --git-dir)/MERGE_HEAD")
  echo "!! merge in progress: MERGE_HEAD=$(git rev-parse --short "$mh")"
  echo "   new commits on $REF since MERGE_HEAD: $(git rev-list --count "$mh..$REF")"
  echo "   -> see references/merge-rules.md 'fold into pending merge'"
fi

BASE=$(git merge-base HEAD "$REF")
echo "== merge base:  $(git log -1 --format='%h %s' "$BASE")"
echo "local commits:    $(git rev-list --count "$BASE..HEAD")"
echo "upstream commits: $(git rev-list --count "$BASE..$REF")"

echo "== local adaptation files (base -> HEAD): $(git diff --name-only "$BASE" HEAD | wc -l)"
echo "== upstream changes overlapping local adaptations:"
comm -12 <(git diff --name-only "$BASE" HEAD | sort) <(git diff --name-only "$BASE" "$REF" | sort) | sed 's/^/  /'
