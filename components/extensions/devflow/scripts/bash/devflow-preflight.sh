#!/usr/bin/env bash
# DevFlow machinery preflight (finding 9): assert the loop's own assets exist in THIS
# working tree before any state is written or any phase dispatches.
#
# Why: rendered assets (.claude/skills/, .claude/agents/) are written locally at install
# time and are not necessarily committed on every branch — a checkout of a branch that
# doesn't carry them leaves the loop SILENTLY DEGRADED: scripts still run, but the
# prompt/skill layer and the checker are gone, and nothing errors. This gate makes that
# state loud instead of silent (ADR-0010: the guarantee at the strongest layer).
#
# Callers: devflow-init.sh (every loop entry) and devflow-flow.sh init (the /start
# orchestrator's ledger creation). Exit 0 = complete; non-zero = missing assets, message
# names each one.
set -uo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}"

# The command stems every install renders (dot-form docs → dashed slugs). Kept in
# lockstep with components/extensions/devflow/commands/ — test-21 cross-checks the list.
STEMS="capture iterate onboard reconcile-contract record-decision review start status verify"

missing=()

[ -f .specify/extensions/devflow/devflow-config.yml ] \
  || missing+=("config: .specify/extensions/devflow/devflow-config.yml")

for s in devflow-init.sh devflow-flow.sh devflow-judge.sh devflow-judge-prep.sh \
         devflow-open-iteration.sh devflow-loop-status.sh devflow-diff-surface.sh; do
  [ -f ".specify/extensions/devflow/scripts/bash/$s" ] \
    || missing+=("script: .specify/extensions/devflow/scripts/bash/$s")
done

[ -f .claude/agents/devflow-checker.md ] \
  || missing+=("checker agent: .claude/agents/devflow-checker.md (iterate's independent grader)")

# Rendered command layer — either form counts per stem: a spec-kit skill render
# (.claude/skills/speckit-devflow-<stem>/SKILL.md) or a slash-command copy
# (.claude/commands/speckit-devflow-<stem>.md).
for s in $STEMS; do
  if [ ! -f ".claude/skills/speckit-devflow-$s/SKILL.md" ] \
     && [ ! -f ".claude/commands/speckit-devflow-$s.md" ]; then
    missing+=("command: speckit-devflow-$s (no .claude/skills/ render and no .claude/commands/ copy)")
  fi
done

if [ "${#missing[@]}" -gt 0 ]; then
  {
    echo "devflow-preflight: BLOCKED — the working tree is missing DevFlow machinery:"
    printf '  - %s\n' "${missing[@]}"
    echo "Likely cause: this branch/checkout does not carry the rendered assets (they are"
    echo "written at install time, not always committed). Fix: return this checkout to the"
    echo "branch that has them and do other-branch work in a separate 'git worktree add'"
    echo "(the DevFlow checkout should never switch away), or re-run the install"
    echo "(specify extension add … + /speckit-devflow-onboard). Do NOT run the loop degraded."
  } >&2
  exit 1
fi
echo "devflow-preflight: OK — machinery complete"
