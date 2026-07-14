# ADR-0005: Why the baseline workflow is shaped this way

**Status:** Accepted (documents the design that predates this bundle)

**Context:** We needed a repeatable way to ship software with an AI agent that is (a) high-quality
and verifiable, (b) safe for client work under NDA, (c) spec-driven rather than vibe-driven, and
(d) compounding — each project leaving behind reusable knowledge. No single tool provided all four,
so we composed one. See [`baseline-workflow.md`](../baseline-workflow.md) for the resulting 16-step
flow.

**Decision — and the reasoning behind each load-bearing choice:**

- **Spec Kit is the spine.** Spec-driven development makes the spec the contract every downstream
  step checks against. Getting the spec right is the cheapest quality available; a wrong spec is
  the most expensive bug. Everything else hangs off spec-kit's phased artifacts.
- **The Loop extension is required (maker/checker).** An agent that grades its own work overstates
  completion — so the maker never declares done. Verification is a separate, adversarial step in a
  fresh context. This is the single highest-value habit and the one most people skip.
- **Review is local by design — `/code-review` + Semgrep + `/security-review`.** Because we do
  client work under NDA, the quality/security gate must run **on the machine**; source never leaves
  it. Semgrep adds dataflow/taint analysis an LLM can't do reliably. This rules out cloud review
  SaaS.
- **A knowledge track runs in parallel (Prime → Record → Capture).** Files are the source of truth
  (Kepano); the LLM does the bookkeeping (Karpathy). Prime reads prior decisions so we don't
  re-litigate solved problems; Record writes durable decisions to committed files as we build;
  Capture graduates them into a vault we own. The write half only works because decisions are on
  disk, not in the chat.
- **Gates are placed where errors are cheapest to catch.** Analyze (consistency) before building;
  Verify (adversarial + human sign-off) before shipping; Validate (VCS hygiene) as its own stop,
  kept separate from code correctness so each gate means one thing.
- **Ralph is offered as an alternate engine.** For hands-off runs, a brute-force autonomous loop
  replaces the careful maker/checker — chosen per feature, not globally.
- **Onboarding installs everything at project scope.** The workflow only works if every
  prerequisite is present; onboarding validates and installs them so a repo is workflow-ready in
  one command.

**Consequences:** The flow is more ceremony than "just prompt the agent," and it depends on several
extensions + a vault. In return it is verifiable, NDA-safe, and compounding. Running it for real
exposed five structural gaps (over-scoped loop, skipped review gate, decisions not recorded inline,
stale contract on accepted deviation, hand-cranked with no auto-commit) — see [`retro.md`](../retro.md).
**Those gaps are the reason this bundle exists:** DevFlow automates this baseline and fixes them by
construction. ADRs 0001–0004 record the bundle's structural response.
