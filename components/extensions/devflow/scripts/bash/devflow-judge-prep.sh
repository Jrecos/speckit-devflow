#!/usr/bin/env bash
# DevFlow judge prep (ADR-0023 extraction; the invariant behind finding 6).
# Assembles the THREE files devflow-judge.sh reads — diff, criteria, slice — and GUARANTEES the
# criteria file begins with a `TESTS:` line (the primary-oracle signal, ADR-0003), so a judge
# that sees only the diff won't FAIL on code already covered by a green suite or on code outside
# the diff. Both callers share this one assembler; only the pieces differ, passed as args:
#   iterate → --diff working  (the per-task working-tree diff)
#   verify  → --diff feature  (the whole-feature diff via devflow-diff-surface.sh, C1)
# devflow-judge.sh itself stays dumb: it just reads the three files. Prints the three temp-file
# paths on ONE line — `<diff> <criteria> <slice>` — to feed straight into devflow-judge.sh:
#   bash devflow-judge.sh $(bash devflow-judge-prep.sh --diff feature --tests "..." \
#                          --criteria-file <ac> --slice-file <spec>)
set -euo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}"

DIFF_MODE=""; TESTS=""; CRIT_BODY=""; SLICE=""; OUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --diff)          DIFF_MODE="${2:?}"; shift 2 ;;
    --tests)         TESTS="${2?}";      shift 2 ;;   # may be empty string, but must be provided
    --criteria-file) CRIT_BODY="${2:?}"; shift 2 ;;
    --slice-file)    SLICE="${2:?}";     shift 2 ;;
    --out-dir)       OUT="${2:?}";       shift 2 ;;
    *) echo "devflow-judge-prep: unknown arg '$1'" >&2; exit 2 ;;
  esac
done
: "${DIFF_MODE:?--diff working|feature required}"
[ -n "$CRIT_BODY" ] || { echo "devflow-judge-prep: --criteria-file required" >&2; exit 2; }
[ -n "$SLICE" ]     || { echo "devflow-judge-prep: --slice-file required" >&2; exit 2; }
[ -f "$CRIT_BODY" ] || { echo "devflow-judge-prep: criteria file not found: $CRIT_BODY" >&2; exit 1; }
[ -f "$SLICE" ]     || { echo "devflow-judge-prep: slice file not found: $SLICE" >&2; exit 1; }
OUT="${OUT:-$(mktemp -d)}"; mkdir -p "$OUT"

case "$DIFF_MODE" in
  working) git diff > "$OUT/diff.txt" ;;
  feature) bash .specify/extensions/devflow/scripts/bash/devflow-diff-surface.sh diff > "$OUT/diff.txt" ;;
  *) echo "devflow-judge-prep: --diff must be 'working' or 'feature'" >&2; exit 2 ;;
esac

# THE guarantee (finding 6): the TESTS: line is always the criteria's first line.
{ printf 'TESTS: %s\n' "$TESTS"; cat "$CRIT_BODY"; } > "$OUT/criteria.txt"
cp "$SLICE" "$OUT/slice.txt"

printf '%s %s %s\n' "$OUT/diff.txt" "$OUT/criteria.txt" "$OUT/slice.txt"
