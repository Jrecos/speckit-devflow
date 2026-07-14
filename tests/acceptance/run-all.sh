#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"
failures=0
for t in test-*.sh; do
  echo "── $t"
  if bash "$t"; then echo "   ✓ $t"; else echo "   ✗ $t"; failures=$((failures+1)); fi
done
echo
[ "$failures" -eq 0 ] && echo "ALL ACCEPTANCE TESTS PASS" || { echo "$failures test file(s) FAILED"; exit 1; }
