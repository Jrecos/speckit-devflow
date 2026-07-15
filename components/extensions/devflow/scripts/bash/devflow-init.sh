#!/usr/bin/env bash
# Initialize (or refresh) DevFlow loop state for the current feature.
set -euo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}"
MODE="${1:-attended}"
FDIR=$(python3 -c 'import json;print(json.load(open(".specify/feature.json"))["feature_directory"])')
mkdir -p "$FDIR/loop" "$FDIR/review" .specify/devflow docs/decisions
python3 - "$FDIR" "$MODE" <<'PY'
import json, sys, os, datetime, re, subprocess
sys.path.insert(0, ".specify/extensions/devflow/scripts/python")
import devflow_tasks  # ADR-0023/C5: one definition of the tasks.md count primitives
fdir, mode = sys.argv[1], sys.argv[2]
path = os.path.join(fdir, "loop", "state.json")
prev = json.load(open(path)) if os.path.exists(path) else {}
# Stamp the feature's base commit ONCE at loop start (HEAD before any build commits).
# review/verify diff against this — deterministic, robust to stacked-branch topology
# where merge-base picks a stale point and floods the diff with prior features.
base_commit = prev.get("base_commit")
if not base_commit:
    try:
        base_commit = subprocess.run(["git", "rev-parse", "HEAD"],
                                     capture_output=True, text=True).stdout.strip() or None
    except Exception:
        base_commit = None
cfg = open(".specify/extensions/devflow/devflow-config.yml").read()
tb = float(re.search(r"time_box_hours:\s*([\d.]+)", cfg).group(1))
done = devflow_tasks.count_done(open(os.path.join(fdir, "tasks.md")).read()) \
       if os.path.exists(os.path.join(fdir, "tasks.md")) else 0
state = {
  "feature": os.path.basename(fdir), "feature_dir": fdir,
  "mode": mode, "entry": "tasks",
  "in_iteration": False, "iteration": prev.get("iteration", 0),
  "base_commit": base_commit,
  "current_task": None, "tasks_done_at_start": done, "last_record": None,
  "iteration_outcome": None,
  "budget": prev.get("budget", {"used": 0, "total": 0}),
  "started_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
  "time_box_hours": tb,
  "attempts": prev.get("attempts", {}), "parked": prev.get("parked", []),
  "verdicts": prev.get("verdicts", {}), "failure_notes": prev.get("failure_notes", {}),
  "cycle": prev.get("cycle", 0), "continue": True, "exit_reason": None,
}
json.dump(state, open(path, "w"), indent=2)
print(f"devflow: state initialized for {fdir} (mode={mode})")
PY
