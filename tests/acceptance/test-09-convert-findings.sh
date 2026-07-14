#!/usr/bin/env bash
source "$(dirname "$0")/helpers.sh"
S=$(mktemp -d); make_scratch_project "$S"; install_devflow_assets "$S"
cd "$S"
write_state "$S"
echo '{"status":"findings","open":[{"id":"F1","severity":"high","file":"src/a.ts","summary":"SQL injection in signup"}],"cycle":0}' > specs/012-demo/review/findings.json
bash .specify/extensions/devflow/scripts/bash/devflow-convert-findings.sh 1
grep -q '\- \[ \] F1 fix: SQL injection in signup (finding F1)' specs/012-demo/tasks.md || fail "fix-task not appended"
[ "$(read_state_key "$S" entry)" = '"fix-tasks"' ] || fail "entry not flipped"
[ "$(read_state_key "$S" cycle)" = "1" ] || fail "cycle not set"
# 1 fix-task → ceil(1*2.5)=3
python3 -c 'import json;s=json.load(open("specs/012-demo/loop/state.json"));assert s["budget"]["total"]==3 and s["budget"]["used"]==0, s["budget"]' || fail "fix budget wrong"

# resume-idempotency: same cycle again must NOT duplicate the block
before=$(grep -c 'F1 fix:' specs/012-demo/tasks.md)
bash .specify/extensions/devflow/scripts/bash/devflow-convert-findings.sh 1
after=$(grep -c 'F1 fix:' specs/012-demo/tasks.md)
[ "$before" -eq "$after" ] || fail "re-running same cycle duplicated fix-tasks"

# clean findings → no-op
echo '{"status":"clean","open":[],"cycle":1}' > specs/012-demo/review/findings.json
before=$(md5 -q specs/012-demo/tasks.md 2>/dev/null || md5sum specs/012-demo/tasks.md | cut -d' ' -f1)
bash .specify/extensions/devflow/scripts/bash/devflow-convert-findings.sh 2
after=$(md5 -q specs/012-demo/tasks.md 2>/dev/null || md5sum specs/012-demo/tasks.md | cut -d' ' -f1)
[ "$before" = "$after" ] || fail "clean findings must be a no-op"
pass "convert-findings: fix-tasks appended, state flipped, idempotent, clean no-op"
