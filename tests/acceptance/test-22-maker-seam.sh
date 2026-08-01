#!/usr/bin/env bash
# test-22 — the maker seam (ADR-0025): exit 0/1/3 contract + mechanical anti-regression.
# Hermetic: a fake maker command injected via $DEVFLOW_MAKER_CMD, no live model.
source "$(dirname "$0")/helpers.sh"
S=$(mktemp -d); make_scratch_project "$S"; install_devflow_assets "$S"
cd "$S"
M=".specify/extensions/devflow/scripts/bash/devflow-maker.sh"

# A payload exposing one current file (3 lines) so the anti-regression checks have something to bite.
cat > payload.json <<'EOF'
{"task_id":"T1","instruction":"add x","criteria":"AC: x=1","spec_slice":"x is 1","files":[{"path":"a.js","content":"const a=1;\nconst b=2;\nconst c=3;\n"}],"new_files":[]}
EOF

# 1. Unset DEVFLOW_MAKER_CMD → exit 3 (Claude-sufficient, NOT a failure)
set +e; err=$(DEVFLOW_MAKER_CMD= bash "$M" payload.json 2>&1 >/dev/null); rc=$?; set -e
[ "$rc" -eq 3 ] || fail "unset maker must exit 3, got $rc"
echo "$err" | grep -qi "Claude-sufficient" || fail "exit-3 reason must say Claude-sufficient"

# 2. Valid whole-file output → exit 0, normalized JSON on stdout
set +e; out=$(DEVFLOW_MAKER_CMD='cat >/dev/null; printf "%s" "{\"files\":[{\"path\":\"a.js\",\"content\":\"const a=1;\nconst b=2;\nconst c=3;\nconst x=1;\n\"}]}"' bash "$M" payload.json 2>err.log); rc=$?; set -e
[ "$rc" -eq 0 ] || fail "valid maker output must exit 0, got $rc: $(cat err.log)"
echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["files"][0]["path"]=="a.js", d' || fail "normalized files missing"

# 3. Output writes a path the maker was never shown → exit 1 (anti-regression)
set +e; err=$(DEVFLOW_MAKER_CMD='cat >/dev/null; printf "%s" "{\"files\":[{\"path\":\"secret.js\",\"content\":\"x\"}]}"' bash "$M" payload.json 2>&1 >/dev/null); rc=$?; set -e
[ "$rc" -eq 1 ] || fail "unseen-path write must exit 1, got $rc"
echo "$err" | grep -qi "unseen path" || fail "must name the unseen-path violation"

# 4. Output deletes most of an existing file → exit 1 (continuity regression)
set +e; err=$(DEVFLOW_MAKER_CMD='cat >/dev/null; printf "%s" "{\"files\":[{\"path\":\"a.js\",\"content\":\"const a=1;\"}]}"' bash "$M" payload.json 2>&1 >/dev/null); rc=$?; set -e
[ "$rc" -eq 1 ] || fail "massive shrink must exit 1, got $rc"
echo "$err" | grep -qi "continuity regression" || fail "must name the continuity regression"

# 5. Malformed JSON → exit 1 (fail-safe)
set +e; DEVFLOW_MAKER_CMD='cat >/dev/null; echo not-json' bash "$M" payload.json >/dev/null 2>&1; rc=$?; set -e
[ "$rc" -eq 1 ] || fail "malformed maker output must exit 1, got $rc"

# 6. A configured maker that fails (non-zero) → exit 1 (failed attempt, feeds escalation)
set +e; DEVFLOW_MAKER_CMD='cat >/dev/null; exit 7' bash "$M" payload.json >/dev/null 2>&1; rc=$?; set -e
[ "$rc" -eq 1 ] || fail "failing maker command must exit 1, got $rc"

# 7. A maker that signals degrade-to-Claude (exit 3) → passed through as exit 3
set +e; DEVFLOW_MAKER_CMD='cat >/dev/null; exit 3' bash "$M" payload.json >/dev/null 2>&1; rc=$?; set -e
[ "$rc" -eq 3 ] || fail "maker exit-3 (degrade) must pass through as 3, got $rc"

# 8. Tolerates a stray {"notes"} object inside the files array (real local-model deviation)
set +e; out=$(DEVFLOW_MAKER_CMD='cat >/dev/null; printf "%s" "{\"files\":[{\"path\":\"a.js\",\"content\":\"const a=1;\nconst b=2;\nconst c=3;\nconst x=1;\n\"},{\"notes\":\"did it\"}]}"' bash "$M" payload.json 2>err.log); rc=$?; set -e
[ "$rc" -eq 0 ] || fail "stray notes object must be tolerated (exit 0), got $rc: $(cat err.log)"
echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert len(d["files"])==1 and d.get("notes")=="did it", d' || fail "stray notes must be salvaged, files normalized"

pass "maker seam: exit 0/1/3 contract, anti-regression (unseen path + shrink), fail-safe, stray-notes tolerance"
