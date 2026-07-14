#!/usr/bin/env bash
source "$(dirname "$0")/helpers.sh"
S=$(mktemp -d); make_scratch_project "$S"; install_devflow_assets "$S"
cd "$S"
J=".specify/extensions/devflow/scripts/bash/devflow-judge.sh"
echo "diff" > d.txt; echo "crit" > c.txt; echo "slice" > s.txt

# 1a. Missing DEVFLOW_JUDGE_CMD AND no claude CLI on PATH → exit 1, clear reason (ADR-0018 fail-safe)
mkdir -p fakebin   # minimal PATH: python3+bash reachable, no claude
ln -sf "$(command -v python3)" fakebin/python3
ln -sf "$(command -v bash)" fakebin/bash
ln -sf "$(command -v sed)" fakebin/sed 2>/dev/null || true
set +e; err=$(DEVFLOW_JUDGE_CMD= PATH="$PWD/fakebin:/usr/bin:/bin" bash "$J" d.txt c.txt s.txt 2>&1 >/dev/null); rc=$?; set -e
[ "$rc" -eq 1 ] || fail "no judge cmd + no claude must exit 1, got $rc"
echo "$err" | grep -q "DEVFLOW_JUDGE_CMD" || fail "reason must name the env var"

# 1b. Missing DEVFLOW_JUDGE_CMD with a (fake) claude on PATH → same-family fallback runs, warns
cat > fakebin/claude <<'EOF'
#!/usr/bin/env bash
cat > /dev/null   # drain the piped payload
echo '{"verdict":"PASS","reason":"fallback ok","criteria":[]}'
EOF
chmod +x fakebin/claude
set +e; out=$(DEVFLOW_JUDGE_CMD= PATH="$PWD/fakebin:/usr/bin:/bin" bash "$J" d.txt c.txt s.txt 2>fallback.err); rc=$?; set -e
[ "$rc" -eq 0 ] || fail "fallback should succeed with claude present, got $rc: $(cat fallback.err)"
echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["verdict"]=="PASS", d'
grep -qi "same-family" fallback.err || fail "fallback must warn about same-family judging"

# 2. Malformed verdict JSON → exit 1 (fail-safe)
set +e; DEVFLOW_JUDGE_CMD="echo not-json" bash "$J" d.txt c.txt s.txt >/dev/null 2>&1; rc=$?; set -e
[ "$rc" -eq 1 ] || fail "malformed verdict must exit 1, got $rc"

# 3. Valid PASS verdict → exit 0, normalized JSON on stdout; input actually reached the judge
cat > fake-judge.sh <<'EOF'
#!/usr/bin/env bash
input=$(cat)
echo "$input" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert set(d)=={"diff","criteria","spec_slice"}'
echo '{"verdict":"PASS","reason":"looks right","criteria":[{"name":"c1","pass":true,"note":""}]}'
EOF
chmod +x fake-judge.sh
out=$(DEVFLOW_JUDGE_CMD="./fake-judge.sh" bash "$J" d.txt c.txt s.txt)
echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["verdict"]=="PASS", d'

# 4. FAIL verdict → exit 0 (verdict delivered; caller decides), verdict FAIL in output
cat > fail-judge.sh <<'EOF'
#!/usr/bin/env bash
cat > /dev/null
echo '{"verdict":"FAIL","reason":"error paths leak state","criteria":[]}'
EOF
chmod +x fail-judge.sh
out=$(DEVFLOW_JUDGE_CMD="./fail-judge.sh" bash "$J" d.txt c.txt s.txt)
echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["verdict"]=="FAIL", d'
pass "judge seam: env fail-safe, schema validation, PASS/FAIL delivery"
