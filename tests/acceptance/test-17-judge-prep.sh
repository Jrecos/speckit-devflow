#!/usr/bin/env bash
# C2 (ADR-0023): the judge's 3-file assembly now lives in devflow-judge-prep.sh — this test is
# where the `TESTS:`-line-first invariant (dogfood finding 6) is mechanically enforced, so
# test-15 can assert the commands merely INVOKE the script.
source "$(dirname "$0")/helpers.sh"
S=$(mktemp -d); make_scratch_project "$S"; install_devflow_assets "$S"
cd "$S"
JP=".specify/extensions/devflow/scripts/bash/devflow-judge-prep.sh"
DS=".specify/extensions/devflow/scripts/bash/devflow-diff-surface.sh"

bash .specify/extensions/devflow/scripts/bash/devflow-init.sh attended >/dev/null
echo "code" > specs/012-demo/impl.txt; git add -A; git commit -qm "feature build"
echo "wip"  >> specs/012-demo/impl.txt          # an uncommitted working change

printf -- '- AC: does the thing\n' > ac.txt
printf 'spec slice body\n' > slice.txt

# 1. --diff working: criteria LEADS with the TESTS: line; body is the AC file verbatim;
#    diff == `git diff`; slice passed through unchanged.
read -r D C SL < <(bash "$JP" --diff working --tests "scoped green" --criteria-file ac.txt --slice-file slice.txt)
{ [ -f "$D" ] && [ -f "$C" ] && [ -f "$SL" ]; } || fail "judge-prep must emit three files"
head -1 "$C" | grep -qx 'TESTS: scoped green' || fail "criteria first line must be 'TESTS: scoped green'"
tail -n +2 "$C" | diff - ac.txt >/dev/null || fail "criteria body must be the AC file verbatim after the TESTS line"
diff "$D" <(git diff) >/dev/null || fail "--diff working must equal 'git diff' byte-for-byte"
diff "$SL" slice.txt >/dev/null || fail "slice must be passed through verbatim"

# 2. --diff feature: diff == devflow-diff-surface.sh diff (the C1 feature surface).
read -r D2 C2 SL2 < <(bash "$JP" --diff feature --tests "36 passed / 0 failed" --criteria-file ac.txt --slice-file slice.txt)
head -1 "$C2" | grep -qx 'TESTS: 36 passed / 0 failed' || fail "verify-mode TESTS line wrong"
diff "$D2" <(bash "$DS" diff) >/dev/null || fail "--diff feature must equal devflow-diff-surface.sh diff"

# 3. the assembled paths drive devflow-judge.sh unchanged (it still just reads the 3 files);
#    the judge receives criteria whose first line is the TESTS: oracle.
cat > fj.sh <<'EOF'
#!/usr/bin/env bash
python3 -c 'import json,sys
d=json.load(sys.stdin)
assert set(d)=={"diff","criteria","spec_slice"}, d.keys()
assert d["criteria"].splitlines()[0].startswith("TESTS:"), "criteria must lead with TESTS:"
print(json.dumps({"verdict":"PASS","reason":"ok","criteria":[]}))'
EOF
chmod +x fj.sh
out=$(DEVFLOW_JUDGE_CMD="./fj.sh" bash .specify/extensions/devflow/scripts/bash/devflow-judge.sh "$D" "$C" "$SL")
echo "$out" | python3 -c 'import json,sys;assert json.load(sys.stdin)["verdict"]=="PASS"' \
  || fail "assembled files must feed devflow-judge.sh and carry the TESTS: line"

pass "judge-prep: TESTS: line guaranteed first; working/feature diff sources; slice passthrough; feeds judge"
