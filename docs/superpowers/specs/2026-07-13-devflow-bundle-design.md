# DevFlow bundle — design spec

**Date:** 2026-07-13 · **Status:** approved design, pre-implementation
**Decisions:** ADRs 0006–0015 (`docs/decisions/`) — this spec assembles them; the ADRs are
the record of *why*. Visual explorations: `.superpowers/brainstorm/` (screens 1–6, local only).

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
| C · decisions unrecorded | Stop-hook denies session exit until the iteration's decision record exists | Claude harness |
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

**Modes (ADR-0013)** change human presence and permission posture only — never gates or
protocol: `attended` = live terminal, default permissions (un-allowlisted actions prompt),
watch-only pulse between iterations, never blocks; `attended --step` = pulse becomes a
blocking pause each iteration; `autonomous` = headless, pre-approved allowlist via
`SPECKIT_INTEGRATION_CLAUDE_EXTRA_ARGS`. The word "supervised" is retired (ADR-0013).

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
  loop/state.json) → pick ONE task (skip parked; read judge verdicts; fix-tasks first in
  re-entry mode) → implement (whole-file edits for weak-maker compatibility) → scoped
  tests → checker subagent grades vs done-criteria → judge verdict via `DEVFLOW_JUDGE_CMD`
  → exit protocol (record-decision; Stop-gate enforces). RED path: tests fail → iteration
  ends, `attempts[task]++`, failure note to state, no commit.
- **`record-decision`** — ADR-lite record (what/why/alternatives) to `docs/decisions/`;
  in fix-task iterations must link the finding it resolves.
- **`reconcile-contract`** — accepted deviation → edit spec contract text + write ADR.
  Invoked by the workflow's deviation branch, before Ship.
- **`status`** — compact render of loop state (iteration, budget, clock, parked, verdicts).

**Assets:**

- **Hooks pack** (`.claude/settings.json` fragment):
  - `PostToolUse` on Edit|Write → lint + typecheck; failure output returns to the agent.
  - `Stop` → iteration gate script: exit 2 (block, reason to agent) unless the iteration's
    decision record exists and scoped tests are green; on pass → `git add -A && git commit`
    (gaps C + E, mechanically).
- **Checker subagent def** — fresh-context grader; never the session that made the change.
- **CLAUDE.md protocol block** — loop invariants reloaded deterministically each iteration.
- **`devflow-config.yml`** defaults:

```yaml
loop:
  iteration_factor: 2.5      # budget = ceil(open_tasks × factor); shown at STOP #1
  retry_cap: 2               # attempts per task before parking
  time_box: 4h
review:
  cycles: 2                  # loopback re-entries before findings park at STOP #2
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

Engine-owned topology (ADR-0008, 0012); all inter-step signals via files (stdout is not
capturable for conditions — verified):

```
init → Frame(command: specify → superspec.brainstorm → clarify)
     → Plan+Tasks(command; preset-hardened: red acceptance tests + budget line)
     → Analyze(command)
     → STOP #1 (gate: show plan/tests/leash; reject → abort to re-plan)
     → build-loop (do-while, max_iterations from budget):
         iterate(command) → loop-status(shell: read state.json, output_format: json)
         condition: open unparked tasks ∧ budget ∧ time-box
     → Review(command: /code-review + semgrep + /security-review → findings.md FIRST)
     → findings? (if-then on findings.md status):
         findings → fix-tasks appended (each links its finding)
                  → re-enter build-loop (entry=fix-tasks, budget ⌈n×2.5⌉, cycle ≤ 2)
                  → full re-review; cap hit → park findings with history
     → Verify (shell prerequisite: findings.md exists ∧ clean-or-parked;
               command: full suite + judge over whole diff → verify-report.md)
     → STOP #2 (gate: accept / accept-with-deviation / reject)
         accept-with-deviation → reconcile-contract(command) → Ship
     → Ship (command: git.validate → git.commit / PR; PR links the full trail)
     → Capture (command: scan docs/decisions/ → propose vault notes; human curates/merges)
```

### 4.3 `devflow-plan-hardening` preset (ours)

`strategy: append`, `priority: 10` on core `plan`/`tasks` templates: failing acceptance
tests are a **required output** of planning (the visible-target finding); tasks.md gains
the task-count line the budget computation and STOP #1 display read.

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
3. Hook behavior: a session that edits files cannot exit without a decision record
   (Stop-gate blocks with reason); green iteration auto-commits.
4. Workflow dry run in a toy repo: STOP gates pause/resume non-interactively;
   do-while terminates on each brake (task exhaustion, budget, time-box) — verify all
   three; parked task excluded from picking and surfaced at STOP #2.
5. Judge seam: missing `DEVFLOW_JUDGE_CMD` → onboard fails with instructions; malformed
   verdict JSON → iteration blocks (fail-safe).
6. Review loopback: seeded finding → fix-task → re-entry → re-review; cycle cap parks
   with history.
7. No personal/client/infra strings anywhere in the bundle (public-repo constraint).

## 7. Out of scope for v0.1 (each with a path back)

Other integrations (relax the pin + prompt-enforced hook fallbacks) · `aide` (document as
optional) · `ralph` (autonomous mode supersedes; revisit if a grind-style engine is wanted)
· cost-denominated budgets (needs token accounting; wall-clock is the proxy) · Python step
types (nothing engine-level to enforce yet) · judge MCP server (env seam suffices).

## 8. Risks & mitigations

- **`iteration_factor: 2.5` is uncalibrated** — educated default; STOP #1 displays it,
  config overrides it, retros recalibrate it (ADR-0011 expectation).
- **Stop-hook script quality is load-bearing** (gaps C/E hang off it) — acceptance test 3
  covers it directly; keep the script minimal and side-effect-free beyond record/commit.
- **Community pins can drift or break** (superspec depends on obra/superpowers presence)
  — exact pins mean updates are deliberate; onboard validates the seams actually respond.
- **Judge availability** — `required: true` means no judge, no loop; deliberate (never let
  the maker self-certify), surfaced clearly at onboard.
