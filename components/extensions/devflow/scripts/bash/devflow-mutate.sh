#!/usr/bin/env bash
# DevFlow internal mutation tester (ADR-0032). Answers "are these real tests?" mechanically:
# it MUTATES a source file (flips an operator or constant), re-runs the test command, and checks
# whether the tests CAUGHT the mutation (went red). A mutation that SURVIVES (tests stay green with
# broken code) is proof of a weak test — the exact blind spot that let E2E-1's dt/collision bug and
# thin "a bullet spawns" test through. No external dependency (honors ADR-0029); pure bash + sed.
#
# Usage: devflow-mutate.sh <src-glob-or-file> [--test "<cmd>"] [--max N]
#   Defaults: test cmd = commands.test_scoped from devflow-config.yml; --max 40 mutants total.
# Output: a human summary + one JSON line {mutants,killed,survived,score,survivors:[...]}.
# Non-blocking by design: exit 0 always; the caller decides what to do with the score.
set -uo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}"

TARGET="${1:?usage: devflow-mutate.sh <src file or glob> [--test CMD] [--max N]}"; shift || true
TEST_CMD=""; MAX=40
while [ $# -gt 0 ]; do
  case "$1" in
    --test) TEST_CMD="${2:?}"; shift 2 ;;
    --max)  MAX="${2:?}";      shift 2 ;;
    *) echo "devflow-mutate: unknown arg '$1'" >&2; exit 2 ;;
  esac
done
if [ -z "$TEST_CMD" ]; then
  CFG=".specify/extensions/devflow/devflow-config.yml"
  TEST_CMD=$(grep -E '^\s*test_scoped:' "$CFG" 2>/dev/null | sed -E 's/.*test_scoped:\s*"([^"]*)".*/\1/')
fi
[ -n "$TEST_CMD" ] || { echo "devflow-mutate: no test command (set commands.test_scoped or --test)" >&2; exit 2; }

# Baseline must be GREEN — mutation testing is meaningless on a red suite.
if ! bash -c "$TEST_CMD" >/tmp/devflow-mutate-base.log 2>&1; then
  echo "devflow-mutate: baseline tests are RED — cannot mutation-test (fix the suite first)" >&2
  printf '{"mutants":0,"killed":0,"survived":0,"score":null,"survivors":[],"error":"red baseline"}\n'
  exit 0
fi

# The mutation operators: (pattern, replacement) — small, semantics-changing edits.
# Applied one at a time to a single occurrence, per source line, so each mutant is minimal.
MUTATIONS=(
  's/<=/</'  's/</<=/'  's/>=/>/'  's/>/>=/'
  's/===/!==/'  's/!==/===/'  's/ && / || /'  's/ || / && /'
  's/ + / - /'  's/ - / + /'  's/ \* / \/ /'
  's/\btrue\b/false/'  's/\bfalse\b/true/'
  's/\b0\b/1/'  's/\b1\b/0/'
)

FILES=$(ls $TARGET 2>/dev/null)
[ -n "$FILES" ] || { echo "devflow-mutate: no files match '$TARGET'" >&2; exit 2; }

mutants=0; killed=0; survived=0; survivors=""
echo "devflow-mutate: baseline green — mutating $(echo "$FILES" | wc -w | tr -d ' ') file(s), up to $MAX mutants"

for f in $FILES; do
  [ -f "$f" ] || continue
  orig="$(cat "$f")"
  nlines=$(wc -l < "$f" | tr -d ' ')
  for ln in $(seq 1 "$nlines"); do
    [ "$mutants" -ge "$MAX" ] && break
    line="$(sed -n "${ln}p" "$f")"
    # skip comment-only and import lines (mutating them rarely tests behavior)
    case "$line" in
      *"//"*|*"require("*|*"module.exports"*|"") continue ;;
    esac
    for m in "${MUTATIONS[@]}"; do
      [ "$mutants" -ge "$MAX" ] && break
      mutline="$(printf '%s' "$line" | sed "$m")"
      [ "$mutline" = "$line" ] && continue   # this operator didn't apply here
      # apply the single-line mutation
      printf '%s' "$orig" | awk -v n="$ln" -v repl="$mutline" 'NR==n{print repl; next} {print}' > "$f"
      node --check "$f" 2>/dev/null || { printf '%s' "$orig" > "$f"; continue; }  # skip mutants that don't parse
      mutants=$((mutants+1))
      if bash -c "$TEST_CMD" >/dev/null 2>&1; then
        # tests STILL PASS with broken code => the mutant SURVIVED => weak test
        survived=$((survived+1))
        survivors="${survivors}${survivors:+; }$(basename "$f"):${ln} [${m}]"
      else
        killed=$((killed+1))   # tests caught it => good
      fi
      printf '%s' "$orig" > "$f"   # always restore before the next mutant
    done
  done
  printf '%s' "$orig" > "$f"   # final restore safety
done

score="null"
[ "$mutants" -gt 0 ] && score=$(python3 -c "print(round($killed/$mutants,3))")
echo "devflow-mutate: $mutants mutants · $killed killed · $survived survived · mutation score $score"
[ "$survived" -gt 0 ] && echo "  ⚠ survivors (tests did NOT catch these breakages — weak coverage): $survivors"

SURV="$survivors" python3 -c "
import json, os
survs = [s for s in os.environ.get('SURV','').split('; ') if s]
print(json.dumps({'mutants':$mutants,'killed':$killed,'survived':$survived,'score':$score if '$score'!='null' else None,'survivors':survs}))
"
