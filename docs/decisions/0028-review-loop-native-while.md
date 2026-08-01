# ADR-0028: The review loopback is one native `while` (supersedes the unrolled cycles)

**Status:** Accepted (supersedes the static-unroll decision in
[ADR-0016](0016-verification-corrections.md) crit #4; keeps the cap semantics of
[ADR-0012](0012-review-findings-loop.md); adds the gap-D backstop)

**Context:** ADR-0016 concluded that spec-kit workflows "have no backward edges," so the review
loopback was **hand-unrolled into two near-identical `fix-cycle-1` / `fix-cycle-2` blocks** (and a
twin pair of verifiers `v_fix1` / `v_fix2` in the Path-B ledger). That conclusion was wrong: the
spec-kit engine (verified in `steps/while/__init__.py`) has a real **`while`** step — condition
re-evaluated before each pass, `max_iterations` cap. Duplicated blocks are a maintenance hazard
(change one, forget the other) and the review depth was a magic "2" in two places.

**Decision:** Collapse the two unrolled cycles into **one `while` review-loop** capped at
`review.cycles`, in both drivers.

- **Path A (`workflow.yml`):** a `while` on `findings-status == 'findings'` whose body is
  `convert → fix-loop (do-while) → re-review`, with a trailing top-level `park-findings` step. The
  `convert-findings.sh` cycle arg became optional — it derives the cycle from `state.cycle` since
  `while` exposes no loop index.
- **Path B (`devflow-flow.sh`):** `fix-cycle-1` + `fix-cycle-2` and `v_fix1` + `v_fix2` collapse to
  a single `review-loop` phase + `v_review_loop` verifier that parks survivors (the old `v_fix2`
  body). PHASES shrinks 14 → 13.
- **`review.cycles` is now a REAL cap**, not an informational note.

**A bounded, harmless quirk (documented, not hidden).** The engine bans duplicate step IDs across
all scopes, so the loop condition cannot read a step that also appears inside the body — it reads
the **pre-loop** `findings-status` seed, which goes stale after pass 1. The consequence is a
possible **over-run: the loop may run its full cap even after findings clear.** It is provably
harmless: `convert-findings` re-reads the fresh `findings.json`, finds it clean, appends zero
fix-tasks and exits; the `fix-loop` then finds no pickable task and exits immediately. A stale extra
pass does a re-review and nothing else — no code changes, no commits — and the whole thing is capped
by the engine. The textbook fresh-read (route the decision through a status flag) is a small change
away if the cap ever grows large enough for extra re-reviews to matter.

**gap-D backstop (FIX-4).** Separately: Path A's build-loop `do-while` is capped by the engine at
`max_iterations: 50`. If the leash budget exceeds 50 (many tasks, or escalation inflating per-task
cost) the loop could exit by that cap with `state.continue` still true and tasks **not parked** —
then a plain STOP #2 accept would ship open work without reconcile (gap D). Path B's `v_build`
already refused to complete in that state; Path A had no equivalent. A new `build-loop-backstop`
step runs `devflow-loop-status.sh --force-park` after the loop, forcing a clean park so the
invariant holds in both drivers.

**Consequences:**
- One source of truth for the review depth; no duplicated blocks to drift. DRY, and `review.cycles`
  means what it says.
- Both drivers stay in parity (tests 11/13 updated in lockstep).
- The over-run quirk is a conscious, capped, zero-work tradeoff — recorded here and in the workflow
  comments so a future reader doesn't "fix" a non-bug or trip over it.
