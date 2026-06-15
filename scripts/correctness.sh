#!/bin/bash
# Correctness harness (item 2): unlike run_smoke.sh (which only flags
# crashes), this ASSERTS that every assertion-style test returns its
# success sentinel. The project convention is `ret 42` on all-pass; a
# wrong answer returns 0/1. run_smoke counts those as "pass" (no crash),
# which is exactly how the map-key wrong-answer bug stayed hidden. This
# harness closes that gap: any test whose source contains `ret 42` MUST
# exit 42, or it's a correctness failure.
#
# Usage: build every tests-internal/*.volt into .tempbins/ first (smoke.sh
# does this), then run this.
PASS=0
FAIL=0
SKIP=0
FAILED=()

for bin in .tempbins/*; do
  name=$(basename "$bin")
  [ -x "$bin" ] || continue
  src="tests-internal/${name}.volt"
  [ -f "$src" ] || continue
  # Only check tests that opt into the `ret 42` success convention.
  if ! grep -qE '\bret 42\b' "$src"; then
    SKIP=$((SKIP+1))
    continue
  fi
  timeout 10 "$bin" >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 42 ]; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    FAILED+=("$name returned rc=$rc (expected 42)")
  fi
done

echo "============================"
echo "CORRECTNESS: $PASS pass / $FAIL fail  ($SKIP non-sentinel tests skipped)"
echo "============================"
for x in "${FAILED[@]}"; do
  echo "  - $x"
done
[ "$FAIL" -eq 0 ]
