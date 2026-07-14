#!/usr/bin/env bash
source "$(dirname "$0")/helpers.sh"
S=$(mktemp -d); make_scratch_project "$S"; install_devflow_assets "$S"
cd "$S"
GATE=".specify/extensions/devflow/scripts/bash/devflow-stop-gate.sh"
# 1. No state file at all → exit 0
rm -f specs/012-demo/loop/state.json
echo '{}' | bash "$GATE" || fail "no state file must be a no-op"
# 2. State exists but in_iteration=false → exit 0 even with dirty tree and no record
write_state "$S" in_iteration=false
echo "scratch" > notes.txt
before=$(git rev-list --count HEAD)
echo '{}' | bash "$GATE" || fail "non-loop session must exit freely"
[ "$(git rev-list --count HEAD)" -eq "$before" ] || fail "no-op must not commit"
pass "stop-gate scoping: inert outside iterations"
