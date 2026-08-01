---
description: "Generate a plan-validation checklist from spec.md + plan.md + tasks.md so the human has a concrete review artifact at STOP #1. DevFlow-internal (ADR-0029). Use in the Plan phase after tasks, before Analyze/STOP #1. Keywords: checklist, plan validation, review artifact, stop1, pre-flight."
---

# DevFlow Checklist — a plan-validation artifact for STOP #1

Turn the plan into a checkable list the human can scan at STOP #1 instead of re-reading three
files. Each item is a yes/no assertion tying the plan back to the spec and the tests, so approval
is an informed decision, not a rubber stamp. DevFlow-internal so the bundle needs no external
checklist extension (ADR-0029).

## Standing rules

- You **read** `spec.md`, `plan.md`, `tasks.md`; you **write** only `checklist.md` in the feature
  directory. No code, no plan edits.
- Every checklist item must be objectively checkable — a human (or a later phase) can mark it
  pass/fail by looking at an artifact, not by opinion.

## Steps

1. **Resolve** the feature dir (`.specify/feature.json` → `feature_directory`); read `spec.md`,
   `plan.md`, `tasks.md`.

2. **Generate `<feature_dir>/checklist.md`** with these sections, each a list of `- [ ]` items:
   - **Spec coverage** — every load-bearing requirement in `spec.md` maps to at least one task in
     `tasks.md`. List any requirement with no task (a gap) and any task with no spec basis (scope creep).
   - **Acceptance tests exist and are red** — the plan's acceptance tests are present and currently
     failing (the loop's target). Flag any acceptance criterion with no failing test.
   - **Task shape** — every task is countable (`- [ ]`/`- [x]`), has an `AC:` line, and is small
     enough to close in one iteration.
   - **Boundaries & edge cases** — the edge cases hardened in brainstorm have a task or an explicit
     acceptance test.
   - **Open questions** — any unresolved spec question is listed so the human sees it before approving.

3. **Summarize** the counts (requirements covered / gaps, tasks, red tests) — this line is what the
   leash/STOP #1 view can surface.

## Done when

`checklist.md` exists in the feature directory with the five sections, each item objectively
checkable, and a one-line summary of coverage/gaps for STOP #1.

## Handoff

None — Analyze consumes the same three files and STOP #1 shows the leash; `checklist.md` is the
human's concrete pre-approval artifact.
