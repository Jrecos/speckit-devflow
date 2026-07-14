# ADR-0003: Model topology — local maker + cross-family judge

**Status:** Accepted (with a flagged evidence gap; scoped by [ADR-0016](0016-verification-corrections.md):
maker locality is **deferred** in v0.x — ADR-0009 pins Claude as the maker; the judge's
independence seam stands. Judge FAIL semantics scoped: iteration-level FAIL hard-blocks;
Verify-level FAIL parks to STOP #2 with reject as the recommended default.)

**Context:** The first run used one cloud model as both maker and checker — same-family
self-review, no cost separation, no independence. The literature says same-model self-checking
is the documented weak verification layer, and role-split (not peer-swarm) is the multi-model
pattern that pays.

**Decision:** A **local maker** builds; an **independent, cross-family judge** gates. Tests
remain the primary oracle; the judge covers subjective criteria tests can't express. Judge
**PASS is advisory** into Review; judge **FAIL is a hard block** back into the loop (verdicts are
non-deterministic).

**Consequences:** Maximizes verification independence and separates cost (cheap local build,
sparing judge). A weaker local maker demands a stronger harness — tighter task decomposition,
maximal mechanical backpressure, whole-file edit format. **Flagged gap:** no source benchmarks
cross-family vs. same-family judging; this rests on the documented failure of self-assessment
plus independence-by-design, not a measurement. Revisit if evidence emerges.
