---
description: "Drives the complete DevFlow pipeline from inside Claude Code — frame, plan, leash, analyze, STOP #1, build loop, review, fix cycles, verify, STOP #2, reconcile, ship, capture — tracked in a guarded flow ledger with in-conversation gates. Use to start a new feature end-to-end or to resume one mid-pipeline. Keywords: start, run devflow, new feature, pipeline, orchestrate, resume, continue feature."
argument-hint: "<feature description> (or empty to resume)"
---

# DevFlow Start — the whole pipeline, from this session

## Standing rules (apply to this ENTIRE session)

- **The ledger is law.** Every phase transition goes through
  `bash .specify/extensions/devflow/scripts/bash/devflow-flow.sh` (below: `FLOW`).
  It refuses out-of-order phases and phases whose exit artifacts don't exist.
  If it blocks: the fix is doing the work. NEVER edit `devflow-flow.json` by hand,
  and NEVER mark a phase done to "move things along".
- **You never do build work in this session.** Iterations dispatch as fresh
  `claude -p` sessions; you schedule and read state.
- **Human gates are conversations.** Render the evidence, ask, wait for their
  literal choice, pass it via `--decision`. Never choose for them; never proceed
  on silence.
- Keep a task per phase via the task tools if available, checked off as the ledger
  advances.

## Progress checklist (copy into your response; check off as phases complete)

```
- [ ] frame        - [ ] review
- [ ] plan         - [ ] fix-cycle-1 (or skip)
- [ ] leash        - [ ] fix-cycle-2 (or skip)
- [ ] analyze      - [ ] verify
- [ ] stop1 👤     - [ ] stop2 👤
- [ ] build        - [ ] reconcile (or skip)
                   - [ ] ship
                   - [ ] capture
```

## 0 · Resume or begin

1. No `.specify/feature.json` and empty `$ARGUMENTS`? Ask the user what to build.
2. A ledger already exists (`<fdir>/devflow-flow.json`)? Run `FLOW status`, tell the
   user where things stand, run `FLOW next`, and continue from that phase. This is
   the resume path — never re-init.
3. Fresh feature: ask the mode (attended | attended-step | autonomous; default
   attended), then `FLOW init <mode>`.

## 1 · frame

`FLOW start frame` → run `/speckit-specify` with the feature description → run
`/speckit-superspec-brainstorm` and work the edge cases **with the user**, folding
answers into the spec → run `/speckit-clarify` if open questions remain →
`FLOW complete frame`.
*If FLOW blocks completion:* spec.md doesn't exist yet — the specify step failed;
re-run it, don't argue with the guard.

## 2 · plan

`FLOW start plan` → `/speckit-plan` (the hardened template requires failing
acceptance tests — confirm they exist and are red) → `/speckit-tasks` (countable
format with `AC:` lines) → show the user the plan summary + red-test list →
`FLOW complete plan`.

## 3 · leash

`FLOW start leash` → run exactly:
`bash .specify/extensions/devflow/scripts/bash/devflow-init.sh <mode>` then
`bash .specify/extensions/devflow/scripts/bash/devflow-compute-leash.sh` →
`FLOW complete leash`.

## 4 · analyze

`FLOW start analyze` → `/speckit-analyze` → surface inconsistencies to the user and
fix the artifacts before proceeding → `FLOW complete analyze`.

## 5 · STOP #1 👤

`FLOW start stop1` → render `.specify/devflow/leash.md` AND the plan/red-test
summary in the conversation → ask plainly: **approve or reject?** →
`FLOW complete stop1 --decision <their literal choice>`.
*On reject:* the guard halts the pipeline — help the user re-plan; the ledger keeps
the record. Do not continue past a reject.

## 6 · build (dispatched, never in-session)

`FLOW start build`, then loop:
1. Dispatch ONE iteration via Bash: `claude -p "/speckit-devflow-iterate"`
   (fresh context; the child session's hooks + Stop-gate enforce the close).
2. Run `bash .specify/extensions/devflow/scripts/bash/devflow-loop-status.sh` —
   it parses/updates state, applies brakes and parking, and backstops dead
   dispatches.
3. Give the user a one-line pulse: `iter N/budget · task · outcome · parked: [...]`.
   **attended-step mode:** STOP and ask before the next dispatch.
4. While its JSON says `"continue": true` → repeat from 1.
   When `false` → `FLOW complete build`.

## 7 · review → fix cycles

`FLOW start review` → `/speckit-devflow-review` → `FLOW complete review` → read
`<fdir>/review/findings.json`:
- **status `clean`** → `FLOW complete fix-cycle-1 --skip` and
  `FLOW complete fix-cycle-2 --skip`.
- **status `findings`** → `FLOW start fix-cycle-1` → run exactly
  `bash .specify/extensions/devflow/scripts/bash/devflow-convert-findings.sh 1` →
  dispatch the loop as in §6 (fresh budget) → `/speckit-devflow-review` again (full
  gate, never lighter) → `FLOW complete fix-cycle-1`. Still findings? Repeat as
  cycle 2. After cycle 2, surviving findings are parked (the review command marks
  them).

## 8 · verify

`FLOW start verify` → `/speckit-devflow-verify` (its own prerequisite check refuses
on unresolved findings — if it refuses, the fix cycles above were not finished) →
`FLOW complete verify`.

## 9 · STOP #2 👤

`FLOW start stop2` → run
`bash .specify/extensions/devflow/scripts/bash/devflow-stop2-prep.sh` → render
`.specify/devflow/stop2.md` in the conversation → ask: **accept /
accept-with-deviation / reject?** →
`FLOW complete stop2 --decision <their literal choice>`.
*On reject:* halt, as at STOP #1.

## 10 · reconcile → ship → capture

- Deviation accepted, or anything parked? `FLOW start reconcile` →
  `/speckit-devflow-reconcile-contract` → `FLOW complete reconcile`.
  Nothing to reconcile → `FLOW complete reconcile --skip`.
- `FLOW start ship` → `/speckit-git-validate` → `/speckit-git-commit` (commit/PR
  linking the trail) → `FLOW complete ship`.
- `FLOW start capture` → `/speckit-devflow-capture` → present the vault-note
  candidates for the user to curate → `FLOW complete capture`.

## Done when

`bash .specify/extensions/devflow/scripts/bash/devflow-flow.sh next` prints
`complete`. Final message: the `FLOW status` output + where every artifact lives
(spec, plan, tasks, decisions, findings, verify report, PR).

## Handoff

None — this command IS the pipeline; when the ledger reads complete, the feature is
shipped and captured. A halted run (gate reject, interruption) hands off to a future
`/speckit-devflow-start` session, which resumes from the ledger.

## If anything goes sideways

The ledger + loop state ARE the recovery mechanism: a new session runs
`/speckit-devflow-start`, reads `FLOW status`, picks up at `FLOW next`. The guard
exists because a previous run of this pipeline skipped its review gate by hand
(gap B) — trust it over your own sense of "surely this phase is fine".
