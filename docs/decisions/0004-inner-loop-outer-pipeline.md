# ADR-0004: Split the inner Build loop from the outer pipeline

**Status:** Accepted

**Context:** The first run's loop was scoped to the whole feature (build + e2e + verify + ship +
sign-off) under one iteration budget, which starved the late steps (gap A). The most-replicated
finding in the research is "one task per loop, 40–60% context utilization."

**Decision:** Two nested constructs. **Inner Build loop** (Ralph-style): one task per iteration,
per-edit mechanical checks, `record-decision` + auto-commit on exit, terminates on task
exhaustion or a budget/time-box. **Outer pipeline** (Spec Kit phases): Frame → Plan → Analyze →
[Build loop] → Review → Verify → Ship → Capture, each phase a separate session consuming the
prior artifact. Review/Verify/Ship are phases the build loop cannot reach into or skip.

**Consequences:** The loop stays small and consistent; downstream gates can't be starved or
conflated. Requires the bundle to model these as distinct components (a `devflow` workflow around
a loop engine) rather than one monolithic loop definition.
