# DevFlow bundle — design spec

**Date:** 2026-07-13 · **Status:** approved design, verification-corrected, pre-implementation
**Decisions:** ADRs 0006–0016 (`docs/decisions/`) — this spec assembles them; the ADRs are
the record of *why*. ADR-0016 records the corrections from the three-agent verification
pass (spec-kit source · Claude mechanics · design consistency) applied throughout this spec.
Visual explorations: `.superpowers/brainstorm/` (screens 1–6, local only).

## 1. What DevFlow is

A **Spec Kit bundle** (`devflow`) that provisions an autonomous, spec-driven development
workflow in one install: a phased outer pipeline with exactly two human STOPs, an inner
build loop (one task per fresh-context iteration), layered verification (mechanical → tests
→ checker → cross-family judge → human), a documented review loopback, and a knowledge
track that ends with guaranteed-populated decision records. Targets **Claude Code only**
in v0.x (ADR-0009). Public repo: topology by role, never by host (ADR-0014).

Baked-in fixes for the five gaps from the first real run (`docs/retro.md`):

| Gap | Fix | Enforcing layer |
|---|---|---|
| A · loop over-scoped | one `command` dispatch = one task = fresh context; Review/Verify/Ship outside the do-while | workflow engine |
| B · review skipped | Review is its own phase; Verify's shell step requires `review/findings.md` clean-or-parked | workflow engine |
| C · decisions unrecorded | Stop-hook blocks end-of-turn until the iteration closes GREEN (record + green tests + one task) or RED (failure note); engine backstop for the hook's block cap | Claude harness + engine |
| D · contract went stale | STOP #2 `accept-with-deviation` routes through `reconcile-contract` before Ship is reachable | workflow engine |
| E · hand-cranked | auto-commit in the Stop-gate; engine drives all dispatch; maker/judge role seam | Claude harness + env |

**Design rule (ADR-0010):** behavior lives in prompts (layer 3); every guarantee lives at
the strongest layer that can hold it — workflow engine (layer 1) or Claude hooks/subagents
(layer 2). Prompts never carry guarantees.

## 2. The consumer experience

```bash
# once per project
specify bundle install devflow
/speckit-devflow-onboard        # validates git/claude/semgrep MCP (adds it), judge role
                                # (smoke-test + same-family warning), installs hooks pack,
                                # CLAUDE.md protocol, checker subagent def

# per feature
specify workflow run devflow --input mode=attended
# mode is an enum input: attended | attended-step | autonomous
# (attended-step is the "--step" behavior: blocking pause at each iteration boundary)
```

Two human decisions per feature:

- **STOP #1** (after Analyze): approve plan + failing acceptance tests + the computed
  leash (budget ⌈tasks × 2.5⌉ · time-box 4h · retry cap 2). Reject → re-plan.
- **STOP #2** (after Verify): `accept` → Ship · `accept-with-deviation` → reconcile-contract
  (spec edit + ADR) then Ship · `reject` → back. Ship is topologically unreachable except
  through this gate. Parked tasks/findings are triaged here with full history.

**Modes (ADR-0013, corrected by ADR-0016)** change human presence and permission posture
only — never gates or protocol. All dispatch is headless (`claude -p`), which has **no
interactive permission prompts**:

- `attended` — live streamed output in the operator's terminal; **base allowlist +
  `--permission-mode acceptEdits`**; an un-allowlisted action aborts the iteration, which
  is recorded as a failed iteration (abort-as-pause) — the human allowlists and resumes.
  Watch-only pulse between iterations; the loop never waits for approval.
- `attended-step` — same, plus a blocking pause at each iteration boundary (trailing gate
  in the loop body; resume permits exactly the next iteration — iterate is
  state-idempotent because a resumed gate re-runs the loop body).
- `autonomous` — pre-approved tool allowlist via `SPECKIT_INTEGRATION_CLAUDE_EXTRA_ARGS`
  (set by the operator, documented by onboard); no pulse stop.

True mid-iteration prompting (`--permission-prompt-tool` MCP adjudicator) is a documented
v0.2 path. The word "supervised" is retired (ADR-0013).

## 3. Manifest (ADR-0015 — verified against spec-kit 0.12.11)

