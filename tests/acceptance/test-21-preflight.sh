#!/usr/bin/env bash
source "$(dirname "$0")/helpers.sh"
# Finding 9: the machinery preflight makes a degraded working tree (branch without the
# rendered assets) fail LOUDLY at loop entry instead of running the loop without its
# skill layer / checker. Behavior-tests devflow-preflight.sh and its wiring into
# devflow-init.sh + devflow-flow.sh init.

S=$(mktemp -d); make_scratch_project "$S"; install_devflow_assets "$S"
cd "$S"
PRE=".specify/extensions/devflow/scripts/bash/devflow-preflight.sh"
INIT=".specify/extensions/devflow/scripts/bash/devflow-init.sh"
FLOW=".specify/extensions/devflow/scripts/bash/devflow-flow.sh"

# 1. intact tree → preflight passes
bash "$PRE" >/dev/null || fail "preflight must pass on a complete install"

# 2. commands layer gone (the konexo failure: checkout of a branch without the renders)
mv .claude/commands /tmp/preflight-cmds-backup
set +e; err=$(bash "$PRE" 2>&1); rc=$?; set -e
[ "$rc" -ne 0 ] || fail "preflight must fail when the rendered command layer is missing"
echo "$err" | grep -q 'speckit-devflow-iterate' || fail "error must name a missing command stem"
# 2b. skills form satisfies the same stem check (either render form counts)
mkdir -p .claude/skills
for st in capture iterate onboard reconcile-contract record-decision review start status verify; do
  mkdir -p ".claude/skills/speckit-devflow-$st"; echo x > ".claude/skills/speckit-devflow-$st/SKILL.md"
done
bash "$PRE" >/dev/null || fail "preflight must accept the .claude/skills/ render form"
rm -rf .claude/skills
mv /tmp/preflight-cmds-backup .claude/commands

# 3. checker agent gone → fail, names the checker
mv .claude/agents/devflow-checker.md /tmp/preflight-checker-backup.md
set +e; err=$(bash "$PRE" 2>&1); rc=$?; set -e
[ "$rc" -ne 0 ] || fail "preflight must fail without the checker agent"
echo "$err" | grep -q 'devflow-checker' || fail "error must name the missing checker"
mv /tmp/preflight-checker-backup.md .claude/agents/devflow-checker.md

# 4. a core script gone → fail, names it
mv .specify/extensions/devflow/scripts/bash/devflow-judge.sh /tmp/preflight-judge-backup.sh
set +e; err=$(bash "$PRE" 2>&1); rc=$?; set -e
[ "$rc" -ne 0 ] || fail "preflight must fail without devflow-judge.sh"
echo "$err" | grep -q 'devflow-judge.sh' || fail "error must name the missing script"
mv /tmp/preflight-judge-backup.sh .specify/extensions/devflow/scripts/bash/devflow-judge.sh

# 5. wiring: init refuses to write state in a degraded tree
mv .claude/agents/devflow-checker.md /tmp/preflight-checker-backup.md
set +e; bash "$INIT" attended >/dev/null 2>&1; rc=$?; set -e
[ "$rc" -ne 0 ] || fail "devflow-init.sh must be gated by the preflight"
[ ! -f specs/012-demo/loop/state.json ] || fail "init must not write state.json when preflight blocks"
# 5b. flow init likewise refuses to create the ledger
set +e; bash "$FLOW" init attended >/dev/null 2>&1; rc=$?; set -e
[ "$rc" -ne 0 ] || fail "devflow-flow.sh init must be gated by the preflight"
[ ! -f specs/012-demo/devflow-flow.json ] || fail "flow init must not create the ledger when preflight blocks"
mv /tmp/preflight-checker-backup.md .claude/agents/devflow-checker.md

# 6. restored tree → both entry points work
bash "$INIT" attended >/dev/null || fail "init must succeed once the tree is complete"
[ -f specs/012-demo/loop/state.json ] || fail "init should have written state.json"
bash "$FLOW" init attended >/dev/null || fail "flow init must succeed once the tree is complete"

# 7. the stem list in the preflight stays in lockstep with the shipped commands
cd "$REPO_ROOT"
for f in components/extensions/devflow/commands/*.md; do
  stem="$(basename "$f" .md | sed 's/^speckit\.devflow\.//')"
  grep -q "\b$stem\b" components/extensions/devflow/scripts/bash/devflow-preflight.sh \
    || fail "preflight STEMS list is missing shipped command '$stem'"
done

pass "machinery preflight: degraded trees blocked at init + flow init, intact trees pass"
