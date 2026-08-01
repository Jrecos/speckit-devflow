# ADR-0026: Model escalation — tier derived from the attempts counter

**Status:** Accepted (extends [ADR-0025](0025-local-maker-seam.md); constrained by the parking cap of
[ADR-0011](0011-loop-termination-and-iteration-protocol.md); honors [ADR-0010](0010-fix-enforcement-layers.md))

**Context:** A local maker will fail some tasks. We want it to try harder — the same model
self-correcting a few times (reading its prior failure note), then handing off to progressively
stronger models, and finally to Claude as an escape hatch — *before* the task is parked. The naive
design keeps a separate per-task escalation counter that the iterate prompt bumps. That counter lives
in prose (layer 3) and desynchronizes from the parking cap the instant any dispatch dies without
running it (a dead `claude -p`, a hung session, the loop-status backstop): the task then reaches the
park cap with its tier still at the cheapest model, and the stronger tiers — including Claude — never
run. An independent cross-family review flagged this as a correctness hole that silently breaks the
headline guarantee ("Claude acts before the park").

**Decision:** The maker tier for a task is a **pure function of `state.attempts[<task>]`** — the
single retry counter the Stop-gate already bumps on every RED close (layer 2). There is **no parallel
counter**.

- Ladder (config `maker.escalation.order`, default `local → assistant → agentic → claude`):
  - `attempts 0,1,2` → tier 0 (the local model self-corrects three times, each retry reading the
    prior `failure_note`),
  - `attempts 3` → tier 1, `attempts 4` → tier 2, `attempts ≥5` → tier 3.
- The last tier is conventionally `claude`: the caller then does **not** invoke the maker (the
  iterate Step-4 exit-3 path — Claude types the code), the strongest available maker.
- `max_attempts_per_task` is raised **2 → 6** so the last tier engages at attempt 5, strictly before
  the park at attempt 6. The old design's "4" was a latent contradiction: it parked before Claude.
- `devflow-escalate.sh tier <task>` is a pure read of state + config; `devflow-init.sh` needs **no new
  keys** (attempts already exists), and there is no `note`/`reset` bookkeeping to forget.

**Consequences:**
- **Impossible to desynchronize.** Any path that bumps `attempts` (Stop-gate RED, loop-status
  backstop for a dead dispatch) advances the tier for free. "Claude before the park" is now a
  mechanical property of a single counter, not a prompt instruction — exactly the layer-2 placement
  ADR-0010 demands.
- **Budget interaction is explicit.** A hard task can now consume up to 6 dispatches; the leash
  `⌈open_tasks × 2.5⌉` is a deliberate global cap, so under budget pressure some tasks still park with
  fewer than 6 attempts (clean park, ADR-0011). The escalation is "try harder when budget allows,"
  not a guarantee every task reaches Claude.
- **No local maker, no change.** With `DEVFLOW_MAKER_CMD` unset, every tier resolves to "Claude types
  it," so the ladder is inert and the cap of 6 behaves like an ordinary retry limit.
- The order and the number of self-correction attempts are config-driven, so a different environment
  can choose a different ladder without touching the scripts.
