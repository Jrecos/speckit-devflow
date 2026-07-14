# Manual dogfood checklist — live-Claude checks automation can't cover

Run these in a scratch spec-kit project with the bundle installed and
`/speckit-devflow-onboard` completed. Each item maps to a spec §6 criterion that
needs a real Claude session or a TTY.

## 1. Stop-gate blocks a live session (§6-3 live half)

```bash
# stage an active iteration without a record:
python3 .specify/extensions/devflow/scripts/python/devflow_state.py set specs/<feat>/loop/state.json in_iteration true
claude -p "edit any file, then finish"
```
**Expect:** the transcript shows the gate's block message ("no decision record…"),
Claude reacts to it (writes the record or marks failed), and only then exits.
Also confirm a plain `claude -p "say hi"` in a repo with `in_iteration:false`
exits freely (scoping, §6-5 live).

## 2. Full pipeline dry run (§6-6 live)

```bash
specify workflow run devflow --input feature="add a /health endpoint" --input mode=attended
```
**Expect:** Frame→Plan→Tasks produce artifacts (plan lists red acceptance tests —
preset hardening); STOP #1 shows leash.md and pauses; approve → loop grinds tasks
(one commit per green iteration); Review writes findings artifacts; Verify runs
only after findings are clean/parked; STOP #2 shows stop2.md. Non-TTY runs pause
at gates; `specify workflow resume <run-id>` in a TTY continues.

## 3. Judge seam live (§6-7 live)

```bash
export DEVFLOW_JUDGE_CMD='<a second-family model CLI reading stdin JSON, emitting verdict JSON>'
```
**Expect:** onboard smoke-test passes; iterations write PASS verdicts to state; a
seeded FAIL (make the judge reject once) puts `verdicts.<task>` in state and the
NEXT iteration's transcript shows it targeting the verdict reason (Reflexion path).
Then point `DEVFLOW_JUDGE_CMD` at a Claude-based command and re-run onboard:
**expect the same-family warning.**

## 4. Deviation routing (§6-10 live)

At STOP #2 choose `accept-with-deviation`.
**Expect:** reconcile-contract edits spec.md AND writes an ADR before
`speckit.git.validate` runs; choosing `accept` with a parked task also routes
through reconcile first; `reject` ends the run with no Ship steps executed.

## 5. attended-step behavior

Run with `--input mode=attended-step`.
**Expect:** after each iteration's loop-status, the `step-gate` pauses the run
("iteration boundary reached… Continue?"). In a TTY, choosing `continue` runs
exactly one more iteration. Non-TTY: the run pauses; `specify workflow resume`
re-runs the loop body — iterate picks the NEXT task from disk state, so each
resume advances exactly one iteration (state-idempotency makes the re-run safe).
Choosing `reject` aborts the run.

## 6. --bare guard

Inspect the dispatch invocation during any workflow run (`ps` or verbose output).
**Expect:** `claude -p "/speckit-devflow-iterate ..."` with NO `--bare` flag
(--bare would disable hooks, skills, and CLAUDE.md — the whole layer-2 stack).
Also confirm `SPECKIT_INTEGRATION_CLAUDE_EXTRA_ARGS` doesn't contain it.
