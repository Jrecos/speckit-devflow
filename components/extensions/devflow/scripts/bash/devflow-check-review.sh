#!/usr/bin/env bash
# Verify-phase prerequisite (gap B): review artifact must exist and be clean-or-parked.
set -euo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}"
FDIR=$(python3 -c 'import json;print(json.load(open(".specify/feature.json"))["feature_directory"])')
FJ="$FDIR/review/findings.json"
if [ ! -f "$FJ" ]; then
  echo "devflow: BLOCKED — Review has not produced $FJ. Verify cannot run (gap B guard)." >&2
  exit 1
fi
STATUS=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["status"])' "$FJ")
case "$STATUS" in
  clean|parked) echo "devflow: review artifact OK (status=$STATUS)";;
  *) echo "devflow: BLOCKED — findings.json status is '$STATUS' (need clean or parked)." >&2; exit 1;;
esac
