#!/usr/bin/env bash
# DevFlow behavioral eval runner.  (roadmap candidate #2; command-authoring-research.md §7;
# ADR-0021 item 12 — evaluation-driven maintenance of the prompt layer.)  See evals/README.md.
#
#   run-evals.sh                 live: run each case through the driver (claude -p) in a fresh
#                                scratch, grade the artifacts/state the agent produced
#   run-evals.sh --runs N        repeat each live case N times, report pass-rate (default 1;
#                                live evals are non-deterministic — the skill-creator pattern
#                                wants repetition)
#   run-evals.sh --self-test     deterministic, no model: prove each grader PASSES the
#                                correct-agent fixture, goes RED on the reverted-prompt fixture,
#                                and that revert.sh actually mutates the installed prompt (CI-safe)
#   run-evals.sh --revert        live blind-A/B sensitivity: revert each fix in the installed
#                                prompt, run, and REQUIRE the grader to go RED
#   run-evals.sh --case <name>   restrict to a single case
#   run-evals.sh --list          list the cases and the finding each guards
#
# Prereq-guard: live/--revert modes need `specify` and `claude`. If either is absent they SKIP
# and exit 0 — this is an opt-in/nightly job, never PR-gating. --self-test needs neither.
set -uo pipefail
source "$(dirname "$0")/eval-lib.sh"

MODE="live"; ONLY=""; RUNS=1
while [ $# -gt 0 ]; do
  case "$1" in
    --self-test) MODE="self-test" ;;
    --revert)    MODE="revert" ;;
    --list)      MODE="list" ;;
    --case)      ONLY="${2:?--case needs a name}"; shift ;;
    --runs)      RUNS="${2:?--runs needs a number}"; shift ;;
    -h|--help)   grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $1 (see --help)" >&2; exit 2 ;;
  esac
  shift
done

list_cases() {
  local d name
  for d in "$EVAL_ROOT"/cases/*/; do
    [ -f "$d/case.sh" ] || continue
    name="$(basename "$d")"
    [ -z "$ONLY" ] || [ "$ONLY" = "$name" ] || continue
    echo "$name"
  done
}

# Each case.sh defines the same function names, so we source it in a subshell per run.
selftest_case() { # <name>  → deterministic grader-discrimination + revert-mutation proof
  local name="$1"
  ( source "$EVAL_ROOT/cases/$name/case.sh"
    local s1 s2; s1="$(mktemp -d)"; s2="$(mktemp -d)"
    trap 'rm -rf "$s1" "$s2"' EXIT
    EVAL_LIGHT=1 eval_bootstrap "$s1" >/dev/null 2>&1
    EVAL_LIGHT=1 eval_bootstrap "$s2" >/dev/null 2>&1
    case_bootstrap "$s1" >/dev/null 2>&1 || true
    case_bootstrap "$s2" >/dev/null 2>&1 || true

    case_sim_pass "$s1"
    case_grade "$s1" "$s1/.eval/transcript.txt" >/dev/null 2>&1 \
      || { efail "$name: grader REJECTED the correct-agent fixture (must pass)"; exit 1; }

    case_sim_revert "$s2"
    if case_grade "$s2" "$s2/.eval/transcript.txt" >/dev/null 2>&1; then
      efail "$name: grader ACCEPTED the reverted-prompt fixture (must go red)"; exit 1; fi

    local before after
    before="$(cat "$s1"/.claude/commands/*.md | shasum | awk '{print $1}')"
    case_revert "$s1"
    after="$(cat "$s1"/.claude/commands/*.md | shasum | awk '{print $1}')"
    [ "$before" != "$after" ] \
      || { efail "$name: revert.sh changed no installed prompt (revert is a no-op)"; exit 1; }

    epass "$name: grader discriminates pass↔fail + revert mutates the installed prompt"
  )
}

live_case() { # <name> <reverted?>  → run through the driver RUNS times, report pass-rate
  local name="$1" reverted="${2:-}"
  ( source "$EVAL_ROOT/cases/$name/case.sh"
    local want_desc; [ "$reverted" = "reverted" ] && want_desc="went RED" || want_desc="passed"
    local hits=0 i
    for i in $(seq 1 "$RUNS"); do
      local s; s="$(mktemp -d)"
      eval_bootstrap "$s" >/dev/null 2>&1 || { enote "$name run $i: bootstrap failed"; rm -rf "$s"; continue; }
      case_bootstrap "$s" >/dev/null 2>&1 || true
      [ "$reverted" = "reverted" ] && case_revert "$s"
      local tr="$s/.eval/transcript.txt"
      eval_dispatch "$s" "$(case_prompt)" "$tr" || enote "$name run $i: driver dispatch non-zero (see transcript)"
      if case_grade "$s" "$tr" >/dev/null 2>&1; then
        [ "$reverted" = "reverted" ] || hits=$((hits+1))   # live: correct = grader passed
      else
        [ "$reverted" = "reverted" ] && hits=$((hits+1))   # revert: correct = grader red
      fi
      rm -rf "$s"
    done
    local rate=$(( hits * 100 / RUNS ))
    local tag; [ "$reverted" = "reverted" ] && tag="live,reverted" || tag="live"
    if [ "$hits" -eq "$RUNS" ]; then
      epass "$name ($tag): $hits/$RUNS $want_desc (${rate}%)"
    else
      efail "$name ($tag): only $hits/$RUNS $want_desc (${rate}%)"; exit 1
    fi
  )
}

if [ "$MODE" = "list" ]; then
  for name in $(list_cases); do
    printf '%-26s %s\n' "$name" "$( ( source "$EVAL_ROOT/cases/$name/case.sh"; case_meta ) )"
  done
  exit 0
fi

# Prereq-guard for the live modes: never hard-fail a CI box that lacks the live tooling.
if [ "$MODE" = "live" ] || [ "$MODE" = "revert" ]; then
  missing=""
  command -v claude  >/dev/null 2>&1 || missing="$missing claude"
  command -v specify >/dev/null 2>&1 || missing="$missing specify"
  if [ -n "$missing" ]; then
    echo "SKIP: live evals need$missing — not installed here. This is an opt-in/nightly job; not PR-gating."
    echo "(Run 'run-evals.sh --self-test' for the deterministic, model-free grader check.)"
    exit 0
  fi
fi

fails=0; n=0
for name in $(list_cases); do
  n=$((n+1))
  echo "── $name"
  case "$MODE" in
    self-test) selftest_case "$name" || fails=$((fails+1)) ;;
    revert)    live_case "$name" reverted || fails=$((fails+1)) ;;
    live)      live_case "$name" || fails=$((fails+1)) ;;
  esac
done

echo
[ "$n" -gt 0 ] || { echo "no cases matched"; exit 2; }
if [ "$fails" -eq 0 ]; then
  echo "ALL EVALS PASS ($MODE, $n case(s)$([ "$MODE" = live ] && echo ", $RUNS run(s) each"))"
else
  echo "$fails/$n case(s) FAILED ($MODE)"; exit 1
fi
