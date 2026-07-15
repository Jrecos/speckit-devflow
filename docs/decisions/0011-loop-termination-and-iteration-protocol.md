# ADR-0011: Loop termination model & iteration protocol placement

**Status:** Accepted (amended by [ADR-0016](0016-verification-corrections.md): config key
renamed `retry_cap` → `max_attempts_per_task`; one-task-per-iteration upgraded to
hook-enforced via the GREEN close; the engine's `max_iterations` is a static cap — budget
enforcement lives in the shell-evaluated loop condition; accepting with parked items at
STOP #2 routes through reconcile-contract)

**Context:** HANDOFF Q5: where do auto-commit and one-task-per-iteration live? And (surfaced
while simulating multi-task runs) how is the loop's budget determined? The research is
explicit that termination criteria *are* the cost control (cost scales with wall-clock),
and that no single brake catches every runaway mode. Community engines use fixed caps
(loop: 8, ralph: 10); Devin uses a 45-minute time-box; nothing in the corpus calibrates
budget-to-task ratios.

**Decision:**

**Three independent brakes**, each catching a different runaway mode:

1. **Per-task retry cap** — default **2** attempts per task. A task that exhausts it is
   **parked** (`needs-human`): excluded from picking, loop continues, surfaced with
   evidence at STOP #2. A stuck task never burns the run.
2. **Global iteration budget** — **derived, not fixed**: `budget = ceil(task_count × 2.5)`
   (`iteration_factor: 2.5`, config default). Computed at loop start from `tasks.md` and
   **displayed at STOP #1 for approval** — the human always sees the leash length before
   the run starts and can override per feature. 2.5 is deliberately generous: it absorbs
   within-task retries *and* cross-task integration repair; it is an educated initial
   default to be recalibrated from our own retro data, not a measured constant.
3. **Wall-clock time-box** — default **4h** (`time_box`, config). The true cost brake for
   slow-burn runs whose iterations individually pass.

**Budget exhaustion is a clean park, not a failure:** everything done is already committed
and recorded (see below), remaining tasks are marked open, and STOP #2 presents "N/M
iterations used, X/Y tasks done" for the human to extend, re-plan, or accept partial.

**Iteration protocol placement** (the rest of Q5):

- **One task per iteration** — enforced *structurally* by ADR-0008's topology (one
  `command` dispatch = one fresh session = one task) and *behaviorally* by the iterate
  command's protocol. Not a convention; a consequence of the architecture.
- **Auto-commit** — a Claude **Stop-hook** action (ADR-0009/0010): on iteration exit the
  gate verifies decision record + green tests, then commits. The agent cannot forget it
  because the agent doesn't do it — the harness does. Prompt-level "remember to commit"
  appears nowhere.
- Judge/checker verdicts and failure notes are **written to loop state**, so retry
  iterations (fresh context) read and target them.

All defaults live in `devflow-config.yml`: `iteration_factor: 2.5`, `max_attempts_per_task: 2`,
`time_box_hours: 4`. STOP #1 shows the computed values per run.

**Consequences:** Cost control scales with the work instead of strangling large features or
over-leashing small ones; no magic constants hidden from the human; the parked-task
mechanism keeps one bad task from becoming a failed run. Recalibrating `iteration_factor`
from real runs is an explicit expectation of this ADR. Supersedes the fixed-cap approach of
the community engines we absorbed (ADR-0007).
