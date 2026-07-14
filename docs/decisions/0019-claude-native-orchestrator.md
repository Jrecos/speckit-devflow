# ADR-0019: /speckit-devflow-start — a Claude-native pipeline driver with a guarded flow file

**Status:** Accepted (complements [ADR-0008](0008-devflow-workflow-shape.md); does not replace it)

**Context:** The engine path (`specify workflow run devflow`) drives the pipeline from
outside the agent — correct, but it is not how people actually live in Claude Code: they
sit *inside* a session. The interactive phases (brainstorm, clarify, the two STOPs) are
also plainly better as conversation than as terminal gates. The operator asked for a
single Claude command that executes the complete process with per-phase tracking.

The design constraint is ADR-0010's law: **prompts cannot hold guarantees.** A pure
"Claude, please follow the phases" command would recreate gap B (the agent conflating or
skipping gates). Whatever orchestrates from inside a session needs its control flow
anchored to mechanical checks.

**Decision:** Add a Claude-only orchestrator, `speckit.devflow.start`, built on three parts:

1. **A control-flow file** — `specs/<feature>/devflow-flow.json`: the phase ledger
   (`frame → plan → leash → analyze → stop1 → build → review → fix-cycle-1/2 → verify →
   stop2 → reconcile → ship → capture`), each phase with status
   (`pending | active | done | skipped`), timestamps, and recorded human decisions.
   Durable on disk, committed on the feature branch (ADR-0017) — any later session
   resumes exactly where the last one stopped.

2. **A mechanical phase guard** — `devflow-flow.sh init|start|complete|status|next`.
   `complete <phase>` **verifies the phase's exit artifacts before flipping status**:
   frame needs `spec.md`; plan needs `plan.md` + `tasks.md` with `AC:` lines; leash needs
   `state.json` + `leash.md`; build needs `state.continue == false`; review needs
   `findings.json`; verify runs `devflow-check-review.sh` AND needs `verify-report.md`;
   the STOPs require an explicit `--decision <choice>` argument the command may only pass
   after the human literally chose; phases complete strictly in order. The guard is layer
   2 (a script Claude runs but cannot argue with), so the flow file cannot lie about
   progress the disk does not show.

3. **Hybrid dispatch, preserving the loop's discipline:** interactive phases (Frame's
   specify/brainstorm/clarify, plan review, both STOPs, Capture curation) run
   **in-session** — that is the point of the driver. The build loop does **not** run
   in-session: each iteration is dispatched as `claude -p "/speckit-devflow-iterate"`
   via Bash — one fresh context per task, hooks and Stop-gate armed in the child session,
   brakes evaluated by `devflow-loop-status.sh` between dispatches, exactly as the engine
   does it (ADR-0008 unchanged, just a different do-while owner). The orchestrator session
   stays a thin scheduler (the research's "main context as scheduler" pattern).

STOPs become conversational: the driver renders `leash.md` / `stop2.md` in-chat and asks
for the decision; the human's literal choice is recorded into the flow file via the guard.
The engine workflow remains the path for other integrations and headless/CI use — this
driver is Claude-only by design (ADR-0009 scope).

**Consequences:** One command from inside Claude runs the whole lifecycle with resumable,
disk-backed progress; UX for interactive phases improves substantially. Risks and their
mitigations: orchestrator-session context growth (mitigated: iterations are dispatched,
not inlined; the driver holds only phase state), gate-skipping by prompt drift (mitigated:
the guard refuses out-of-order or artifact-less transitions; Verify's prerequisite check
is inside the guard), duplicated topology with the workflow YAML (accepted: two thin
expressions of one protocol whose enforcement lives in shared scripts — the scripts are
the single source of truth). Supersedes nothing; `specify workflow run devflow` and
`/speckit-devflow-start` are peers.
