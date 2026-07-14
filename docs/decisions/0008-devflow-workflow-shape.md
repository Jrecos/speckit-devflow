# ADR-0008: The devflow workflow — engine-owned outer pipeline, dispatched inner loop

**Status:** Accepted

**Context:** HANDOFF Q2: how does one spec-kit workflow encode the phased pipeline, the two
human STOPs, and the inner/outer split (ADR-0002/0004)? Verified against the spec-kit
0.12.11 workflow engine: workflows are YAML step lists over a fixed step registry
(`command`, `gate`, `shell`, `do-while`/`while`, `if-then`, `switch`, `fan-out`/`fan-in`);
workflows cannot invoke other workflows; `gate` steps prompt a human interactively and
**pause** the run when unattended (resumable via `specify workflow resume`); `command`
steps dispatch a slash-command to the integration CLI non-interactively (`claude -p ...`),
streaming output — step stdout is *not* captured for downstream conditions.

Candidates: (A) the loop lives in the workflow YAML as a `do-while` around a one-iteration
command; (B) the loop lives inside one long-running command session; (C) no workflow
engine, commands + hooks only.

**Decision:** **Option A.** One `devflow` workflow owns the outer pipeline:

- Phases are `command` steps (Frame → Plan → Analyze → … → Ship → Capture), each a fresh
  agent session consuming the prior phase's on-disk artifact (ADR-0004).
- The two human STOPs are `gate` steps — STOP #1 after Analyze, STOP #2 after Verify.
  `gate`'s pause/resume gives unattended runs clean STOP semantics.
- The inner Build loop is a `do-while` step whose body dispatches
  `speckit.devflow.iterate` — **one task per dispatch = one fresh context per iteration**
  (the Ralph discipline, and the 40–60% context rule by construction).
- Because stdout is not capturable, **all inter-step signals live on disk** (loop state
  files; the do-while condition reads them via a `shell` step with `output_format: json`).
  Durable-state-on-disk was already blueprint doctrine; the engine makes it mandatory.

**Consequences:** Phase sequencing, both STOPs, and the Review-before-Verify prerequisite
are enforced by the workflow engine — the agent inside an iteration never controls the
outer sequence, so it structurally cannot skip or conflate gates (fixes A and B by
construction, not by prompt). Rejected: (B) one long session violates the context finding
and regresses gate enforcement to prompt discipline; (C) leaves the human as the message
bus (gap E). Cost: many CLI dispatches (one per iteration) — accepted; fresh context per
iteration is a feature, not overhead.