```yaml
schema_version: "1.0"
bundle:
  id: devflow
  name: DevFlow
  version: 0.1.0
  role: developer
  description: >-
    Autonomous, spec-driven development workflow — two human STOPs, an inner build loop,
    layered verification (mechanical → tests → judge → human), documented review loopback,
    and a knowledge track. Claude Code first.
  author: Jrecos
  license: MIT
integration: { id: claude }          # refuses install on non-Claude projects (ADR-0009)
requires:
  speckit_version: ">=0.12.0"
  tools: [git, claude]
  mcp: [semgrep]                     # names-only; onboard runs the actual `claude mcp add`
provides:
  extensions:
    - { id: git,       version: "1.0.0" }   # prerequisite — called at seams (ADR-0006)
    - { id: superspec, version: "1.0.1" }   # prerequisite — called at seams (ADR-0006)
    - { id: devflow,   version: "0.1.0" }   # ours (ADR-0007)
  presets:
    - { id: devflow-plan-hardening, version: "0.1.0", priority: 10, strategy: append }
  steps: []                                  # none — ADR-0010
  workflows:
    - { id: devflow, version: "0.1.0" }
tags: [development, autonomous, spec-driven, verification, knowledge-base]
```

Not pinned: `aide` (optional, upstream of Frame), `ralph` (superseded by autonomous mode).

## 4. Components to author

### 4.1 `devflow` extension (ours — the core)

**Commands** (markdown; rendered as `/speckit-devflow-*` skills on Claude):

- **`onboard`** — validate/install every prerequisite at project scope: tools, semgrep MCP,
  judge role resolution (smoke-test one verdict; warn if judge family == maker family),
  hooks pack into `.claude/settings.json`, checker subagent def into `.claude/agents/`,
  loop-protocol invariants into `CLAUDE.md`, `devflow-config.yml` scaffold.
- **`iterate`** — one iteration: prime deterministically (CLAUDE.md protocol + tasks.md +
  loop/state.json) → set `in_iteration: true` in state → pick ONE task (skip parked; read
  judge verdicts; fix-tasks first in re-entry mode) → implement (whole-file edits for
  weak-maker compatibility) → scoped tests → checker via **`@devflow-checker`** mention
  (guaranteed delegation) grades vs the task's acceptance criteria in tasks.md → judge
  verdict via `DEVFLOW_JUDGE_CMD` (spec-slice assembled from the spec sections the task
  references) → close (Stop-gate enforces; `in_iteration` cleared).

  **Close contract (ADR-0016):** an iteration closes exactly one of two ways —
  - **GREEN:** decision record exists + scoped tests green + exactly one task changed
    state → auto-commit → exit allowed.
  - **RED:** `iteration_outcome: failed` + failure note in state (the failure note *is*
    the record for red) → no commit → exit allowed; `attempts[task]++`.
  The Stop-gate blocks any other exit. It is bounded by Claude's consecutive-block cap,
  so the workflow's loop-status step treats a dispatch that ended without a valid close
  as a failed iteration (engine backstop).
- **`record-decision`** — ADR-lite record (what/why/alternatives) to `docs/decisions/`;
  in fix-task iterations must link the finding it resolves.
- **`reconcile-contract`** — accepted deviation → edit spec contract text + write ADR.
  Invoked by the workflow's deviation branch, before Ship.
- **`status`** — compact render of loop state (iteration, budget, clock, parked, verdicts).

**Assets** — shipped as plain files inside the extension dir
(`.specify/extensions/devflow/assets/`); the spec-kit installer never touches `.claude/`,
so **`onboard` merges them** into place. (The extension.yml `hooks:` key means spec-kit
lifecycle hooks and is *not* used for these.)

- **Hooks pack** (merged into `.claude/settings.json`):
  - `PostToolUse`, matcher `Edit|Write` → lint + typecheck (from `commands:` config);
    failure output returns to the agent.
  - `Stop` (**no matcher** — unsupported on Stop) → iteration gate script:
    **no-op unless `loop/state.json` has `in_iteration: true`** (non-loop sessions exit
    freely); otherwise enforce the GREEN/RED close contract; on GREEN,
    `cd "$CLAUDE_PROJECT_DIR"` and commit non-interactively + idempotently. The script
    re-checks the real condition every fire (never early-exits on `stop_hook_active`).
- **Checker subagent def** → `.claude/agents/devflow-checker.md` (onboard creates the
  dir); fresh-context grader; never the session that made the change.
- **CLAUDE.md protocol block** — loop invariants reloaded deterministically each iteration.
  Onboard asserts the integration dispatch does not use `--bare` (which would disable
  hooks, skills, and CLAUDE.md).
