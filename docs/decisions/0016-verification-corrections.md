# ADR-0016: Design corrections from the pre-implementation verification pass

**Status:** Accepted

**Context:** Before authoring, a three-agent cross-check verified the design against (1) the
installed spec-kit 0.12.11 source, (2) current Claude Code hooks/subagent/headless docs, and
(3) the repo's own ADRs/spec for consistency. It confirmed the architecture but surfaced
4 critical and ~11 major defects. This ADR records the corrections; the spec is updated in
place. Where a correction amends an earlier ADR, that ADR carries a pointer here.

## Critical corrections

**1. Attended mode has no mid-iteration permission prompts (amends ADR-0013).**
`claude -p` is non-interactive: there are no permission prompts in headless mode; an
un-allowlisted action aborts the run. Corrected semantics: **`attended` = live streamed
output + base allowlist + `--permission-mode acceptEdits`**; an un-allowlisted action aborts
the iteration, which is recorded as a *failed iteration* (abort-as-pause) — the human
allowlists and resumes. True mid-iteration prompting via `--permission-prompt-tool` (an MCP
adjudicator) is a documented v0.2 path, not v0.1.

**2. RED-exit contract (amends ADR-0010/0011 — fixes a deadlock).**
As written, the Stop-gate required *green tests* to exit while a red iteration must end —
deadlock, or worse, an incentive to game tests green. Contract now: an iteration closes in
exactly one of two ways, and the Stop-gate allows exit iff one holds in `loop/state.json`:
- **GREEN close:** decision record exists + scoped tests green + exactly one task changed
  state → auto-commit → exit.
- **RED close:** `iteration_outcome: failed` with a **failure note** written to state (the
  failure note *is* the record for red iterations — no ADR-lite required, no commit).
Anything else stays blocked. This also upgrades **one-task-per-iteration** from behavioral
to hook-enforced (the GREEN close verifies exactly one task changed), fixing the
"prompts never carry guarantees" violation.

**3. Stop-gate scoping — the hook must not capture non-loop sessions.**
The hooks pack installs project-wide; without scoping, *every* session in the repo (Frame,
Review, the operator's own interactive work) would be exit-gated. The gate script **no-ops
unless `loop/state.json` has `in_iteration: true`** (set by `iterate` at prime, cleared on
close). Acceptance test added: a non-loop session exits freely.

**4. Loopback topology — workflows are step lists with no goto (fixes ADR-0012's drawing).**
The Review→Build back-edge is not expressible as an edge. v0.1 **unrolls the cycle cap
(2) statically**: `build-loop → Review → [findings? → fix-loop → re-Review] → [still
findings? → park] → Verify`. Each fix-loop is the same do-while template with
`entry: fix-tasks`. `review_cycles` in config documents the unroll; changing it means
editing the workflow. STOP #1 reject = gate `on_reject: abort` (workflow ends; human
re-plans and re-runs). STOP #2 reject = switch branch that ends the workflow without Ship.

## Engine-truth corrections (from source verification)

- **`max_iterations` must be a literal integer** — no expressions. The do-while gets a
  static generous cap (50); the real budget/time-box lives where it already was designed:
  the shell-evaluated condition over `state.json`.
- **`continue_on_error: true` on the `iterate` command step** — a red iteration exits
  non-zero; without this flag it would fail the whole workflow.
- **STOP #2 routing uses a `switch`** on `{{ steps.stop2.output.choice }}`. (An `if-then`
  with the comparison outside one `{{ }}` block is always-truthy — documented trap.)
- **Gate rules:** reject stays the LAST option (EOF/Ctrl+C defaults to `options[-1]`);
  resuming a paused gate requires a TTY (no headless choice injection); a pausable gate
  inside a do-while body re-runs the whole body on resume — `attended-step`'s per-iteration
  pause is therefore a **trailing gate in the loop body relying on `iterate`'s
  state-idempotency** (resume = permit exactly the next iteration).
- **Asset shipping:** extensions are copied wholesale into `.specify/extensions/devflow/`;
  the installer never writes `.claude/`. The hooks pack, checker subagent def, gate scripts,
  and CLAUDE.md block ship as plain asset files in the extension; **`onboard` merges them
  into `.claude/`**. The extension.yml `hooks:` key is reserved for spec-kit lifecycle
  hooks and is not used for Claude hooks.

## Claude-mechanics corrections (from docs verification)

- The Stop hook blocks **end-of-turn**, not "session exit" (wording fixed); it is bounded
  by an ~8-consecutive-blocks override cap → **engine-side backstop:** a dispatch that ends
  without a valid GREEN/RED close is treated as a failed iteration by the loop-status step.
