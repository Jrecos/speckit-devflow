#!/usr/bin/env bash
# DevFlow Stop-hook gate — enforces the iteration close contract (ADR-0016).
# GREEN: record + scoped tests green + exactly one task newly checked -> auto-commit -> allow.
# RED:   iteration_outcome=failed + failure note -> attempts++ -> allow WITHOUT commit.
# Else:  exit 2 (block; stderr is fed back to the agent).
# Inert (exit 0) when not inside an iterate session. Re-checks the real
# condition on every fire — never short-circuits on stop_hook_active.
set -uo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
cat > /dev/null || true   # drain hook stdin; decisions come from disk only

FEATURE_JSON=".specify/feature.json"
[ -f "$FEATURE_JSON" ] || exit 0
FDIR=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("feature_directory",""))' "$FEATURE_JSON" 2>/dev/null) || exit 0
[ -n "$FDIR" ] || exit 0
STATE="$FDIR/loop/state.json"
[ -f "$STATE" ] || exit 0

STATE_PY=".specify/extensions/devflow/scripts/python/devflow_state.py"
sget() { python3 "$STATE_PY" get "$STATE" "$1" 2>/dev/null; }
sset() { python3 "$STATE_PY" set "$STATE" "$1" "$2"; }

[ "$(sget in_iteration)" = "true" ] || exit 0

ITER=$(sget iteration | tr -d '"')
TASK=$(sget current_task)
OUTCOME=$(sget iteration_outcome)

# ---- RED close: failed outcome + a failure note for the current task ----
if [ "$OUTCOME" = '"failed"' ]; then
  TASK_KEY=$(echo "$TASK" | tr -d '"')
  NOTE=$(sget "failure_notes.$TASK_KEY")
  if [ -n "$NOTE" ] && [ "$NOTE" != "null" ]; then
    # honest failures count toward the parking cap (attempts), unlike blocked exits
    python3 "$STATE_PY" bump "$STATE" "attempts.$TASK_KEY"
    sset in_iteration false
    sset current_task null   # avoid backstop mis-attribution if the next dispatch dies early
    exit 0
  fi
  echo "DevFlow gate: iteration marked failed but no failure note for $TASK_KEY. Write the failure note to loop state (failure_notes) before ending." >&2
  exit 2
fi

# ---- GREEN close requirements ----
RECORD=$(sget last_record | tr -d '"')
if [ -z "$RECORD" ] || [ "$RECORD" = "null" ] || [ ! -f "$RECORD" ]; then
  echo "DevFlow gate: no decision record for iteration $ITER. Run /speckit-devflow-record-decision (or mark the iteration failed with a failure note) before ending." >&2
  exit 2
fi

# exactly one task newly checked this iteration
DONE_AT_START=$(sget tasks_done_at_start | tr -d '"')
# count in python: `grep -c || echo 0` emits "0\n0" on zero matches (grep prints 0 AND exits 1)
DONE_NOW=$(python3 -c 'import re,sys;print(len(re.findall(r"^- \[x\]", open(sys.argv[1]).read(), re.M)))' "$FDIR/tasks.md" 2>/dev/null || echo 0)
DELTA=$((DONE_NOW - DONE_AT_START))
if [ "$DELTA" -ne 1 ]; then
  echo "DevFlow gate: expected exactly 1 task to complete this iteration, found $DELTA. One task per iteration — mark exactly one done (or mark the iteration failed)." >&2
  exit 2
fi

# scoped tests green (command from config; empty command = misconfigured = block)
# NOTE: regex is UNANCHORED — config values carry trailing "# comments"; a $-anchor never matches.
TEST_CMD=$(python3 - <<'PY'
import re
txt = open(".specify/extensions/devflow/devflow-config.yml").read()
m = re.search(r'^\s*test_scoped:\s*"([^"]*)"', txt, re.M)
print(m.group(1) if m else "")
PY
)
if [ -z "$TEST_CMD" ]; then
  echo "DevFlow gate: commands.test_scoped is not configured (devflow-config.yml). Run /speckit-devflow-onboard." >&2
  exit 2
fi
if ! bash -c "$TEST_CMD" > /tmp/devflow-scoped-test.log 2>&1; then
  echo "DevFlow gate: scoped tests are red (see /tmp/devflow-scoped-test.log). Fix them, or mark the iteration failed with a failure note." >&2
  exit 2
fi

# ---- GREEN close: state FIRST, then commit (state mutations after commit would dirty the tree) ----
sset iteration_outcome '"green"'
sset in_iteration false
sset current_task null   # avoid backstop mis-attribution if the next dispatch dies early
git add -A
if ! git diff --cached --quiet; then
  git commit -q -m "iter ${ITER}: ${TASK//\"/} (devflow green close)" || {
    sset in_iteration true   # revert: the close did not complete
    echo "DevFlow gate: auto-commit failed — resolve git state before ending." >&2
    exit 2; }
fi
exit 0
