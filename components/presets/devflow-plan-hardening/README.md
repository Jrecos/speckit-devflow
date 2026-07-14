# devflow-plan-hardening preset

Replaces the core `speckit.plan` and `speckit.tasks` command templates with
DevFlow-hardened versions (spec-kit presets replace templates via
`provides.templates[].replaces`; the bundle pins `strategy: replace` to match).
The replacement templates are full lean-style commands (same structure as
spec-kit's own `lean` preset: read `.specify/feature.json`, load context, produce
the artifact) plus the DevFlow hardening requirements — they supersede, not
decorate, the core templates.

What the hardening adds:

- **plan** — failing acceptance tests are a *required output* of planning, listed
  under `## Acceptance tests (red)` (the visible-target finding: making red tests
  the loop's explicit goal roughly doubled success in the research corpus).
- **tasks** — a machine-countable format: `- [ ] T<n> <name>` + indented
  `  - AC: <criterion>` lines. The DevFlow loop counts task lines for its budget
  (⌈n × 2.5⌉), verifies one-task-per-iteration at the Stop gate, and the checker
  subagent grades against the AC lines.

Ships as part of the `devflow` bundle; also installable standalone:
`specify preset add --dev <this directory>`.
