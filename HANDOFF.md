# HANDOFF — build the DevFlow Spec Kit bundle

You are picking this up in a **fresh session** to build the bundle. This doc is self-contained:
read it, read the files it points to, then start with the brainstorm. Do not re-derive what's
already decided below.

## TL;DR

- **What we're building:** `DevFlow` — a **Spec Kit bundle** (role-based setup) that provisions an
  autonomous, spec-driven development workflow in one `specify bundle install`.
- **Spec Kit is the core.** DevFlow *composes* spec-kit components (extensions / presets / steps /
  workflows); it does not fork or replace spec-kit.
- **State:** research done, project scaffolded, 5 ADRs written, `bundle.yml` is a **draft**. The
  components it lists don't exist yet — that's the work.
- **Next move:** run the **brainstorming skill** to design the components (resolve the open
  questions below, one at a time), record each decision as an ADR, *then* author them.
- **Do not** author components or write `bundle.yml` for real until the design is approved.

## Read first (in order)

1. `README.md` — the charter (what/why, blueprint, gap→fix, form factor).
2. `docs/blueprint.md` — the pipeline, the two-STOP gate model, the verification stack, topology.
3. `docs/baseline-workflow.md` — the 16-step workflow this bundle automates.
4. `docs/retro.md` — the five gaps a real run exposed (the reason this exists).
5. `docs/research/loop-architecture-research.md` — the cited evidence base for every choice.
6. `docs/decisions/0001..0005` — decisions already made; don't relitigate them.
7. `bundle/bundle.yml` — the draft manifest (real schema, planned components).

## Already decided (ADRs — treat as settled)

- **0001 Form factor = Spec Kit bundle** (`bundle.yml`, `specify bundle validate`/`build`).
- **0002 Two human STOPs** — after Plan/Analyze (before Build) and after Verify (before Ship).
  Everything between runs unattended. Not one-accept-at-end; not a gate per phase.
- **0003 Local maker + cross-family judge** — tests are the primary oracle; judge PASS advisory,
  judge FAIL hard-block. (Cross-family superiority is design reasoning, not benchmarked.)
- **0004 Inner build loop (one task/iteration) split from the outer pipeline** (phases = separate
  sessions; Review/Verify/Ship can't be reached into or skipped by the loop).
- **0005 Why the baseline workflow is shaped this way** (spec-kit spine, required Loop, local
  NDA-safe review, knowledge track, gate placement).

## The blueprint you're implementing

```
Frame → Plan → Analyze
  → [HUMAN STOP #1: approve plan + failing acceptance tests]
  → Build loop  (one task/iter · 40–60% context · per-edit lint/typecheck
                 · record-decision + auto-commit per iteration
                 · cross-family judge as the iteration exit gate · budget/time-box)
  → Review  (own artifact, prerequisite-enforced: /code-review + Semgrep + /security-review)
  → Verify  (full suite + judge over the diff; accepted deviation → contract-update + ADR)
  → [HUMAN STOP #2: accept]
  → Ship → Capture
```

## Open design questions — the brainstorm's job

Resolve these; each becomes an ADR; then `bundle.yml` gets finalized.

1. **Which extensions to pin?** `loop` is required. Decide on `superspec`, `aide`, `git`, and
   whether `ralph` ships as the alternate engine. Pin versions.
2. **The `devflow` workflow** — how does one spec-kit *workflow* encode the phased pipeline + the
   two human STOPs + the inner/outer split? Or is it a workflow that sequences other
   workflows/steps? (Read how spec-kit workflows compose steps before deciding.)
3. **The two custom steps** — how are `record-decision` (per-iteration → `docs/decisions/*.md`,
   fixes gap C) and `reconcile-contract` (accepted deviation → spec edit + ADR, fixes gap D)
   authored as spec-kit *steps*? What's the step schema/interface?
4. **The gate/preset** — how to make Review a **hard prerequisite** the harness checks before
   Verify (fixes gap B), and how to encode the two STOPs. Preset strategy + priority.
5. **Auto-commit + one-task/iteration** — where do these live (a loop preset? a step? a hook via
   the integration)? Fixes gap E and enforces the most-replicated finding.
6. **Judge wiring** — how the cross-family judge plugs into the loop's exit gate. Keep the
   maker/judge *endpoints* out of this public repo (configure them in your own environment); the
   bundle should reference roles, not hosts.
7. **`requires.mcp` shape** — confirm how spec-kit expects the `semgrep` MCP entry (name only, or
   command/args).

## How Spec Kit bundles work (so you don't re-research)

A bundle is a **`bundle.yml`** manifest — a distribution/composition layer over existing spec-kit
components; it adds no new runtime behavior. Schema (from spec-kit's `examples/bundles/developer`):

```yaml
schema_version: "1.0"
id: <slug>
version: <semver>
name: <str>
description: <str>
license: <str>
author: <str>
# integration: <name>   # omit → "agnostic": inherits the project's agent integration
requires:
  speckit: ">=0.9.0"
  tools: []
  mcp: []
provides:
  extensions: [{ name, version }]
  presets:    [{ name, version, priority, strategy }]   # e.g. strategy: append
  steps:      [ <name> ]
  workflows:  [{ name, version }]
tags: [ ... ]
```

CLI:
```bash
specify bundle validate --path ./bundle            # structural + reference checks (fails if a component ref is absent)
specify bundle build    --path ./bundle --output dist/   # versioned .zip artifact
specify bundle install  devflow                    # consumers; idempotent, confined to project root
```
Resolution is a priority-ordered catalog stack (project > user > built-in). `validate` will fail
until the planned components exist — expected.

## Hard constraints

- **Public repo.** No personal names, client names, infra hostnames, IPs, or internal URLs in any
  committed file. Topology is referenced by role (local maker, cross-family judge), never by host.
- **Spec Kit is the core** — compose it, don't fork it.
- **Stay minimal.** The research is emphatic: interface/guardrail details beat orchestration
  sophistication. Don't build a heavy framework.
- **Dogfood the knowledge track** — record each design decision as an ADR in `docs/decisions/` as
  you make it.
- **Push via `gh`** (HTTPS), account `Jrecos`. Branch `main`. Don't push secrets (`.gitignore`
  already blocks `.env*`, keys).

## Recommended first message for the fresh session

> I'm building the DevFlow Spec Kit bundle (this repo). Read `HANDOFF.md`, `README.md`,
> `docs/blueprint.md`, `docs/baseline-workflow.md`, `docs/retro.md`, and `docs/decisions/*.md`.
> Then use the brainstorming skill to design the bundle: work through the "Open design questions"
> in HANDOFF.md one at a time, and record each decision as an ADR. Don't author components or
> finalize `bundle.yml` until the design is approved. Spec Kit is the core; the repo is public —
> no personal/client/infra references. First, confirm you've read the docs and restate the open
> questions in priority order before we start question 1.
