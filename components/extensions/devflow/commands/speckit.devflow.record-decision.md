---
description: "Writes the ADR-lite decision record for the current DevFlow iteration into docs/decisions/ and points loop state at it; links the finding it resolves in fix-task iterations. Use at every GREEN close inside iterate — the Stop gate blocks the close without it. Keywords: record decision, ADR, decision record, iteration exit, document choice."
---

# DevFlow Record Decision

## Standing rule

Record decisions **while the context that made them is alive** — Capture reads these
files, never the chat. Durable choices only: libraries, patterns, tradeoffs, schema
shapes, noticed deviations. Not mechanical facts git already captures.

## Steps

1. Read `.specify/feature.json` → `feature_directory`; read its `loop/state.json`
   (REQUIRED — if `current_task` is null you are not inside an iteration: STOP and
   report instead of writing an orphan record).
2. Next ADR number: highest `NNNN` prefix in `docs/decisions/*.md`, plus one,
   zero-padded to 4 digits.
3. Write `docs/decisions/<NNNN>-<kebab-slug>.md`:

```markdown
# <NNNN>: <short title of the decision>

**Status:** Accepted
**Iteration:** <state.iteration> · **Task:** <state.current_task>

**Context:** <the problem this iteration faced — one or two sentences>

**Decision:** <what was chosen and done>

**Alternatives considered:** <each viable alternative and why it lost — one line each>
```

4. **IF `state.entry == "fix-tasks"`** (REQUIRED in that case): add the line
   `**Resolves finding:** <finding-id>` — the finding → fix → record chain must be
   traceable (ADR-0012).
5. Point state at the record — run exactly:
   `python3 .specify/extensions/devflow/scripts/python/devflow_state.py set <state> last_record '"docs/decisions/<file>"'`

## Done when

The file exists on disk AND `last_record` in `loop/state.json` names that exact
path. Verify: `python3 -c "import json,os,sys;s=json.load(open('<state>'));p=s['last_record'];assert p and os.path.exists(p);print('record OK:',p)"`
— the Stop gate performs the same check and blocks the close if it fails.

## Handoff

Return to the iterate flow (step 9: end the session; the gate commits).
