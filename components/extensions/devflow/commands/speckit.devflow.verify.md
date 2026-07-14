---
description: "Runs the DevFlow Verify phase — full test suite plus a judge verdict over the WHOLE feature diff; writes verify-report.md with deviations from spec noted. Runs only after Review's findings are clean or parked (hard prerequisite). Use when the pipeline reaches Verify, before STOP #2. Keywords: verify, full suite, whole-diff judge, verify report, deviations, acceptance tests."
---

# DevFlow Verify — full suite + whole-diff judge

## Standing rules

- The prerequisite check is not yours to waive: if it refuses, Verify does not run.
- A judge FAIL here parks to STOP #2 with **reject recommended** — do NOT loop back
  (review cycles are spent by this phase; the human is the backstop — ADR-0016).

## Steps

1. **Prerequisite** (REQUIRED, mechanical — gap B): run exactly
   `bash .specify/extensions/devflow/scripts/bash/devflow-check-review.sh`
   - Exit 0 → continue.
   - Non-zero → STOP. Report its message verbatim and end; the fix is finishing
     Review/fix cycles, not skipping this check.
2. Read `.specify/feature.json` → `feature_directory` (`<fdir>`).
3. **Full suite**: run `commands.test_full` from devflow-config.yml — including the
   acceptance tests written at Plan time. Record pass/fail per file.
   *If `test_full` is empty:* STOP and report — run `/speckit-devflow-onboard`.
4. **Whole-diff judge**:
   - Write temp files: the full diff (feature base → HEAD), the acceptance criteria
     (all `AC:` lines from tasks.md + the acceptance-test list from plan.md), and
     the complete spec.md as the slice.
   - Run exactly:
     `bash .specify/extensions/devflow/scripts/bash/devflow-judge.sh <diff> <criteria> <slice>`
     Do not modify the command. (Fallback warning about same-family judging is
     expected when `DEVFLOW_JUDGE_CMD` is unset — not an error.)
5. **Deviations**: compare implementation against spec.md; note every behavior that
   differs from the contract text, even where tests pass.
6. **Write `<fdir>/verify-report.md`** (REQUIRED, exactly this shape — stop2-prep
   parses the verdict line):

```markdown
# Verify report — <feature>

Judge verdict: PASS|FAIL
Reason: <judge's reason>

## Test results
- acceptance: <n>/<n> green
- full suite: <summary>

## Deviations from spec
- <spec says X, code does Y — or "none">

## Recommendation
<accept | accept-with-deviation (list which) | reject — one sentence why>
```

## Done when

`verify-report.md` exists, contains a line starting exactly `Judge verdict: ` with
PASS or FAIL, and every suite result and deviation is recorded. Verify with:
`grep -E '^Judge verdict: (PASS|FAIL)' <fdir>/verify-report.md` — non-empty output
or the report is not done.

## Handoff

The pipeline proceeds to STOP #2 (stop2-prep renders your report into the evidence
summary). You do not present the gate — end after the report is verified.
