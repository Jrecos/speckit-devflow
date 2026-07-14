# ADR-0017: Artifact versioning policy — what DevFlow commits, and why

**Status:** Accepted

**Context:** DevFlow generates process artifacts continuously (specs, plans, tasks, decision
records, loop state, review findings) and its Stop-gate auto-commits with `git add -A` —
so "what belongs in git" is a design decision, not an accident. A deep-research pass
(2026-07-14; 25 sources, 25 claims adversarially verified 3-vote, 23 confirmed) established
the 2025–2026 tool-author consensus: Spec Kit ships code that commits `specs/NNN/*` and
`.specify/` by default and frames specs as durable primary artifacts ("commit and maintain,
never prune"); MADR prescribes committing ADRs and superseding via status metadata rather
than deleting; Anthropic prescribes committing project `CLAUDE.md` and team-shared
`.claude/settings.json` while gitignoring the `*.local` pair (`CLAUDE.local.md`,
`.claude/settings.local.json`); the one category kept out of the tree is raw session state
(Claude Code stores transcripts outside the repo and declares the format version-unstable).
Notably, practitioner-side evidence largely failed verification — the surviving picture is
tool-author-recommendation-heavy — and no verified guidance exists for agent
implementation-plan/design documents specifically.

**Decision:** DevFlow's policy, per artifact class:

| Artifact | Policy |
|---|---|
| `specs/NNN/{spec,plan,tasks,analysis}.md` | **Commit; maintain, never prune** (Spec Kit doctrine — old feature dirs stay for audit) |
| `.specify/` scaffolding | **Commit**; keep tooling-upgrade commits separate from feature-artifact commits |
| `docs/decisions/*.md` (ADRs, decision records) | **Commit; never delete** — supersede via status metadata |
| Design specs / implementation plans (`docs/superpowers/**`) | **Commit on the feature branch; keep as historical record** (no verified external guidance — extrapolated from Spec Kit's Flow-Forward model; distilling durable content into ADRs is the escape valve, not deletion) |
| `CLAUDE.md`, `AGENTS.md`, shared `.claude/` (settings.json, agents/, skills/) | **Commit** (the DevFlow onboard command itself merges into committed `.claude/settings.json`) |
| `CLAUDE.local.md`, `.claude/settings.local.json`, `.env*` | **Gitignore** (the official local-pair convention; onboard ensures the ignore entries) |
| Session transcripts, scratch dirs (`.superpowers/`), caches | **Never commit** |
| **`loop/state.json`, `review/findings.json`** | **Commit on the feature branch — deliberately** (see below) |

**Why DevFlow's loop state IS committed (a reasoned exception):** the research's
"don't commit loop state" conclusion was its weakest inference — an analogy from Claude
transcript-format instability, which is about script parsing, not version control. DevFlow's
`state.json` is not a transcript: it is the **on-disk coordination contract** between
layers (ADR-0008: disk is the only signal channel). Fresh-context iterations, workflow
resume, the Stop-gate, and STOP #2's evidence summary all read it; the finding→fix→record
trail in `findings.json` is part of the audit story (ADR-0012). This matches the
Ralph-lineage pattern of a *committed plan file* as shared loop state, not the
session-transcript pattern. Scope: it lives on **feature branches** via the loop's
auto-commits; consumers who squash-merge keep it out of main's linear history, and either
way the feature dir remains inspectable (Flow-Forward).

**Consequences:** Consumers get an explicit, defensible answer to "why is all this process
stuff in the repo?" — and onboard codifies the gitignore half mechanically. Costs: public
repos expose process internals by design (mitigated by the role-not-host rule, ADR-0014);
feature branches carry state-churn commits (mitigated by squash-merge). Revisit the
plans-directory row if the superpowers community publishes actual guidance (flagged open
question in the research).
