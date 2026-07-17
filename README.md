<p align="center">
  <img src="docs/assets/devflow-header.png" alt="DevFlow — two human gates, one autonomous loop between them" width="100%">
</p>

# DevFlow — a Spec Kit bundle for autonomous, spec-driven development

**One install. One command per feature. Exactly two human decisions.**
Everything in between — building, testing, checking, judging, reviewing, recording — runs
itself, on rails it cannot leave.

DevFlow is a [Spec Kit](https://github.com/github/spec-kit) **bundle** that provisions the
most autonomous-capable spec-driven workflow we could build *on top of* Spec Kit — never
forking it. It exists because we ran a 16-step pipeline by hand on a real feature
([`docs/baseline-workflow.md`](docs/baseline-workflow.md)), shipped it, and walked away with
[five structural gaps](docs/retro.md). This bundle bakes the fixes in **by construction**.

> Public repo: model topology is referenced **by role** (maker / checker / judge), never by
> host or vendor. Your environment resolves the roles; nothing here knows your endpoints.

---

## The big picture

```
             you                     the machine                              you
              │                          │                                     │
  ┌───────────▼───────────┐   ┌──────────▼──────────────────────┐   ┌──────────▼──────────┐
  │  specify workflow run │   │  Frame → Plan → Analyze         │   │      STOP #2        │
  │  devflow              │──▶│      ▼                          │──▶│ accept              │
  │  --input feature=...  │   │  [STOP #1: approve plan +       │   │ accept-with-        │
  │  --input mode=...     │   │   red tests + the leash]        │   │   deviation ──▶ spec │
  └───────────────────────┘   │      ▼                          │   │   edit + ADR first  │
                              │  BUILD LOOP ──▶ Review ──▶      │   │ reject              │
                              │  (fix cycles ≤2, documented)    │   └──────────┬──────────┘
                              │      ▼                          │              ▼
                              │  Verify (suite + whole-diff     │      Ship → Capture
                              │  judge; review artifact is a    │      (PR links the full
                              │  hard prerequisite)             │       decision trail)
                              └─────────────────────────────────┘
```

Two human STOPs — after Plan/Analyze, before Ship — and **Ship is topologically unreachable**
except through the second one ([ADR-0002](docs/decisions/0002-two-human-stops.md)).

## The inner loop — one task, one fresh context, every time

```
        ┌─────────────────────────── the do-while (engine-owned) ──────────────────────────┐
        │                                                                                  │
   ┌────▼─────┐   ┌───────────────┐   ┌──────────────┐   ┌─────────────┐   ┌─────────────┐ │
   │ dispatch │──▶│ pick ONE task │──▶│  implement   │──▶│ scoped      │──▶│ checker     │ │
   │ claude -p│   │ (skips parked,│   │  (PostToolUse│   │ tests       │   │ subagent    │ │
   │ fresh ctx│   │  reads notes) │   │  lint/type-  │   │             │   │ (fresh ctx) │ │
   └──────────┘   └───────────────┘   │  check hook) │   └──────┬──────┘   └──────┬──────┘ │
        ▲                             └──────────────┘          │ red             │        │
        │                                                       ▼                ▼        │
        │            ┌────────────────┐   ┌──────────┐   RED close:       ┌───────────┐   │
        │            │ STOP-GATE HOOK │◀──│ record-  │   failure note,    │ judge     │   │
        │  continue? │ record? tests? │   │ decision │   no commit,       │ (cross-   │   │
        └────────────│ ONE task done? │   └──────────┘   attempts++       │ family,   │   │
          (budget ∧  │ → auto-commit  │        ▲                          │ via env)  │   │
           time-box ∧│ → allow exit   │        └──── PASS ────────────────┴─────┬─────┘   │
           open tasks)└───────────────┘                    FAIL → verdict to state,        │
                                                           retry targets it next iteration │
        └──────────────────────────────────────────────────────────────────────────────────┘
```

The three-layer rule ([ADR-0010](docs/decisions/0010-fix-enforcement-layers.md)):
**behavior lives in prompts; every guarantee lives at the strongest layer that can hold it.**

| Layer | Owns | The agent can override it? |
|---|---|---|
| 1 · Workflow engine | phase order, both STOPs, the loop, review-before-verify, deviation routing | never — it dispatches the agent |
| 2 · Claude hooks + subagents | per-edit lint/typecheck, the close contract, auto-commit, independent checking | no — hooks fire mechanically |
| 3 · Command prompts | how to iterate, review, record, reconcile | yes — which is why no guarantee lives here |

## The brakes (nothing runs away)

| Brake | Default | Catches |
|---|---|---|
| attempts per task | **2**, then the task is **parked** (loop continues) | one stuck task starving the run |
| iteration budget | **⌈open tasks × 2.5⌉** — computed, shown at STOP #1 | runaway rework |
| wall-clock time-box | **4h**, clock starts *after* STOP #1 approval | slow burn |

Exhaustion is a **clean park**, never a crash: remaining tasks are parked with notes,
everything done is committed and recorded, and STOP #2 gets the full history. Accepting
with *anything* parked routes through `reconcile-contract` first — the spec text can never
ship stale ([ADR-0016](docs/decisions/0016-verification-corrections.md)).

## Quick start

### Install (from the GitHub release)

DevFlow isn't in a public catalog yet, so install its components straight from the release —
`latest/download/` always resolves to the newest tag:

```bash
BASE=https://github.com/Jrecos/speckit-devflow/releases/latest/download
specify extension add git                                    # upstream primitive (catalog)
specify extension add superspec                              # upstream primitive (catalog)
specify extension add devflow --from "$BASE/devflow-extension.zip"
specify preset add     --from "$BASE/devflow-plan-hardening.zip"
specify workflow add   "$BASE/devflow-workflow.yml"
```

*(Once DevFlow is published to a catalog, `specify bundle install devflow` will pull all of
the above in one step.)* Then, inside your project:

```bash
claude
/speckit-devflow-onboard                # validates tools, adds semgrep MCP, installs hooks pack,
                                        # checker subagent, CLAUDE.md protocol; smoke-tests the judge

export DEVFLOW_JUDGE_CMD='<your cross-family judge command>'   # optional but recommended —
                                        # unset = Claude judges Claude (same-family fallback,
                                        # warns every run; ADR-0018)
```

### Updating

A new release out? Re-add the three components from `latest`. `--force` on the extension
overwrites the install but **preserves your `devflow-config.yml`** (your onboard settings):

```bash
BASE=https://github.com/Jrecos/speckit-devflow/releases/latest/download
specify extension add devflow --from "$BASE/devflow-extension.zip" --force
specify preset add     --from "$BASE/devflow-plan-hardening.zip"   # confirm overwrite (y)
specify workflow add   "$BASE/devflow-workflow.yml"                # confirm overwrite (y)
specify extension list                                             # verify the new version
```

> Updating from **before v0.1.2**? Re-run `/speckit-devflow-onboard` afterward — your
> project's `.mcp.json` was written by the old onboard (deprecated `uvx semgrep-mcp`); the
> new onboard registers the built-in `semgrep mcp -t stdio` server. `specify extension update`
> won't work here — it resolves against a catalog, and DevFlow installs by URL.

Then run a feature **either way** — same protocol, same gates, same scripts underneath:

```bash
# A · from your terminal (the spec-kit engine drives; works headless/CI)
specify workflow run devflow \
  --input feature="describe the feature" \
  --input mode=attended                 # attended | attended-step | autonomous

# B · from inside Claude Code (conversational gates, guarded flow ledger; ADR-0019)
/speckit-devflow-start describe the feature
```

Path B keeps a **phase ledger** (`specs/<feature>/devflow-flow.json`) that a mechanical
guard advances only when each phase's artifacts actually exist on disk — brainstorming and
both STOPs happen in the conversation, while loop iterations still dispatch as fresh
`claude -p` sessions. Any later session resumes with `/speckit-devflow-start`.

Then you make exactly two decisions:

1. **STOP #1** — read the plan, the *failing* acceptance tests, and the leash. Approve or reject.
2. **STOP #2** — read the evidence (tasks, verdicts, findings, deviations, records).
   `accept` / `accept-with-deviation` / `reject`.

**Trying it on your own project?** Start with the hands-on
[`docs/try-on-your-project.md`](docs/try-on-your-project.md) — install, onboard, first
feature, troubleshooting, and a feedback template. Where it's headed + what real runs have
taught us: [`docs/roadmap.md`](docs/roadmap.md). **The complete lifecycle** — machine
setup, constitution, the optional product layer, every phase with its artifacts, mid-run
operations, and the baseline→DevFlow mapping — lives in
[`docs/development-workflow.md`](docs/development-workflow.md).

### Modes ([ADR-0013](docs/decisions/0013-loop-modes-attended-step-autonomous.md))

| Mode | You are… | The loop waits for you? |
|---|---|---|
| `attended` | watching live; un-allowlisted actions abort-as-pause | never (only the 2 STOPs) |
| `attended-step` | stepping through — a blocking gate at **every** iteration boundary | every iteration |
| `autonomous` | gone; pre-approved allowlist via `SPECKIT_INTEGRATION_CLAUDE_EXTRA_ARGS` | only the 2 STOPs |

Same gates, same brakes, same close contract in all three — modes change *your presence*,
never the guarantees. (The word "supervised" is retired; it promised input it never asked for.)

### The judge seam ([ADR-0014](docs/decisions/0014-judge-wiring-role-env-seam.md))

Any command that reads `{"diff","criteria","spec_slice"}` on stdin and prints
`{"verdict":"PASS"|"FAIL","reason":"...","criteria":[...]}` can judge. **Unset?** DevFlow
falls back to Claude as the judge — an independent fresh context, but same-family, so it
warns on every run ([ADR-0018](docs/decisions/0018-judge-fallback-same-family.md)).
Cross-family is one env var away and remains the recommended topology: same-family
self-checking is the documented weak layer
([ADR-0003](docs/decisions/0003-maker-plus-cross-family-judge.md)). A malformed or
unreachable judge still **fails safe** (blocks the iteration).

## A session, end to end

What a real feature looks like — 10 tasks, one afternoon, two decisions:

```console
$ specify workflow run devflow --input feature="rate-limited login with audit log" --input mode=attended

▸ specify      spec.md written (the contract)
▸ brainstorm   superspec pressure-tests edge cases → spec revised
▸ clarify      2 questions answered
▸ plan         plan.md + 10 failing acceptance tests (red — the loop's target)
▸ tasks        tasks.md: 10 tasks, each with AC lines
▸ init/leash   budget = ⌈10 × 2.5⌉ = 25 iterations · 4h box · park after 2 attempts
▸ analyze      spec ↔ plan ↔ tasks consistent

  ┌─ Gate ─────────────────────────────────────
  │ STOP #1 - review the plan, the failing acceptance
  │ tests, and the leash below. ...
  │ [1] approve   [2] reject
  └─────────────────────────────────────────────
  Choose [1-2]: 1                     ← decision #1. You can walk away now.

▸ build-loop   iter 1: T1 ✓ green close (record + auto-commit)
               iter 2: T2 ✓ · iter 3: T3 ✓ ...
               iter 5: T5 judge FAIL "error paths leak state" → verdict to state
               iter 6: T5 retry reads verdict → targeted fix ✓
               iter 9-10: T8 red ×2 (flaky test) → PARKED, loop moves on
               iter 12: T10 ✓ → open tasks: 0 → loop exits
▸ review       findings.md + findings.json: F1 SQL injection (Semgrep, high)
▸ fix-cycle-1  F1 → fix-task → mini-loop (budget 3) → fixed, record links F1
▸ re-review    full gate again → clean (cycle 1/2)
▸ verify       prerequisite ✓ · full suite green · whole-diff judge: PASS
               1 deviation noted: sliding refresh window (spec said fixed)

  ┌─ Gate ─────────────────────────────────────
  │ STOP #2 - the evidence is below. ...        (stop2.md: 9 done · T8 parked ·
  │ [1] accept                                   12+2 iters · review clean ·
  │ [2] accept-with-deviation                    1 deviation · 11 records)
  │ [3] reject
  └─────────────────────────────────────────────
  Choose [1-3]: 2                     ← decision #2

▸ reconcile    spec.md §refresh updated + ADR written (T8 descope documented too)
▸ ship         git.validate ✓ → PR opened, links the whole trail
▸ capture      3 vault-note candidates proposed from 12 decision records
```

Useful moves mid-run:

| You want to… | Do |
|---|---|
| see where the loop is | `claude` → `/speckit-devflow-status` (iteration, budget, clock, parked, verdicts) |
| pause the run | `Ctrl+C` — everything durable is already on disk and committed |
| resume (or answer a gate that paused headless) | `specify workflow resume <run-id>` in a TTY (`specify workflow status` lists runs) |
| step iteration-by-iteration | run with `--input mode=attended-step` — a gate blocks at every boundary |
| inspect the loop's raw state | `specs/<feature>/loop/state.json` · findings: `specs/<feature>/review/findings.json` |
| triage a parked task | nothing until STOP #2 — it arrives there with its full attempt history |

### Bundle authors (this repo)

```bash
specify extension add components/extensions/devflow --dev
specify preset add --dev components/presets/devflow-plan-hardening
specify workflow add components/workflows/devflow/workflow.yml

specify bundle validate --path bundle     # ✓
specify bundle build --path bundle --output dist   # → devflow-0.2.0.zip

bash tests/acceptance/run-all.sh          # 20 automated tests
# + tests/acceptance/MANUAL.md            # 6 live-Claude checks
```

## Five gaps → five structural fixes

The reason this exists ([full retro](docs/retro.md)):

| Gap (from the real run) | Fix baked into the bundle | Enforced by |
|---|---|---|
| **A** — loop over-scoped (build+verify+ship in one budget) | one dispatch = one task = fresh context; Review/Verify/Ship live *outside* the loop | engine |
| **B** — review/security gate skipped | Review is its own phase; Verify **refuses to run** without a clean-or-parked findings artifact | engine |
| **C** — decisions never recorded | the Stop-gate **blocks the session** until the iteration closes GREEN (record + green tests + one task) or RED (failure note) | Claude hook |
| **D** — accepted deviation left the spec stale | accept-with-deviation (or accept with parked work) routes through `reconcile-contract`: spec edit + ADR **before** Ship | engine |
| **E** — hand-cranked, nothing committed | auto-commit on every green close; the engine is the message bus, not you | Claude hook + engine |

## What's in the box

```
bundle/bundle.yml                 the manifest (validate/build against real spec-kit 0.12+)
components/
  extensions/devflow/             9 commands · Stop-gate + PostToolUse hook scripts ·
                                  loop scripts (init/leash/status/convert/check) ·
                                  judge seam · checker subagent · CLAUDE.md protocol · config
  presets/devflow-plan-hardening/ plan/tasks templates: red acceptance tests required,
                                  countable task format with per-task acceptance criteria
  workflows/devflow/              the pipeline: gates, loops (unrolled review cycles ×2),
                                  switch routing, clean-park semantics
tests/acceptance/                 21 automated tests + MANUAL.md (live-Claude checklist)
docs/
  decisions/                      ADRs 0001–0024 — every design decision, including the
                                  three-agent verification pass that corrected the design
  superpowers/specs/              the approved design spec
  research/                       the cited loop-architecture research this is built on
  development-workflow.md · blueprint.md · retro.md · baseline-workflow.md
```

## Evidence-based, verified twice

Every load-bearing choice traces to the [research corpus](docs/research/loop-architecture-research.md)
(SWE-agent, Ralph loops, spec-kit doctrine, Reflexion-style feedback) via
[ADRs](docs/decisions/). Before authoring, a **three-agent verification pass** checked the
design against spec-kit's actual source, Claude Code's hook semantics, and internal
consistency — and corrected it ([ADR-0016](docs/decisions/0016-verification-corrections.md)).
After authoring, an independent cross-validation pass reviewed the implementation against
the spec and found what tests couldn't; all findings fixed.

## Status

- [x] Research → blueprint → 24 ADRs → approved spec
- [x] Components authored (extension · workflow · preset) + final `bundle.yml`
- [x] `specify bundle validate` ✓ · `build` ✓ · **21/21 automated acceptance tests**
- [ ] Live-Claude dogfood run ([`tests/acceptance/MANUAL.md`](tests/acceptance/MANUAL.md))
- [ ] Catalog publication

## License

MIT — see [`bundle/bundle.yml`](bundle/bundle.yml).

