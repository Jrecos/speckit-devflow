# ADR-0031: The checker is pinned to Opus (strongest per-task grader)

**Status:** Accepted (amends [ADR-0022](0022-skills-and-subagents-doctrine.md)'s `model: inherit`
choice; complements — does not replace — the cross-family judge of
[ADR-0003](0003-maker-plus-cross-family-judge.md)/[ADR-0027](0027-judge-cross-family-local.md))

**Context:** ADR-0022 left the checker subagent at `model: inherit` — it ran on whatever the
session model was — reasoning that cross-family independence is the *judge's* job, so the checker's
model tier didn't matter. Practice (a real E2E: a local maker building a web game) showed the flaw
in that reasoning. The layered verification stack is:

1. **scoped tests** — mechanical, per task; only as strong as the acceptance test the planner wrote.
2. **checker** — a fresh-context subagent grading the diff against the AC.
3. **judge** — cross-family, per-iteration and whole-diff at Verify.
4. **review + two human STOPs.**

When the maker is a weaker/cheaper model, its failures are disproportionately **behavioral**: code
that passes a thin unit test but is wrong in a way the test didn't assert (e.g. counting a kill
before resolving the hit; a `dt` units mismatch that only manifests over many composed frames). Those
are exactly what layer 2 exists to catch — *if* the checker reasons well enough. Leaving it at
`inherit` means the quality of the per-task grade silently tracks the session model; run the loop on
a cheap session model and the one reasoning gate between the maker and the human weakens with it.

**Decision:** Pin the checker to **Opus** — the strongest reasoning tier — via `model: opus` in the
subagent frontmatter (`assets/claude/agents/devflow-checker.md`). `devflow-config.yml`'s
`checker.model: opus` documents the intent. The checker is now the strongest, most independent
per-task grader regardless of what model drives the rest of the loop.

- **`model: opus` is a Claude tier alias, not a host/vendor**, so this stays within the Claude-first
  posture of ADR-0009 and does not reintroduce a topology dependency. The public bundle names a tier,
  not an endpoint.
- **The cross-family judge STAYS** (explicitly not replaced). Opus is same-family as a maker that has
  escalated to the Claude tier (ADR-0026) — when a hard task climbs to `claude`, the Opus checker's
  independence collapses, and the gemma judge is then the *only* cross-family lens. Two layers, two
  purposes: the Opus checker is the strong per-task reasoner; the cross-family judge is the
  shared-blind-spot catcher. Defense in depth.

**Consequences:**
- **The per-task reasoning gate is now consistently strong**, decoupled from the session model. The
  layer most able to catch a weak maker's behavioral bugs is always the strongest reasoner.
- **Cost/latency:** the checker runs on Opus every iteration. Acceptable — the checker is one focused
  grade per task, and the whole premise is a cheap local maker + a premium check, not a premium maker.
- **ADR-0022 amended:** its "`model: inherit` is correct because independence is the judge's job" no
  longer holds. Independence and *reasoning strength* are different axes; the judge covers cross-family
  independence, the pinned checker covers per-task reasoning strength. Both matter.
- **Honest limitation, unchanged:** emergent/runtime bugs (the `dt` tunneling class) still may need a
  human playtest at STOP #2 — no per-diff grader, however strong, runs the composed system. A stronger
  checker raises the catch rate; it does not make the human STOP redundant (ADR-0002 stands).
- Guarded by test-15 (the `model: opus` line can't silently drop).
