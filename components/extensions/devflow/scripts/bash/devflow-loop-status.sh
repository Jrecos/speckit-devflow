#!/usr/bin/env bash
# DevFlow loop-status: the do-while's condition source + engine backstop.
# Prints JSON {"continue","reason","open_tasks","budget_used","budget_total"}.
# Budget semantics: budget.used counts loop passes (one per dispatch), incremented
# here — not by iterate — so failed dispatches still spend budget (that's the leash).
set -euo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}"
FDIR=$(python3 -c 'import json;print(json.load(open(".specify/feature.json"))["feature_directory"])')
STATE="$FDIR/loop/state.json"
CFG=".specify/extensions/devflow/devflow-config.yml"
python3 - "$STATE" "$FDIR/tasks.md" "$CFG" <<'PY'
import json, re, sys, datetime
state_p, tasks_p, cfg_p = sys.argv[1:4]
state = json.load(open(state_p))
cfg = open(cfg_p).read()
cap = int(re.search(r"max_attempts_per_task:\s*(\d+)", cfg).group(1))

# --- backstop: dispatch ended without a valid close ---
if state.get("in_iteration"):
    t = state.get("current_task") or "unknown"
    state["attempts"][t] = state["attempts"].get(t, 0) + 1
    state["failure_notes"][t] = state["failure_notes"].get(t) or \
        "iteration ended without a valid close (dispatch died or gate cap hit) — treated as failed"
    state["in_iteration"] = False
    state["iteration_outcome"] = "failed"

# --- parking ---
tasks_txt = open(tasks_p).read()
open_tasks = re.findall(r"^- \[ \] (\S+)", tasks_txt, re.M)
for t, n in state["attempts"].items():
    if n >= cap and t in open_tasks and t not in state["parked"]:
        state["parked"].append(t)
pickable = [t for t in open_tasks if t not in state["parked"]]

# --- budget bookkeeping: count a pass ONLY when an iteration actually advanced.
# Keyed to `iteration`, not to how many times this script is called — so a spurious or
# out-of-order call (e.g. a "peek" before the first dispatch, or the orchestrator calling
# it twice) cannot inflate the budget or burn the leash. A dispatch that opened then failed
# still counts (iterate bumps `iteration` at open). Live-run finding, 2026-07-15.
iter_now = state.get("iteration", 0)
last_counted = state["budget"].get("last_counted_iteration", 0)
if iter_now > last_counted:
    state["budget"]["used"] = state["budget"].get("used", 0) + 1
    state["budget"]["last_counted_iteration"] = iter_now

# --- brakes ---
reason = None
if not pickable:
    reason = "tasks_exhausted"
elif state["budget"]["used"] >= state["budget"]["total"]:
    reason = "budget_exhausted"
else:
    started = datetime.datetime.fromisoformat(state["started_at"])
    hours = (datetime.datetime.now(datetime.timezone.utc) - started).total_seconds() / 3600
    if hours >= float(state.get("time_box_hours", 4)):
        reason = "time_box_exceeded"

# Budget/time exhaustion is a CLEAN PARK (ADR-0016): remaining open tasks are parked
# with a note, so STOP #2's accept path routes through reconcile-contract (gap D guard —
# plain accept must never ship open work without a spec edit).
if reason in ("budget_exhausted", "time_box_exceeded"):
    for t in pickable:
        if t not in state["parked"]:
            state["parked"].append(t)
            state["failure_notes"][t] = state["failure_notes"].get(t) or \
                f"parked without attempt: loop ended ({reason})"

state["continue"] = reason is None
state["exit_reason"] = reason
json.dump(state, open(state_p, "w"), indent=2)
print(json.dumps({
    "continue": state["continue"], "reason": reason or "ok",
    "open_tasks": len(pickable),
    "budget_used": state["budget"]["used"], "budget_total": state["budget"]["total"],
}))
PY
