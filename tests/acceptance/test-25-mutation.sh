#!/usr/bin/env bash
# test-25 — internal mutation tester (ADR-0032 Layer B): proves it distinguishes a STRONG test
# (kills mutants) from a WEAK test (mutants survive). Hermetic, no model, no external dependency.
source "$(dirname "$0")/helpers.sh"
S=$(mktemp -d); make_scratch_project "$S"; install_devflow_assets "$S"; cd "$S"
MUT=".specify/extensions/devflow/scripts/bash/devflow-mutate.sh"

mkdir -p src test
# Pure arithmetic functions with NO equivalent mutants — every operator/constant mutation changes
# an output the test can observe, so a strong test kills all of them (no equivalent-mutant ceiling).
cat > src/m.js <<'JS'
function price(qty, unit) { return qty * unit; }
function net(gross, fee) { return gross - fee; }
function bothPositive(a, b) { return a > 0 && b > 0; }
module.exports = { price, net, bothPositive };
JS

# 1. STRONG test — pins each function with inputs that make every mutation observable.
cat > test/strong.test.js <<'JS'
const { test } = require('node:test'); const assert = require('node:assert');
const { price, net, bothPositive } = require('../src/m.js');
test('arithmetic + logic fully pinned', () => {
  assert.strictEqual(price(3, 4), 12);      // * -> / would give 0.75; kills it
  assert.strictEqual(price(1, 5), 5);
  assert.strictEqual(net(10, 3), 7);        // - -> + would give 13; kills it
  assert.strictEqual(bothPositive(1, 1), true);
  assert.strictEqual(bothPositive(1, -1), false);   // && -> || would give true; kills it
  assert.strictEqual(bothPositive(-1, 1), false);
});
JS
out=$(CLAUDE_PROJECT_DIR="$S" bash "$MUT" src/m.js --test "node --test test/strong.test.js" --max 20 2>/dev/null | tail -1)
strong_score=$(echo "$out" | python3 -c "import sys,json;print(json.load(sys.stdin)['score'])")
strong_surv=$(echo "$out" | python3 -c "import sys,json;print(json.load(sys.stdin)['survived'])")
# no equivalent mutants here → a strong test should catch (nearly) all of them
python3 -c "assert $strong_score >= 0.7, 'strong test should score >=0.7, got $strong_score'" || fail "strong test scored too low ($strong_score)"

# 2. WEAK test — tautological / non-observing assertions; the arith + logic mutants SURVIVE
cat > test/weak.test.js <<'JS'
const { test } = require('node:test'); const assert = require('node:assert');
const { price, net, bothPositive } = require('../src/m.js');
test('weak — barely checks anything', () => {
  assert.ok(typeof price(3,4) === 'number');   // any number passes; * -> / survives
  assert.ok(net(10,3) !== undefined);          // tautological; - -> + survives
  assert.ok(bothPositive(1,1) === true);       // only the true case; && -> || survives
});
JS
out2=$(CLAUDE_PROJECT_DIR="$S" bash "$MUT" src/m.js --test "node --test test/weak.test.js" --max 20 2>/dev/null | tail -1)
weak_score=$(echo "$out2" | python3 -c "import sys,json;print(json.load(sys.stdin)['score'])")
weak_surv=$(echo "$out2" | python3 -c "import sys,json;print(json.load(sys.stdin)['survived'])")
# the weak test must let mutants survive → strictly lower score than the strong test, with survivors
python3 -c "assert $weak_surv >= 1, 'weak test must leave survivors, got $weak_surv'" || fail "weak test left no survivors ($weak_surv)"
python3 -c "assert $weak_score < $strong_score, 'weak ($weak_score) must score below strong ($strong_score)'" || fail "mutation score did not discriminate weak from strong"

# 3. RED baseline → refuses (mutation testing is meaningless on a red suite)
cat > test/red.test.js <<'JS'
const { test } = require('node:test'); const assert = require('node:assert');
const { price } = require('../src/m.js');
test('deliberately failing', () => { assert.strictEqual(price(3,4), 999); });
JS
red=$(CLAUDE_PROJECT_DIR="$S" bash "$MUT" src/m.js --test "node --test test/red.test.js" --max 5 2>/dev/null | tail -1)
echo "$red" | grep -q 'red baseline' || fail "must refuse a red baseline"

pass "mutation tester: strong test kills mutants ($strong_score), weak test leaves survivors ($weak_score), red baseline refused"
