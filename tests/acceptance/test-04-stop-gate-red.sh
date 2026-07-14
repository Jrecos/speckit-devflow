#!/usr/bin/env bash
source "$(dirname "$0")/helpers.sh"
S=$(mktemp -d); make_scratch_project "$S"; install_devflow_assets "$S"
cd "$S"
GATE=".specify/extensions/devflow/scripts/bash/devflow-stop-gate.sh"
# RED close: outcome failed + failure note → exit 0, NO commit, in_iteration cleared, attempts bumped
write_state "$S" in_iteration=true iteration=9 current_task='"T2"' \
  iteration_outcome='"failed"' failure_notes='{"T2":"flaky limiter timing"}' attempts='{"T2":1}'
echo "half-done" > wip.txt
before=$(git rev-list --count HEAD)
echo '{}' | bash "$GATE" || fail "RED close should exit 0"
after=$(git rev-list --count HEAD)
[ "$after" -eq "$before" ] || fail "RED close must NOT commit"
[ "$(read_state_key "$S" in_iteration)" = "false" ] || fail "in_iteration must clear on RED close"
# honest RED closes count toward the parking cap
python3 -c 'import json;s=json.load(open("specs/012-demo/loop/state.json"));assert s["attempts"]["T2"]==2, s["attempts"]' \
  || fail "RED close must increment attempts (1→2)"

# RED without a failure note → still blocked (exit 2), attempts NOT bumped
write_state "$S" in_iteration=true iteration=10 current_task='"T2"' iteration_outcome='"failed"' attempts='{"T2":1}'
set +e; echo '{}' | bash "$GATE" 2>/dev/null; rc=$?; set -e
[ "$rc" -eq 2 ] || fail "failed outcome without failure note must block, got $rc"
python3 -c 'import json;s=json.load(open("specs/012-demo/loop/state.json"));assert s["attempts"]["T2"]==1, s["attempts"]' \
  || fail "blocked exit must NOT increment attempts"
pass "stop-gate RED: clean no-commit exit + attempts bump; blocks (no bump) when note missing"
