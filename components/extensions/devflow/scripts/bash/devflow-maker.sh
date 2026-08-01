#!/usr/bin/env bash
# DevFlow maker seam (ADR-0025, mirrors the judge seam of ADR-0014).
# Role resolved by $DEVFLOW_MAKER_CMD in the user's env; when unset, the maker is Claude
# itself (Claude-sufficient, ADR-0020) — the caller types the code, no delegation.
#
# stdin to the maker command: the payload built by devflow-maker-prep.sh —
#   {"task_id","instruction","criteria","spec_slice","files":[{"path","content"}],"constraints":[...]}
# stdout from the maker command: whole-file result JSON —
#   {"files":[{"path":"<str>","content":"<full new file text>"}],"notes":"<optional>"}
#
# EXIT CONTRACT (this is the design decision; it differs from the judge):
#   0  -> valid files JSON on stdout; the caller applies each file with its Write tool
#         (so the PostToolUse lint/typecheck hook and the Stop-gate see the edits — ADR-0010).
#   3  -> no maker configured (DEVFLOW_MAKER_CMD unset). NOT a failure: the caller types the
#         code itself. Also used by the local adapter to degrade when its backend is down.
#   1  -> a configured maker ran but produced bad/empty/malformed output. A failed attempt:
#         it feeds the retry/escalation ladder (tier derived from state.attempts — ADR-0026),
#         never a silent success.
#
# Anti-regression (FIX from cross-validation): the payload carries the CURRENT file contents and
# instructs the maker to preserve them, but "input shaping" is not enforcement. So this seam also
# MECHANICALLY rejects (exit 1) any output that (a) writes a path the maker was never shown, or
# (b) deletes more than DEVFLOW_MAKER_MAX_SHRINK of a file without the task being a deletion.
# That turns the weakest guarantee (a weak local model silently dropping code) into a layer-2 check.
set -uo pipefail
PAYLOAD_F="${1:?payload file}"
payload="$(cat "$PAYLOAD_F")"

if [ -z "${DEVFLOW_MAKER_CMD:-}" ]; then
  echo "devflow-maker: no DEVFLOW_MAKER_CMD set — Claude-sufficient (ADR-0020): the caller types this task." >&2
  exit 3
fi

raw="$(printf '%s' "$payload" | bash -c "$DEVFLOW_MAKER_CMD" 2>/tmp/devflow-maker.err)"; rc=$?
# The adapter signals "backend unreachable / degrade to Claude" with exit 3; pass it through so
# the caller types the code instead of escalating over a dead backend (FIX-2).
if [ "$rc" -eq 3 ]; then
  echo "devflow-maker: maker signaled degrade-to-Claude (exit 3)." >&2
  exit 3
fi
if [ "$rc" -ne 0 ]; then
  echo "devflow-maker: maker command failed (see /tmp/devflow-maker.err) — failed attempt." >&2
  exit 1
fi

# Validate schema + mechanical anti-regression. script via -c, data via argv (a heredoc would
# steal stdin). Exit 1 on any violation (fail-safe: a bad maker output is a failed attempt).
printf '%s' "$raw" | sed -e 's/^```json//' -e 's/^```//' -e 's/```$//' > /tmp/devflow-maker.json
python3 - "$PAYLOAD_F" /tmp/devflow-maker.json "${DEVFLOW_MAKER_MAX_SHRINK:-0.5}" <<'PY' || exit 1
import json, sys, os
payload_f, out_f, max_shrink = sys.argv[1], sys.argv[2], float(sys.argv[3])
try:
    payload = json.load(open(payload_f))
    out = json.load(open(out_f))
except Exception as e:
    print(f"devflow-maker: malformed maker output ({e}) — treating as failed attempt (fail-safe)", file=sys.stderr)
    sys.exit(1)
files = out.get("files")
if not isinstance(files, list):
    print("devflow-maker: output missing 'files' list", file=sys.stderr); sys.exit(1)
shown = {f["path"]: f.get("content", "") for f in payload.get("files", []) if isinstance(f, dict) and "path" in f}
# Tolerate a common local-model deviation: a stray {"notes": ...} object sitting inside the
# files array. Skip objects that carry neither path nor content; only real file entries below.
file_entries = [f for f in files if isinstance(f, dict) and ("path" in f or "content" in f)]
if not file_entries:
    print("devflow-maker: output has no file entries with path+content", file=sys.stderr); sys.exit(1)
for f in file_entries:
    if "path" not in f or not isinstance(f.get("content"), str):
        print("devflow-maker: each file needs a string 'path' and 'content'", file=sys.stderr); sys.exit(1)
    p = f["path"]
    # (a) the maker may only write files it was shown (or brand-new files it declares via the payload).
    #     A path neither shown nor allowed = it is inventing edits to unseen code -> reject.
    if p not in shown and p not in payload.get("new_files", []):
        print(f"devflow-maker: output writes unseen path '{p}' (not in payload) — rejecting (anti-regression)", file=sys.stderr)
        sys.exit(1)
    # (b) massive unexplained shrink of an existing file = likely silent deletion of prior code.
    if p in shown and shown[p]:
        old_lines = shown[p].count("\n") + 1
        new_lines = f["content"].count("\n") + 1
        if new_lines < old_lines * (1 - max_shrink):
            print(f"devflow-maker: '{p}' shrank {old_lines}->{new_lines} lines (> {max_shrink:.0%}) — rejecting (continuity regression)", file=sys.stderr)
            sys.exit(1)
# Emit a normalized result: only real file entries, plus any notes we salvaged from a stray object.
stray_notes = " ".join(str(f["notes"]) for f in files if isinstance(f, dict) and "notes" in f and "path" not in f)
normalized = {"files": file_entries}
if out.get("notes") or stray_notes:
    normalized["notes"] = out.get("notes") or stray_notes
print(json.dumps(normalized))
PY
