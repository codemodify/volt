#!/bin/bash
# A test is "broken" only if it crashes (SIGSEGV=139, SIGABRT=134, killed=137, timeout=124)
PASS=0
CRASH=0
FAILED=()

for bin in .tempbins/*; do
  name=$(basename "$bin")
  [ -x "$bin" ] || continue
  [ -f "tests-internal/${name}.volt" ] || continue
  timeout 10 "$bin" >/dev/null 2>&1
  rc=$?
  case $rc in
    124|125|134|137|139|143)
      CRASH=$((CRASH+1))
      FAILED+=("$name rc=$rc")
      ;;
    *)
      PASS=$((PASS+1))
      ;;
  esac
done

echo "RUN-NO-CRASH: $PASS pass / $CRASH crashed"
for x in "${FAILED[@]}"; do
  echo "  - $x"
done
