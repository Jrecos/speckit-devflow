---
description: "Write an ADR-lite decision record for the current iteration (links its finding when resolving one)"
---

# DevFlow Record Decision

Write the durable decision record for the current iteration — while the context
that made the decision is still alive. Capture reads these files, never the chat.

## Steps

1. Read `.specify/feature.json` → `feature_directory`; read its `loop/state.json`.
2. Determine the next ADR number: highest `NNNN` prefix in `docs/decisions/*.md`
   plus one, zero-padded to 4 digits.
3. Write `docs/decisions/<NNNN>-<kebab-slug>.md`:

```markdown
# <NNNN>: <short title of the decision>

**Status:** Accepted
**Iteration:** <state.iteration> · **Task:** <state.current_task>

**Context:** <what problem this iteration faced — one or two sentences>

**Decision:** <what was chosen and done>

**Alternatives considered:** <what else was viable and why it lost — one line each>
```

4. **If `state.entry == "fix-tasks"`:** add a line `**Resolves finding:** <finding-id>`
   — the finding → fix → record chain must be traceable (ADR-0012).
5. Record durable decisions only: library/pattern/tradeoff choices, schema shapes,
   deviations noticed. Do not record mechanical facts git already captures.
6. Update state:
   `python3 .specify/extensions/devflow/scripts/python/devflow_state.py set <state> last_record '"docs/decisions/<file>"'`
