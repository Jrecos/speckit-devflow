#!/usr/bin/env bash
# Initialize (or refresh) DevFlow loop state for the current feature.
set -euo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}"
MODE="${1:-attended}"
FDIR=$(python3 -c 'import json;print(json.load(open(".specify/feature.json"))["feature_directory"])')
mkdir -p "$FDIR/loop" "$FDIR/review" .specify/devflow docs/decisions
python3 - "$FDIR" "$MODE" <<'PY'
import json, sys, os, datetime, re
fdir, mode = sys.argv[1], sys.argv[2]
path = os.path.join(fdir, "loop", "state.json")
prev = json.load(open(path)) if os.path.exists(path) else {}
cfg = open(".specify/extensions/devflow/devflow-config.yml").read()
tb = float(re.search(r"time_box_hours:\s*([\d.]+)", cfg).group(1))
done = len(re.findall(r"^- \[x\]", open(os.path.join(fdir, "tasks.md")).read(), re.M)) \
       if os.path.exists(os.path.join(fdir, "tasks.md")) else 0
state = {
  "feature": os.path.basename(fdir), "feature_dir": fdir,
  "mode": mode, "entry": "tasks",
  "in_iteration": False, "iteration": prev.get("iteration", 0),
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
