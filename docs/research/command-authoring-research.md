# Authoring Agent Command Documents: Verified Best Practices (2025–2026)

**Research method:** deep-research harness, 2026-07-15 — 5 search angles, 18 sources
fetched, 89 claims extracted, top 25 adversarially verified (3-vote refutation test);
**23 confirmed, 2 refuted, 0 unverified**. The surviving evidence is almost entirely
primary-source: Anthropic's official documentation (platform.claude.com,
code.claude.com, engineering blog), the agentskills.io SKILL.md specification, and
GitHub spec-kit's shipped command templates (verified against a fresh clone of main).

**Scope note on evidence:** practitioner-side and academic material largely did not
survive verification — OpenAI's agents guidance, peer-reviewed prompt-length research,
third-party eval tooling (promptfoo, golden transcripts), and community collections
beyond spec-kit (obra/superpowers, claude-code command packs) are **uncovered**, so this
report cannot confirm cross-vendor generality. It is a tool-author-doctrine report, and
it says so. Two widely-repeated claims were refuted and must not be reused (§8).

**Why DevFlow cares:** the bundle's prompt layer (9 command documents under
`components/extensions/devflow/commands/`) carries all *behavior* while the mechanical
layer carries all *guarantees* (ADR-0010/0020). Better-authored commands raise the floor
of every execution even though outputs vary per run.

---

## 1 · Length and dilution: the 500-line / ~5k-token ceiling

Three independent official sources converge on the same ceiling, verbatim:

- *"Keep SKILL.md body under 500 lines for optimal performance"* — platform.claude.com
  best-practices (repeated three times, including its final checklist)
- *"< 5000 tokens recommended … Keep your main SKILL.md under 500 lines"* —
  agentskills.io specification
- *"Keep SKILL.md under 500 lines. Move detailed reference material to separate
  files"* — code.claude.com/docs/en/skills

The mechanism is documented, not just asserted: *"Bloated CLAUDE.md files cause Claude
to ignore your actual instructions! … important rules get lost in the noise. Fix:
Ruthlessly prune."* The prescribed pruning test: **"Would removing this line cause
Claude to make mistakes?"** — keep only lines that pass.

> Honesty note: "Claude ignores half of it" is colloquial vendor phrasing, not a
> measured benchmark. The one academic effect-size claim in circulation was refuted
> (§8). Instruction dilution as a *failure mode* is officially documented; its
> *magnitude* is not.

**Verdict for DevFlow:** all 9 commands are already well under the ceiling (largest:
`start` at ~150 lines). The ceiling matters as a budget for revisions — improvements
must not balloon the bodies.

## 2 · Progressive disclosure: the three-tier loading model

The sanctioned architecture (agentskills.io spec, defined verbatim):

| Tier | What loads | When | Budget |
|---|---|---|---|
| 1 · Metadata | `name` + `description` only | startup, for **all** skills | ~100 tokens |
| 2 · Instructions | the SKILL.md body | on activation | < 5k tokens |
| 3 · Resources | bundled scripts / references / assets | only when needed | unbounded |

Anthropic's engineering blog adds the split heuristics: *"When the SKILL.md file
becomes unwieldy, split its content into separate files and reference them"*; *"If
certain contexts are mutually exclusive or rarely used together, keeping the paths
separate will reduce the token usage."* And the load-pattern rule from
code.claude.com: broadly-applicable rules belong in the always-loaded file (CLAUDE.md);
situational workflows belong in on-demand skills/commands.

**Verdict for DevFlow:** we already practice this shape — loop invariants live in the
CLAUDE.md protocol block (always loaded), workflows in commands (on demand), and
deterministic machinery in `scripts/` (tier 3). No structural change needed.

## 3 · Frontmatter: the description is the activation signal

Only the metadata is preloaded, so **the `description` is the sole signal for when a
command gets used**. The spec's requirements (verbatim): 1–1024 characters; *"should
describe both what the skill does and when to use it"*; *"should include specific
keywords that help agents identify relevant tasks."* The spec's own contrast pair:
keyword-rich descriptions vs. the poor *"Helps with PDFs."*

**Verdict for DevFlow:** our descriptions state *what* well but mostly omit *when* and
trigger keywords — a concrete revision item.

## 4 · Body structure: imperative, numbered, checklisted

