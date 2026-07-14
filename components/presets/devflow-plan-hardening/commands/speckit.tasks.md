---
description: Create tasks.md from plan and spec — in DevFlow's countable, checker-gradable format.
---

## User Input

```text
$ARGUMENTS
```

## Outline

1. Read `.specify/feature.json` to get the feature directory path
   (key: `feature_directory`).

2. **Load context**: `<feature_directory>/spec.md` and `<feature_directory>/plan.md`.

3. Break the plan into ordered, independently-testable tasks and store them in
   `<feature_directory>/tasks.md`.

4. **REQUIRED format (DevFlow hardening) — the harness parses this file:**
   - Every task line must be exactly: `- [ ] T<n> <short name>`
   - Followed by one or more indented acceptance-criteria lines:
     `  - AC: <verifiable criterion>`
   - The DevFlow loop counts `^- [ ]` / `^- [x]` lines to compute budgets and
     verify one-task-per-iteration; the checker subagent grades diffs against the
     AC lines; deviations from this format break the harness.
   - Size each task to fit one focused session (the 40–60% context rule): small,
     isolated, with its own verifiable criteria.
   - Do not append anything after the last task section.

5. Report the task count (the leash computation reads it).
