#!/usr/bin/env bash
# DevFlow test-audit seam (ADR-0032; mirrors the judge seam of ADR-0014).
# Cross-family review of ONE acceptance test against the spec. Role resolved by
# $DEVFLOW_TESTAUDIT_CMD; when unset, the audit is SKIPPED (Claude-sufficient, ADR-0020) — it is a
# proactive safety net, not a hard requirement, so absence must not block planning.
#
# Args: <spec-file> <test-file>
# stdin to the audit command: {"spec","test","path"}; stdout: {"ok":bool,"issues":[...]}.
# Exit: 0 = audited (JSON on stdout). 3 = skipped (no auditor, or backend down — caller treats as
#       "not audited", not a failure). 1 = configured auditor produced bad output.
set -uo pipefail
SPEC_F="${1:?spec file}"; TEST_F="${2:?test file}"
[ -f "$SPEC_F" ] && [ -f "$TEST_F" ] || { echo "devflow-testaudit: missing spec or test file" >&2; exit 2; }

if [ -z "${DEVFLOW_TESTAUDIT_CMD:-}" ]; then
  echo "devflow-testaudit: no DEVFLOW_TESTAUDIT_CMD — audit skipped (Claude-sufficient, ADR-0020)" >&2
  exit 3
fi

payload="$(python3 -c "
import json,sys
print(json.dumps({'spec':open('$SPEC_F').read(),'test':open('$TEST_F').read(),'path':'$TEST_F'}))
")"
raw="$(printf '%s' "$payload" | bash -c "$DEVFLOW_TESTAUDIT_CMD" 2>/tmp/devflow-testaudit.err)"; rc=$?
if [ "$rc" -eq 3 ]; then
  echo "devflow-testaudit: auditor signaled skip/degrade (exit 3)" >&2; exit 3
elif [ "$rc" -ne 0 ]; then
  echo "devflow-testaudit: auditor command failed (see /tmp/devflow-testaudit.err)" >&2; exit 1
fi
# validate + normalize
printf '%s' "$raw" | sed -e 's/^```json//' -e 's/^```//' -e 's/```$//' | python3 -c "
import json,sys
d=json.loads(sys.stdin.read())
assert isinstance(d.get('ok'),bool), 'ok must be bool'
assert isinstance(d.get('issues'),list), 'issues must be a list'
print(json.dumps(d))
" || { echo "devflow-testaudit: malformed audit JSON" >&2; exit 1; }
