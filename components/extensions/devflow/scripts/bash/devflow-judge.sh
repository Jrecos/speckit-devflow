#!/usr/bin/env bash
# DevFlow judge seam (ADR-0014): role resolved by $DEVFLOW_JUDGE_CMD in the user's env.
# stdin to the judge: {"diff","criteria","spec_slice"}; stdout: verdict JSON (schema-validated).
# Fail-safe: missing env / malformed output = exit 1 (callers treat as FAIL/block).
set -uo pipefail
DIFF_F="${1:?diff file}"; CRIT_F="${2:?criteria file}"; SLICE_F="${3:?spec-slice file}"
if [ -z "${DEVFLOW_JUDGE_CMD:-}" ]; then
  echo "devflow-judge: DEVFLOW_JUDGE_CMD is not set. Configure your cross-family judge in your environment (never committed). See /speckit-devflow-onboard." >&2
  exit 1
fi
payload=$(python3 - "$DIFF_F" "$CRIT_F" "$SLICE_F" <<'PY'
import json, sys
print(json.dumps({
  "diff": open(sys.argv[1]).read(),
  "criteria": open(sys.argv[2]).read(),
  "spec_slice": open(sys.argv[3]).read(),
}))
PY
)
raw=$(printf '%s' "$payload" | bash -c "$DEVFLOW_JUDGE_CMD" 2>/tmp/devflow-judge.err) || {
  echo "devflow-judge: judge command failed (see /tmp/devflow-judge.err)" >&2; exit 1; }
# NOTE: script via -c, data via argv — a `python3 - <<EOF` heredoc would steal stdin from the pipe.
python3 -c '
import json, sys
d = json.loads(sys.argv[1])
assert d.get("verdict") in ("PASS", "FAIL"), "verdict must be PASS|FAIL"
assert isinstance(d.get("reason"), str), "reason must be a string"
assert isinstance(d.get("criteria"), list), "criteria must be a list"
print(json.dumps(d))' "$raw" || { echo "devflow-judge: malformed verdict JSON — treating as FAIL (fail-safe)" >&2; exit 1; }
