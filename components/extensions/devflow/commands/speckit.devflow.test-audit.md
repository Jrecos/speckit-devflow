---
description: "Cross-family audit of the acceptance tests against the spec — a different model family reviews the test author's tests for contradictions, gaps, and tautologies, so a wrong test is caught BEFORE the build loop wastes iterations on it. Use in the Plan phase after tasks/checklist, before STOP #1, to validate the tests themselves; writes test-audit.md. DevFlow-internal (ADR-0032). Keywords: test audit, validate tests, spec-vs-test, cross-family, are these real tests."
---

# DevFlow Test Audit — a second family checks the tests before the loop runs

The acceptance tests are the build loop's *target*, so a wrong test is worse than wrong code: it
rejects a correct implementation and burns the whole escalation ladder chasing an impossible green
(a real, observed failure mode). This step has a **different model family** review the tests the
planner wrote, against the spec — catching contradictions and gaps *before* STOP #1. It is a
warning, not a gate: findings surface to the human, who can revise or approve.

## Standing rules

- You **read** `spec.md` and each acceptance test; you **write** only `test-audit.md`. Never edit
  the tests here — that is the human's call at STOP #1 (they can use the revise loop).
- The audit is advisory. If the auditor is unavailable, say so plainly and continue — planning is
  not blocked by a missing auditor (Claude-sufficient, ADR-0020).

## Steps

1. **Resolve** the feature dir (`.specify/feature.json` → `feature_directory`). Read `spec.md` and
   the list of acceptance tests (from `plan.md`'s `## Acceptance tests (red)` section, or discover
   the test files under the project's test tree).

2. **Audit each test** — for each acceptance test file, run the seam:
   ```
   bash .specify/extensions/devflow/scripts/bash/devflow-testaudit.sh <fdir>/spec.md <test-file>
   ```
   - **exit 0** → parse the `{ok, issues}` JSON. `ok:false` means the auditor found problems.
   - **exit 3** → no auditor configured (`DEVFLOW_TESTAUDIT_CMD` unset) or its backend is down: the
     test is **not audited**. Record it as `unaudited`, not as a failure.
   - **exit 1** → the auditor ran but returned bad output: record `audit-error`, move on.
   The auditor checks concretely: does the test contradict itself or the spec (the highest-value
   catch — e.g. it empties a value then asserts it is present)? does it call the functions the spec
   names? does it assert real behavior or is it tautological? does it over-constrain beyond the spec?

3. **Write `<fdir>/test-audit.md`** — a section per test:
   ```markdown
   ## test-audit
   - <test path>: OK   (or)   ⚠ ISSUES
     - <each concrete issue>
   ```
   End with a one-line summary: `N tests · M clean · K with issues · U unaudited`. This line is what
   STOP #1 surfaces.

4. **Report** the summary. Do NOT change any test. If issues were found, note that the human can fix
   them at STOP #1 via the revise loop (regenerate the plan/tests), or approve with the risk noted.

## Done when

`test-audit.md` exists with a per-test verdict and a summary line, produced by the cross-family
auditor (or clearly marked `unaudited` when no auditor is configured).

## Handoff

None — Analyze and STOP #1 follow. `test-audit.md` is the human's evidence that the tests themselves
were checked, not just written.
