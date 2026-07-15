#!/usr/bin/env bash
source "$(dirname "$0")/helpers.sh"
S=$(mktemp -d); make_scratch_project "$S"; install_devflow_assets "$S"
cd "$S"
FLOW=".specify/extensions/devflow/scripts/bash/devflow-flow.sh"
LEDGER="specs/012-demo/devflow-flow.json"

# init: creates ledger; idempotent
bash "$FLOW" init attended >/dev/null
[ -f "$LEDGER" ] || fail "init must create the ledger"
bash "$FLOW" init attended | grep -q "resuming" || fail "re-init must resume, not overwrite"

# order enforcement: cannot start plan while frame pending
set +e; bash "$FLOW" start plan 2>/dev/null; rc=$?; set -e
[ "$rc" -ne 0 ] || fail "must not start plan before frame is done"

# artifact enforcement: frame can't complete without spec.md... fixture HAS spec.md, so remove it
mv specs/012-demo/spec.md /tmp/spec-backup.md
bash "$FLOW" start frame >/dev/null
set +e; err=$(bash "$FLOW" complete frame 2>&1); rc=$?; set -e
[ "$rc" -ne 0 ] || fail "frame must not complete without spec.md"
echo "$err" | grep -q "spec.md" || fail "error must name the missing artifact"
mv /tmp/spec-backup.md specs/012-demo/spec.md
bash "$FLOW" complete frame >/dev/null || fail "frame should complete with spec.md present"

# plan requires tasks.md with AC lines (fixture has them)
bash "$FLOW" start plan >/dev/null
echo "# plan" > specs/012-demo/plan.md
bash "$FLOW" complete plan >/dev/null || fail "plan should complete (plan.md + AC tasks)"

# leash requires state + leash.md
bash "$FLOW" start leash >/dev/null
set +e; bash "$FLOW" complete leash 2>/dev/null; rc=$?; set -e
[ "$rc" -ne 0 ] || fail "leash must not complete without state/leash.md"
bash .specify/extensions/devflow/scripts/bash/devflow-init.sh attended >/dev/null
bash .specify/extensions/devflow/scripts/bash/devflow-compute-leash.sh >/dev/null
bash "$FLOW" complete leash >/dev/null || fail "leash should complete after init+compute"

# analyze: ordering only
bash "$FLOW" start analyze >/dev/null && bash "$FLOW" complete analyze >/dev/null

# stop1 is a human gate: refuses without --decision, records the choice with it
bash "$FLOW" start stop1 >/dev/null
set +e; bash "$FLOW" complete stop1 2>/dev/null; rc=$?; set -e
[ "$rc" -ne 0 ] || fail "stop1 must require --decision"
# clock re-stamp on approve: set a stale started_at, approve, assert it advanced (path-B/A parity)
python3 .specify/extensions/devflow/scripts/python/devflow_state.py set specs/012-demo/loop/state.json started_at '"2020-01-01T00:00:00+00:00"'
bash "$FLOW" complete stop1 --decision approve >/dev/null || fail "stop1 approve should record"
python3 -c 'import json;f=json.load(open("'"$LEDGER"'"));assert f["phases"]["stop1"]["decision"]=="approve", f["phases"]["stop1"]'
python3 -c 'import json;s=json.load(open("specs/012-demo/loop/state.json"));assert not s["started_at"].startswith("2020"), ("clock not re-stamped after approval:",s["started_at"])' || fail "stop1 approve must re-stamp the time-box clock"

# build can't complete while the loop says continue=true
bash "$FLOW" start build >/dev/null
set +e; bash "$FLOW" complete build 2>/dev/null; rc=$?; set -e
[ "$rc" -ne 0 ] || fail "build must not complete while state.continue != false"
python3 .specify/extensions/devflow/scripts/python/devflow_state.py set specs/012-demo/loop/state.json continue false
bash "$FLOW" complete build >/dev/null || fail "build should complete once loop exhausted"

# review + fix cycles: fix-cycle-2 is the cap and parks surviving findings itself
bash "$FLOW" start review >/dev/null
echo '{"status":"findings","open":[{"id":"F1","severity":"high","file":"x.ts","summary":"leftover"}],"cycle":0}' > specs/012-demo/review/findings.json
echo "# findings: F1" > specs/012-demo/review/findings.md
bash "$FLOW" complete review >/dev/null
# cycle 1 completes even with findings still open (they flow to cycle 2)
bash "$FLOW" start fix-cycle-1 >/dev/null && bash "$FLOW" complete fix-cycle-1 >/dev/null || fail "fix-cycle-1 should complete; survivors flow to cycle 2"
# cycle 2 is the cap: completing it PARKS surviving findings (findings -> parked)
bash "$FLOW" start fix-cycle-2 >/dev/null && bash "$FLOW" complete fix-cycle-2 >/dev/null || fail "fix-cycle-2 should complete (cap)"
[ "$(python3 -c 'import json;print(json.load(open("specs/012-demo/review/findings.json"))["status"])')" = "parked" ] || fail "fix-cycle-2 must park surviving findings"
bash "$FLOW" start verify >/dev/null
set +e; bash "$FLOW" complete verify 2>/dev/null; rc=$?; set -e
[ "$rc" -ne 0 ] || fail "verify must not complete without verify-report.md"
printf '# Verify\nJudge verdict: PASS\n' > specs/012-demo/verify-report.md
bash "$FLOW" complete verify >/dev/null || fail "verify should complete with report + clean findings"

# stop2 reject stops the pipeline (exit non-zero, ledger keeps pending)
bash "$FLOW" start stop2 >/dev/null
set +e; bash "$FLOW" complete stop2 --decision reject 2>/dev/null; rc=$?; set -e
[ "$rc" -ne 0 ] || fail "stop2 reject must halt (non-zero)"
# then accept: reconcile is skippable (nothing parked/deviated), ship needs clean tree
bash "$FLOW" complete stop2 --decision accept >/dev/null
bash "$FLOW" complete reconcile --skip >/dev/null
bash "$FLOW" start ship >/dev/null
git add -A >/dev/null && git commit -qm "wip" >/dev/null
bash "$FLOW" complete ship >/dev/null || fail "ship should complete on a clean tree"
bash "$FLOW" start capture >/dev/null && bash "$FLOW" complete capture >/dev/null
[ "$(bash "$FLOW" next)" = "complete" ] || fail "pipeline should read complete"
pass "flow guard: order, artifacts, human gates, skips, full walk"
