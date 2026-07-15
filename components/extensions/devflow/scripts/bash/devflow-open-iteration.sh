#!/usr/bin/env bash
# DevFlow open-iteration (ADR-0023/C5 extraction of iterate.md step 2). The fixed 5-command
# state transition that begins an iteration: mark in_iteration, bump the counter, clear the
# per-iteration fields, and stamp tasks_done_at_start = current `- [x]` count (via the shared
# devflow_tasks helper). Byte-identical to the prose it replaces; run it, don't hand-run the five.
set -euo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}"
FDIR=$(python3 -c 'import json;print(json.load(open(".specify/feature.json"))["feature_directory"])')
STATE="$FDIR/loop/state.json"
STATE_PY=".specify/extensions/devflow/scripts/python/devflow_state.py"

python3 "$STATE_PY" set  "$STATE" in_iteration true
python3 "$STATE_PY" bump "$STATE" iteration
python3 "$STATE_PY" set  "$STATE" iteration_outcome null
python3 "$STATE_PY" set  "$STATE" last_record null
N=$(python3 -c 'import sys;sys.path.insert(0,".specify/extensions/devflow/scripts/python");import devflow_tasks;print(devflow_tasks.count_done(open(sys.argv[1]).read()))' "$FDIR/tasks.md")
python3 "$STATE_PY" set  "$STATE" tasks_done_at_start "$N"

echo "devflow: iteration opened (tasks_done_at_start=$N)"