- **`devflow-config.yml`** defaults:

```yaml
loop:
  iteration_factor: 2.5      # budget = ceil(open_tasks × factor); shown at STOP #1
  max_attempts_per_task: 2   # attempts before parking (renamed from retry_cap, ADR-0016)
  time_box: 4h
review:
  cycles: 2                  # documented unroll depth of the workflow (ADR-0016)
commands:                    # detected/confirmed by onboard — hooks are inert without them
  lint: ""
  typecheck: ""
  test_scoped: ""
  test_full: ""
judge:
  role: cross-family-judge   # resolved by DEVFLOW_JUDGE_CMD in user env (ADR-0014)
  required: true
  votes: 1
checker:
  role: independent-checker
  independent: true
```

**Verdict contract** (judge stdin/stdout; schema-validated, malformed = FAIL = block):
in `{diff, criteria, spec-slice}` → out `{"verdict": "PASS"|"FAIL", "reason": str,
"criteria": [{name, pass, note}]}`. Verdicts persist to loop state (iterations) or
`verify-report.md` (Verify). One seam, both call sites.

### 4.2 `devflow` workflow (ours — the outer pipeline)

Engine-owned topology (ADR-0008, 0012, corrected by 0016); all inter-step signals via
files (stdout is not capturable for conditions — verified). Workflows are step lists with
**no backward edges**, so the review loopback is **statically unrolled** (cycles = 2):

```
init (shell) → writes .specify/devflow-current.json {feature_dir}
             → writes loop/state.json initial schema (see below)
→ Frame: specify(command) → superspec.brainstorm(command) → clarify(command)   # 3 steps
→ Plan(command) → Tasks(command)      # preset-hardened: red acceptance tests +
                                      # per-task acceptance criteria + task-count line
→ compute-leash (shell): count tasks → budget = ceil(n × iteration_factor)
                       → write to state + leash-summary.md
→ Analyze(command)
→ STOP #1 (gate: show_file leash-summary.md; options [approve, reject] — reject LAST;
           on_reject: abort → human re-plans, re-runs workflow)
→ build-loop (do-while, max_iterations: 50 ← static literal; real brakes in condition):
    iterate(command, continue_on_error: true)     # red iteration ≠ workflow failure
    [attended-step only: pause-gate — trailing; resume permits next iteration]
    loop-status(shell, output_format: json)       # reads state.json; also backstops
                                                  # dispatches that ended w/o valid close
    condition: {{ steps.loop-status.output.data.continue }}
               # = open unparked tasks ∧ budget ∧ time-box, computed by the script
→ Review(command) → findings.md (human) + findings.json (machine) FIRST
→ findings-1? (switch on findings.json status):
    findings → convert-fix-tasks(shell: append fix-tasks, write entry=fix-tasks, cycle=1)
             → fix-loop-1 (same do-while template)
             → re-Review(command, full gate)
             → findings-2? (switch):
                 findings → convert(cycle=2) → fix-loop-2 → re-Review
                          → still findings → park with history (shell)
→ Verify: prereq(shell: findings.json exists ∧ status ∈ {clean, parked} — else FAIL)
        → verify(command: full suite + judge over whole diff → verify-report.md)
          # Verify-level judge FAIL → parks to STOP #2, reject recommended (ADR-0016)
→ STOP #2 (gate: options [accept, accept-with-deviation, reject] — reject LAST)
→ route (switch on {{ steps.stop2.output.choice }}):    # switch, not if-then (ADR-0016)
    accept                → [if any parked task/finding: reconcile-contract first] → Ship
    accept-with-deviation → reconcile-contract(command) → Ship
    reject                → end (Ship unreachable)
→ Ship (command: git.validate → git.commit / PR; PR links the full trail)
→ Capture (command: scan docs/decisions/ → propose vault notes; human curates/merges)
```

**`loop/state.json` schema** (written by init, updated by iterate/gate/shell steps):
`feature`, `mode`, `entry` (tasks|fix-tasks), `in_iteration`, `iteration`,
`iteration_outcome`, `budget {used,total}`, `started_at`, `time_box`,
`attempts {task: n}`, `parked []`, `verdicts {task: {verdict, reason}}`,
`failure_notes {task: note}`, `cycle`, `continue`, `exit_reason`.

**`review/findings.json` schema:** `{status: clean|findings|parked,
open: [{id, severity, file, summary}], cycle}`.

