#!/usr/bin/env bash
# Build (and optionally install) a DeepSpeed DAS wheel on Hygon DCU / DTK.
# Usage: build.sh [--ops default|all|minimal] [--no-install] [--log-dir DIR] [--dtk-env FILE]
# Writes a log ending with "=== DS_BUILD_DONE exit=<code> ===".
set -uo pipefail

OPS=default; INSTALL=1
LOG_DIR="${DS_WORK_DIR:-/workspace/deepspeed-work}/build"
DTK_ENV="${DTK_ENV:-/opt/dtk/env.sh}"
while [ $# -gt 0 ]; do
  case "$1" in
    --ops) OPS="$2"; shift 2;;
    --no-install) INSTALL=0; shift;;
    --log-dir) LOG_DIR="$2"; shift 2;;
    --dtk-env) DTK_ENV="$2"; shift 2;;
    *) echo "unknown arg $1" >&2; exit 2;;
  esac
done

test -f setup.py -a -d op_builder || { echo "ERROR: run from DeepSpeed repo root" >&2; exit 2; }
VERSION=$(cat version.txt)
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/compile_${VERSION}_$(date +%Y%m%d-%H%M).log"

case "$OPS" in
  default) OPS_ENV="DS_BUILD_OPS=1 DS_BUILD_EVOFORMER_ATTN=0 DS_BUILD_CUTLASS_OPS=1 DS_BUILD_FP_QUANTIZER=1 DS_BUILD_GDS=1 DS_BUILD_DEEP_COMPILE=1";;
  all)     OPS_ENV="DS_BUILD_OPS=1";;
  minimal) OPS_ENV="DS_BUILD_OPS=0";;
  *) echo "unknown --ops $OPS" >&2; exit 2;;
esac

{
  echo "=== DS_BUILD_START $(date '+%F %T') ==="
  echo "branch: $(git rev-parse --abbrev-ref HEAD)  head: $(git rev-parse --short HEAD)  version: $VERSION"
  echo "ops: $OPS_ENV"
} | tee "$LOG"

(
  set -e
  # shellcheck disable=SC1090
  source "$DTK_ENV"
  export BUILD_ROOT=$(pwd)
  TORCH_LIB=$(python3 -c 'import torch,os;print(os.path.join(os.path.dirname(torch.__file__),"lib"))')
  export LD_LIBRARY_PATH="$TORCH_LIB:$BUILD_ROOT/third_party/libaio_build/lib:${LD_LIBRARY_PATH:-}"
  export C_INCLUDE_PATH="$BUILD_ROOT/third_party/libaio_build/include:${C_INCLUDE_PATH:-}"
  export CPLUS_INCLUDE_PATH="$BUILD_ROOT/third_party/libaio_build/include:${CPLUS_INCLUDE_PATH:-}"
  export CFLAGS="-I$BUILD_ROOT/third_party/libaio_build/include"
  export LDFLAGS="-L$BUILD_ROOT/third_party/libaio_build/lib"
  export CXX=hipcc CC=hipcc DS_ACCELERATOR=cuda

  python3 -c "import torch; assert torch.version.hip, 'torch is not a ROCm/DTK build'; print('torch', torch.__version__, 'hip', torch.version.hip)"

  if ls dist/*.whl >/dev/null 2>&1; then
    OLD="dist/old/$(date +%Y%m%d-%H%M%S)"; mkdir -p "$OLD"; mv dist/*.whl "$OLD"/
    echo "moved previous wheels to $OLD"
  fi

  env $OPS_ENV python3 setup.py bdist_wheel
  WHL=$(ls -t dist/deepspeed-*.whl | head -1)
  echo "wheel: $WHL ($(du -h "$WHL" | cut -f1))"
  if [ "$INSTALL" = 1 ]; then
    pip3 install --force-reinstall --no-deps "$WHL"
  fi
) >>"$LOG" 2>&1
RC=$?

echo "=== DS_BUILD_DONE exit=$RC $(date '+%F %T') ===" | tee -a "$LOG"
echo "log: $LOG"
if [ $RC -ne 0 ]; then
  echo "--- first error ---"
  grep -n -m1 -E '(^|[^a-z])error:|Error:|FAILED' "$LOG" || tail -30 "$LOG"
fi
exit $RC
