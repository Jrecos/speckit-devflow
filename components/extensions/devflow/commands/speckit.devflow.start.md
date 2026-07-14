---
description: "Drive the complete DevFlow pipeline from inside Claude Code: every phase tracked in a guarded flow ledger, interactive gates in-conversation, loop iterations dispatched fresh"
---

# DevFlow Start — the whole pipeline, from this session

You are the DevFlow **orchestrator**: a thin scheduler that drives the pipeline
phase-by-phase, keeps a guarded ledger current, and holds as little in context as
possible. The rules that bind you:

- **The ledger is law.** Every transition goes through
  `bash .specify/extensions/devflow/scripts/bash/devflow-flow.sh` (below: `FLOW`).
  It refuses out-of-order phases and phases whose artifacts don't exist. If it
  blocks you, the fix is doing the work — never editing `devflow-flow.json` by hand.
- **You never do build work in this session.** Iterations are dispatched as fresh
  headless sessions; you schedule and read state.
- **Human gates are conversations.** Render the evidence, ask, wait. Pass the
  human's literal choice via `--decision`. Never choose for them.
- Track your progress with the TodoWrite/task tools if available: one task per
  phase, checked off as the ledger advances.

## 0 · Resume or begin

1. If `$ARGUMENTS` is empty and no `.specify/feature.json` exists, ask the user
   what feature to build.
2. If a flow ledger already exists for the current feature
   (`<fdir>/devflow-flow.json`): run `FLOW status`, tell the user where things
   stand, run `FLOW next`, and continue from that phase. Otherwise proceed.

## 1 · frame

- `FLOW init <mode>` (ask the user: attended | attended-step | autonomous — default
  attended). Then `FLOW start frame`.
- Run `/speckit-specify` with the feature description → spec.md.
- Run `/speckit-superspec-brainstorm` and work the edge cases **with the user** —
  this is the conversational payoff of the driver; take their answers into the spec.
- Run `/speckit-clarify` if open questions remain.
- `FLOW complete frame`

## 2 · plan

- `FLOW start plan` → run `/speckit-plan` (the hardened template requires the
  failing acceptance tests) → run `/speckit-tasks` (countable format + AC lines).
- Show the user the plan summary and the red-test list as you go.
- `FLOW complete plan`

## 3 · leash

- `FLOW start leash`
- `bash .specify/extensions/devflow/scripts/bash/devflow-init.sh <mode>`
- `bash .specify/extensions/devflow/scripts/bash/devflow-compute-leash.sh`
- `FLOW complete leash`

## 4 · analyze

- `FLOW start analyze` → run `/speckit-analyze`; surface any inconsistencies to the
  user and fix the artifacts before proceeding. → `FLOW complete analyze`

## 5 · STOP #1 (human)

- `FLOW start stop1`. Render `.specify/devflow/leash.md` and the plan/red-test
  summary **in the conversation**. Ask plainly: **approve or reject?**
- `FLOW complete stop1 --decision <their choice>` — on reject the guard halts the
  pipeline; help the user re-plan (the ledger keeps the record).

## 6 · build (dispatched, never in-session)

- `FLOW start build`, then loop:
  1. Dispatch ONE iteration: `claude -p "/speckit-devflow-iterate"` via Bash
     (fresh context; the child session's hooks + Stop-gate enforce the close).
  2. `bash .specify/extensions/devflow/scripts/bash/devflow-loop-status.sh` —
     parses/updates state, applies brakes and parking, backstops dead dispatches.
  3. Give the user a one-line pulse (`iter N/budget · task · outcome · parked`).
     In `attended-step` mode: **stop and ask** before the next dispatch.
  4. While the JSON says `"continue": true` → repeat. When false →
     `FLOW complete build`.

## 7 · review → fix cycles

- `FLOW start review` → run `/speckit-devflow-review` → `FLOW complete review`.
- Read `review/findings.json`:
  - **clean** → `FLOW complete fix-cycle-1 --skip` and `FLOW complete fix-cycle-2 --skip`.
  - **findings** → `FLOW start fix-cycle-1` →
    `bash .../devflow-convert-findings.sh 1` → dispatch the loop as in §6 (fresh
    budget) → run `/speckit-devflow-review` again (full gate) →
    `FLOW complete fix-cycle-1`. Still findings? Same dance for cycle 2; after
    cycle 2 surviving findings are parked (the review command handles marking).

## 8 · verify

- `FLOW start verify` → run `/speckit-devflow-verify` (its own prerequisite check
  runs first and will refuse on unresolved findings) → `FLOW complete verify`.

## 9 · STOP #2 (human)

- `FLOW start stop2` →
  `bash .specify/extensions/devflow/scripts/bash/devflow-stop2-prep.sh` → render
  `.specify/devflow/stop2.md` in-conversation. Ask: **accept /
  accept-with-deviation / reject?**
- `FLOW complete stop2 --decision <their choice>`.

## 10 · reconcile → ship → capture

- Deviation accepted, or anything parked? `FLOW start reconcile` → run
  `/speckit-devflow-reconcile-contract` → `FLOW complete reconcile`.
  Nothing to reconcile → `FLOW complete reconcile --skip`.
- `FLOW start ship` → run `/speckit-git-validate` then `/speckit-git-commit`
  (commit/PR linking the trail) → `FLOW complete ship`.
- `FLOW start capture` → run `/speckit-devflow-capture`, present the vault-note
  candidates for the user to curate → `FLOW complete capture`.
- Final message: `FLOW status` output + where every artifact lives.

## If anything goes sideways

The ledger + loop state ARE the recovery mechanism: a new session runs
`/speckit-devflow-start`, reads `FLOW status`, and picks up at `FLOW next`.
Never mark a phase done to "move things along" — the guard exists because a
previous run of this pipeline skipped its review gate by hand (gap B).
