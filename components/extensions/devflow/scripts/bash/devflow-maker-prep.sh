#!/usr/bin/env bash
# DevFlow maker prep (ADR-0025; mirrors devflow-judge-prep.sh).
# Assembles the single JSON payload devflow-maker.sh feeds to $DEVFLOW_MAKER_CMD. Passing the
# CURRENT whole-file contents is the mechanical half of anti-regression: the maker sees exactly
# what exists and is told to preserve it (the enforcement half is the shrink/unseen-path check
# in devflow-maker.sh).
#
# Usage:
#   devflow-maker-prep.sh --task-id T7 --instruction "<direct, explicit imperative>" \
#     --criteria-file <ac> --slice-file <spec-slice> [--files a.ts,b.ts] [--new-files c.ts]
# Prints ONE line: the path of the payload temp file (feed straight into devflow-maker.sh).
set -euo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}"

TASK_ID=""; INSTRUCTION=""; CRIT=""; SLICE=""; FILES=""; NEW_FILES=""; OUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --task-id)     TASK_ID="${2:?}";     shift 2 ;;
    --instruction) INSTRUCTION="${2?}";  shift 2 ;;
    --criteria-file) CRIT="${2:?}";      shift 2 ;;
    --slice-file)  SLICE="${2:?}";       shift 2 ;;
    --files)       FILES="${2?}";        shift 2 ;;   # comma-separated existing paths to expose
    --new-files)   NEW_FILES="${2?}";    shift 2 ;;   # comma-separated paths the maker may create
    --out-dir)     OUT="${2:?}";         shift 2 ;;
    *) echo "devflow-maker-prep: unknown arg '$1'" >&2; exit 2 ;;
  esac
done
: "${TASK_ID:?--task-id required}"
[ -n "$CRIT" ]  || { echo "devflow-maker-prep: --criteria-file required" >&2; exit 2; }
[ -n "$SLICE" ] || { echo "devflow-maker-prep: --slice-file required" >&2; exit 2; }
[ -f "$CRIT" ]  || { echo "devflow-maker-prep: criteria file not found: $CRIT" >&2; exit 1; }
[ -f "$SLICE" ] || { echo "devflow-maker-prep: slice file not found: $SLICE" >&2; exit 1; }
OUT="${OUT:-$(mktemp -d)}"; mkdir -p "$OUT"
PAYLOAD="$OUT/maker-payload.json"

python3 - "$TASK_ID" "$INSTRUCTION" "$CRIT" "$SLICE" "$FILES" "$NEW_FILES" "$PAYLOAD" <<'PY'
import json, sys, os
task_id, instruction, crit_f, slice_f, files_csv, new_csv, out = sys.argv[1:8]
files = []
for p in [x for x in files_csv.split(",") if x]:
    try:
        files.append({"path": p, "content": open(p).read()})
    except FileNotFoundError:
        # a listed existing file that isn't there yet is treated as new (empty) — the maker creates it
        files.append({"path": p, "content": ""})
payload = {
    "task_id": task_id,
    "instruction": instruction,
    "criteria": open(crit_f).read(),
    "spec_slice": open(slice_f).read(),
    "files": files,
    "new_files": [x for x in new_csv.split(",") if x],
    "constraints": [
        "Return the COMPLETE new content of each file you change — never a fragment, never a diff.",
        "PRESERVE every existing export, function, and behavior not required to change (anti-regression).",
        "Do not delete or rewrite unrelated code.",
        "Only write files listed in 'files' or 'new_files'.",
        "Respond with ONLY the JSON: {\"files\":[{\"path\":...,\"content\":...}],\"notes\":...} — no prose, no fences.",
    ],
}
with open(out, "w") as f:
    json.dump(payload, f)
PY

printf '%s\n' "$PAYLOAD"
