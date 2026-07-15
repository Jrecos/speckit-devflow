#!/usr/bin/env bash
# C1 (ADR-0023): the feature diff surface now lives in devflow-diff-surface.sh — this test is
# where the base_commit-not-merge-base invariant (dogfood finding 5) is mechanically enforced,
# so test-15 can assert the command merely INVOKES the script.
source "$(dirname "$0")/helpers.sh"
S=$(mktemp -d); make_scratch_project "$S"; install_devflow_assets "$S"
cd "$S"
DS=".specify/extensions/devflow/scripts/bash/devflow-diff-surface.sh"

# A PRIOR-feature commit: the stacked-branch churn a stale merge-base would wrongly include.
echo "prior" > prior-feature.txt; git add -A; git commit -qm "prior feature work"
PRIOR=$(git rev-parse HEAD)

# Stamp base_commit at loop start = HEAD (PRIOR) via the real init script.
bash .specify/extensions/devflow/scripts/bash/devflow-init.sh attended >/dev/null
base_stamped=$(python3 -c 'import json;print(json.load(open("specs/012-demo/loop/state.json"))["base_commit"])')
[ "$base_stamped" = "$PRIOR" ] || fail "init should stamp base_commit=HEAD ($PRIOR), got $base_stamped"

# A feature build commit touching the feature dir.
echo "feature code" > specs/012-demo/impl.txt; git add -A; git commit -qm "feature build T1"

# 1. `base` returns the STAMPED base_commit — never a recomputed merge-base.
[ "$(bash "$DS" base)" = "$PRIOR" ] || fail "diff-surface base must equal the stamped base_commit"

# 2. `diff` is byte-identical to `git diff <base_commit> HEAD`, and scoped to the feature build:
#    prior-feature.txt predates base_commit, so it must NOT appear (the merge-base bug would show it).
got=$(bash "$DS" diff); want=$(git diff "$PRIOR" HEAD)
[ "$got" = "$want" ] || fail "diff-surface diff must equal 'git diff base_commit HEAD' byte-for-byte"
echo "$got" | grep -q 'impl.txt' || fail "diff should contain the feature build (impl.txt)"
if echo "$got" | grep -q 'prior-feature.txt'; then
  fail "diff must NOT include prior-feature churn — proof it uses base_commit, not merge-base"
fi

# 3. Null base_commit (older state) → fall back to the first commit that touched the feature dir.
python3 -c 'import json;p="specs/012-demo/loop/state.json";d=json.load(open(p));d["base_commit"]=None;json.dump(d,open(p,"w"))'
first_touch=$(git log --reverse --format=%H -- specs/012-demo | head -1)
[ "$(bash "$DS" base 2>/dev/null)" = "$first_touch" ] || fail "null base_commit must fall back to the first commit touching the feature dir"

# 4. `first-commit` = the first commit touching the feature dir (capture's range base).
[ "$(bash "$DS" first-commit)" = "$first_touch" ] || fail "first-commit must be the first commit touching the feature dir"

pass "diff-surface: base_commit honored (not merge-base), byte-identical diff, null→first-touch fallback"
