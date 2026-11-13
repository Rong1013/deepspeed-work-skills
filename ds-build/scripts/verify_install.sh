#!/usr/bin/env bash
# Verify the installed DeepSpeed matches this checkout and its ops are usable.
# Usage: verify_install.sh [expected-ops...|none]
#   default ops: fp_quantizer gds async_io cpu_adam fused_adam; pass "none" for --ops minimal builds.
set -uo pipefail

EXPECTED=("$@")
[ ${#EXPECTED[@]} -eq 0 ] && EXPECTED=(fp_quantizer gds async_io cpu_adam fused_adam)
[ "${EXPECTED[0]}" = none ] && EXPECTED=()
FAIL=0

# Run from outside the repo so the installed package (not ./deepspeed) is imported.
REPO=$(pwd)
WANT=$(cat "$REPO/version.txt" 2>/dev/null || echo "?")
cd /tmp

python3 - "$WANT" <<'EOF' || FAIL=1
import sys
import deepspeed, torch
want = sys.argv[1]
print("deepspeed", deepspeed.__version__, "from", deepspeed.__file__)
print("hcu_version", getattr(deepspeed, "__hcu_version__", None))
print("torch", torch.__version__, "hip", torch.version.hip)
ok = deepspeed.__version__.split("+")[0] == want
print("version matches version.txt:", ok, f"(want {want})")
sys.exit(0 if ok else 1)
EOF

REPORT=$(ds_report 2>&1) || FAIL=1
echo "$REPORT" | sed -n '/op name/,/^-\{5,\}$/p' | head -60
for op in ${EXPECTED[@]+"${EXPECTED[@]}"}; do
  line=$(echo "$REPORT" | grep -E "^$op[ .]" | head -1)
  # ds_report columns: "<op> .... [installed] .... [compatible]"; prebuilt ops must be [YES] and [OKAY].
  if echo "$line" | grep -q "\[YES\].*\[OKAY\]"; then echo "OK    $op"; else echo "BAD   $op :: ${line:-not listed}"; FAIL=1; fi
done

echo "verify: $([ $FAIL = 0 ] && echo PASS || echo FAIL)"
exit $FAIL