- **Recommended sections** (spec): step-by-step instructions · input/output examples ·
  common edge cases. No format mandates beyond that.
- **Voice** (code.claude.com, verbatim): *"State what to do rather than narrating how
  or why."* Imperative over explanatory.
- **Complex workflows** (platform best-practices, verbatim): *"Break complex operations
  into clear, sequential steps. For particularly complex workflows, provide a checklist
  that Claude can copy into its response and check off as it progresses"* — with worked
  `- [ ]` examples.
- **Against exhaustiveness** (same page): *"Concise, stepwise guidance with a working
  example tends to outperform exhaustive documentation"* — don't enumerate every edge
  case; defer most to the agent's judgment.

## 5 · The reliability core: exit criteria, feedback loops, failure paths

**5.1 — Exit criteria are the single most load-bearing mechanism.** Verbatim from
code.claude.com best-practices: *"Claude stops when the work looks done. Without a
check it can run, 'looks done' is the only signal available, and you become the
verification loop… Give Claude something that produces a pass or fail, and the loop
closes on its own."* Platform docs prescribe the loop shape: *"Run validator → fix
errors → repeat"*, *"Only proceed when validation passes"*, *"If verification fails,
return to Step 2."* Anthropic's canonical workflow-skill example (fix-issue) is
numbered imperative steps naming exact CLI commands, with verification steps (tests,
lint, typecheck) before completion.

**5.2 — Degrees of freedom must match task fragility** (platform docs, three-level
scale, verbatim examples):

| Freedom | Form | When |
|---|---|---|
| High | heuristic prose | decisions depend on context (e.g. judging code quality) |
| Medium | pseudocode / parameterized scripts | a preferred pattern exists, some variation OK |
| Low | exact scripts — *"Run exactly this script… Do not modify the command or add additional flags"* | fragile, sequence-critical operations |

