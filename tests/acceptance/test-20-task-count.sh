#!/usr/bin/env bash
# C5 (ADR-0023): the tasks.md count primitive is folded into devflow_tasks.py (used by
# init/compute-leash/loop-status/stop-gate/stop2-prep/open-iteration/status). This test proves
# the helper is BYTE-IDENTICAL to the inline regexes it replaced, and that devflow-open-iteration
# performs the exact 5-command transition. The 5 folded scripts' own tests (03/04/06/10) are the
# integration safety net.
source "$(dirname "$0")/helpers.sh"
S=$(mktemp -d); make_scratch_project "$S"; install_devflow_assets "$S"
cd "$S"

# --- the helper equals the exact old inline regexes (incl. the lowercase-[x]-only quirk) ---
python3 - <<'PY'
import sys, re
sys.path.insert(0, ".specify/extensions/devflow/scripts/python")
import devflow_tasks as T
samples = [
  ("- [x] A\n- [ ] B\n- [x] C\n- [ ] D E\n", 2, 2, ["B", "D"]),
  ("", 0, 0, []),
  ("- [x] only\n", 1, 0, []),
  ("- [ ] a1\n  - AC: sub\n- [x] b2\n", 1, 1, ["a1"]),
  ("- [X] upper\n- [ ] x\n", 0, 1, ["x"]),   # uppercase [X] not counted — matches inline regex
]
for text, ed, eo, eids in samples:
    old_done = len(re.findall(r"^- \[x\]", text, re.M))
    old_open = len(re.findall(r"^- \[ \]", text, re.M))
    old_ids  = re.findall(r"^- \[ \] (\S+)", text, re.M)
    assert T.count_done(text)    == old_done == ed,  (text, T.count_done(text), old_done, ed)
    assert T.count_open(text)    == old_open == eo,  (text, T.count_open(text), old_open, eo)
    assert T.open_task_ids(text) == old_ids  == eids, (text, T.open_task_ids(text), old_ids, eids)
print("devflow_tasks matches the inline regexes it replaced")
PY

# --- devflow-open-iteration.sh: the fixed 5-command transition ---
SJ="specs/012-demo/loop/state.json"
bash .specify/extensions/devflow/scripts/bash/devflow-init.sh attended >/dev/null   # iteration 0, fixture done=1
bash .specify/extensions/devflow/scripts/bash/devflow-open-iteration.sh >/dev/null
python3 -c 'import json,sys;d=json.load(open(sys.argv[1]))
assert d["in_iteration"] is True, d["in_iteration"]
assert d["iteration"]==1, d["iteration"]
assert d["iteration_outcome"] is None, d["iteration_outcome"]
assert d["last_record"] is None, d["last_record"]
assert d["tasks_done_at_start"]==1, d["tasks_done_at_start"]' "$SJ" || fail "open-iteration: transition or done-count wrong"

# mark another task done, open again → iteration bumps, tasks_done_at_start tracks the new count
perl -0pi -e 's/- \[ \] T1/- [x] T1/' specs/012-demo/tasks.md
bash .specify/extensions/devflow/scripts/bash/devflow-open-iteration.sh >/dev/null
python3 -c 'import json,sys;d=json.load(open(sys.argv[1]))
assert d["iteration"]==2, d["iteration"]
assert d["tasks_done_at_start"]==2, d["tasks_done_at_start"]' "$SJ" || fail "open-iteration: second call wrong"

pass "task-count helper byte-identical to inline regexes; open-iteration performs the 5-command transition"
