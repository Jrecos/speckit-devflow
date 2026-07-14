#!/usr/bin/env bash
source "$(dirname "$0")/helpers.sh"
S=$(mktemp -d); make_scratch_project "$S"; install_devflow_assets "$S"
cd "$S"
CHK=".specify/extensions/devflow/scripts/bash/devflow-check-review.sh"
# missing findings.json → FAIL
set +e; bash "$CHK" 2>/dev/null; rc=$?; set -e
[ "$rc" -ne 0 ] || fail "must fail when findings.json is missing"
# status=findings (unresolved) → FAIL
echo '{"status":"findings","open":[{"id":"F1","severity":"high","file":"x.ts","summary":"SQLi"}],"cycle":1}' > specs/012-demo/review/findings.json
set +e; bash "$CHK" 2>/dev/null; rc=$?; set -e
[ "$rc" -ne 0 ] || fail "must fail when status=findings"
# clean → PASS ; parked → PASS
echo '{"status":"clean","open":[],"cycle":1}' > specs/012-demo/review/findings.json
bash "$CHK" || fail "clean must pass"
echo '{"status":"parked","open":[{"id":"F9","severity":"low","file":"y.ts","summary":"nit"}],"cycle":2}' > specs/012-demo/review/findings.json
bash "$CHK" || fail "parked must pass"
pass "verify prerequisite: blocks on missing/unresolved, passes clean/parked"
