#!/usr/bin/env bash
# Eval case: start-flow-literal  (dogfood finding 3)
#
# Behavior under test: start.md's `FLOW …` shorthand is the LITERAL path
# `bash .specify/extensions/devflow/scripts/bash/devflow-flow.sh …`, written out in each
# command — NOT a shell variable. The pre-fix wording made the agent do `FLOW="bash …"; $FLOW
# init`; because every Bash tool call is a fresh shell, `$FLOW` expands to nothing and the guard
# never runs, so the ledger is never created. Graded state: the flow ledger exists and the
# `frame` phase actually advanced — proof the literal path executed.

case_meta() { echo "start-flow-literal | finding 3 | FLOW is a literal path invocation, not a \$FLOW shell variable"; }

case_prompt() {
  cat <<'EOF'
/speckit-devflow-start demo refresh-window feature

Scope for this run: do ONLY the "Resume or begin" step and open the `frame` phase — nothing
past it. Concretely: initialize the flow ledger in autonomous mode, run the flow guard's
`status`, then mark the `frame` phase active. Do NOT run /speckit-specify or any later phase.
Stop as soon as `frame` is active.
EOF
}

case_bootstrap() { :; }  # the scaffolded feature.json + spec.md are enough for init + start frame

case_grade() { # <scratch> <transcript>
  local dir="$1" tr="$2"
  local ledger="$dir/$EVAL_FDIR/devflow-flow.json"
  [ -f "$ledger" ] || { enote "no flow ledger — 'devflow-flow.sh init/start frame' never took effect (FLOW likely used as a var that expanded empty)"; return 1; }
  python3 - "$ledger" <<'PY' || return 1
import json, sys
f = json.load(open(sys.argv[1]))
st = f.get("phases", {}).get("frame", {}).get("status")
if st not in ("active", "done"):
    print(f"frame phase is {st!r}, not active/done — the guard never advanced", file=sys.stderr)
    sys.exit(1)
print("flow ledger advanced via the literal path: frame is", st)
PY
  # Secondary symptom guard: an agent invoking FLOW as a variable (`$FLOW init`) is the finding-3
  # regression. (Narrow to the invocation form so quoting the standing rule isn't a false hit.)
  if [ -f "$tr" ] && grep -Eq '\$FLOW[[:space:]]+(init|start|complete|status|next)' "$tr"; then
    enote "transcript invokes FLOW as a shell variable (\$FLOW <subcommand>) — finding 3 regression"
    return 1
  fi
  return 0
}

# Revert finding 3's fix in the INSTALLED start prompt: recast FLOW as a shell variable and
# drop the "NOT a shell variable" warning, so a live run is nudged back toward `$FLOW`.
case_revert() { # <scratch>
  local f; f="$(eval_cmd_path "$1" speckit.devflow.start.md)"
  perl -0pi -e 's/the \*\*literal path\*\*/a convenient shell variable/g' "$f"
  perl -0pi -e 's/It is NOT a shell variable: do not `FLOW=…` then run `\$FLOW`/Set it once with `FLOW=…` then run `\$FLOW`/g' "$f"
}

# --- deterministic sims for --self-test -------------------------------------------------
case_sim_pass() { # a correct agent: runs the real guard via the literal path
  ( cd "$1"
    CLAUDE_PROJECT_DIR="$1" bash .specify/extensions/devflow/scripts/bash/devflow-flow.sh init autonomous >/dev/null
    CLAUDE_PROJECT_DIR="$1" bash .specify/extensions/devflow/scripts/bash/devflow-flow.sh start frame  >/dev/null
  )
  {
    echo "Running: bash .specify/extensions/devflow/scripts/bash/devflow-flow.sh init autonomous"
    echo "Running: bash .specify/extensions/devflow/scripts/bash/devflow-flow.sh start frame"
    echo "frame is now active."
  } > "$1/.eval/transcript.txt"
}
case_sim_revert() { # a reverted-prompt agent: sets FLOW=… then calls $FLOW in a fresh shell (no-op)
  # deliberately do NOT create the ledger — mirrors the empty-expansion failure
  {
    echo 'Setting FLOW="bash .specify/extensions/devflow/scripts/bash/devflow-flow.sh"'
    echo 'Running: $FLOW init autonomous'
    echo 'bash: init: command not found'
  } > "$1/.eval/transcript.txt"
}