### 4.3 `devflow-plan-hardening` preset (ours)

`strategy: append`, `priority: 10` on core `plan`/`tasks` templates. Required outputs it
adds: failing acceptance tests (the visible-target finding); **per-task acceptance
criteria** in tasks.md (the checker's done-criteria source — ADR-0016); the task-count
line the budget computation and STOP #1 display read.

## 5. Install footprint (consumer repo)

```
.specify/extensions/{git,superspec,devflow}/ · workflows/devflow/ · devflow-config.yml
.claude/skills/speckit-devflow-*/ · agents/devflow-checker.md · settings.json (hooks)
CLAUDE.md (+protocol) · user env (gitignored): DEVFLOW_JUDGE_CMD
# generated per feature:
specs/NNN/{spec,plan,tasks,analysis}.md · loop/state.json · review/findings.md · verify-report.md
docs/decisions/*.md
```

## 6. Testing / acceptance (for the implementation phase)

1. `specify bundle validate --path bundle/` passes structural checks; reference checks
   pass once components are installed locally.
2. `specify bundle build` produces the artifact; dry-run `install` into a scratch repo is
   idempotent and matches §5.
3. Stop-gate GREEN path: an iterate session that edited files cannot end its turn without
   a decision record (blocks with reason); on record + green tests + one task changed →
   auto-commit → exit.
4. Stop-gate RED path (ADR-0016): tests red → session may exit after writing
   `iteration_outcome: failed` + failure note; **no commit**; `attempts[task]`
   incremented.
5. Stop-gate scoping (ADR-0016): a session with `in_iteration: false` (or no state file)
   exits freely — the hook is inert outside the loop.
6. Workflow dry run in a toy repo: STOP gates pause when non-interactive and resume
   (resume requires a TTY); do-while terminates on each brake (task exhaustion, budget,
   time-box) — verify all three; parked task excluded from picking and surfaced at
   STOP #2; a dispatch that ends without a valid close is counted as a failed iteration
   by loop-status (engine backstop).
7. Judge seam: missing `DEVFLOW_JUDGE_CMD` → onboard fails with instructions; malformed
   verdict JSON → iteration blocks (fail-safe); judge-FAIL verdict persists to state and
   the retry iteration's prompt includes it (Reflexion path); onboard warns when judge
   and maker are the same family.
8. Review gate enforcement (gap B, negative case): Verify's prerequisite shell step FAILS
   when findings.json is missing or status ∉ {clean, parked}.
9. Review loopback: seeded finding → fix-task (links finding) → fix-loop → re-review;
   cycle cap parks with history.
10. Gap D routing: STOP #2 `accept-with-deviation` → reconcile-contract → Ship reachable;
    Ship unreachable on that branch without reconcile; plain `accept` with parked
    items also routes through reconcile-contract.
11. STOP #1 displays the leash (budget/time-box/cap) via show_file.
12. No personal/client/infra strings anywhere in the bundle (public-repo constraint).

## 7. Out of scope for v0.1 (each with a path back)

Other integrations (relax the pin + prompt-enforced hook fallbacks) · `aide` (document as
optional) · `ralph` (autonomous mode supersedes; revisit if a grind-style engine is wanted)
· cost-denominated budgets (needs token accounting; wall-clock is the proxy) · Python step
types (nothing engine-level to enforce yet) · judge MCP server (env seam suffices).

## 8. Risks & mitigations

- **`iteration_factor: 2.5` is uncalibrated** — educated default; STOP #1 displays it,
  config overrides it, retros recalibrate it (ADR-0011 expectation).
- **Stop-hook script quality is load-bearing** (gaps C/E hang off it) — acceptance tests
  3–5 cover it directly (GREEN, RED, scoping); the hook's block cap is backstopped by the
  loop-status step; keep the script minimal and side-effect-free beyond record/commit.
- **Maker is cloud Claude in v0.x** (ADR-0016 amendment to ADR-0003) — local-maker
  topology deferred; the *review gate* remains fully local (NDA-scope preserved there).
- **Community pins can drift or break** (superspec depends on obra/superpowers presence)
  — exact pins mean updates are deliberate; onboard validates the seams actually respond.
- **Judge availability** — `required: true` means no judge, no loop; deliberate (never let
  the maker self-certify), surfaced clearly at onboard.
- **Static unroll fixes `review_cycles` at 2** — changing depth means editing the workflow
  YAML; acceptable at this cadence (config documents, workflow embodies).
