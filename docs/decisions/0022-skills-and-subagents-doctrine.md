# ADR-0022: Skills, subagents & memory doctrine — applied, with one deferred lever

**Status:** Accepted

**Context:** A deep-research pass on Claude Code *skill/subagent/memory* authoring
(distinct from command *bodies*, covered by ADR-0021) established the 2025–2026 doctrine.
The verify phase was rate-limited (Fable cooling down): 4 claims completed the 3-vote
check, the rest were primary-source-quoted; the load-bearing findings were re-verified
first-hand this session by fetching `code.claude.com/docs/en/{skills,sub-agents,memory}`.
Full report + verification tags:
[`docs/research/skills-and-subagents-authoring-research.md`](../research/skills-and-subagents-authoring-research.md).

DevFlow ships no hand-authored `SKILL.md`; its skill-adjacent artifacts are the 9 command
markdowns spec-kit renders into skills, the `devflow-checker` subagent, and the CLAUDE.md
protocol block. Most already conformed (ADR-0021's command-authoring pass covered the
overlapping ground) — this ADR records what changed and what was deliberately not.

**Decision — applied now (low-risk, alignment-improving):**

1. **Third-person, front-loaded descriptions** on all 9 commands ("Runs…", "Writes…",
   "Reconciles…" rather than "Run…", "Write…"). Vendor + superpowers guidance: the
   description is injected into the skill listing to drive auto-activation; third-person
   and key-use-case-first are the recommended forms, and the 1,536-char listing truncation
   makes front-loading matter (ours stay <1024, never truncated).
2. **`argument-hint`** on `speckit.devflow.start` (`"<feature description> (or empty to
   resume)"`). Verified: spec-kit injects `argument-hint` only for its 8 core stems and
   bails if the key is already present, so ours survives the render.
3. **Checker role-assertion.** Verified first-hand: custom subagents load the project
   CLAUDE.md (unlike built-in Explore/Plan), so `devflow-checker` inherits the
   maker-oriented loop-protocol block. Added a line telling the checker those rules
   describe the maker and are not its job — prevents grader confusion. (Its other
   properties already conform: single-purpose, restricted tools, "Use PROACTIVELY"
   description, `model: inherit` — correct, because cross-family independence is the
   *judge's* job, not the checker's.)

**Confirmed already-conformant (no change):** CLAUDE.md protocol block (≤200 lines; only
always-do-X invariants, procedures live in the command skills; soft-reinforcement of
hook-enforced rules; comment markers stripped from context but present on disk for
onboard's grep — the design is correct as-is); packaging (deterministic work in bundled
scripts invoked by exact path, not generate-code instructions).

**Deferred — `disable-model-invocation: true` on the 6 worker commands** (iterate,
review, verify, record-decision, reconcile-contract, capture). This is the *correct*
design — those commands should run only when dispatched, not when Claude auto-fires on a
stray message — and spec-kit's bail-if-present render lets us set it. **Not applied**
because whether headless `claude -p "/speckit-devflow-iterate"` still dispatches a skill
flagged `disable-model-invocation: true` is an unverified interaction, and if the
assumption is wrong *every* pipeline dispatch breaks on the first iteration. Per DevFlow's
own doctrine (ADR-0016 exists because a "verified" assumption was wrong; ADR-0020: never
ship an unvalidated guarantee), it is deferred to the live dogfood — added as a MANUAL.md
validation step. The mis-fire it would prevent is already neutralized by the guard layer
(iterate/record-decision STOP when their preconditions are absent), so not flipping it
degrades nothing; it only forgoes a token optimization.

**Consequences:** Skill activation is better-signposted; the checker won't misread
inherited maker rules; no runtime behavior changed, so all 14 acceptance tests stay green.
The one behavior-changing lever is queued for validation rather than shipped blind. Open
questions from the research (measured activation-rate effects of third-person phrasing;
the `-p` + disable-model-invocation interaction) are recorded there and in MANUAL.md.
