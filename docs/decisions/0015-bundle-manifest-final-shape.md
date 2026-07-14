# ADR-0015: bundle.yml — verified schema, requires.mcp shape, final component set

**Status:** Accepted

**Context:** HANDOFF Q7 asked to confirm how spec-kit expects the `semgrep` MCP entry.
Verified against installed spec-kit 0.12.11 source (`bundler/models/manifest.py`) — which
also revealed the draft `bundle.yml` in this repo does not match the real schema.

**Decision:**

**Q7 answer — `requires.mcp` is a plain list of names** (`_parse_str_list`): entry is
`- semgrep`, nothing more. Command/args are not expressible in the manifest; the resolver
only surfaces a warning listing required MCP servers at install. The devflow onboarding
command therefore owns actually adding it
(`claude mcp add semgrep --scope project uvx semgrep-mcp --metrics off`) and validating it.

**Schema corrections** (draft → real 1.0 schema):

- Top-level `bundle:` mapping with required `id, name, version, role, description, author,
  license` — `role` was missing from the draft; DevFlow uses `role: developer`.
- Component refs use `id:` (not `name:`); extensions/presets/workflows must pin **exact
  semver** (`"*"` is rejected); steps carry no version.
- Presets must declare integer `priority` + `strategy` ∈ {replace, prepend, append, wrap}.
- `integration: {id: claude}` pinned per ADR-0009 (installs refuse on non-Claude projects).

**Final component set** (from ADRs 0006–0014):

```yaml
provides:
  extensions:
    - { id: git,       version: "1.0.0" }   # prerequisite, called at seams (ADR-0006)
    - { id: superspec, version: "1.0.1" }   # prerequisite, called at seams (ADR-0006)
    - { id: devflow,   version: "0.1.0" }   # OURS: loop engine (modes), iterate,
                                            # record-decision, reconcile-contract, onboard,
                                            # hooks pack, checker/judge subagent defs
  presets:
    - { id: devflow-plan-hardening, version: "0.1.0", priority: 10, strategy: append }
      # hardens core plan/tasks templates: failing acceptance tests are a required output
  steps: []          # none — ADR-0010 (fixes live in commands + hook + workflow branch)
  workflows:
    - { id: devflow, version: "0.1.0" }     # the outer pipeline (ADR-0008/0012)
requires:
  speckit_version: ">=0.12.0"
  tools: [git, claude]
  mcp: [semgrep]
```

**Consequences:** `specify bundle validate` structural checks will pass once components
exist (reference checks fail until then — expected). The `aide` and `ralph` extensions are
documented as optional/superseded, not pinned (ADR-0006/0007). Version pins are exact, so
bundle updates are deliberate acts. The draft `bundle.yml` gets rewritten to this shape
during authoring — not before design approval.
