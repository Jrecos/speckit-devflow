---
description: "Renders a compact, budget-aware view of the DevFlow loop state — iteration, budget, clock, parked tasks, verdicts — plus one mechanically-chosen next action. Use anytime to check where a feature stands, especially before resuming. Keywords: status, progress, where are we, loop state, budget, parked, resume."
---

# DevFlow Status

## Standing rule

Read-only: this command changes nothing. Report only what the files say; if a file
is missing, say which and what creates it — never guess at state.

## Steps

1. Read `.specify/feature.json` → `feature_directory` (`<fdir>`).
   *Missing?* Report "no active feature — start one with /speckit-devflow-start or
   /speckit-specify" and end.
2. Read (IF EXISTS, note which are absent): `<fdir>/loop/state.json`,
   `<fdir>/tasks.md`, `<fdir>/devflow-flow.json`, `<fdir>/review/findings.json`,
   `<fdir>/verify-report.md`.
3. Render exactly this shape (fill from the files; `?` for absent data):

```
DevFlow · <feature> · mode=<mode> · entry=<entry> (cycle <cycle>)
iteration <n> · budget <used>/<total> · clock <elapsed>h/<box>h
tasks: <done> done · <open> open · parked: <list or none>
last outcome: <green|failed|null> · verdicts: <task: FAIL reason, ...>
review: <clean|findings|parked|not run> · verify: <verdict|not run>
ledger: <FLOW next output, if devflow-flow.json exists>
```

4. **One next action**, chosen mechanically in this priority order (first match wins):
   1. budget or clock exhausted → "STOP #2 triage (park report)"
   2. open unparked tasks ∧ budget ∧ clock left → "continue the loop (dispatch next
      iterate / resume the workflow)"
   3. all tasks done ∧ no findings.json → "run Review"
   4. findings.json status `findings` → "convert + fix cycle"
   5. review clean/parked ∧ no verify-report.md → "run Verify"
   6. verify-report.md exists → "STOP #2 decision"

## Done when

The status block and exactly one recommended action are in your reply. Nothing was
written.

## Handoff

Whatever the recommended action names — the user (or orchestrator) triggers it.
