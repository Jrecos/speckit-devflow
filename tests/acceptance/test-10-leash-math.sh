#!/usr/bin/env bash
source "$(dirname "$0")/helpers.sh"
S=$(mktemp -d); make_scratch_project "$S"; install_devflow_assets "$S"
cd "$S"
bash .specify/extensions/devflow/scripts/bash/devflow-init.sh attended
[ -f specs/012-demo/loop/state.json ] || fail "init must create state.json"
[ "$(read_state_key "$S" mode)" = '"attended"' ] || fail "mode not recorded"
# base_commit is stamped at init to HEAD (deterministic diff base for review/verify)
HEAD_SHA=$(git rev-parse HEAD)
[ "$(read_state_key "$S" base_commit)" = "\"$HEAD_SHA\"" ] \
  || fail "base_commit must be HEAD at init: $(read_state_key "$S" base_commit) != \"$HEAD_SHA\""
# re-init must NOT re-stamp base_commit (it is captured once, before build commits)
bash .specify/extensions/devflow/scripts/bash/devflow-init.sh attended
[ "$(read_state_key "$S" base_commit)" = "\"$HEAD_SHA\"" ] \
  || fail "base_commit must be preserved across re-init"
bash .specify/extensions/devflow/scripts/bash/devflow-compute-leash.sh
# fixture has 2 open tasks → ceil(2*2.5)=5
[ "$(read_state_key "$S" budget)" = '{"used": 0, "total": 5}' ] || fail "budget math wrong: $(read_state_key "$S" budget)"
grep -q "5 iterations" .specify/devflow/leash.md || fail "leash.md must state the budget"
grep -q "4" .specify/devflow/leash.md || fail "leash.md must state the time-box"
pass "init + leash: state created, ceil(2×2.5)=5, leash.md written"
