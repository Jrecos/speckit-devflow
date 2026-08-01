#!/usr/bin/env bash
# DevFlow model escalation (ADR-0026).
# The maker tier for a task is a PURE FUNCTION of state.attempts[<task>] — the single retry
# counter the Stop-gate already bumps on every RED close (layer 2). There is deliberately NO
# parallel `maker_fails` counter: a second counter, bumped from prose, desynchronizes from the
# park cap the moment any dispatch dies without running it, and a task would then park while its
# tier is still at the cheapest model. Deriving the tier from attempts makes "Claude acts before
# the park" a mechanical guarantee, not a prompt instruction.
#
# Ladder (config: maker.escalation.order; default local -> assistant -> agentic -> claude):
#   attempts 0,1,2 -> tier 0  (the local model self-corrects 3x, reading the prior failure_note)
#   attempts 3     -> tier 1
#   attempts 4     -> tier 2
#   attempts >=5   -> tier 3  (the escape hatch: the LAST tier before the park cap of 6)
# The last tier is conventionally "claude": the caller then does NOT invoke the maker (it types
# the code itself). Any tier can be a model role; the environment resolves what each name means.
#
# Usage:
#   devflow-escalate.sh tier <task-id>     # prints the model role/alias for this task's tier
#   devflow-escalate.sh index <task-id>    # prints the numeric tier index (for tests/inspection)
set -euo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}"

OP="${1:?tier|index}"; TASK="${2:?task-id}"
FEATURE_DIR="$(python3 -c "import json;print(json.load(open('.specify/feature.json'))['feature_directory'])")"
STATE="$FEATURE_DIR/loop/state.json"
STATE_PY=".specify/extensions/devflow/scripts/python/devflow_state.py"
CONFIG=".specify/extensions/devflow/devflow-config.yml"

attempts="$(python3 "$STATE_PY" get "$STATE" "attempts.$TASK" 2>/dev/null)"
[ "$attempts" = "null" ] || [ -z "$attempts" ] && attempts=0

# Escalation order + per-tier boundaries. The boundary list maps an attempts count to a tier:
# tier index = number of boundaries <= attempts. Default boundaries [3,4,5] give 0-2->0, 3->1,
# 4->2, >=5->3. Read the order from config (fallback to the default 4-tier ladder).
python3 - "$CONFIG" "$attempts" "$OP" <<'PY'
import sys, re
config_path, attempts, op = sys.argv[1], int(sys.argv[2]), sys.argv[3]
order = ["local", "assistant", "agentic", "claude"]
boundaries = [3, 4, 5]
try:
    text = open(config_path).read()
    # minimal YAML sniff for maker.escalation.order: [a, b, c] — stdlib only, no pyyaml dep
    m = re.search(r'escalation:\s*\n(?:\s+\w+:.*\n)*?\s+order:\s*\[([^\]]*)\]', text)
    if m:
        parsed = [x.strip().strip('"\'' ) for x in m.group(1).split(",") if x.strip()]
        if parsed:
            order = parsed
            # boundaries: first tier gets 3 self-correction attempts, the rest get 1 each
            boundaries = [3 + i for i in range(len(order) - 1)]
except FileNotFoundError:
    pass
tier = sum(1 for b in boundaries if attempts >= b)
tier = min(tier, len(order) - 1)
print(order[tier] if op == "tier" else tier)
PY
