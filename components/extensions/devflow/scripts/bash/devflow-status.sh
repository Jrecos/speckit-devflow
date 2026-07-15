#!/usr/bin/env bash
# DevFlow status (ADR-0023 extraction). READ-ONLY: renders the compact loop-state block and
# the ONE mechanically-chosen next action (the 6-branch ladder — the guarantee). Writes nothing.
# Both drivers and the user share this one implementation of "where does the feature stand".
set -euo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}"

if [ ! -f .specify/feature.json ]; then
  echo "no active feature — start one with /speckit-devflow-start or /speckit-specify"
  exit 0
fi
FDIR=$(python3 -c 'import json;print(json.load(open(".specify/feature.json"))["feature_directory"])')

# The ledger line is `FLOW next` verbatim (only when a ledger exists).
LEDGER="—"
if [ -f "$FDIR/devflow-flow.json" ]; then
  LEDGER=$(bash .specify/extensions/devflow/scripts/bash/devflow-flow.sh next 2>/dev/null || echo "?")
fi

python3 - "$FDIR" "$LEDGER" <<'PY'
import json, os, re, sys, datetime
fdir, ledger = sys.argv[1], sys.argv[2]
sys.path.insert(0, ".specify/extensions/devflow/scripts/python")
import devflow_tasks as T

def load(p):
    try: return json.load(open(p))
    except Exception: return None

state = load(f"{fdir}/loop/state.json")
tasks_txt = open(f"{fdir}/tasks.md").read() if os.path.exists(f"{fdir}/tasks.md") else ""
done = T.count_done(tasks_txt)
open_ids = T.open_task_ids(tasks_txt)

if state is None:
    feature = os.path.basename(fdir); mode = entry = cycle = "?"
    it = "?"; used = total = "?"; parked = []; verdicts = {}; outcome = "?"
    elapsed = box = "?"; budget_left = clock_left = True; total_n = 0
else:
    feature = state.get("feature", os.path.basename(fdir))
    mode = state.get("mode", "?"); entry = state.get("entry", "?"); cycle = state.get("cycle", "?")
    it = state.get("iteration", "?")
    b = state.get("budget", {}) or {}
    used = b.get("used", "?"); total = b.get("total", "?"); total_n = b.get("total", 0) or 0
    parked = state.get("parked", []) or []
    verdicts = state.get("verdicts", {}) or {}
    outcome = state.get("iteration_outcome"); outcome = "null" if outcome is None else outcome
    box = state.get("time_box_hours", "?")
    try:
        started = datetime.datetime.fromisoformat(state["started_at"])
        elapsed_h = (datetime.datetime.now(datetime.timezone.utc) - started).total_seconds()/3600
        elapsed = f"{elapsed_h:.1f}"
        clock_left = elapsed_h < float(box)
    except Exception:
        elapsed = "?"; clock_left = True
    budget_left = isinstance(used, int) and isinstance(total, int) and used < total

open_unparked = [t for t in open_ids if t not in parked]
open_count = len(open_ids)

# review + verify status
fj_p = f"{fdir}/review/findings.json"
review = "not run"
if os.path.exists(fj_p):
    try: review = json.load(open(fj_p)).get("status", "?")
    except Exception: review = "?"
vr_p = f"{fdir}/verify-report.md"
verify = "not run"
if os.path.exists(vr_p):
    m = re.search(r"^Judge verdict:\s*(\S+)", open(vr_p).read(), re.M)
    verify = m.group(1) if m else "see report"

verdict_str = ", ".join(f"{k}: {v.get('verdict','?')} {v.get('reason','')}".strip()
                        for k, v in verdicts.items()) or "none"
parked_str = ", ".join(parked) if parked else "none"

print(f"DevFlow · {feature} · mode={mode} · entry={entry} (cycle {cycle})")
print(f"iteration {it} · budget {used}/{total} · clock {elapsed}h/{box}h")
print(f"tasks: {done} done · {open_count} open · parked: {parked_str}")
print(f"last outcome: {outcome} · verdicts: {verdict_str}")
print(f"review: {review} · verify: {verify}")
print(f"ledger: {ledger}")

# --- the 6-branch next-action ladder (first match wins) ---
budget_exhausted = isinstance(total_n, int) and total_n > 0 and isinstance(used, int) and used >= total_n
clock_exhausted = not clock_left
if budget_exhausted or clock_exhausted:
    action = "STOP #2 triage (park report)"
elif open_unparked and budget_left and clock_left:
    action = "continue the loop (dispatch next iterate / resume the workflow)"
elif not open_unparked and not os.path.exists(fj_p):
    action = "run Review"
elif review == "findings":
    action = "convert + fix cycle"
elif review in ("clean", "parked") and not os.path.exists(vr_p):
    action = "run Verify"
elif os.path.exists(vr_p):
    action = "STOP #2 decision"
else:
    action = "inspect state (no branch matched — unusual state)"
print(f"next action: {action}")
PY
