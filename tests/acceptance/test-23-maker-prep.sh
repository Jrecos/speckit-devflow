#!/usr/bin/env bash
# test-23 — maker prep (ADR-0025): the payload carries the current whole-file contents (the
# mechanical half of anti-regression) plus task/criteria/spec and the constraints.
source "$(dirname "$0")/helpers.sh"
S=$(mktemp -d); make_scratch_project "$S"; install_devflow_assets "$S"
cd "$S"
PREP=".specify/extensions/devflow/scripts/bash/devflow-maker-prep.sh"

printf 'function sub(a,b){ return a-b; }\n' > math.js
printf 'AC: export add(a,b)\n' > ac.txt
printf 'add returns a+b\n' > slice.txt

PAYLOAD=$(CLAUDE_PROJECT_DIR="$S" bash "$PREP" --task-id T7 \
  --instruction "Add add(a,b) to math.js, keep sub" \
  --criteria-file ac.txt --slice-file slice.txt --files math.js --new-files util.js)
[ -f "$PAYLOAD" ] || fail "prep must print a payload file path"

python3 - "$PAYLOAD" <<'PY' || fail "payload schema wrong"
import json, sys
p = json.load(open(sys.argv[1]))
assert p["task_id"] == "T7", p["task_id"]
assert "Add add" in p["instruction"], p["instruction"]
assert "add(a,b)" in p["criteria"], p["criteria"]
assert "a+b" in p["spec_slice"], p["spec_slice"]
# the CURRENT file content must be present verbatim (this is what prevents continuity regression)
f = [f for f in p["files"] if f["path"] == "math.js"][0]
assert "function sub(a,b)" in f["content"], "current math.js content must be embedded verbatim"
assert "util.js" in p["new_files"], p["new_files"]
# constraints must instruct whole-file + preservation
joined = " ".join(p["constraints"]).lower()
assert "complete new content" in joined and "preserve" in joined, joined
print("ok")
PY

# A file listed under --files that does not exist yet is embedded as empty (the maker creates it).
PAYLOAD2=$(CLAUDE_PROJECT_DIR="$S" bash "$PREP" --task-id T8 --instruction "new" \
  --criteria-file ac.txt --slice-file slice.txt --files brand-new.js)
python3 - "$PAYLOAD2" <<'PY' || fail "missing --files entry should embed empty content"
import json, sys
p = json.load(open(sys.argv[1]))
f = [f for f in p["files"] if f["path"] == "brand-new.js"][0]
assert f["content"] == "", "a not-yet-existing listed file must embed empty content"
print("ok")
PY

pass "maker prep: payload carries task/criteria/spec + verbatim current file contents + constraints"
