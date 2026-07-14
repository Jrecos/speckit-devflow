#!/usr/bin/env bash
source "$(dirname "$0")/helpers.sh"
S=$(mktemp -d); make_scratch_project "$S"; install_devflow_assets "$S"
cd "$S"
# configure a trivially green scoped test
python3 - <<'PY'
import pathlib
p = pathlib.Path(".specify/extensions/devflow/devflow-config.yml")
p.write_text(p.read_text().replace('test_scoped: ""', 'test_scoped: "true"'))
PY
GATE=".specify/extensions/devflow/scripts/bash/devflow-stop-gate.sh"

# Case 1: in_iteration, work done, NO record → must BLOCK (exit 2, reason on stderr)
write_state "$S" in_iteration=true iteration=3 current_task='"T1"' tasks_done_at_start=1
echo "code" > src.txt   # uncommitted work
set +e; err=$(echo '{}' | bash "$GATE" 2>&1 >/dev/null); rc=$?; set -e
[ "$rc" -eq 2 ] || fail "expected exit 2 without record, got $rc"
echo "$err" | grep -qi "record" || fail "block reason should mention the missing record, got: $err"

# Case 2: record exists + tests green + exactly one task newly checked → commit + exit 0
mkdir -p docs/decisions && echo "# 0001: chose X" > docs/decisions/0001-iter3-choice.md
write_state "$S" in_iteration=true iteration=3 current_task='"T1"' tasks_done_at_start=1 \
  last_record='"docs/decisions/0001-iter3-choice.md"'
python3 - <<'PY'
import pathlib
t = pathlib.Path("specs/012-demo/tasks.md")
t.write_text(t.read_text().replace("- [ ] T1 first thing", "- [x] T1 first thing"))
PY
before=$(git rev-list --count HEAD)
echo '{}' | bash "$GATE" || fail "GREEN close should exit 0"
after=$(git rev-list --count HEAD)
[ "$after" -eq $((before+1)) ] || fail "GREEN close must auto-commit exactly one commit"
[ "$(read_state_key "$S" in_iteration)" = "false" ] || fail "in_iteration must clear on close"
git diff --quiet && git diff --cached --quiet || fail "working tree must be clean after commit"
pass "stop-gate GREEN: blocks without record, commits+clears with it"
