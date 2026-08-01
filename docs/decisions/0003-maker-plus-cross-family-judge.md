# ADR-0003: Model topology — local maker + cross-family judge

**Status:** Accepted (with a flagged evidence gap; scoped by [ADR-0016](0016-verification-corrections.md):
maker locality is **deferred** in v0.x — ADR-0009 pins Claude as the maker; the judge's
independence seam stands. Judge FAIL semantics scoped: iteration-level FAIL hard-blocks;
Verify-level FAIL parks to STOP #2 with reject as the recommended default.)

> **Update (v0.3.0):** maker locality is **no longer deferred.** [ADR-0025](0025-local-maker-seam.md)
> builds the maker env seam (additive; unset = Claude, exact status quo), [ADR-0026](0026-model-escalation.md)
> adds attempts-derived model escalation, and [ADR-0027](0027-judge-cross-family-local.md) makes the
> cross-family judge real in practice. The whole-file-edit-format and stronger-harness caveats this ADR
> flagged are honored in ADR-0025 (whole-file payload + mechanical anti-regression in layer 2).

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
