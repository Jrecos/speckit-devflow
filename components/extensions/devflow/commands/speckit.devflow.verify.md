---
description: "Verify phase: full test suite + judge verdict over the whole diff; write verify-report.md"
---

# DevFlow Verify — full suite + whole-diff judge

## Steps

1. **Prerequisite (mechanical, gap B):** run
   `bash .specify/extensions/devflow/scripts/bash/devflow-check-review.sh`.
   If it exits non-zero, STOP — report its message and do nothing else. Verify
   cannot run without a clean-or-parked review artifact.
2. Read `.specify/feature.json` → `feature_directory` (`<fdir>`).
3. Run the FULL test suite (`commands.test_full` from devflow-config.yml) —
   including the acceptance tests written at Plan time. Record pass/fail per file.
4. Judge the WHOLE feature diff:
   - Write temp files: full diff (feature base → HEAD), the acceptance criteria
     (all AC lines from tasks.md + the acceptance-test list from plan.md), and the
     complete spec.md as the slice.
   - Run `bash .specify/extensions/devflow/scripts/bash/devflow-judge.sh <diff> <criteria> <slice>`.
5. Compare implementation against spec.md and note any **deviations** (behavior
   that differs from the contract text, even if tests pass).
6. Write `<fdir>/verify-report.md`:

```markdown
# Verify report — <feature>

Judge verdict: PASS|FAIL
Reason: <judge's reason>

## Test results
- acceptance: <n>/<n> green
- full suite: <summary>

## Deviations from spec
- <each deviation: what the spec says vs what the code does — or "none">

## Recommendation
<accept | accept-with-deviation (list which) | reject — one sentence why>
```

A judge FAIL here parks to STOP #2 with **reject recommended** — do NOT loop back
(review cycles are spent by this phase; the human is the backstop — ADR-0016).
