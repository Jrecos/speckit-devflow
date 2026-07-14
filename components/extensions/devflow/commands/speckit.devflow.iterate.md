---
description: "Runs exactly ONE DevFlow build-loop iteration: picks one task from tasks.md, implements it, passes scoped tests, checker and judge verdicts, then closes GREEN or RED under the Stop-gate contract. Use when the devflow workflow or orchestrator dispatches an iteration; also to manually advance the loop one task. Keywords: iterate, iteration, build loop, one task, maker."
---

# DevFlow Iterate — one task, one fresh context

## Standing rules (apply to this ENTIRE session)

- You do exactly **ONE** task this session, then end. Never start a second.
- You never run `git commit` — the Stop gate commits on a valid GREEN close.
- You never grade your own work — the checker subagent and the judge do.
- Durable state lives on disk (`loop/state.json`, `tasks.md`, `docs/decisions/`),
  never in this conversation.
- The Stop gate blocks any session end that is not a valid GREEN or RED close.
  If it blocks you, do what its message says — never work around it.

## Progress checklist (copy into your response; check off as you go)

```
- [ ] 1. Primed (feature dir, state, tasks, config read)
- [ ] 2. Iteration opened in state
- [ ] 3. ONE task picked and recorded
- [ ] 4. Implemented
- [ ] 5. Scoped tests green (or RED close taken)
- [ ] 6. Checker verdict PASS (or RED close taken)
- [ ] 7. Judge verdict PASS (or RED close taken)
- [ ] 8. Task checked off + decision record written
- [ ] 9. Session ended (gate closes it)
```

## Steps

1. **Prime** (REQUIRED, same files every iteration):
   read `.specify/feature.json` → key `feature_directory` (call it `<fdir>`);
   read `<fdir>/loop/state.json`, `<fdir>/tasks.md`, `<fdir>/spec.md`,
   `.specify/extensions/devflow/devflow-config.yml`.
   *If `feature.json` or `state.json` is missing:* STOP and report — the workflow's
   init step has not run; do not create them yourself.

2. **Open the iteration** — run exactly these (STATE_PY =
   `.specify/extensions/devflow/scripts/python/devflow_state.py`, STATE =
   `<fdir>/loop/state.json`):
   - `python3 STATE_PY set STATE in_iteration true`
   - `python3 STATE_PY bump STATE iteration`
   - `python3 STATE_PY set STATE iteration_outcome null`
   - `python3 STATE_PY set STATE last_record null`
   - `python3 STATE_PY set STATE tasks_done_at_start <N>` — where `<N>` is the count
     of lines matching `^- [x]` in `<fdir>/tasks.md` (count with python, not grep -c).

3. **Pick exactly ONE task**:
   - Candidates: unchecked `- [ ]` tasks in `tasks.md`, **excluding** anything in
     `state.parked`.
   - If `state.entry == "fix-tasks"`: prefer unchecked `F*` fix-tasks first.
   - If a candidate has an entry in `state.verdicts` or `state.failure_notes`, prefer
     it — and read that verdict/note carefully: your implementation must target
     exactly what it describes.
   - Record it: `python3 STATE_PY set STATE current_task '"<task-id>"'`
   - *If no candidate exists:* RED-close (step 5's else-branch) with the note
     "no pickable task"; the loop-status brake will end the loop.

4. **Implement** the one task. Prefer whole-file writes over fragile partial edits.
   The PostToolUse hook lints/typechecks after every Edit/Write — when it reports
   errors, fix them immediately before continuing. Notice other problems? Note them
   in the decision record later; do NOT fix them now.

5. **Scoped tests** — run the `commands.test_scoped` command from devflow-config.yml.
   - **Green** → step 6.
   - **Red after honest effort within this session** → take the **RED close**:
     `python3 STATE_PY set STATE iteration_outcome '"failed"'` and
     `python3 STATE_PY set STATE failure_notes.<task-id> '"<one paragraph: what
     failed, your hypothesis, the next approach>"'`.
     Do NOT check the task off. Go to step 9 — the gate allows a RED close; the loop
     retries with your note or parks the task at the attempts cap.

6. **Checker** — ask **@devflow-checker** to grade the diff against this task's `AC:`
   line(s) from tasks.md. Provide: task id, the AC text, `git diff` output.
   - `CHECKER: PASS` → step 7.
   - `CHECKER: FAIL` → treat as red tests (step 5's RED close), quoting the checker's
     reason in the failure note.

7. **Judge** — the iteration exit gate:
   1. Write three temp files: the diff (`git diff`), the criteria (the task's AC
      lines), the spec slice (sections of `<fdir>/spec.md` this task touches).
   2. Run exactly:
      `bash .specify/extensions/devflow/scripts/bash/devflow-judge.sh <diff> <criteria> <slice>`
      Do not modify the command. (No `DEVFLOW_JUDGE_CMD` in the env → it falls back
      to Claude and warns; that is expected, not an error.)
   3. **Non-zero exit or verdict FAIL** →
      `python3 STATE_PY set STATE verdicts.<task-id> '{"verdict":"FAIL","reason":"<reason>"}'`
      then the RED close (step 5) with the judge's reason as the failure note.
   4. **PASS** → advisory; continue.

8. **Close GREEN**:
   1. Mark exactly one task done in tasks.md: `- [ ] <task>` → `- [x] <task>`.
   2. Run `/speckit-devflow-record-decision` — it writes the ADR-lite record and sets
      `state.last_record`. Fix-task iterations: the record MUST name the finding it
      resolves.
   3. Verify `last_record` in state points at an existing file — if not, the gate
      will block you; write the record before ending.

9. **End the session.** Just finish your final message. The Stop gate verifies the
   close and auto-commits on GREEN.

## Done when

One of exactly two states holds in `loop/state.json` (the gate enforces this):
- **GREEN:** `last_record` names an existing file ∧ scoped tests green ∧ exactly one
  more `- [x]` in tasks.md than `tasks_done_at_start` → the gate commits and releases.
- **RED:** `iteration_outcome == "failed"` ∧ `failure_notes.<task>` is written →
  the gate releases without commit.
Anything else = the gate blocks with a reason; do what it says.

## Handoff

None from you — the workflow engine (or the /speckit-devflow-start orchestrator)
reads `loop/state.json` via `devflow-loop-status.sh` and decides whether another
iteration dispatches. Your session ends here.
