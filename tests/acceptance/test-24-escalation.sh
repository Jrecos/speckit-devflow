#!/usr/bin/env bash
# test-24 — model escalation (ADR-0026): the maker tier is a PURE FUNCTION of state.attempts,
# and the last tier (claude) is reached BEFORE the park cap of 6. No parallel counter.
source "$(dirname "$0")/helpers.sh"
S=$(mktemp -d); make_scratch_project "$S"; install_devflow_assets "$S"
cd "$S"
ESC=".specify/extensions/devflow/scripts/bash/devflow-escalate.sh"
STATE_PY=".specify/extensions/devflow/scripts/python/devflow_state.py"
STATE="specs/012-demo/loop/state.json"
write_state "$S"

# tier derives from attempts: 0-2 -> local, 3 -> assistant, 4 -> agentic, >=5 -> claude
expect() {  # attempts, expected-tier, expected-index
  python3 "$STATE_PY" set "$STATE" "attempts.T1" "$1" >/dev/null
  local t i
  t=$(CLAUDE_PROJECT_DIR="$S" bash "$ESC" tier T1)
  i=$(CLAUDE_PROJECT_DIR="$S" bash "$ESC" index T1)
  [ "$t" = "$2" ] || fail "attempts=$1 expected tier '$2', got '$t'"
  [ "$i" = "$3" ] || fail "attempts=$1 expected index $3, got $i"
}
expect 0 local     0
expect 1 local     0
expect 2 local     0
expect 3 assistant 1
expect 4 agentic   2
expect 5 claude    3
expect 6 claude    3

# The park cap (max_attempts_per_task) must be strictly greater than the attempts at which the
# last tier engages — otherwise the strongest maker never acts before the park.
CAP=$(grep -E 'max_attempts_per_task:' .specify/extensions/devflow/devflow-config.yml | grep -oE '[0-9]+' | head -1)
[ "$CAP" -ge 6 ] || fail "max_attempts_per_task ($CAP) must be >=6 so 'claude' (attempts 5) acts before the park"

# A task with no attempts key at all defaults to tier 0 (no crash).
python3 "$STATE_PY" set "$STATE" "attempts" '{}' >/dev/null
t=$(CLAUDE_PROJECT_DIR="$S" bash "$ESC" tier T_missing)
[ "$t" = "local" ] || fail "missing attempts must default to tier 0 (local), got '$t'"

pass "escalation: tier is a pure function of attempts (0-2/3/4/5+), claude before the park cap"
