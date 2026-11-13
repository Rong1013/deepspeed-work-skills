#!/usr/bin/env bash
# Detect local adaptations that a merge silently dropped.
#
# A file is an "adaptation" if the local branch changed it relative to the merge base.
# After the merge (result = index by default), each adaptation is classified:
#   KEPT     result == local
#   MIXED    result differs from both local and upstream (hand-merged)
#   SAME     local == upstream (upstream made the identical change; nothing to lose)
#   LOST     result == upstream != local   <- adaptation dropped, review!
#   DELETED  file absent from result while local had it
#
# Usage:
#   check_adaptations.sh --local <ref> --upstream <ref> [--result <ref>|--index] [--all]
# Defaults: --local ORIG_HEAD (falls back to HEAD), --upstream MERGE_HEAD, --result index.
# Exit code 1 if any LOST or DELETED entries exist.
set -euo pipefail

LOCAL=""; UPSTREAM="MERGE_HEAD"; RESULT=""; SHOW_ALL=0
while [ $# -gt 0 ]; do
  case "$1" in
    --local) LOCAL="$2"; shift 2;;
    --upstream) UPSTREAM="$2"; shift 2;;
    --result) RESULT="$2"; shift 2;;
    --index) RESULT=""; shift;;
    --all) SHOW_ALL=1; shift;;
    *) echo "unknown arg $1" >&2; exit 2;;
  esac
done

if [ -z "$LOCAL" ]; then
  # During an uncommitted merge HEAD is still the local side.
  if [ -f "$(git rev-parse --git-dir)/MERGE_HEAD" ]; then LOCAL=HEAD; else LOCAL=ORIG_HEAD; fi
fi

if [ -z "$RESULT" ]; then
  RESULT_TREE=$(git write-tree)
  RESULT_DESC="index"
else
  RESULT_TREE=$(git rev-parse "$RESULT^{tree}")
  RESULT_DESC="$RESULT"
fi

BASE=$(git merge-base "$LOCAL" "$UPSTREAM")
echo "local=$(git rev-parse --short "$LOCAL") upstream=$(git rev-parse --short "$UPSTREAM") base=$(git rev-parse --short "$BASE") result=$RESULT_DESC"

blob() { git rev-parse --verify --quiet "$1:$2" 2>/dev/null || echo "-"; }

declare -A count=([KEPT]=0 [MIXED]=0 [SAME]=0 [LOST]=0 [DELETED]=0)
while IFS= read -r f; do
  l=$(blob "$LOCAL" "$f"); u=$(blob "$UPSTREAM" "$f"); r=$(blob "$RESULT_TREE" "$f")
  if   [ "$l" = "$u" ];                 then s=SAME
  elif [ "$r" = "-" ] && [ "$l" != "-" ]; then s=DELETED
  elif [ "$r" = "$l" ];                 then s=KEPT
  elif [ "$r" = "$u" ];                 then s=LOST
  else                                       s=MIXED
  fi
  count[$s]=$((count[$s]+1))
  if [ "$SHOW_ALL" = 1 ] || [ "$s" = LOST ] || [ "$s" = DELETED ]; then
    printf '%-8s %s\n' "$s" "$f"
  fi
done < <(git diff --name-only "$BASE" "$LOCAL")

echo "summary: KEPT=${count[KEPT]} MIXED=${count[MIXED]} SAME=${count[SAME]} LOST=${count[LOST]} DELETED=${count[DELETED]}"
[ "${count[LOST]}" -eq 0 ] && [ "${count[DELETED]}" -eq 0 ]
