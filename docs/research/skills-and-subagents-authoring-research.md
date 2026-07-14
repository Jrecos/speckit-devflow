# Authoring Skills, Subagents & Memory Files: Verified Best Practices (2025–2026)

**Research method:** deep-research harness, 2026-07-15 — 5 angles, 18 sources fetched,
90 claims extracted, top 25 sent to 3-vote adversarial verification. **The verify phase
was rate-limited mid-run** (Fable credentials cooling down): **4 claims completed the
3-vote check (all confirmed), 21 were extracted from primary sources with direct quotes
but their verification agents 429'd** — so those are *primary-source-attested but not
independently 3-voted*. To compensate, the load-bearing claims that drive changes to
DevFlow's artifacts were **re-verified first-hand this session** by fetching the primary
docs directly (`code.claude.com/docs/en/{skills,sub-agents,memory}`). Each finding below
is tagged with its verification status.

**Verification tags:** `[3-VOTE]` completed the harness check · `[FIRST-HAND]` re-fetched
and confirmed against the primary doc this session · `[PRIMARY-QUOTED]` extracted with a
source quote but not independently re-verified (429).

**Scope:** DevFlow ships no hand-authored `SKILL.md`. Its skill-adjacent artifacts are
three, and this report targets exactly them: (a) the 9 command markdowns that spec-kit's
`SkillsIntegration` *renders into* skills at install; (b) the `devflow-checker` subagent
definition; (c) the CLAUDE.md protocol block that onboard installs. This is the companion
to `command-authoring-research.md` (which covered command *bodies*); here the focus is
*activation, packaging, subagents, and memory*.

---

## 1 · Skill discovery & activation

**1.1 — The activation signal is the description, in a truncated listing** `[3-VOTE]`
Claude auto-invokes from a context-resident listing of skill names + descriptions; each
skill's combined `description`/`when_to_use` text is **truncated at 1,536 characters** in
that listing, the listing budget scales at ~1% of the context window, and on overflow
Claude Code drops the least-invoked skills' descriptions first.
→ *Consequence:* put the key use case **first**; keep descriptions short (ours are all
<1024, enforced by test-14) so they never truncate.

**1.2 — Two invocation-control fields, asymmetric effects** `[3-VOTE]`
`disable-model-invocation: true` removes the skill's description from context entirely
(only explicit `/name` invocation loads it; also blocks subagent preload + scheduled-task
use since v2.1.196). `user-invocable: false` only hides it from the `/` menu but keeps its
description always in context for auto-invocation.
→ *Consequence (see §6):* worker commands that should run only when dispatched — not when
Claude notices a vibe — are candidates for `disable-model-invocation: true`.

