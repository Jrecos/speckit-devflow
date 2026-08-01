# ADR-0029: DevFlow's only dependency is spec-kit core (internalize git.* and superspec)

**Status:** Accepted (reverses [ADR-0006](0006-component-strategy.md)'s "compose prereqs" choice
for git + superspec; unchanged: spec-kit core primitives specify/plan/tasks/clarify/analyze stay)

**Context:** ADR-0006 chose to *compose* the upstream `git` and `superspec` extensions as pinned
prerequisites rather than reimplement them. That was reasonable when the goal was minimal authoring.
But it made DevFlow a bundle that pulls **three** installs (git ext, superspec ext, devflow) plus
their catalog resolution — and every external extension is a version-drift and availability risk for
what is meant to be a self-contained, install-once bundle. The operator's rule: **the only
dependency is spec-kit core.**

**Decision:** Internalize the *behaviors* DevFlow used from the external extensions, and drop the
extensions from the bundle.

- **`git.feature` / `git.validate` / `git.commit`** → one internal `devflow-git.sh` (create/switch a
  numbered feature branch; assert feature-branch naming + spec dir; stage-all + commit, skipping
  cleanly when clean). The workflow's ship steps call it via `shell`, not `command`. `git` the
  **binary** remains a system prerequisite (`requires.tools`) — the spec-kit **extension** does not.
- **`superspec.brainstorm`** → an internal `speckit.devflow.brainstorm` command: pressure-test
  `spec.md` for edge cases / contradictions / ambiguity and revise it in place. Still a reasoning
  task dispatched to Claude — internalizing it removes the *dependency*, not the intelligence.
- **`checklist`** (new) → `speckit.devflow.checklist`: generate a plan-validation artifact
  (`checklist.md`) shown at STOP #1 so approval is informed.
- **`agent-context.update`** (new) → `devflow-agent-context.sh`: refresh a managed block in
  CLAUDE.md/AGENTS.md pointing at the current plan, so maker/checker sessions see fresh context.
- **`bundle.yml`:** `provides.extensions` drops `git` and `superspec`, leaving only `devflow`.

**Reasoning vs. implementation boundary (reaffirmed).** Internalizing these did not move any
reasoning off Claude. Every pipeline command — specify, brainstorm, clarify, plan, tasks, checklist,
analyze, iterate, review, verify, reconcile, capture — is dispatched via `claude -p`. The **only**
place a local model runs is the maker seam inside iterate's Implement step (ADR-0025). Planning and
judgment stay with Claude (Opus/Fable); the local model only types the implementation.

**Consequences:**
- **Single install.** `specify extension add devflow` + the preset + the workflow — no separate
  git/superspec adds. README and the preflight command inventory updated (now 11 command docs).
- **No external version drift.** DevFlow's guarantees no longer depend on another extension's
  behavior staying compatible.
- **Small internal surface to own.** `devflow-git.sh` replicates only the essential git behavior;
  it is not a general git-workflow extension. If a project needs richer git-ext features, it can
  still install that extension separately — DevFlow just doesn't require it.
- ADR-0006 is superseded for git + superspec; its "own the core loop, keep primitives upstream"
  reasoning still holds for spec-kit *core* (specify/plan/tasks/clarify/analyze), which DevFlow
  continues to use as the spine.
