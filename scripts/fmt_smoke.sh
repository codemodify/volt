#!/bin/bash
# fmt round-trip smoke: format every tests-internal/*.volt and verify
# the formatted source still builds + runs to the same exit code.
# A failure here means `volt fmt` is corrupting source — which would
# be terrible for `gofmt-on-save` workflows.
PASS=0
FAIL=0
DIFFERS=0
FAILED=()
for f in tests-internal/*.volt; do
  name=$(basename "$f" .volt)
  # Get the original exit code (allow build failure for negative tests).
  orig_exit=""
  if [ -x ".tempbins/$name" ]; then
    timeout 10 ".tempbins/$name" >/dev/null 2>&1
    orig_exit=$?
  fi
  # Format → write to a temp file.
  fmtted="/tmp/fmt_${name}.volt"
  if ! .tempbins/volt fmt "$f" > "$fmtted" 2>/dev/null; then
    # fmt itself failed
    FAIL=$((FAIL+1))
    FAILED+=("$name fmt-crash")
    continue
  fi
  # Build the formatted version.
  out=$(.tempbins/volt build "$fmtted" 2>&1)
  build_rc=$?
  # Move the binary out of cwd.
  fmtted_bin="fmt_${name}"
  if [ -f "$fmtted_bin" ]; then
    mv "$fmtted_bin" "/tmp/$fmtted_bin"
  fi
  if [ $build_rc -ne 0 ]; then
    FAIL=$((FAIL+1))
    FAILED+=("$name fmt-rebuild-failed")
    continue
  fi
  if [ -z "$orig_exit" ]; then
    # No original binary; just confirm the formatted version builds.
    PASS=$((PASS+1))
    continue
  fi
  # Run formatted binary, compare exit codes.
  timeout 10 "/tmp/$fmtted_bin" >/dev/null 2>&1
  new_exit=$?
  if [ "$new_exit" = "$orig_exit" ]; then
    PASS=$((PASS+1))
  else
    DIFFERS=$((DIFFERS+1))
    FAILED+=("$name exit_codes_differ orig=$orig_exit new=$new_exit")
  fi
done
echo "============================"
echo "FMT-ROUNDTRIP: $PASS pass / $FAIL fmt-or-build-fail / $DIFFERS exit-differs"
echo "============================"
for x in "${FAILED[@]}"; do
  echo "  - $x"
done
