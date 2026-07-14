# ADR-0007: One DevFlow-owned loop engine with supervision modes

**Status:** Accepted (mode names amended by [ADR-0013](0013-loop-modes-attended-step-autonomous.md): `supervised` → `attended`, plus a new blocking `attended --step`)

**Context:** The baseline workflow required the community `loop` extension and offered
`ralph` as a hands-off alternate engine (ADR-0005). Inspection of both (loop 1.0.0:
define/run/check/guard/status, maker/checker split, externalized state, human-signoff
guard; ralph 1.2.1: run/iterate, agent-CLI grind loop) shows two engines with two state
formats and two completion gates — ralph's own gate would replace our Verify phase and
bend the two-STOP model (ADR-0002). We want supervised *and* hands-off runs, and an engine
we can evolve from our own run experience (retro gaps A/C/E live inside the loop).

**Decision:** DevFlow authors **one loop engine** as its own extension. Autonomy is a
**mode**, not a second engine:

- **`attended`** (named `supervised` when first accepted; renamed by ADR-0013) — checker
  verdict surfaces per iteration; the human watches live and may interrupt between
  iterations, but the loop **never blocks waiting for input**. The careful default
  (absorbs community `loop`'s maker/checker discipline). ADR-0013 adds `--step` for a
  truly blocking per-iteration pause.
- **`autonomous`** — grinds unattended until tasks are exhausted or the budget/time-box
  hits (absorbs the Ralph pattern: fresh-context iterations, plan-file state, mechanical
  backpressure).

Both modes share one protocol invariant set: one task per iteration; externalized on-disk
state; per-edit mechanical checks; `record-decision` + auto-commit on iteration exit; the
maker never self-grades; cross-family judge as the iteration exit gate (ADR-0003); STOPs
and phase gates identical (ADR-0002). The engine is designed against the loop literature
(ReAct thought–action–observation core; Reflexion-style verdict fed to the next iteration;
budget/time-box termination) as distilled in `docs/research/`.

**Consequences:** DevFlow owns its center of gravity and can evolve it (new modes, better
verdict protocols) without waiting on upstream. Supersedes "pin community `loop`" and
retires "`ralph` as alternate engine" (mode swap replaces engine swap; `baseline-workflow.md`
step 8/11 wording to be updated when components are authored). Cost: we maintain an engine;
mitigated by staying minimal — markdown commands + on-disk state, no new runtime.
