# DevFlow roadmap & dogfood log

Where the bundle is going and what real runs have taught us. Two lists: **candidate
improvements** (ideas earning their priority from evidence, not memory) and the
**dogfood findings log** (concrete issues real runs surfaced, and what was done).

Principle (from the runs themselves): the architecture is proven (14 automated tests, the
three-layer model holds). What sets priority is **runs, not features** — a candidate gets
promoted when a pain repeats across features, not on first sighting. Premature harness-
building is the "orchestration over interface" trap the research warned against.

---

## Candidate improvements (v0.2+, unbuilt — ranked by current gut, re-ranked by evidence)

### 1 · Assumptions harness / verification-strategy declaration
**Gap:** the agent resolves underspecified situations by *assuming* (e.g. "no test
framework → build+visual is an acceptable oracle") and stating it in **chat** — which
breaks the durable-state-on-disk rule and slips a load-bearing choice past both STOPs
without explicit human sign-off.
**Shape:** make **assumptions** the third disk-backed, human-gated artifact alongside
decisions (record-decision) and deviations (reconcile-contract) — logged to
`assumptions.md`, surfaced at STOP #1, human must acknowledge each. Sharpest piece: a
**verification-strategy declaration** at Plan (`unit|integration|build-only|visual|human`)
that STOP #1 makes the human explicitly approve ("build-only oracle — accept?"). Mechanical
part: the phase must emit the artifact (guard checks existence); human part: confirm.
**Status:** #1 candidate; on-thesis; cheap (same pattern as decisions/deviations). Needs
≥2–3 runs of evidence on *how often* agents assume silently before building.

### 2 · Eval harness for the command prompts
**Gap:** every prompt-layer bug so far (`$FLOW` word-splitting, the phantom `--metrics`
flag, loop-status misuse) was found *by hand in a live run*. There's no regression net for
the markdown commands — ADR-0021 prescribed eval-driven maintenance but deferred it.
**Shape:** the Anthropic skill-creator pattern — ≥3 evals per command, fresh-session
with/without baselines, graded assertions, blind A/B between versions, run on every edit.
**Status:** arguably *more* foundational than #1 — it's the mechanism that catches the
whole class of fragility #1-style findings come from, before they reach a user.

### 3 · Visual-verification ladder
**Gap:** the verification stack assumes a mechanical test oracle; UI/visual features may
have none, so "green" degrades to "builds clean".
**Shape (ladder):** detect visual work → prefer an existing visual suite (Playwright/
Storybook/Percy) → screenshot + vision-judge (extends the judge seam; Claude has vision) →
scaffold a render-smoke test → human visual gate at STOP #2.
**Status:** a *special case* of #1 (it's one assumption the agent makes); likely falls out
of the assumptions harness rather than needing its own build. Watch whether it recurs.

---

## Dogfood findings log (real runs → fixes)

First real run: **konexo `003-voltpulse-module-foundation`, feature 004** (a UI catalog +
one constructible landing), driven by `/speckit-devflow-start`, 2026-07-15.

| # | Finding | Layer | Fix | Commit |
|---|---|---|---|---|
| 1 | onboard's semgrep line broke on-machine: phantom `--metrics off` flag; `uvx` Python-3.14 protobuf crash; missing semgrep CLI | prompt | corrected to `-e SEMGREP_SEND_METRICS=off`, `uvx --python 3.12`, `uv tool install semgrep` + `--semgrep-path`; troubleshooting row added | `2b9aa48` |
| 2 | release install reported `v0.1.0` — tag was bumped but manifest `version:` fields weren't | release process | bump component + bundle versions atomically with the tag; verify a clean install reports the new number | `305c7eb` |
| 3 | `start.md`'s `FLOW` shorthand read as a shell var — zsh doesn't word-split it, and the Bash tool's fresh-shell-per-call means a var never survives anyway | prompt | clarified `FLOW` is a doc-shorthand for the literal `bash …/devflow-flow.sh` path, not a variable | `b8014f9` |
| 4 | `loop-status` looks read-only but mutates + spent budget per *call* → a "peek" before the first dispatch burned phantom budget | script + prompt | budget keyed to **iteration advancement** (`last_counted_iteration`), so spurious/early calls can't inflate it; start.md §6 marks loop-status as a once-per-dispatch advance step and points inspection at read-only `/speckit-devflow-status` | *(this change)* |

**Meta-signal:** findings 1, 3, 4 are all *prompt/driver fragilities* — which is the
evidence promoting **candidate #2 (eval harness)** as the highest-leverage v0.2 investment:
it would catch this whole class before a user does. Finding 4 also reinforces the
driver-parity theme (the orchestrator manually reproducing engine behavior is where
fragility clusters).

**Process rule adopted:** a release = bump manifest versions **and** tag **and** re-upload
assets, then verify a clean install reports the new number — atomically, not the tag alone.
Patch releases are cut per fix-batch (not silently), so the `latest/download` install stays
current.
