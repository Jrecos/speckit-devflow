# ADR-0010: record-decision & reconcile-contract — commands + hook + branch, not step types

**Status:** Accepted

**Context:** HANDOFF Q3 assumed the two gap-fixes would be bundle **steps**. Verified against
spec-kit 0.12.11: a bundle step is a Python **step type** (`StepBase` subclass in
`.specify/workflows/steps/<id>/`) extending the *workflow engine's* vocabulary. But
`record-decision` (gap C) must run inside every loop iteration — inside one `claude -p`
dispatch, *below* the engine's visibility — so an engine step type cannot see, let alone
enforce, it. `reconcile-contract` (gap D) fires on deviation acceptance at STOP #2, which
*is* engine-visible. Meanwhile ADR-0009 gives us a stronger enforcement layer inside the
session: Claude Code hooks.

**Decision:** No Python step types in v0.1 (`provides.steps` is empty). The design rule —
**behavior lives in prompts; each guarantee lives at the strongest layer that can hold it**:

| Fix | Behavior (layer 3) | Guarantee (enforcing layer) |
|---|---|---|
| gap C | `speckit.devflow.record-decision` command (ADR-lite template), called in `iterate`'s exit protocol | **Claude `Stop` hook** (layer 2): session exit is denied (exit 2, reason fed back) until the iteration's decision record exists; then auto-commit runs |
| gap D | `speckit.devflow.reconcile-contract` command (spec edit + ADR) | **Workflow branch** (layer 1): STOP #2 gate options `accept / accept-with-deviation / reject`; `accept-with-deviation` routes via `if-then` on `output.choice` through reconcile-contract *before* Ship is reachable |

Loop-engine parameters surfaced by simulating multi-task runs, recorded here as protocol
requirements: a **per-task retry cap** (default 2) distinct from the **global iteration
budget** — a task that exhausts its cap is **parked** (`needs-human`, excluded from picking,
loop continues) and surfaced with evidence at STOP #2. Judge-FAIL verdicts are **written to
loop state** so the retry iteration (fresh context) reads and targets them (Reflexion-style
verbal feedback, persisted to disk).

**Consequences:** Same fixes as HANDOFF envisioned, on strictly stronger layers, with zero
engine plugins to maintain ("stay minimal"). Capture reads a guaranteed-populated
`docs/decisions/`; a stale contract cannot ship because Ship is topologically behind
reconcile. Cost: the Stop-hook gate script is Claude-specific (accepted under ADR-0009) and
`bundle.yml` loses its `steps` entries (the fixes move into the extension + workflow).
