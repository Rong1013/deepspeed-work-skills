#!/usr/bin/env bash
# Fold newer upstream commits into an uncommitted (already resolved & staged) merge,
# without committing anything on the current branch.
# Usage: fold_into_pending_merge.sh <new-upstream-ref>
set -euo pipefail

NEW="${1:?usage: fold_into_pending_merge.sh <new-upstream-ref>}"
GITDIR=$(git rev-parse --git-dir)
TOP=$(git rev-parse --show-toplevel)

test -f "$GITDIR/MERGE_HEAD" || { echo "ERROR: no merge in progress" >&2; exit 2; }
[ -z "$(git diff --name-only)" ] || { echo "ERROR: unstaged changes present; stage or ask user first" >&2; exit 2; }
[ -z "$(git diff --name-only --diff-filter=U)" ] || { echo "ERROR: unresolved conflicts remain" >&2; exit 2; }

OLD=$(git rev-parse MERGE_HEAD)
NEWC=$(git rev-parse "$NEW^{commit}")
git merge-base --is-ancestor "$OLD" "$NEWC" || { echo "ERROR: $NEW does not contain old MERGE_HEAD" >&2; exit 2; }

TREE=$(git write-tree)
SNAP=$(git commit-tree "$TREE" -p HEAD -p "$OLD" -m "snapshot of staged merge of $OLD (not on any branch)")
BACKUP="refs/backup/pending-merge-$(git rev-parse --short "$OLD")"
git update-ref "$BACKUP" "$SNAP"
echo "snapshot: $SNAP  (backup ref: $BACKUP)"

WT="${TMPDIR:-/tmp}/ds-fold-$$"
git worktree add --detach "$WT" "$SNAP" >/dev/null
if ! git -C "$WT" merge --no-commit --no-ff "$NEWC"; then
  echo "CONFLICTS in temp worktree $WT:"
  git -C "$WT" diff --name-only --diff-filter=U
  echo "Resolve there (git -C $WT add ...), then rerun the apply step manually:"
  echo "  git read-tree --reset -u \$(git -C $WT write-tree) && git rev-parse $NEWC > $GITDIR/MERGE_HEAD"
  exit 1
fi

NT=$(git -C "$WT" write-tree)
cd "$TOP"
git read-tree --reset -u "$NT"
echo "$NEWC" > "$GITDIR/MERGE_HEAD"
git worktree remove --force "$WT"
git worktree prune

echo "folded $(git rev-list --count "$OLD..$NEWC") commits; MERGE_HEAD -> $(git rev-parse --short "$NEWC")"
git diff --cached --stat "$SNAP" | tail -1
echo "restore previous state if needed: git read-tree --reset -u $BACKUP && echo $OLD > $GITDIR/MERGE_HEAD"
