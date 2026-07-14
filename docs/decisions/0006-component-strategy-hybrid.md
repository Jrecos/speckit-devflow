# ADR-0006: Component strategy — compose prerequisites, own the core

**Status:** Accepted

**Context:** The bundle must decide, per capability, whether to *pin* a community extension
as-is, or *own* a DevFlow component that absorbs its best techniques (HANDOFF Q1). Verified
against the live spec-kit catalogs (2026-07-13): `git` 1.0.0 (core), `superspec` 1.0.1,
`loop` 1.0.0, `ralph` 1.2.1, `aide` 1.0.0. A bundle installs everything it lists — there is
no optional component — and every pinned extension is a dependency on an external author's
repo and cadence.

**Decision:** Hybrid, by role:

- **Pin as prerequisites (call, never reimplement):** `git` (branch/validate/commit
  primitives — Ship and auto-commit build on them) and `superspec` (Frame-phase
  brainstorm/pressure-test, review skills). DevFlow *invokes* their commands
  (`speckit.superspec.brainstorm`, `speckit.git.validate`, `speckit.git.commit`); it does
  not wrap or fork them.
- **Own the loop.** The build-loop engine is a DevFlow-authored extension — see
  [ADR-0007](0007-own-loop-engine-with-modes.md). Neither community `loop` nor `ralph` is
  pinned; their best mechanics are absorbed into our engine.
- **Out of the bundle:** `aide` (product layer sits upstream of Frame; not every project
  needs it — documented as optional) and `ralph` (superseded as a separate engine by
  ADR-0007's autonomous mode).

**Consequences:** Two external dependencies (both small, both called at their public command
seams), one owned core. Supersedes HANDOFF's "loop is required" (the required loop is now
ours) and amends ADR-0005's "Ralph is offered as an alternate engine" — the alternate engine
becomes a *mode* of the DevFlow loop. Cost: we author and maintain a loop engine; accepted
because the loop is the bundle's center of gravity and no catalog extension implements our
full protocol (modes + judge gate + per-iteration record/commit).
