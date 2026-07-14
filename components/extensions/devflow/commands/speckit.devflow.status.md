---
description: "Render a compact, budget-aware view of loop state with one recommended next action"
---

# DevFlow Status

Render the loop's state for a human glance — compact, no prose padding.

## Steps

1. Read `.specify/feature.json` → `feature_directory`; read its `loop/state.json`
   and `tasks.md`; read `review/findings.json` and `verify-report.md` if present.
2. Render:

```
DevFlow · <feature> · mode=<mode> · entry=<entry> (cycle <cycle>)
iteration <n> · budget <used>/<total> · clock <elapsed>h/<box>h
tasks: <done> done · <open> open · parked: <list or none>
last outcome: <green|failed|null> · verdicts: <task: FAIL reason, ...>
review: <clean|findings|parked|not run> · verify: <verdict|not run>
```

3. One recommended next action, chosen mechanically:
   - open unparked tasks + budget/clock left → "continue: run the workflow / next iterate"
   - all done, no review → "run Review"
   - findings present → "convert + fix cycle"
   - review clean, no verify → "run Verify"
   - verify done → "STOP #2 decision"
   - budget/clock exhausted → "STOP #2 triage (park report)"