**1.3 — Description voice** `[PRIMARY-QUOTED` + superpowers-corroborated`]`
Anthropic's skill best-practices instruct **third-person** descriptions stating both what
the skill does *and* when to use it, with a `Use when…` trigger clause (the docs' PDF
example ends "Use when working with PDF files or when the user mentions PDFs, forms, or
document extraction"). obra/superpowers `writing-skills` independently requires the same:
third-person, starts with "Use when…".

**1.4 — `allowed-tools` is pre-approval, not restriction** `[3-VOTE]`
It grants prompt-free permission for listed tools while active; every tool stays callable.
To actually remove tools, use `disallowed-tools` (clears on the next user message). For
project skills, `allowed-tools` only takes effect after the workspace-trust dialog.

## 2 · Skill packaging & the command→skill render

**2.1 — Custom commands ARE skills now** `[FIRST-HAND]`
Verbatim from the skills doc: *"Custom commands have been merged into skills. A file at
`.claude/commands/deploy.md` and a skill at `.claude/skills/deploy/SKILL.md` both create
`/deploy` and work the same way… Skills add optional features: a directory for supporting
files, frontmatter to control whether you or Claude invokes them, and the ability for
Claude to load them automatically when relevant."*
→ *Consequence:* DevFlow's command markdowns, once spec-kit renders them under
`.claude/skills/speckit-devflow-*/SKILL.md`, are first-class skills — their descriptions
drive auto-activation, and their frontmatter can carry skill fields.

**2.2 — What spec-kit injects at render** `[FIRST-HAND, spec-kit 0.12.11 source]`
`ClaudeIntegration.post_process_skill_content` injects `user-invocable: true` and
`disable-model-invocation: false` — **but only if the key is not already present**
(`_inject_frontmatter_flag` bails on a pre-existing key). `argument-hint` is injected only
for the 8 core spec-kit stems (specify/plan/…), never for `devflow.*`.
→ *Consequence:* we CAN override both flags and set our own `argument-hint` by declaring
them in the source markdown; spec-kit will not clobber them.

**2.3 — Progressive disclosure & scripts** `[PRIMARY-QUOTED]`
Three tiers (metadata ~100 tokens at startup / SKILL.md body <5k tokens on activation /
bundled files at zero cost until read); split reference material to separate files;
**prefer bundled executable scripts over instructions-to-generate-code** for deterministic
steps (a script's code never enters context — only its output does), and state whether a
script is to be *run* or *read*. DevFlow already does this: deterministic machinery lives
in `scripts/bash/*.sh` and `scripts/python/*.py`, invoked by exact path.

## 3 · Subagent definitions (`.claude/agents/*.md`)

**3.1 — Schema** `[FIRST-HAND]` Only `name` + `description` are required; all else optional
(`tools`, `disallowedTools`, `model`, `permissionMode`, `skills`, `memory`, `effort`,
`color`, …). `tools` omitted → inherits all; listing it restricts. The **body becomes the
system prompt**; a subagent *"receive[s] only this system prompt plus basic environment
details… not the full Claude Code system prompt."*

**3.2 — Delegation phrasing** `[FIRST-HAND]` The description is how Claude decides to
delegate; the docs' own examples use *"Use proactively after code changes"* to make
delegation aggressive. Invocation escalates: natural-language naming = heuristic;
**`@name` = guaranteed** that subagent runs for one task; `--agent`/`agent` setting = whole
session runs as it.

**3.3 — `model` field** `[FIRST-HAND]` Accepts `sonnet|opus|haiku|fable`, a full model ID,
or `inherit`; **defaults to `inherit`**. Cost-control lever: route to Haiku for cheap
graders.

**3.4 — Custom subagents DO load CLAUDE.md** `[FIRST-HAND]` Verbatim: *"Explore and Plan
skip your CLAUDE.md files and the parent session's git status… Every other built-in and
custom subagent loads both."*
→ *Consequence (important for DevFlow):* the `devflow-checker` subagent **inherits the
project CLAUDE.md protocol block** — which is written for the *maker* ("you never grade
your own work", "never commit"). Harmless (those rules don't conflict with grading) but
mildly incongruous; the checker body should assert its own role so it isn't confused by
inherited maker rules.

**3.5 — Body best practices** `[FIRST-HAND/PRIMARY-QUOTED]` Design each subagent to excel
at one task; restrict tool access; write a detailed description; check the definition into
version control. DevFlow's checker already conforms: single-purpose adversarial grader,
tools restricted to `Read, Grep, Glob, Bash`, "Use PROACTIVELY" description, committed.

## 4 · CLAUDE.md / memory-file authoring

**4.1 — Size** `[FIRST-HAND]` *"target under 200 lines per CLAUDE.md file. Longer files
consume more context and reduce adherence."* DevFlow's protocol block is ~10 lines. ✓

**4.2 — What belongs in it** `[FIRST-HAND]` *"facts Claude should hold in every session:
build commands, conventions, project layout, 'always do X' rules. If an entry is a
multi-step procedure or only matters for one part of the codebase, move it to a skill or
a path-scoped rule."* DevFlow's block is 6 always-do-X loop invariants — correctly scoped
(the *procedures* live in the command skills). ✓

**4.3 — CLAUDE.md is soft, hooks are hard** `[FIRST-HAND]` *"Both are loaded… Claude treats
them as context, not enforced configuration. To block an action regardless of what Claude
decides, use a PreToolUse hook instead."* This is exactly DevFlow's layering (ADR-0010):
the protocol block reinforces; the hooks + flow guard enforce.

**4.4 — Block-level HTML comments are stripped** `[FIRST-HAND]` *"Block-level HTML comments
(`<!-- maintainer notes -->`) in CLAUDE.md files are stripped before the content is injected
into Claude's context… When you open a CLAUDE.md file directly with the Read tool, comments
remain visible."*
→ *Consequence:* DevFlow's `<!-- devflow-protocol -->` / `<!-- /devflow-protocol -->`
markers vanish from Claude's context (good — no wasted tokens) but remain on disk, so
onboard's idempotency `grep` for the marker still works. The design is correct as-is; this
finding confirms rather than changes it.

**4.5 — `@import` doesn't save context** `[FIRST-HAND]` Imports expand at launch (max 4
hops, relative-to-file); importing organizes but does not reduce tokens. Project-root
CLAUDE.md survives `/compact` (re-read from disk). AGENTS.md is not read natively — a
CLAUDE.md that `@AGENTS.md`-imports it is the sanctioned bridge.

## 5 · Evidence base & caveats

Surviving evidence is Anthropic first-party docs + agentskills.io + spec-kit source +
obra/superpowers conventions. **No claim was refuted.** The main caveat is the
rate-limited verify phase: 21 findings rest on primary-source quotes rather than the full
3-vote check — mitigated by first-hand re-fetching the docs that drive actual changes.
Practitioner activation-rate measurements (e.g. scottspence's sandboxed-eval blog) were
fetched but did not complete verification; treat "third-person improves activation" as
sound vendor guidance, not a measured effect size. Time-sensitive: mechanics cite
v2.1.196–207-era behavior.

## 6 · The decision that needs live validation: `disable-model-invocation`

The one lever the research surfaces that could change runtime behavior. The **worker**
commands (`iterate`, `review`, `verify`, `record-decision`, `reconcile-contract`,
`capture`) should run only when the workflow/orchestrator dispatches them
(`claude -p "/speckit-devflow-iterate"`) — never when Claude auto-fires on a stray user
message. Setting `disable-model-invocation: true` on them would block auto-fire and drop
their descriptions from context (a token saving), while explicit `/name` dispatch keeps
working (per §1.2).

**Why it is NOT applied yet:** whether headless `claude -p "/speckit-devflow-iterate"`
still dispatches a skill flagged `disable-model-invocation: true` is an **unverified
interaction** — and if the assumption is wrong, *every* pipeline dispatch breaks on the
first iteration. Per DevFlow's own doctrine (ADR-0016 exists because a "verified
assumption" was wrong; ADR-0020: never ship an unvalidated guarantee), this is deferred to
the live dogfood rather than shipped blind. The mis-fire it would prevent is already
*neutralized* by the guard layer (iterate STOPs without feature.json/state.json;
record-decision STOPs when `current_task` is null) — so not flipping it degrades nothing;
it only forgoes a token optimization. See ADR-0022 and MANUAL.md for the validation step.

## 7 · Checklist for DevFlow's skill-side artifacts

1. **Descriptions:** third-person, key-use-case-first, what + when + trigger keywords,
   <1024 chars. `[applied]`
2. **`argument-hint`** on commands that take free-text args (`start`). `[applied]`
3. **Worker-command auto-invocation:** `disable-model-invocation: true` — *recommended,
   deferred to live validation* (§6). `[deferred]`
4. **Checker subagent:** single-purpose, restricted tools, "Use proactively" description,
   `model: inherit` (cross-family independence is the *judge's* job, not the checker's),
   body asserts its own role vs. inherited maker CLAUDE.md. `[applied: role assertion]`
5. **CLAUDE.md protocol block:** ≤200 lines, only always-do-X invariants (procedures live
   in skills), soft-reinforcement of hook-enforced rules, comment-delimited for onboard's
   disk-grep. `[already conformant]`
6. **Packaging:** deterministic work in bundled scripts invoked by exact path, not
   generate-code instructions. `[already conformant]`

## Source register

| Source | Status |
|---|---|
| code.claude.com/docs/en/skills · sub-agents · memory | primary — **re-fetched first-hand this session** |
| platform.claude.com — agent-skills best-practices · overview | primary — quoted (429 on re-vote) |
| anthropic.com/engineering — equipping agents with skills | primary — quoted |
| agentskills.io/specification | primary |
| github.com/obra/superpowers — writing-skills SKILL.md | primary conventions |
| anthropics/skills, VoltAgent/awesome-claude-code-subagents, scottspence sandboxed-evals | fetched; did not complete verification |
