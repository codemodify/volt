#!/bin/bash
PASS=0
FAIL=0
FAILED=()
for f in tests-internal/*.volt; do
  name=$(basename "$f" .volt)
  out=$(.tempbins/volt build "$f" 2>&1)
  if [ $? -ne 0 ]; then
    FAIL=$((FAIL+1))
    FAILED+=("$name BUILD: $(echo "$out" | head -2)")
    continue
  fi
  # binary is dropped at cwd with name = stem; move it to tempbins
  if [ -f "$name" ]; then
    mv "$name" ".tempbins/$name" 2>/dev/null
  fi
  PASS=$((PASS+1))
done
echo "============================"
echo "BUILD: $PASS pass / $FAIL fail"
echo "============================"
for x in "${FAILED[@]}"; do
  echo "  - $x"
done
