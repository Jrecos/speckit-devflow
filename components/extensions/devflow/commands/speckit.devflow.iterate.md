---
description: "Run exactly one build-loop iteration: pick one task, implement, test, checker + judge verdicts, close GREEN or RED under the Stop-gate contract"
---

# DevFlow Iterate — one task, one fresh context

You are one iteration of the DevFlow build loop. You do exactly ONE task, then end
the session. The Stop gate enforces your close — you cannot end otherwise.

## 1. Prime (deterministic — same files every iteration)

1. Read `.specify/feature.json` → `feature_directory` (call it `<fdir>` below).
2. Read `<fdir>/loop/state.json`, `<fdir>/tasks.md`, `<fdir>/spec.md`, and
   `.specify/extensions/devflow/devflow-config.yml`.
3. The DevFlow protocol block in CLAUDE.md applies to this whole session.

## 2. Open the iteration (state first)

Using `python3 .specify/extensions/devflow/scripts/python/devflow_state.py`:

- `set <state> in_iteration true`
- `bump <state> iteration`
- `set <state> iteration_outcome null`
- `set <state> last_record null`
- `set <state> tasks_done_at_start <N>` where `<N>` = current count of lines
  matching `^- [x]` in `<fdir>/tasks.md`.

## 3. Pick exactly ONE task

- Candidates: unchecked `- [ ]` tasks in `<fdir>/tasks.md`, excluding anything in
  `state.parked`.
- If `state.entry == "fix-tasks"`, prefer unchecked `F*` fix-tasks first.
- If a candidate has an entry in `state.verdicts` or `state.failure_notes`, prefer
  it and read that verdict/note carefully — your implementation must target exactly
  what it describes.
- Write your choice: `set <state> current_task '"<task-id>"'`.

## 4. Implement

- Prefer whole-file writes over fragile partial edits.
- After every Edit/Write the PostToolUse hook runs lint + typecheck automatically;
  if it reports errors, fix them immediately before proceeding.
- Stay on the ONE task. If you notice other problems, note them in the decision
  record later — do not fix them now.

## 5. Test

Run the scoped test command from `devflow-config.yml` (`commands.test_scoped`).

**If red after honest effort within this session (RED close):**
- `set <state> iteration_outcome '"failed"'`
- `set <state> failure_notes.<task-id> '"<one paragraph: what failed, your hypothesis, the next approach to try>"'`
- Do NOT check the task off. Do NOT commit. End the session (step 9). The loop
  retries with your note, or parks the task at the attempts cap.

## 6. Checker (you never grade your own work)

Ask **@devflow-checker** to grade the diff against this task's `AC:` line(s) from
tasks.md. Give it: the task id, the AC text, and `git diff` output.
If the checker returns FAIL → treat exactly like a red test (step 5), quoting the
checker's reason in the failure note.

## 7. Judge (the iteration exit gate)

1. Write three temp files: the diff (`git diff`), the criteria (the task's AC
   lines), and the spec slice (the sections of `<fdir>/spec.md` this task touches).
2. Run: `bash .specify/extensions/devflow/scripts/bash/devflow-judge.sh <diff> <criteria> <slice>`
3. If the script exits non-zero OR the verdict is FAIL:
   - `set <state> verdicts.<task-id> '{"verdict":"FAIL","reason":"<the reason>"}'`
   - Then the RED close path (step 5) with the judge's reason as the failure note.
4. If PASS: continue (the verdict is advisory; tests remain the primary oracle).

## 8. Close GREEN

1. Mark the task done in tasks.md: `- [ ] <task>` → `- [x] <task>` (exactly one).
2. Run `/speckit-devflow-record-decision` — it writes the ADR-lite record and sets
   `state.last_record`. In fix-task iterations the record must name the finding it
   resolves.
3. Confirm `last_record` in state points at an existing file.

## 9. End the session

Simply finish. The Stop gate verifies your close (record + green tests + exactly
one task, or failed + note), auto-commits on GREEN, and releases the session.
**Never run `git commit` yourself. Never bypass or edit the gate.**
