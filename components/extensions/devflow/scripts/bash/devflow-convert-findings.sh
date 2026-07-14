#!/usr/bin/env bash
set -euo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}"
CYCLE="${1:?usage: devflow-convert-findings.sh <cycle>}"
FDIR=$(python3 -c 'import json;print(json.load(open(".specify/feature.json"))["feature_directory"])')
python3 - "$FDIR" "$CYCLE" <<'PY'
import json, math, re, sys, datetime
fdir, cycle = sys.argv[1], int(sys.argv[2])
fj = json.load(open(f"{fdir}/review/findings.json"))
if fj.get("status") != "findings" or not fj.get("open"):
    print("devflow: findings clean/parked — no conversion")
    raise SystemExit(0)
cfg = open(".specify/extensions/devflow/devflow-config.yml").read()
factor = float(re.search(r"iteration_factor:\s*([\d.]+)", cfg).group(1))
lines = []
for f in fj["open"]:
    lines.append(f"- [ ] {f['id']} fix: {f['summary']} (finding {f['id']})")
    lines.append(f"  - AC: finding {f['id']} no longer reproduces; regression test added")
# Idempotent per cycle: workflow resume re-runs the whole if-branch (engine re-executes
# parent + nested body), so a second invocation for the same cycle must not duplicate tasks.
marker = f"## Fix-tasks (review cycle {cycle})"
tasks_path = f"{fdir}/tasks.md"
tasks_txt = open(tasks_path).read()
if marker in tasks_txt:
    print(f"devflow: cycle {cycle} already converted — skipping append")
else:
    with open(tasks_path, "a") as t:
        t.write("\n%s\n%s\n" % (marker, "\n".join(lines)))
sp = f"{fdir}/loop/state.json"
state = json.load(open(sp))
state["entry"] = "fix-tasks"; state["cycle"] = cycle
state["budget"] = {"used": 0, "total": math.ceil(len(fj["open"]) * factor)}
# fresh time-box for the fix loop — the build loop's clock is usually spent by now
state["started_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
state["continue"] = True; state["exit_reason"] = None
json.dump(state, open(sp, "w"), indent=2)
print(f"devflow: {len(fj['open'])} fix-task(s) for cycle {cycle}; budget {state['budget']['total']}")
PY
