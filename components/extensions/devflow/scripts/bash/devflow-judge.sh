#!/usr/bin/env bash
# DevFlow judge seam (ADR-0014, fallback per ADR-0018).
# Role resolved by $DEVFLOW_JUDGE_CMD in the user's env; when unset, falls back to
# Claude as the judge (same-family — the documented weak layer; warns every time).
# stdin to the judge: {"diff","criteria","spec_slice"}; stdout: verdict JSON (schema-validated).
# Fail-safe: no judge resolvable / malformed output = exit 1 (callers treat as FAIL/block).
set -uo pipefail
DIFF_F="${1:?diff file}"; CRIT_F="${2:?criteria file}"; SLICE_F="${3:?spec-slice file}"
payload=$(python3 - "$DIFF_F" "$CRIT_F" "$SLICE_F" <<'PY'
import json, sys
print(json.dumps({
  "diff": open(sys.argv[1]).read(),
  "criteria": open(sys.argv[2]).read(),
  "spec_slice": open(sys.argv[3]).read(),
}))
PY
)

if [ -n "${DEVFLOW_JUDGE_CMD:-}" ]; then
  raw=$(printf '%s' "$payload" | bash -c "$DEVFLOW_JUDGE_CMD" 2>/tmp/devflow-judge.err) || {
    echo "devflow-judge: judge command failed (see /tmp/devflow-judge.err)" >&2; exit 1; }
else
  # ---- ADR-0018 fallback: Claude judges (same-family) ----
  command -v claude >/dev/null 2>&1 || {
    echo "devflow-judge: DEVFLOW_JUDGE_CMD is not set and no 'claude' CLI found for the fallback. Configure a judge (see /speckit-devflow-onboard)." >&2
    exit 1; }
  echo "devflow-judge: WARNING — same-family fallback (Claude judging Claude). Cross-family judging via DEVFLOW_JUDGE_CMD is the recommended topology (ADR-0003/0018)." >&2
  # Run from a temp dir: a project-cwd subprocess would load project hooks/CLAUDE.md and,
  # mid-iteration, arm our own Stop-gate against the judge session (must stay independent).
  JUDGE_DIR=$(mktemp -d)
  PROMPT='You are an adversarial, independent code judge. stdin is JSON: {"diff","criteria","spec_slice"}. Grade the diff STRICTLY against the criteria and spec slice — try to refute the claim that this work is done, not confirm it. Reply with ONLY minified JSON, no prose, no code fences: {"verdict":"PASS"|"FAIL","reason":"<one paragraph>","criteria":[{"name":"<criterion>","pass":true|false,"note":"<short>"}]}'
  raw=$(printf '%s' "$payload" | ( cd "$JUDGE_DIR" && claude -p "$PROMPT" 2>/tmp/devflow-judge.err )) || {
    rm -rf "$JUDGE_DIR"
    echo "devflow-judge: claude fallback failed (see /tmp/devflow-judge.err)" >&2; exit 1; }
  rm -rf "$JUDGE_DIR"
  # Strip accidental code fences before validation (models sometimes wrap JSON)
  raw=$(printf '%s' "$raw" | sed -e 's/^```json//' -e 's/^```//' -e 's/```$//')
fi
# NOTE: script via -c, data via argv — a `python3 - <<EOF` heredoc would steal stdin from the pipe.
python3 -c '
import json, sys
d = json.loads(sys.argv[1])
assert d.get("verdict") in ("PASS", "FAIL"), "verdict must be PASS|FAIL"
assert isinstance(d.get("reason"), str), "reason must be a string"
assert isinstance(d.get("criteria"), list), "criteria must be a list"
print(json.dumps(d))' "$raw" || { echo "devflow-judge: malformed verdict JSON — treating as FAIL (fail-safe)" >&2; exit 1; }