- Gate script requirements: **omit `matcher`** on the Stop entry; **re-check the real
  condition every fire** (never early-exit on `stop_hook_active`); `cd "$CLAUDE_PROJECT_DIR"`
  before git ops; commits non-interactive and idempotent.
- `onboard` must assert the integration dispatch does **not** use `--bare` (it would
  disable hooks and CLAUDE.md), and must create `.claude/agents/` itself.
- The iterate prompt invokes the checker via **`@devflow-checker` mention** (guaranteed
  delegation), not prose.

## Consistency corrections (amend earlier docs)

- **Local maker deferred (amends ADR-0003):** pinning `integration: claude` (ADR-0009)
  makes Claude the maker in v0.x — cloud, not local. Maker locality is deferred, not
  abandoned; ADR-0005's "source never leaves the machine" claim is scoped to the *review
  gate* (still fully local: /code-review + Semgrep + /security-review). ADR-0003 annotated.
- **Accept-partial is a deviation (extends ADR-0012/0011):** at STOP #2, `accept` with any
  parked task or finding routes through `reconcile-contract` (spec edit documenting the
  descope + ADR) — otherwise gap D re-enters through the side door.
- **Verify-level judge FAIL (scopes ADR-0003):** at iteration level FAIL hard-blocks (as
  decided). At Verify, FAIL **parks to STOP #2** with the verdict displayed and reject as
  the recommended default — by that point the loopback cycles are spent and the human is
  the backstop; Ship remains unreachable without an explicit accept.
- **baseline-workflow.md** gets an amendment banner (steps 2/8/11 and "Engine swap" are
  superseded by ADRs 0006/0007/0013).

## Implementation contracts pinned (were underspecified)

- **`loop/state.json` schema** (written by the workflow's `init` step, updated by
  `iterate`/gate): `feature`, `mode`, `entry` (tasks|fix-tasks), `in_iteration`,
  `iteration`, `iteration_outcome`, `budget {used,total}`, `started_at`/`time_box`,
  `attempts {task: n}`, `parked []`, `verdicts {task: {verdict,reason}}`,
  `failure_notes {task: note}`, `cycle`, `continue`, `exit_reason`.
- **Feature pointer:** `.specify/devflow-current.json` (`{feature_dir}`), written by the
  workflow `init` step; every later step reads it.
- **`review/findings.json` sidecar** (machine-readable twin of findings.md):
  `{status: clean|findings|parked, open: [{id,severity,file,summary}], cycle}` — consumed
  by the findings switch and Verify's prerequisite shell check.
- **Budget computation:** a shell step after Tasks counts tasks, computes
  `ceil(n × iteration_factor)`, writes it to state and to a leash summary file that
  STOP #1's gate displays via `show_file`. Budget override = edit config/state before
  re-running (gates return choices, not numbers).
- **`devflow-config.yml` additions:** `commands: {lint, typecheck, test_scoped, test_full}`
  (detected/confirmed by onboard — hooks are inert without them);
  `max_attempts_per_task: 2` (renamed from `retry_cap` — it counts attempts, not retries).
- **Done-criteria source:** per-task acceptance criteria lines in `tasks.md`, made a
  required output by the plan-hardening preset (extends its scope alongside red acceptance
  tests and the task-count line).
- Frame is three separate `command` steps (specify → superspec.brainstorm → clarify), not
  one. The judge's `spec-slice` input is assembled by `iterate` from the spec sections the
  task references. The fix-task conversion step writes `entry: fix-tasks` + `cycle` to
  state before the fix-loop runs. Autonomous mode's extra-args env is set by the operator
  (documented), not by the workflow, in v0.1.

## Acceptance tests added (spec §6)

RED close: red iteration exits with failure note, no commit · non-loop session exits freely
· Verify refuses when findings.json is missing/not clean-or-parked · STOP #2
accept-with-deviation → reconcile → Ship reachable, and Ship unreachable without reconcile
on that branch · judge-FAIL verdict persisted and read by the retry iteration · onboard
same-family warning · leash displayed at STOP #1.

**Consequences:** The architecture survives verification intact — every correction lands
inside the already-decided structure (layers, STOPs, brakes, loopback-with-cap). Cost:
`review_cycles` is fixed at 2 by the unroll; attended mode is honest about headless limits;
the spec gains pinned schemas that constrain authoring. The verification pass itself
(3 agents, ~30 findings) validated the "cross-check before build" habit this bundle exists
to encode.