Corollary: *"Prefer scripts for deterministic operations"* — bundle executable code
rather than asking the model to generate it (*"because code is deterministic, this
workflow is consistent and repeatable"*), and *"it should be clear whether Claude
should run scripts directly or read them into context as reference."*

**5.3 — Failure paths, with calibrated severity.** Spec-kit's shipped templates
(verified against main) systematically encode three severities:

- **silent-skip** for malformed *optional* config (*"If the YAML cannot be parsed or is
  invalid, skip hook checking silently and continue normally"* — in all 8 core templates)
- **abort-with-instruction** for missing prerequisites (name the command that fixes it)
- **hard STOP-and-ask** with enumerated responses before irreversible steps
  (*"If user says 'no' or 'wait' or 'stop', halt execution"*)

**5.4 — Content lifecycle: the file is read once.** Claude Code renders the invoked
command into the conversation **once and never re-reads it**: *"write guidance that
should apply throughout a task as standing instructions rather than one-time steps."*
Every line is also *"a recurring token cost"* for the rest of the session — conciseness
is a runtime cost issue, not a style preference. (Version-specific: v2.1.202-era;
auto-compaction may truncate re-attached content to the first ~5k tokens — which further
rewards putting the most durable rules **early**.)

## 6 · Emphasis markers: a tuning lever, not a foundation

Officially endorsed — *"You can tune instructions by adding emphasis (e.g., 'IMPORTANT'
or 'YOU MUST') to improve adherence"* (code.claude.com); *"stronger language like 'MUST
filter' instead of 'always filter'"* (platform docs) — but **only as escalation after
observed misses**, and never as a substitute for pruning: the same docs say bloat makes
instructions ignored regardless of emphasis. No measured effect sizes exist anywhere in
the verified corpus; the endorsement is qualitative. Overuse plausibly neutralizes it
(open question, §9).

## 7 · Regression-testing the prompt layer: evaluation-driven development

Officially prescribed (platform best-practices + code.claude.com + the skill-creator
plugin), verbatim highlights:

1. *"Create evaluations BEFORE writing extensive documentation"* — at least **three
   evals per skill** (checklist requirement).
2. **Baseline first:** measure performance *without* the skill, in fresh sessions —
   *"a fresh session matters because leftover context from authoring the skill will
   mask gaps in the written instructions."*
3. Write minimal instructions → iterate against the evals.
4. Test across model tiers (Haiku / Sonnet / Opus).
5. The skill-creator plugin automates the pipeline: `evals/evals.json` test cases, each
   run in an isolated subagent with clean context, graded assertions →
   `grading.json`, pass-rate/token/time benchmarks, **blind A/B comparison between
   skill versions before committing an edit**.

Caveat: no built-in eval runner exists outside that plugin; tooling is otherwise
user-supplied. This is the vendor-official analogue of promptfoo/golden-transcript
practice (which the research could not verify independently).

## 8 · Refuted claims — do not reuse

1. **"Changing only the prompt's formatting can shift GPT-3.5 performance by up to 40
   percentage points"** (attributed to arXiv 2411.10541) — refuted 0-3 as sourced.
   Do not cite.
2. **"Every spec-kit template opens with identical `## User Input` / `$ARGUMENTS`
   boilerplate"** — refuted 1-2. Spec-kit conventions are *prevailing*, not verbatim
   universal; don't assert per-file uniformity.

Also flagged: one spec-kit claim ("failure paths for every branch") passed only 2-1 —
soften to *systematically encoded*, not exhaustive.

## 9 · Open questions

- Quantitative, peer-reviewed evidence for adherence degradation vs. document length
  (beyond the vendor's qualitative 500-line guidance)?
- OpenAI's official divergences from this doctrine (emphasis, checklists, eval-first)?
- How community collections (superpowers, command packs) actually structure and test
  theirs — and whether teams use promptfoo/golden transcripts in practice?
- The saturation point of emphasis markers — at what density does inflation neutralize
  the benefit?

---

## 10 · The DevFlow authoring checklist (normative for `commands/*.md`)

Synthesized from the unanimous findings above; applied by ADR-0021.

1. **Frontmatter** — `description` ≤ 1024 chars stating **what + when**, with trigger
   keywords. Deterministic setup declared as exact script paths, not prose.
2. **Body ≤ 500 lines / ~5k tokens** — schemas, templates, long examples go to
   companion reference files; mutually-exclusive paths to separate files.
3. **Imperative voice, numbered sequential steps**; mark context loads
   **REQUIRED** vs **IF EXISTS**.
4. **Copyable `- [ ]` progress checklist** for long workflows (start, iterate) that
   the agent checks off in its responses.
5. **Every command ends with a machine-checkable "Done when" gate** — exit codes,
   literal checkbox counting, file-existence checks — never "looks done".
6. **Feedback loops spelled out** — "run validator → fix → repeat; only proceed when
   validation passes; if verification fails, return to step N."
7. **Every precondition gets a failure path with calibrated severity** — silent-skip
   (optional config) / abort-with-instruction naming the fix (missing prereq) /
   STOP-and-ask with enumerated responses (irreversible steps).
8. **Freedom matches fragility** — exact non-modifiable commands for
   fragile/deterministic steps; heuristics for judgment steps.
9. **Standing instructions, stated early** — the file is rendered once and never
   re-read; session-wide rules phrased as invariants, placed at the top.
10. **Emphasis sparingly** — IMPORTANT/YOU MUST only on load-bearing rules after
    observed misses; apply the pruning test to every line.
11. **Explicit handoffs** — each command names what comes next (and who triggers it)
    instead of relying on inference.
12. **Eval-driven maintenance** — ≥ 3 evals per command authored before major
    rewrites; fresh-session with/without baselines; blind A/B between versions;
    re-run on every edit. (DevFlow status: prescribed, not yet implemented — see
    ADR-0021's consequences.)

## Source register

| Source | Quality | Angle |
|---|---|---|
| platform.claude.com/docs — agent-skills best practices | primary | vendor guidance |
| agentskills.io/specification | primary | vendor guidance |
| code.claude.com/docs — skills · best-practices | primary | vendor guidance |
| anthropic.com/engineering — equipping agents with skills | primary | vendor guidance |
| github.com/github/spec-kit — templates/commands (fresh clone, 2026-07-14) | primary | OSS conventions |
| github.com/anthropics/skills · claude-plugins-official (skill-creator) | primary | evals |
| obra/superpowers, promptfoo, hamel.dev, arXiv 2307.03172 / 2411.10541 / 2507.11538, OpenAI cookbook | fetched, **claims did not survive verification** — listed for the record |
