# ADR-0030: STOP #1 gains a `revise` option — a real revision loop, not just approve/reject

**Status:** Accepted (extends [ADR-0002](0002-two-human-stops.md); uses the native `while` proven in
[ADR-0028](0028-review-loop-native-while.md))

**Context:** STOP #1 was binary: approve (hand the loop the keys) or reject (abort the whole run). But
the common real case is neither — the human reads the plan and wants it **revised**: a missed edge
case, a task that's too big, a wrong acceptance test. With only approve/reject, revising meant
aborting and re-running the whole pipeline by hand. The engine has no `goto`, but ADR-0028 showed
`while` is a real loop; a revision loop is expressible natively.

**Decision:** STOP #1 offers **approve / revise / reject**, and a `while(choice == 'revise')` sends
the plan back for another round, in both drivers.

- **Path A (`workflow.yml`):** after the `stop1` gate, a `revise-loop` `while` whose body re-runs
  `brainstorm → clarify → plan → tasks → checklist → reinit --fresh → compute-leash → agent-context
  → analyze → stop1-again`, capped at 5 revisions. Two design points that matter:
  - **`compute-leash` is INSIDE the body.** A revision regenerates `tasks.md`, so the budget from the
    first pass is stale; the leash must be recomputed from the new task set each round.
  - **`reinit --fresh`** resets per-task state. Regenerated task ids must not inherit the previous
    round's `attempts/parked/verdicts` — a new `T003` carrying the old `T003`'s attempts would park
    prematurely. `devflow-init.sh --fresh` clears them (and `cycle`).
  - The loop condition ORs the seed gate and the in-body re-gate choices (the duplicate-id constraint
    again), so a fresh `revise` from either keeps looping; `approve`/`reject` end it (reject aborts at
    the gate).
- **Path B (`devflow-flow.sh`):** `stop1`'s decision set gains `revise`. Choosing it **re-opens**
  `frame/plan/leash/analyze/stop1` (status → pending) and resets per-task state, so `start` re-runs
  them — the ledger equivalent of the engine's revise-loop. Verified: after a `revise`, frame and
  stop1 return to pending and `attempts/parked/cycle` clear.

**Consequences:**
- **The engineer stays in control at STOP #1**, not just at STOP #2. A plan that's close-but-wrong is
  cheap to fix — one `revise` instead of an abort + full re-run.
- **Bounded.** The `while` cap (5) and the ledger's strict ordering prevent infinite revision; the
  human is still the one choosing `revise` each round.
- **Both drivers in parity** (test-11 asserts two whiles — review-loop + revise-loop — and the STOP #1
  option set).
- **A non-TTY caveat, documented:** resuming a paused gate inside a `while` re-runs the loop body
  (the engine re-executes the parent step on resume). For revise that is the intended effect —
  regenerating the plan is the whole point — but operators running headless should know a resumed
  STOP #1 revise re-plans before re-prompting.
