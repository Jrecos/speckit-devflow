#!/usr/bin/env bash
# C3 (ADR-0023): the status render + the 6-branch next-action ladder now live in
# devflow-status.sh. This test pins the ladder (the guarantee) across representative states,
# checks the rendered block, and enforces read-only.
source "$(dirname "$0")/helpers.sh"
S=$(mktemp -d); make_scratch_project "$S"; install_devflow_assets "$S"
cd "$S"
ST=".specify/extensions/devflow/scripts/bash/devflow-status.sh"
SJ="specs/012-demo/loop/state.json"
bash .specify/extensions/devflow/scripts/bash/devflow-init.sh attended >/dev/null
bash .specify/extensions/devflow/scripts/bash/devflow-compute-leash.sh >/dev/null   # n=2 open → total=5

setbudget() { python3 -c 'import json,sys;p=sys.argv[1];d=json.load(open(p));d["budget"]["used"]=int(sys.argv[2]);json.dump(d,open(p,"w"))' "$SJ" "$1"; }

# --- render + branch 2 (open tasks, budget & clock left → continue) ---
out=$(bash "$ST")
echo "$out" | grep -q '^DevFlow · 012-demo · mode=attended · entry=tasks' || fail "status header wrong: $out"
echo "$out" | grep -q '^tasks: 1 done · 2 open · parked: none' || fail "task counts wrong: $out"
echo "$out" | grep -q '^review: not run · verify: not run' || fail "review/verify line wrong: $out"
echo "$out" | grep -q '^next action: continue the loop' || fail "branch 2 (continue) wrong: $out"

# --- branch 1 (budget exhausted → STOP #2 triage), highest priority even with open tasks ---
setbudget 5
bash "$ST" | grep -q '^next action: STOP #2 triage (park report)' || fail "branch 1 (budget exhausted) wrong"
setbudget 0

# --- branch 3 (all tasks done, no findings.json → run Review) ---
perl -pi -e 's/^- \[ \]/- [x]/' specs/012-demo/tasks.md
bash "$ST" | grep -q '^tasks: 3 done · 0 open' || fail "done count after check-off wrong"
bash "$ST" | grep -q '^next action: run Review' || fail "branch 3 (run Review) wrong"

# --- branch 4 (findings status = findings → convert + fix cycle) ---
printf '%s\n' '{"status":"findings","open":[{"id":"F1","severity":"low","file":"x","summary":"y"}],"cycle":0}' > specs/012-demo/review/findings.json
bash "$ST" | grep -q '^next action: convert + fix cycle' || fail "branch 4 (convert+fix) wrong"
bash "$ST" | grep -q '^review: findings ·' || fail "review status not rendered"

# --- branch 5 (review clean, no verify-report → run Verify) ---
printf '%s\n' '{"status":"clean","open":[],"cycle":0}' > specs/012-demo/review/findings.json
bash "$ST" | grep -q '^next action: run Verify' || fail "branch 5 (run Verify) wrong"

# --- branch 6 (verify-report exists → STOP #2 decision) ---
printf 'Judge verdict: PASS\n' > specs/012-demo/verify-report.md
bash "$ST" | grep -q '^next action: STOP #2 decision' || fail "branch 6 (STOP #2 decision) wrong"
bash "$ST" | grep -q '^review: clean · verify: PASS' || fail "verify verdict not rendered"

# --- read-only: a status call writes nothing ---
git add -A; git commit -qm "wip fixtures" >/dev/null
bash "$ST" >/dev/null
{ git diff --quiet && git diff --cached --quiet; } || fail "status must be read-only — it changed the tree"

pass "status: 6-branch ladder correct, block rendered, read-only"
