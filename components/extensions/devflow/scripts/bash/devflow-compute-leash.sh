#!/usr/bin/env bash
set -euo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}"
FDIR=$(python3 -c 'import json;print(json.load(open(".specify/feature.json"))["feature_directory"])')
python3 - "$FDIR" <<'PY'
import json, math, re, sys
fdir = sys.argv[1]
cfg = open(".specify/extensions/devflow/devflow-config.yml").read()
factor = float(re.search(r"iteration_factor:\s*([\d.]+)", cfg).group(1))
cap = int(re.search(r"max_attempts_per_task:\s*(\d+)", cfg).group(1))
tb = re.search(r"time_box_hours:\s*([\d.]+)", cfg).group(1)
tasks = open(f"{fdir}/tasks.md").read()
n = len(re.findall(r"^- \[ \]", tasks, re.M))
total = math.ceil(n * factor)
sp = f"{fdir}/loop/state.json"
state = json.load(open(sp)); state["budget"] = {"used": 0, "total": total}
json.dump(state, open(sp, "w"), indent=2)
with open(".specify/devflow/leash.md", "w") as f:
    f.write(f"""# The leash for this run (approve at STOP #1)

- Open tasks: **{n}**
- Iteration budget: **{total} iterations** (= ceil({n} x {factor}))
- Time-box: **{tb}h** wall-clock
- Attempts per task before parking: **{cap}**

Between STOP #1 and STOP #2 the loop runs unattended within these limits.
Budget exhaustion is a clean park, not a failure — everything lands at STOP #2 with history.
""")
print(f"devflow: leash = {total} iterations / {tb}h (n={n}, factor={factor})")
PY
