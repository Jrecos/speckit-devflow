#!/usr/bin/env bash
set -euo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}"
FDIR=$(python3 -c 'import json;print(json.load(open(".specify/feature.json"))["feature_directory"])')
python3 - "$FDIR" <<'PY'
import glob, json, re, sys, os
sys.path.insert(0, ".specify/extensions/devflow/scripts/python")
import devflow_tasks  # ADR-0023/C5
fdir = sys.argv[1]
state = json.load(open(f"{fdir}/loop/state.json"))
tasks = open(f"{fdir}/tasks.md").read()
done = devflow_tasks.count_done(tasks); open_t = devflow_tasks.count_open(tasks)
fj_p = f"{fdir}/review/findings.json"
fstat = json.load(open(fj_p))["status"] if os.path.exists(fj_p) else "MISSING"
verdict = "not run"
vr = f"{fdir}/verify-report.md"
if os.path.exists(vr):
    m = re.search(r"^Judge verdict:\s*(\S+)", open(vr).read(), re.M)
    verdict = m.group(1) if m else "see report"
recs = len(glob.glob("docs/decisions/*.md"))
os.makedirs(".specify/devflow", exist_ok=True)
with open(".specify/devflow/stop2.md", "w") as f:
    f.write(f"""# STOP #2 — evidence summary

- Tasks: **{done} done**, {open_t} open, parked: {state['parked'] or 'none'}
- Iterations used: {state['budget']['used']}/{state['budget']['total']} (cycle {state['cycle']})
- Review: findings status = **{fstat}**
- Verify: judge verdict = **{verdict}** (full report: {fdir}/verify-report.md)
- Decision records in docs/decisions/: {recs}
- Loop exit reason: {state.get('exit_reason') or 'tasks complete'}

Choices: accept / accept-with-deviation / reject.
Accepting with ANY parked task or finding routes through reconcile-contract first (ADR-0016).
""")
print("devflow: stop2.md written")
PY
