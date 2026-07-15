#!/usr/bin/env bash
source "$(dirname "$0")/helpers.sh"
S=$(mktemp -d); make_scratch_project "$S"; install_devflow_assets "$S"
cd "$S"
LS=".specify/extensions/devflow/scripts/bash/devflow-loop-status.sh"
run_ls() { bash "$LS"; }

# Brake 1 — task exhaustion: all tasks done → continue=false, reason tasks_exhausted
python3 - <<'PY'
import pathlib
t = pathlib.Path("specs/012-demo/tasks.md")
t.write_text(t.read_text().replace("- [ ]", "- [x]"))
PY
write_state "$S" budget='{"used":1,"total":5}'
out=$(run_ls)
echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["continue"]==False and d["reason"]=="tasks_exhausted", d' || fail "exhaustion brake: $out"

# Brake 2 — budget: open tasks but budget.used >= total → clean park of remaining tasks
cd /tmp   # never rm -rf the directory we're standing in
make_scratch_project "$S"; install_devflow_assets "$S"; cd "$S"
write_state "$S" budget='{"used":5,"total":5}'
out=$(run_ls)
echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["continue"]==False and d["reason"]=="budget_exhausted", d' || fail "budget brake: $out"
# gap-D guard: exhaustion parks ALL remaining open tasks (so accept routes via reconcile)
python3 -c '
import json;s=json.load(open("specs/012-demo/loop/state.json"))
assert set(s["parked"]) >= {"T1","T2"}, s["parked"]
assert "T1" in s["failure_notes"], s["failure_notes"]' || fail "budget exhaustion must park open tasks"

# Brake 3 — time-box: started_at years ago with 4h box
write_state "$S" budget='{"used":1,"total":5}' started_at='"2020-01-01T00:00:00+00:00"'
out=$(run_ls)
echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["continue"]==False and d["reason"]=="time_box_exceeded", d' || fail "time-box brake: $out"

# Backstop — dispatch died mid-iteration: in_iteration still true → failed iteration recorded
write_state "$S" in_iteration=true current_task='"T1"' budget='{"used":1,"total":5}'
out=$(run_ls)
[ "$(read_state_key "$S" in_iteration)" = "false" ] || fail "backstop must clear in_iteration"
python3 -c '
import json;s=json.load(open("specs/012-demo/loop/state.json"))
assert s["attempts"].get("T1")==1, s["attempts"]
assert "T1" in s["failure_notes"], s["failure_notes"]' || fail "backstop must count attempt + note"

# Parking — attempts at cap → task parked, continue still true (other tasks open)
write_state "$S" budget='{"used":2,"total":9}' attempts='{"T1":2}'
out=$(run_ls)
python3 -c '
import json;s=json.load(open("specs/012-demo/loop/state.json"))
assert "T1" in s["parked"], s["parked"]' || fail "cap must park T1"
echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["continue"]==True, d' || fail "loop should continue past parked task"
# Anti-phantom budget (2026-07-15 finding): budget spends per iteration ADVANCE, not per call.
cd /tmp; make_scratch_project "$S"; install_devflow_assets "$S"; cd "$S"
write_state "$S" iteration=0 budget='{"used":0,"total":9}'
run_ls >/dev/null; run_ls >/dev/null   # two spurious calls before any dispatch
[ "$(python3 -c 'import json;print(json.load(open("specs/012-demo/loop/state.json"))["budget"]["used"])')" = "0" ] || fail "spurious loop-status calls (iteration=0) must NOT spend budget"
# now an iteration advances → exactly one budget count, and a repeat call doesn't double it
write_state "$S" iteration=1 budget='{"used":0,"total":9}'
run_ls >/dev/null
u1=$(python3 -c 'import json;print(json.load(open("specs/012-demo/loop/state.json"))["budget"]["used"])')
run_ls >/dev/null   # same iteration, no advance
u2=$(python3 -c 'import json;print(json.load(open("specs/012-demo/loop/state.json"))["budget"]["used"])')
[ "$u1" = "1" ] && [ "$u2" = "1" ] || fail "budget must count once per iteration advance, not per call (got $u1 then $u2)"
pass "loop-status: three brakes + backstop + parking + iteration-keyed budget"
