#!/usr/bin/env bash
# Eval case: iterate-judge-tests-line  (dogfood finding 6)
#
# Behavior under test: in iterate step 7 the agent prepends a `TESTS:` line (the step-5 scoped
# result) to the judge CRITERIA file, so the judge weighs the green suite as the primary oracle
# and doesn't FAIL on code outside the diff (ADR-0003). We capture the criteria the agent
# actually feeds the judge by installing a judge-recorder as $DEVFLOW_JUDGE_CMD (the same seam
# devflow-judge.sh reads). Graded artifact: the recorded criteria's first line.

case_meta() { echo "iterate-judge-tests-line | finding 6 | iterate prepends a TESTS: line to the judge criteria"; }

case_prompt() {
  cat <<'EOF'
/speckit-devflow-iterate

Run exactly one build-loop iteration on this project's tasks.md, closing under the Stop gate as
the command specifies. Use the scoped-test command from devflow-config.yml (it is `true`).
EOF
}

# Scaffold a runnable single iteration: loop state, a passing scoped-test command, and a
# judge-recorder wired through the DEVFLOW_JUDGE_CMD seam so we can inspect the criteria.
case_bootstrap() { # <scratch>
  local dir="$1"
  # loop/state.json — fresh, not yet in an iteration
  python3 - "$dir/$EVAL_FDIR/loop/state.json" <<'PY'
import json, sys, datetime
state = {
  "feature": "012-demo", "feature_dir": "specs/012-demo",
  "mode": "attended", "entry": "tasks",
  "in_iteration": False, "iteration": 0,
  "current_task": None, "tasks_done_at_start": 1, "last_record": None,
  "iteration_outcome": None, "budget": {"used": 0, "total": 5},
  "started_at": datetime.datetime.now(datetime.timezone.utc).isoformat(), "time_box_hours": 4,
  "attempts": {}, "parked": [], "verdicts": {}, "failure_notes": {},
  "cycle": 0, "continue": True, "exit_reason": None,
}
json.dump(state, open(sys.argv[1], "w"), indent=2)
PY
  # give the scoped/full test commands a trivially-green command so the loop can reach the judge
  local cfg="$dir/.specify/extensions/devflow/devflow-config.yml"
  perl -pi -e 's/^  test_scoped: ""/  test_scoped: "true"/; s/^  test_full: ""/  test_full: "true"/' "$cfg"
  # judge-recorder: captures the criteria file the agent passes, then returns a valid PASS verdict
  cat > "$dir/.eval/judge-recorder.sh" <<'EOF'
#!/usr/bin/env bash
# stdin: {"diff","criteria","spec_slice"}; arg1: where to record the criteria text.
out="$1"
python3 -c 'import json,sys; d=json.load(sys.stdin); open(sys.argv[1],"w").write(d.get("criteria",""))' "$out"
echo '{"verdict":"PASS","reason":"eval judge-recorder","criteria":[]}'
EOF
  chmod +x "$dir/.eval/judge-recorder.sh"
  # env.sh is sourced into the live session by eval_dispatch (absolute paths — cwd-independent)
  cat > "$dir/.eval/env.sh" <<EOF
export DEVFLOW_JUDGE_CMD="bash $dir/.eval/judge-recorder.sh $dir/.eval/judge-criteria.txt"
EOF
}

case_grade() { # <scratch> <transcript>
  local dir="$1"
  local crit="$dir/.eval/judge-criteria.txt"
  [ -f "$crit" ] || { enote "judge was never invoked with a criteria file (iteration did not reach the judge)"; return 1; }
  local first; first="$(grep -m1 -v '^[[:space:]]*$' "$crit" || true)"
  case "$first" in
    TESTS:*) echo "judge criteria leads with the TESTS: oracle line"; return 0 ;;
    *) enote "judge criteria's first line is '${first}', not a TESTS: line — finding 6 regression"; return 1 ;;
  esac
}

# Revert finding 6's fix in the INSTALLED iterate prompt: drop the instruction to prepend the
# TESTS: line, so the agent writes only AC: lines into the criteria.
case_revert() { # <scratch>
  local f; f="$(eval_cmd_path "$1" speckit.devflow.iterate.md)"
  perl -0pi -e "s/The \\*\\*criteria\\*\\* file starts.*?then the task's \`AC:\` lines/The **criteria** file is the task's \`AC:\` lines/s" "$f"
}

# --- deterministic sims for --self-test -------------------------------------------------
case_sim_pass() { # correct agent: criteria leads with the TESTS: line
  cat > "$1/.eval/judge-criteria.txt" <<'EOF'
TESTS: scoped green
- AC: does the first thing
EOF
}
case_sim_revert() { # reverted-prompt agent: no TESTS: line, straight to AC:
  cat > "$1/.eval/judge-criteria.txt" <<'EOF'
- AC: does the first thing
EOF
}
