# ADR-0001: Form factor — a Spec Kit bundle

**Status:** Accepted

**Context:** What we're building spans skills, slash commands, hooks, a loop driver, MCP config,
and a knowledge track. Candidate form factors: (1) one Claude Code plugin that orchestrates
Spec Kit; (2) a Spec Kit bundle; (3) a marketplace suite of plugins. Spec Kit is our core.

**Decision:** Build it as a **Spec Kit bundle** (`bundle.yml`), authored and shipped via
`specify bundle validate` / `build`. Bundles are the spec-kit-native, role-oriented composition
layer over extensions/presets/steps/workflows — one-command install, versioned, catalog-resolved.

**Consequences:** We stay inside the Spec Kit ecosystem (no seam between two packaging systems),
inherit its catalog/versioning/install semantics, and align with "Spec Kit is the core." Cost:
we're bound to the bundle schema and its component model; Claude-Code-specific primitives (hooks,
subagents) must be delivered through spec-kit components/integration rather than a plugin. Revisit
only if the bundle model can't express a required capability.
