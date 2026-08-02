# ADR-0032: Validate the tests, not just the code — two complementary layers

**Status:** Accepted (extends the maker/checker/judge topology of
[ADR-0003](0003-maker-plus-cross-family-judge.md); internal per [ADR-0029](0029-internalize-deps-sole-spec-kit.md);
warns, does not block, per [ADR-0002](0002-two-human-stops.md))

**Context:** The acceptance tests are the build loop's *target and oracle*. Two live E2E runs exposed
that a wrong test is worse than wrong code:
- **A test that contradicts the spec** (an inventory test that removed all of an item, then asserted
  the item was still present) rejected a *correct* local implementation and made it climb the entire
  escalation ladder to the Claude tier chasing an impossible green.
- **A test that is too weak** (asserting "a bullet spawns" but never "a kill scores", and never
  exercising the collision integration) let a real gameplay bug ship green — caught only by a human
  playtest.
These are different failure modes and neither was caught by anything before the loop ran. DevFlow
graded the *code* (checker/judge) but never the *tests*.

**Decision:** Add two internal, complementary test-validation layers. Both are advisory — they surface
findings at a human STOP; neither blocks.

**Layer A — cross-family test audit (Plan phase).** A model of a *different family* than the test
author reviews each acceptance test against `spec.md`. Same cross-family logic as the judge: the model
that wrote the tests shares its own blind spots, so a different family catches what a same-family
review would miss. Wired by role: `speckit.devflow.test-audit` (command) → `devflow-testaudit.sh`
(seam) → `$DEVFLOW_TESTAUDIT_CMD` (resolved in the environment; unset ⇒ audit skipped,
Claude-sufficient). The auditor answers **concrete** questions — contradiction, calls-the-right-thing,
asserts-real-behavior, overshoot — not open-ended judgment (playing to a weaker reasoner's strengths).
Output: `test-audit.md`, surfaced at STOP #1. This catches the *contradiction* class. (Verified live:
a local model correctly flagged the real inventory-test contradiction with a precise, spec-tied
explanation.)

**Layer B — mutation testing (Verify phase).** `devflow-mutate.sh` mechanically mutates the feature
source (flips operators/constants, one minimal edit at a time) and re-runs the test command. A mutation
that **survives** (tests stay green with broken code) is proof of weak coverage. Pure bash + `sed` + the
project's own test runner — **no external dependency** (honors ADR-0029; Stryker/mutmut were considered
and rejected as external deps). Bounded mutant budget; refuses a red baseline; always exits 0. Output:
a mutation score + surviving-mutant list, surfaced at STOP #2. This catches the *weak-test* class.
(Verified live: it scored the arena game's thinly-tested `world.js` at 0.31, flagging the exact
bullet-integration lines whose weak coverage let the real bug through.)

**Consequences:**
- **The tests now get a second opinion, from both directions.** Layer A (a different family reads the
  intent) catches tests that contradict the spec; Layer B (mechanical) catches tests too weak to notice
  broken code. Combined with the code-side checker (Opus, ADR-0031) and cross-family judge, every
  artifact — code *and* tests — has an independent check.
- **Symmetry:** Opus checks the local maker's CODE (ADR-0031); a different family checks Opus's TESTS
  (Layer A here). Each family audits the other's output.
- **Honest limits, documented:** Layer B surfaces *equivalent mutants* (a mutation with no
  behavioral difference, e.g. `<` vs `<=` at a boundary both returning the same value) as unkillable
  survivors — a known false-positive source in mutation testing. The score is advisory precisely
  because of this; a human reads the survivor list, not a pass/fail. Layer A on a weaker local family
  can miss subtle intent mismatches; it's a net, not a proof.
- **Never blocks** (ADR-0002): both are warnings at the STOPs. A wrong test found at STOP #1 is fixed
  via the revise loop (ADR-0030) before the build loop wastes a single iteration on it.
- Config: `test_validation.{audit,mutation}` toggles + `mutation.{max_mutants,min_score}`. Both drivers
  carry a `test-audit` phase (skippable). Guarded by test-25 (mutation discrimination) and the command
  authoring/preflight tests.
