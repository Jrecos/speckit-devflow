#!/usr/bin/env bash
# DevFlow behavioral eval runner.  (roadmap candidate #2 — the net that catches prompt-behavior
# regressions before a user does.)  See evals/README.md for the methodology.
#
#   run-evals.sh                 live: run each case through the driver (claude -p), grade
#                                the artifacts/state the agent produced
#   run-evals.sh --self-test     deterministic, no model: prove each grader PASSES the
#                                correct-agent sim, goes RED on the reverted-prompt sim, and
#                                that revert.sh actually mutates the installed prompt (CI-safe)
#   run-evals.sh --revert        live red-on-revert: revert each fix in the installed prompt,
#                                run, and REQUIRE the grader to go RED
#   run-evals.sh --case <name>   restrict to a single case
#   run-evals.sh --list          list the cases and the finding each guards
set -uo pipefail
source "$(dirname "$0")/eval-lib.sh"

MODE="live"; ONLY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --self-test) MODE="self-test" ;;
    --revert)    MODE="revert" ;;
    --list)      MODE="list" ;;
    --case)      ONLY="${2:?--case needs a name}"; shift ;;
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
      || { efail "$name: grader REJECTED the correct-agent sim (must pass)"; exit 1; }

    case_sim_revert "$s2"
    if case_grade "$s2" "$s2/.eval/transcript.txt" >/dev/null 2>&1; then
      efail "$name: grader ACCEPTED the reverted-prompt sim (must go red)"; exit 1; fi

    local before after
    before="$(cat "$s1"/.claude/commands/*.md | shasum | awk '{print $1}')"
    case_revert "$s1"
    after="$(cat "$s1"/.claude/commands/*.md | shasum | awk '{print $1}')"
    [ "$before" != "$after" ] \
      || { efail "$name: revert.sh changed no installed prompt (revert is a no-op)"; exit 1; }

    epass "$name: grader discriminates pass↔fail + revert mutates the installed prompt"
  )
}

live_case() { # <name> <reverted?>  → run through the driver and grade
  local name="$1" reverted="${2:-}"
  ( source "$EVAL_ROOT/cases/$name/case.sh"
    local s; s="$(mktemp -d)"; trap 'rm -rf "$s"' EXIT
    eval_bootstrap "$s" >/dev/null 2>&1 || { efail "$name: bootstrap failed"; exit 1; }
    case_bootstrap "$s" >/dev/null 2>&1 || true
    [ "$reverted" = "reverted" ] && case_revert "$s"
    local tr="$s/.eval/transcript.txt"
    eval_dispatch "$s" "$(case_prompt)" "$tr" || enote "$name: driver dispatch returned non-zero (see $tr)"
    if case_grade "$s" "$tr"; then
      if [ "$reverted" = "reverted" ]; then
        efail "$name (reverted): STILL passed — the eval is not sensitive to the fix"; exit 1
      fi
      epass "$name (live): behavior correct"
    else
      if [ "$reverted" = "reverted" ]; then
        epass "$name (live, reverted): went RED as required"
      else
        efail "$name (live): behavior WRONG (finding regressed or run inconclusive)"; exit 1
      fi
    fi
  )
}

if [ "$MODE" = "list" ]; then
  for name in $(list_cases); do
    printf '%-26s %s\n' "$name" "$( ( source "$EVAL_ROOT/cases/$name/case.sh"; case_meta ) )"
  done
  exit 0
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
  echo "ALL EVALS PASS ($MODE, $n case(s))"
else
  echo "$fails/$n case(s) FAILED ($MODE)"; exit 1
fi
