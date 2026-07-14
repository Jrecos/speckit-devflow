# DevFlow — a Spec Kit bundle for autonomous, spec-driven development

**DevFlow** is a [Spec Kit](https://github.com/github/spec-kit) **bundle** (role-based setup)
that provisions the most autonomous-capable spec-driven development workflow we can build on
top of Spec Kit — in one `specify bundle install`.

Spec Kit is the **core**. DevFlow does not replace it or fork it; it *composes* Spec Kit
components (extensions, presets, steps, workflows) into one versioned, opinionated setup that
bakes in the structure our own first real run proved we needed.

> Intended to be shareable/public — **no personal, client, or infra references** live in this repo.

## Why this exists

We ran a 16-step spec-driven pipeline (spec-kit + a build loop + a knowledge track) on a real
feature end-to-end. It shipped — but the run surfaced **five structural gaps** (see
[`docs/retro.md`](docs/retro.md)). Rather than patch a checklist, we bake the fixes into a
bundle so the *next* execution is smooth by construction.

A [Fable-powered deep-research pass](docs/research/loop-architecture-research.md) across the
SWE-agent literature (SWE-agent, OpenHands, SWE-bench, ReAct, Devin), the Ralph-loop corpus,
and the Spec Kit docs turned each gap into an evidence-backed structural fix. That report is
the design input; the blueprint below is its distillation.

## The blueprint (see [`docs/blueprint.md`](docs/blueprint.md))

```
Frame → Plan → Analyze
  → [HUMAN STOP #1: approve plan + failing acceptance tests]
  → Build loop        (one task/iteration · 40–60% context · per-edit lint/typecheck
                       · per-iteration decision-record + auto-commit
                       · cross-family judge as the iteration exit gate · budget/time-box)
  → Review            (own artifact, prerequisite-enforced: /code-review + Semgrep + /security-review)
  → Verify            (full suite + judge over the whole diff; accepted deviation → contract-update + ADR)
  → [HUMAN STOP #2: accept]
  → Ship → Capture    (reads guaranteed-populated decision files)
```

Two human STOPs (before Build, before Ship) — everything between runs unattended. Not one
accept at the end; not a gate on every phase. ([ADR-0002](docs/decisions/0002-two-human-stops.md))

## Gap → structural fix

| Gap (from the run) | Fix baked into the bundle |
|---|---|
| **A** loop over-scoped (build+verify+ship in one budget) | split **inner Build loop** (one task/iter) from **outer pipeline** (phases = separate sessions) |
| **B** review/security gate skipped (conflated into the loop checker) | Review is its own phase; its output artifact is a **prerequisite** the harness checks before Verify |
| **C** decisions not recorded inline (capture came up near-empty) | `record-decision` step, **mandatory per-iteration** |
| **D** accepted deviation left the contract text stale | `reconcile-contract` — accepting a deviation *is* a spec edit → contract update + ADR |
| **E** hand-cranked, no auto-commit, wrong model topology | auto-commit hook + local **maker** / cross-family **judge** topology ([ADR-0003](docs/decisions/0003-maker-plus-cross-family-judge.md)) |

## Form factor

A **Spec Kit bundle** (`bundle/bundle.yml`), not a Claude Code plugin — spec-kit-native,
role-oriented, one-command install. ([ADR-0001](docs/decisions/0001-form-factor-speckit-bundle.md))

Authored and shipped with the Spec Kit CLI:

```bash
specify bundle validate --path ./bundle    # structural + reference checks
specify bundle build    --path ./bundle --output dist/   # versioned .zip artifact
# consumers: specify bundle install devflow
```

## Structure

```
HANDOFF.md          # cold-start doc — open a fresh session with this to build the bundle
bundle/
  bundle.yml        # the manifest (draft — components below are planned, not yet authored)
  README.md         # how to validate / build / install
docs/
  baseline-workflow.md   # the 16-step workflow this bundle automates
  blueprint.md      # the pipeline + gate model + verification stack
  retro.md          # the 5 gaps from the first real run
  research/
    loop-architecture-research.md   # the cited deep-research report (design input)
  decisions/        # ADRs 0001–0005 (dogfooding the knowledge track)
```

## Status

- [x] Research (loop architectures + harness design) — done, cited
- [x] Project scaffold + findings captured
- [x] Baseline workflow + rationale captured (`docs/baseline-workflow.md`, ADR-0005)
- [x] Cold-start handoff doc (`HANDOFF.md`)
- [x] Brainstorm the bundle design — ADRs 0006–0016 + approved spec
  (`docs/superpowers/specs/2026-07-13-devflow-bundle-design.md`)
- [x] Author the components (`components/`: devflow extension + workflow + preset) + final `bundle.yml`
- [x] `specify bundle validate` → `build` green; 12 automated acceptance tests pass
  (`tests/acceptance/run-all.sh`)
- [ ] **Next:** live-Claude dogfood run (`tests/acceptance/MANUAL.md`) → catalog publication
