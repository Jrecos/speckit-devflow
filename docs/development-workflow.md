# The complete development workflow

The full lifecycle, from an empty machine to a shipped feature and a fed knowledge base —
what to run, in what order, what each step produces, and where the humans stand. This is
the automated successor to the [16-step manual baseline](baseline-workflow.md); the
[mapping table](#appendix--baseline-16-steps--devflow) at the bottom shows where every
baseline step went.

- `👤` = a human decision · `⚙` = runs itself · `▸` = produces an artifact on disk

---

## Stage 0 — once per machine

| # | What | Command |
|---|---|---|
| 0.1 | Spec Kit CLI (≥ 0.12) | `uv tool install specify-cli` (see [spec-kit](https://github.com/github/spec-kit)) |
| 0.2 | Claude Code | [install](https://code.claude.com/docs) — DevFlow targets the `claude` integration ([ADR-0009](decisions/0009-claude-code-first.md)) |
| 0.3 | A cross-family judge | any command that speaks the [verdict contract](#the-judge-one-line-of-env) — configured per shell, never committed |

## Stage 1 — once per project

```bash
specify init . --integration claude        # spec-kit scaffolding (.specify/, skills)
specify bundle install devflow             # git + superspec + devflow ext · preset · workflow
```

Then, inside `claude`:

| # | Step | Command | Notes |
|---|---|---|---|
| 1.1 👤▸ | **Constitution** — the project's non-negotiables | `/speckit-constitution` | quality bars, stack rules, review standards → `.specify/memory/constitution.md`. Every later phase checks against it. |
| 1.2 👤 | *(optional)* **Product layer** | `aide` extension: vision → roadmap → items | only for products that need a layer above features: `specify extension add aide`, then `/speckit-aide-create-vision` → `/speckit-aide-create-roadmap` → `/speckit-aide-create-item`. Skip for libraries/tools. ([ADR-0006](decisions/0006-component-strategy-hybrid.md)) |
| 1.3 👤▸ | **Onboard** — make the repo workflow-ready | `/speckit-devflow-onboard` | validates git/claude, adds semgrep MCP, detects & confirms your lint/typecheck/test commands, smoke-tests the judge (warns on same-family), installs the hooks pack + checker subagent + CLAUDE.md protocol, fixes `.gitignore` ([ADR-0017](decisions/0017-artifact-versioning-policy.md)). Ends with a ✓/✗ checklist. |

### The judge: one line of env

```bash
export DEVFLOW_JUDGE_CMD='<any command: reads {"diff","criteria","spec_slice"} JSON on stdin,
                           prints {"verdict":"PASS"|"FAIL","reason":...,"criteria":[...]}>'
```

Role in the repo, resolution in your environment ([ADR-0014](decisions/0014-judge-wiring-role-env-seam.md)).
**Optional but recommended:** unset → Claude judges Claude — an independent fresh context,
but same-family, warning on every run ([ADR-0018](decisions/0018-judge-fallback-same-family.md)).
Malformed verdict or no resolvable judge at all → fail-safe block.

## Stage 2 — per feature: one command, two decisions

Two equivalent drivers — pick per run ([ADR-0019](decisions/0019-claude-native-orchestrator.md)):

```bash
# A · engine-driven (terminal; headless/CI-friendly)
specify workflow run devflow \
  --input feature="what you want built" \
  --input mode=attended        # attended | attended-step | autonomous  (ADR-0013)

# B · Claude-native (inside a claude session; conversational gates)
/speckit-devflow-start what you want built
```

Both walk the same phase map below with the same guarantees — the enforcement lives in
shared scripts, not in whichever driver you chose. Path B additionally maintains
`specs/<feature>/devflow-flow.json`: a phase ledger advanced by a **mechanical guard**
(`devflow-flow.sh`) that refuses out-of-order transitions and phases whose exit artifacts
don't exist — brainstorm/clarify/STOPs become conversation, loop iterations still dispatch
as fresh headless sessions, and any new session resumes from the ledger.

### Phase map

| Phase | ⚙/👤 | What happens | ▸ Artifacts |
|---|---|---|---|
| **Frame** | ⚙ | `specify` writes the contract → `superspec.brainstorm` pressure-tests edge cases → `clarify` asks its questions | `specs/NNN/spec.md` |
| **Plan** | ⚙ | plan + **failing acceptance tests** (required by the plan-hardening preset — the loop's visible target) | `plan.md`, red tests |
| **Tasks** | ⚙ | ordered tasks, each with `AC:` criteria in the countable format the harness parses | `tasks.md` |
| **Leash** | ⚙ | budget = ⌈open tasks × 2.5⌉ · 4h time-box · park after 2 attempts ([ADR-0011](decisions/0011-loop-termination-and-iteration-protocol.md)) | `leash.md`, `loop/state.json` |
| **Analyze** | ⚙ | spec ↔ plan ↔ tasks consistency check | analysis report |
| **STOP #1** | 👤 | **your highest-leverage minutes**: read plan + red tests + leash. `approve` → the loop gets the keys · `reject` → re-plan. The clock starts *after* you approve. | gate record |
| **Build loop** | ⚙ | per iteration: fresh context → ONE task → implement (lint/typecheck fire per edit) → scoped tests → `@devflow-checker` grades vs AC → judge verdict → decision record → auto-commit. RED close = failure note, no commit, attempt counted. Judge FAIL = verdict written, retry targets it. 2 failed attempts = task **parked**, loop moves on. ([ADR-0016](decisions/0016-verification-corrections.md)) | commits, `docs/decisions/*`, state |
| **Review** | ⚙ | its own phase, local & NDA-safe: code review + Semgrep + security over the whole diff. Findings written to disk **before anything reacts**. | `review/findings.{md,json}` |
| **Fix cycles** | ⚙ | findings → fix-tasks → the same loop re-enters (≤ 2 cycles, [ADR-0012](decisions/0012-review-loopback-documented.md)) → full re-review. Survivors after cycle 2 are parked with history. | fix commits, records linking findings |
| **Verify** | ⚙ | hard prerequisite: findings must be clean-or-parked (the gap-B guard). Then full suite + judge over the **whole diff**; deviations from the spec noted. | `verify-report.md` |
| **STOP #2** | 👤 | the evidence summary: tasks/parked, cycles, findings, verdict, deviations, record count. `accept` · `accept-with-deviation` · `reject`. **Ship is unreachable except through this gate** — and accepting with *anything* parked or deviated routes through reconcile first. | gate record |
| **Reconcile** | ⚙ | accepting a deviation **is a spec edit**: contract text updated + ADR written before Ship (the gap-D fix) | spec edit, ADR |
| **Ship** | ⚙ | `git.validate` (branch hygiene) → commit/PR linking the whole trail | PR |
| **Capture** | ⚙→👤 | scans `docs/decisions/` (guaranteed-populated — every green close required a record) and proposes durable knowledge notes. **You curate; you merge.** Nothing durable → skip is a success. | vault-note candidates |

### While it runs

`/speckit-devflow-status` for a glance · `Ctrl+C` pauses safely (everything durable is on
disk and committed) · `specify workflow resume <run-id>` continues, including gates that
paused headless · `mode=attended-step` blocks at every iteration boundary.

## The knowledge track (runs through everything)

Files are the source of truth; the LLM does the bookkeeping:

- **read** — every fresh iteration deterministically reloads CLAUDE.md protocol + spec +
  tasks + state. Constitution primes every phase.
- **record** — decision records are *enforced*, not hoped for: the Stop-gate blocks any
  green close without one (the gap-C fix). Failure notes and judge verdicts persist to
  state so retries learn.
- **write back** — Capture reads the repo (never the chat) and proposes; the human curates
  and merges. Next feature starts smarter.

## What lands in git ([ADR-0017](decisions/0017-artifact-versioning-policy.md))

Commit and keep: `specs/NNN/*`, `.specify/`, `docs/decisions/`, CLAUDE.md/AGENTS.md,
shared `.claude/`. Commit on feature branches (squash-merge keeps main linear):
`loop/state.json`, `review/findings.json`. Gitignore: `CLAUDE.local.md`,
`.claude/settings.local.json`, `.env*`, session scratch.

---

## Appendix — baseline 16 steps → DevFlow

Where every step of the [manual baseline](baseline-workflow.md) went:

| Baseline step | DevFlow home |
|---|---|
| 1 · Onboard | `/speckit-devflow-onboard` (Stage 1.3) |
| 2 · Extensions | `specify bundle install devflow` (one command) |
| 3 · Semgrep MCP | onboard installs it |
| 4 · Vault mapping | external to the public bundle — Capture proposes, your vault process merges |
| 5 · Constitution | `/speckit-constitution` (Stage 1.1) |
| 6 · Product layer | optional `aide` (Stage 1.2) |
| 1 · Prime from vault | superseded: deterministic file re-priming per iteration + constitution per phase |
| 2–4 · Specify / Brainstorm / Clarify | **Frame** phase, automated |
| 5–7 · Plan / Tasks / Analyze | **Plan → Tasks → Analyze**, hardened (red acceptance tests + AC format required) |
| — | **STOP #1** (was implicit in gates 5/7 👤 — now one explicit gate with the leash) |
| 8 · Implement (loop.define/run) | the **Build loop** — DevFlow's own engine ([ADR-0007](decisions/0007-own-loop-engine-with-modes.md) retired the community `loop`/`ralph` pair; `autonomous` mode replaced the engine swap) |
| 9 · Record decisions | per-iteration, **hook-enforced** (was "continuous, by discipline") |
| 10 · Review | **Review** phase + fix cycles — now structurally unskippable |
| 11 · Verify (loop.check/guard) | **Verify** phase: full suite + whole-diff judge, prerequisite-gated |
| 12 · Validate | `git.validate` inside **Ship** |
| 13 · Ship | **Ship** (behind STOP #2, always) |
| 14–16 · Capture / Curate / Merge | **Capture** proposes → you curate → you merge (the human firebreak stands) |
