---
description: "Renders a compact, budget-aware view of the DevFlow loop state — iteration, budget, clock, parked tasks, verdicts — plus one mechanically-chosen next action. Use anytime to check where a feature stands, especially before resuming. Keywords: status, progress, where are we, loop state, budget, parked, resume."
---

# DevFlow Status

## Standing rule

Read-only: this command changes nothing. Report only what the files say; if a file
is missing, say which and what creates it — never guess at state.

## Steps

1. Run exactly:
   `bash .specify/extensions/devflow/scripts/bash/devflow-status.sh`
   It reads `.specify/feature.json` → `feature_directory`, then (each only IF it exists)
   `<fdir>/loop/state.json`, `tasks.md`, `devflow-flow.json`, `review/findings.json`,
   `verify-report.md`, and prints the compact state block **plus one mechanically-chosen next
   action** — the 6-branch ladder (budget/clock exhausted → continue → Review → fix cycle →
   Verify → STOP #2) lives IN the script (ADR-0023). It writes nothing.
2. Present that output verbatim. If it prints `no active feature …`, relay that and end.

## Done when

The status block and exactly one recommended action are in your reply. Nothing was
written.

## Handoff

Whatever the recommended action names — the user (or orchestrator) triggers it.
