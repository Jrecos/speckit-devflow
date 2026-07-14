# DevFlow Bundle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Author the DevFlow Spec Kit bundle — devflow extension (commands + hook scripts + checker subagent + config), devflow workflow (unrolled pipeline), plan-hardening preset, and final bundle.yml — ending at `specify bundle validate → build` with automated acceptance tests green.

**Architecture:** Three enforcement layers (ADR-0010): the workflow YAML owns phases/STOPs/loop (layer 1), Claude hook scripts own the iteration close contract + auto-commit (layer 2), markdown commands own behavior only (layer 3). All inter-step signals travel via files; scripts are bash + embedded python3 (no new runtime deps).

**Tech Stack:** spec-kit 0.12.11 (verified source), Claude Code hooks/subagents/skills, bash + python3 (stdlib only), YAML/JSON.

**Source spec:** `docs/superpowers/specs/2026-07-13-devflow-bundle-design.md` (ADRs 0006–0016).

## Global Constraints

- **Public repo:** no personal names (except author handle `Jrecos`), client names, hostnames, IPs, or internal URLs in any authored file.
- **spec-kit floor:** `requires.speckit_version: ">=0.12.0"`; integration pinned `claude`.
- **Verified engine facts (do not violate):** step types are exactly `command, gate, shell, prompt, init, do-while, while, if, switch, fan-out, fan-in` (note: if-then's type key is **`if`**); `do-while.max_iterations` must be a **literal int** (use `50`); dispatched command steps inside the loop need **`continue_on_error: true`**; STOP #2 routing uses **`switch`** (never split-`{{ }}` if-conditions); gate `options` keep **reject LAST** (EOF defaults to last); gate `show_file` supports `{{ }}` but we use **fixed paths**; `Stop` hook entries take **no matcher**; `requires.mcp` is a names-only list.
- **Config values (ADR-0011/0016):** `iteration_factor: 2.5`, `max_attempts_per_task: 2`, `time_box_hours: 4`, `review.cycles: 2` (documented unroll).
- **Verdict contract (ADR-0014):** stdin `{diff, criteria, spec_slice}` → stdout `{"verdict":"PASS"|"FAIL","reason":str,"criteria":[{name,pass,note}]}`.
- **Close contract (ADR-0016):** GREEN = decision record exists ∧ scoped tests green ∧ exactly one task newly checked → auto-commit → exit; RED = `iteration_outcome:"failed"` ∧ failure note → **no commit** → exit; anything else blocked (exit 2). Gate script no-ops unless `in_iteration: true`.
- **`state.json` schema (single source of truth):**

```json
{
  "feature": "<slug>", "feature_dir": "specs/<slug>",
  "mode": "attended|attended-step|autonomous", "entry": "tasks|fix-tasks",
  "in_iteration": false, "iteration": 0,
  "current_task": null, "tasks_done_at_start": 0, "last_record": null,
  "iteration_outcome": null,
  "budget": {"used": 0, "total": 0},
  "started_at": "<ISO8601>", "time_box_hours": 4,
  "attempts": {}, "parked": [], "verdicts": {}, "failure_notes": {},
  "cycle": 0, "continue": true, "exit_reason": null
}
```

- **`findings.json` schema:** `{"status":"clean|findings|parked","open":[{"id","severity","file","summary"}],"cycle":0}`
- **Canonical paths:** state `specs/<feature>/loop/state.json` (feature dir from spec-kit-native `.specify/feature.json`); fixed-path gate displays `.specify/devflow/leash.md`, `.specify/devflow/stop2.md`; config `.specify/extensions/devflow/devflow-config.yml`; scripts `.specify/extensions/devflow/scripts/bash/*.sh`.
- Commit after every task (conventional messages, `feat:`/`test:`/`docs:`).

## File Structure

```
components/
  extensions/devflow/
    extension.yml
    README.md
    config-template.yml                  # → installs as devflow-config.yml
    commands/
      speckit.devflow.onboard.md
      speckit.devflow.iterate.md
      speckit.devflow.review.md          # NEW vs spec §4.1 (Review phase dispatch)
      speckit.devflow.verify.md          # NEW vs spec §4.1 (Verify phase dispatch)
      speckit.devflow.record-decision.md
      speckit.devflow.reconcile-contract.md
      speckit.devflow.capture.md         # NEW vs spec §4.1 (Capture phase dispatch)
      speckit.devflow.status.md
    assets/claude/
      settings-hooks.json                # hooks fragment; onboard merges into .claude/settings.json
      agents/devflow-checker.md
      claude-md-protocol.md              # block onboard appends to CLAUDE.md
    scripts/bash/
      devflow-postedit.sh                # PostToolUse: lint + typecheck
      devflow-stop-gate.sh               # Stop: close contract + auto-commit
      devflow-init.sh                    # workflow init-loop step
      devflow-compute-leash.sh           # budget math + leash.md
      devflow-loop-status.sh             # do-while condition JSON + backstop
      devflow-convert-findings.sh        # findings → fix-tasks, entry/cycle flip
      devflow-check-review.sh            # Verify prerequisite (negative-fails)
      devflow-stop2-prep.sh              # STOP #2 evidence summary
    scripts/python/
      devflow_state.py                   # shared JSON state helpers (used via python3)
      merge_settings.py                  # deterministic settings.json hook merge
  presets/devflow-plan-hardening/
    preset.yml
    README.md
    commands/
      speckit.plan.md                    # replacement template (core behavior + hardening)
      speckit.tasks.md
  workflows/devflow/
    workflow.yml
bundle/
  bundle.yml                             # rewritten to verified schema
  README.md                              # updated install/validate/build docs
tests/acceptance/
  helpers.sh                             # scratch-project fixture builder
  run-all.sh
  test-01-bundle-validate.sh
  test-02-bundle-build.sh
  test-03-stop-gate-green.sh
  test-04-stop-gate-red.sh
  test-05-stop-gate-scope.sh
  test-06-loop-status-brakes.sh
  test-07-judge-seam.sh
  test-08-verify-prereq.sh
  test-09-convert-findings.sh
  test-10-leash-math.sh
  test-11-workflow-structure.sh
  test-12-no-leaks.sh
  MANUAL.md                              # live-Claude dogfood checklist (tests needing real dispatch)
```

**Numbering note:** spec §6's twelve acceptance criteria map onto these scripts; criteria needing live Claude dispatch (§6-3 hook-blocks-real-session, §6-6 full dry run, §6-10 gate routing live, parts of §6-7) live in `MANUAL.md` — everything mechanically testable is automated here.

---

### Task 1: Test harness + scratch-project fixture

**Files:**
- Create: `tests/acceptance/helpers.sh`
- Create: `tests/acceptance/run-all.sh`
- Create: `tests/acceptance/test-12-no-leaks.sh`

**Interfaces:**
- Produces: `make_scratch_project <dir>` (bash function: git repo + minimal `.specify/` + `.claude/` + toy feature fixture with `specs/012-demo/{spec.md,tasks.md}`, `.specify/feature.json`); `REPO_ROOT` env; every test sources `helpers.sh` and exits non-zero on failure.

- [ ] **Step 1: Write `tests/acceptance/helpers.sh`**

```bash
#!/usr/bin/env bash
# Shared helpers for DevFlow acceptance tests. Source me.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export REPO_ROOT

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

# Build a minimal spec-kit-shaped scratch project with a toy feature.
# Usage: make_scratch_project <dir>
make_scratch_project() {
  local dir="$1"
  rm -rf "$dir"; mkdir -p "$dir"
  ( cd "$dir"
    git init -q -b main
    git config user.email "test@example.com"; git config user.name "DevFlow Test"
    mkdir -p .specify/devflow .claude specs/012-demo/loop specs/012-demo/review docs/decisions
    printf '{"feature": "012-demo", "dir": "specs/012-demo"}\n' > .specify/feature.json
    cat > specs/012-demo/spec.md <<'EOF'
# Spec: demo feature
## Refresh
Sessions use a fixed refresh window.
EOF
    cat > specs/012-demo/tasks.md <<'EOF'
# Tasks
- [ ] T1 first thing
  - AC: does the first thing
- [ ] T2 second thing
  - AC: does the second thing
- [x] T0 scaffolding
  - AC: repo builds
EOF
    git add -A && git commit -qm "fixture: scratch project"
  )
}

# Install devflow scripts+config into a scratch project (simulating extension install)
install_devflow_assets() {
  local dir="$1"
  mkdir -p "$dir/.specify/extensions/devflow"
  cp -R "$REPO_ROOT/components/extensions/devflow/scripts" "$dir/.specify/extensions/devflow/"
  cp "$REPO_ROOT/components/extensions/devflow/config-template.yml" \
     "$dir/.specify/extensions/devflow/devflow-config.yml"
  chmod +x "$dir/.specify/extensions/devflow/scripts/bash/"*.sh
}

# Write a state.json into the fixture feature. Args: dir, then key=value JSON-ish overrides via python.
write_state() {
  local dir="$1"; shift
  python3 - "$dir/specs/012-demo/loop/state.json" "$@" <<'PY'
import json, sys
path = sys.argv[1]
state = {
  "feature": "012-demo", "feature_dir": "specs/012-demo",
  "mode": "attended", "entry": "tasks",
  "in_iteration": False, "iteration": 0,
  "current_task": None, "tasks_done_at_start": 1, "last_record": None,
  "iteration_outcome": None,
  "budget": {"used": 0, "total": 5},
  "started_at": "2026-07-14T00:00:00+00:00", "time_box_hours": 4,
  "attempts": {}, "parked": [], "verdicts": {}, "failure_notes": {},
  "cycle": 0, "continue": True, "exit_reason": None,
}
for kv in sys.argv[2:]:
    k, v = kv.split("=", 1)
    state[k] = json.loads(v)
import os; os.makedirs(os.path.dirname(path), exist_ok=True)
json.dump(state, open(path, "w"), indent=2)
PY
}

read_state_key() { # dir key -> prints JSON value
  python3 -c 'import json,sys;print(json.dumps(json.load(open(sys.argv[1]))[sys.argv[2]]))' \
    "$1/specs/012-demo/loop/state.json" "$2"
}
```

- [ ] **Step 2: Write `tests/acceptance/run-all.sh`**

```bash
#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"
failures=0
for t in test-*.sh; do
  echo "── $t"
  if bash "$t"; then echo "   ✓ $t"; else echo "   ✗ $t"; failures=$((failures+1)); fi
done
echo
[ "$failures" -eq 0 ] && echo "ALL ACCEPTANCE TESTS PASS" || { echo "$failures test file(s) FAILED"; exit 1; }
```

- [ ] **Step 3: Write `tests/acceptance/test-12-no-leaks.sh`** (spec §6-12; runs against authored components as they appear)

```bash
#!/usr/bin/env bash
source "$(dirname "$0")/helpers.sh"
# Forbidden strings: infra/personal references. Author handle Jrecos is allowed.
patterns='jreco[^s]|/Users/|alliedstone|aig-|git-asi|192\.168\.|10\.0\.|\.local[^h]|ssh://'
hits=$(grep -RInE "$patterns" "$REPO_ROOT/components" "$REPO_ROOT/bundle" 2>/dev/null | grep -v 'Binary' || true)
[ -z "$hits" ] || fail "leak-like strings found:
$hits"
pass "no personal/client/infra strings in components/ or bundle/"
```

- [ ] **Step 4: Make executable, run the leak test (components/ may not exist yet — must still pass), commit**

Run: `chmod +x tests/acceptance/*.sh && bash tests/acceptance/test-12-no-leaks.sh`
Expected: `PASS: no personal/client/infra strings...`

```bash
git add tests/acceptance/ && git commit -m "test: acceptance harness, scratch fixture, leak scan"
```

---

### Task 2: Shared state helper + extension manifest + config template

**Files:**
- Create: `components/extensions/devflow/extension.yml`
- Create: `components/extensions/devflow/config-template.yml`
- Create: `components/extensions/devflow/scripts/python/devflow_state.py`
- Create: `components/extensions/devflow/README.md`

**Interfaces:**
- Produces: `devflow_state.py` CLI — `python3 devflow_state.py get <state> <key>` (prints JSON), `set <state> <key> <json>`, `bump <state> <key>` (int +1); config keys exactly as in Global Constraints; extension id `devflow` v `0.1.0` with the 8 commands listed in File Structure.

- [ ] **Step 1: Write `config-template.yml`**

```yaml
# DevFlow configuration — copied to .specify/extensions/devflow/devflow-config.yml on install.
# Onboard (/speckit-devflow-onboard) detects and fills the commands section; hooks are inert until it does.
loop:
  iteration_factor: 2.5        # budget = ceil(open_tasks * factor); shown at STOP #1
  max_attempts_per_task: 2     # attempts before a task is parked
  time_box_hours: 4
review:
  cycles: 2                    # unroll depth of the workflow's review loopback (informational)
commands:
  lint: ""                     # e.g. "npm run lint" — required for the PostToolUse hook
  typecheck: ""                # e.g. "npx tsc --noEmit"
  test_scoped: ""              # e.g. "npm test -- --changed" — required for the Stop gate
  test_full: ""                # e.g. "npm test"
judge:
  role: cross-family-judge     # resolved by $DEVFLOW_JUDGE_CMD in your environment (never committed)
  required: true
  votes: 1
checker:
  role: independent-checker
  independent: true
```

- [ ] **Step 2: Write `scripts/python/devflow_state.py`**

```python
#!/usr/bin/env python3
"""Tiny JSON state CLI used by DevFlow bash scripts (stdlib only).

Usage:
  devflow_state.py get  <state.json> <key>            # dotted keys ok: budget.used
  devflow_state.py set  <state.json> <key> <json>     # value parsed as JSON
  devflow_state.py bump <state.json> <key>            # integer += 1
"""
import json, sys

def resolve(d, dotted, create=False):
    parts = dotted.split(".")
    for p in parts[:-1]:
        if create and p not in d:
            d[p] = {}
        d = d[p]
    return d, parts[-1]

def main():
    op, path, key = sys.argv[1], sys.argv[2], sys.argv[3]
    with open(path) as f:
        state = json.load(f)
    if op == "get":
        d, k = resolve(state, key)
        print(json.dumps(d.get(k)))
        return
    if op == "set":
        d, k = resolve(state, key, create=True)
        d[k] = json.loads(sys.argv[4])
    elif op == "bump":
        d, k = resolve(state, key, create=True)
        d[k] = int(d.get(k, 0)) + 1
    else:
        sys.exit(f"unknown op {op!r}")
    with open(path, "w") as f:
        json.dump(state, f, indent=2)

if __name__ == "__main__":
    main()
```

- [ ] **Step 3: Write `extension.yml`** (schema mirrors the installed `git` extension — verified)

```yaml
schema_version: "1.0"

extension:
  id: devflow
  name: "DevFlow Loop Engine"
  version: "0.1.0"
  description: "Autonomous spec-driven build loop: one task per fresh-context iteration, maker/checker/judge verification, close-contract Stop gate with auto-commit, and pipeline commands for review, verify, reconcile, and capture"
  category: "process"
  effect: "read-write"
  author: "Jrecos"
  repository: "https://github.com/Jrecos/speckit-devflow"
  license: MIT

requires:
  speckit_version: ">=0.12.0"
  tools:
    - name: git
      required: true
    - name: claude
      required: true

provides:
  commands:
    - name: speckit.devflow.onboard
      file: commands/speckit.devflow.onboard.md
      description: "Validate and install every DevFlow prerequisite at project scope: commands config, semgrep MCP, judge seam, hooks pack, checker subagent, CLAUDE.md protocol"
    - name: speckit.devflow.iterate
      file: commands/speckit.devflow.iterate.md
      description: "Run exactly one build-loop iteration: pick one task, implement, test, checker + judge verdicts, close GREEN or RED under the Stop-gate contract"
    - name: speckit.devflow.review
      file: commands/speckit.devflow.review.md
      description: "Review phase: local code review + Semgrep + security review; write findings.md and machine-readable findings.json FIRST"
    - name: speckit.devflow.verify
      file: commands/speckit.devflow.verify.md
      description: "Verify phase: full test suite + judge verdict over the whole diff; write verify-report.md"
    - name: speckit.devflow.record-decision
      file: commands/speckit.devflow.record-decision.md
      description: "Write an ADR-lite decision record for the current iteration (links its finding when resolving one)"
    - name: speckit.devflow.reconcile-contract
      file: commands/speckit.devflow.reconcile-contract.md
      description: "Accepted deviation or descoped/parked items: edit the spec contract text and write an ADR before Ship"
    - name: speckit.devflow.capture
      file: commands/speckit.devflow.capture.md
      description: "Capture phase: scan committed decision records and propose durable knowledge notes for human curation"
    - name: speckit.devflow.status
      file: commands/speckit.devflow.status.md
      description: "Render a compact, budget-aware view of loop state with one recommended next action"

  config:
    - name: "devflow-config.yml"
      template: "config-template.yml"
      description: "Loop brakes, project commands (lint/typecheck/tests), judge/checker roles"
      required: false

tags:
  - "loop"
  - "automation"
  - "verification"
  - "maker-checker"
  - "workflow"
```

- [ ] **Step 4: Write `README.md`** (short: what the extension provides, that assets under `assets/` + `scripts/` are installed wholesale into `.specify/extensions/devflow/` and **onboard merges the Claude-side pieces into `.claude/`**; judge seam via `DEVFLOW_JUDGE_CMD`; modes attended / attended-step / autonomous per ADR-0013.)

- [ ] **Step 5: Test — YAML parses & state CLI round-trips**

Run:
```bash
python3 -c "import yaml,sys; yaml.safe_load(open('components/extensions/devflow/extension.yml')); yaml.safe_load(open('components/extensions/devflow/config-template.yml')); print('yaml ok')" 2>/dev/null || python3 -c "print('pyyaml missing — use ruby or npx js-yaml')" 
tmp=$(mktemp); echo '{"budget":{"used":0}}' > "$tmp"
python3 components/extensions/devflow/scripts/python/devflow_state.py bump "$tmp" budget.used
python3 components/extensions/devflow/scripts/python/devflow_state.py get "$tmp" budget.used
```
Expected: `yaml ok` and `1`

- [ ] **Step 6: Commit**

```bash
git add components/ && git commit -m "feat: devflow extension manifest, config template, state helper CLI"
```

---

### Task 3: Stop-gate script (the close contract) — TDD

**Files:**
- Create: `components/extensions/devflow/scripts/bash/devflow-stop-gate.sh`
- Create: `tests/acceptance/test-03-stop-gate-green.sh`
- Create: `tests/acceptance/test-04-stop-gate-red.sh`
- Create: `tests/acceptance/test-05-stop-gate-scope.sh`

**Interfaces:**
- Consumes: `devflow_state.py` (Task 2); state.json schema (Global Constraints); config `commands.test_scoped`.
- Produces: hook script with contract — reads Stop-hook JSON on stdin (uses only `stop_hook_active` informationally, never to skip); locates state via `.specify/feature.json`; **exit 0 silently when no state file or `in_iteration != true`**; GREEN close → verify record + tests + exactly-one-task → `git add -A && git commit` → clear `in_iteration` → exit 0; RED close (`iteration_outcome=="failed"` ∧ failure note present) → clear `in_iteration`, exit 0, **no commit**; otherwise **exit 2** with reason on stderr.

- [ ] **Step 1: Write failing test `test-03-stop-gate-green.sh`** (spec §6-3)

```bash
#!/usr/bin/env bash
source "$(dirname "$0")/helpers.sh"
S=$(mktemp -d); make_scratch_project "$S"; install_devflow_assets "$S"
cd "$S"
# configure a trivially green scoped test
python3 - <<'PY'
import re, pathlib
p = pathlib.Path(".specify/extensions/devflow/devflow-config.yml")
p.write_text(p.read_text().replace('test_scoped: ""', 'test_scoped: "true"'))
PY
GATE=".specify/extensions/devflow/scripts/bash/devflow-stop-gate.sh"

# Case 1: in_iteration, work done, NO record → must BLOCK (exit 2, reason on stderr)
write_state "$S" in_iteration=true iteration=3 current_task='"T1"' tasks_done_at_start=1
echo "code" > src.txt   # uncommitted work
set +e; err=$(echo '{}' | bash "$GATE" 2>&1 >/dev/null); rc=$?; set -e
[ "$rc" -eq 2 ] || fail "expected exit 2 without record, got $rc"
echo "$err" | grep -qi "record" || fail "block reason should mention the missing record, got: $err"

# Case 2: record exists + tests green + exactly one task newly checked → commit + exit 0
mkdir -p docs/decisions && echo "# 0001: chose X" > docs/decisions/0001-iter3-choice.md
write_state "$S" in_iteration=true iteration=3 current_task='"T1"' tasks_done_at_start=1 \
  last_record='"docs/decisions/0001-iter3-choice.md"'
python3 - <<'PY'
import pathlib
t = pathlib.Path("specs/012-demo/tasks.md")
t.write_text(t.read_text().replace("- [ ] T1 first thing", "- [x] T1 first thing"))
PY
before=$(git rev-list --count HEAD)
echo '{}' | bash "$GATE" || fail "GREEN close should exit 0"
after=$(git rev-list --count HEAD)
[ "$after" -eq $((before+1)) ] || fail "GREEN close must auto-commit exactly one commit"
[ "$(read_state_key "$S" in_iteration)" = "false" ] || fail "in_iteration must clear on close"
git diff --quiet && git diff --cached --quiet || fail "working tree must be clean after commit"
pass "stop-gate GREEN: blocks without record, commits+clears with it"
```

- [ ] **Step 2: Write failing test `test-04-stop-gate-red.sh`** (spec §6-4)

```bash
#!/usr/bin/env bash
source "$(dirname "$0")/helpers.sh"
S=$(mktemp -d); make_scratch_project "$S"; install_devflow_assets "$S"
cd "$S"
GATE=".specify/extensions/devflow/scripts/bash/devflow-stop-gate.sh"
# RED close: outcome failed + failure note → exit 0, NO commit, in_iteration cleared
write_state "$S" in_iteration=true iteration=9 current_task='"T2"' \
  iteration_outcome='"failed"' failure_notes='{"T2":"flaky limiter timing"}' attempts='{"T2":1}'
echo "half-done" > wip.txt
before=$(git rev-list --count HEAD)
echo '{}' | bash "$GATE" || fail "RED close should exit 0"
after=$(git rev-list --count HEAD)
[ "$after" -eq "$before" ] || fail "RED close must NOT commit"
[ "$(read_state_key "$S" in_iteration)" = "false" ] || fail "in_iteration must clear on RED close"

# RED without a failure note → still blocked (exit 2)
write_state "$S" in_iteration=true iteration=10 current_task='"T2"' iteration_outcome='"failed"'
set +e; echo '{}' | bash "$GATE" 2>/dev/null; rc=$?; set -e
[ "$rc" -eq 2 ] || fail "failed outcome without failure note must block, got $rc"
pass "stop-gate RED: exits clean without commit; blocks when note missing"
```

- [ ] **Step 3: Write failing test `test-05-stop-gate-scope.sh`** (spec §6-5)

```bash
#!/usr/bin/env bash
source "$(dirname "$0")/helpers.sh"
S=$(mktemp -d); make_scratch_project "$S"; install_devflow_assets "$S"
cd "$S"
GATE=".specify/extensions/devflow/scripts/bash/devflow-stop-gate.sh"
# 1. No state file at all → exit 0
rm -f specs/012-demo/loop/state.json
echo '{}' | bash "$GATE" || fail "no state file must be a no-op"
# 2. State exists but in_iteration=false → exit 0 even with dirty tree and no record
write_state "$S" in_iteration=false
echo "scratch" > notes.txt
before=$(git rev-list --count HEAD)
echo '{}' | bash "$GATE" || fail "non-loop session must exit freely"
[ "$(git rev-list --count HEAD)" -eq "$before" ] || fail "no-op must not commit"
pass "stop-gate scoping: inert outside iterations"
```

- [ ] **Step 4: Run tests to verify they fail** (script doesn't exist yet)

Run: `bash tests/acceptance/test-03-stop-gate-green.sh`
Expected: FAIL (no such file devflow-stop-gate.sh)

- [ ] **Step 5: Write `devflow-stop-gate.sh`**

```bash
#!/usr/bin/env bash
# DevFlow Stop-hook gate — enforces the iteration close contract (ADR-0016).
# GREEN: record + scoped tests green + exactly one task newly checked -> auto-commit -> allow.
# RED:   iteration_outcome=failed + failure note -> allow WITHOUT commit.
# Else:  exit 2 (block; stderr is fed back to the agent).
# Inert (exit 0) when not inside an iterate session. Re-checks the real
# condition on every fire — never short-circuits on stop_hook_active.
set -uo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
cat > /dev/null || true   # drain hook stdin; decisions come from disk only

FEATURE_JSON=".specify/feature.json"
[ -f "$FEATURE_JSON" ] || exit 0
FDIR=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("dir",""))' "$FEATURE_JSON" 2>/dev/null) || exit 0
STATE="$FDIR/loop/state.json"
[ -f "$STATE" ] || exit 0

STATE_PY=".specify/extensions/devflow/scripts/python/devflow_state.py"
sget() { python3 "$STATE_PY" get "$STATE" "$1" 2>/dev/null; }
sset() { python3 "$STATE_PY" set "$STATE" "$1" "$2"; }

[ "$(sget in_iteration)" = "true" ] || exit 0

ITER=$(sget iteration | tr -d '"')
TASK=$(sget current_task)
OUTCOME=$(sget iteration_outcome)

# ---- RED close: failed outcome + a failure note for the current task ----
if [ "$OUTCOME" = '"failed"' ]; then
  TASK_KEY=$(echo "$TASK" | tr -d '"')
  NOTE=$(sget "failure_notes.$TASK_KEY")
  if [ -n "$NOTE" ] && [ "$NOTE" != "null" ]; then
    sset in_iteration false
    exit 0
  fi
  echo "DevFlow gate: iteration marked failed but no failure note for $TASK_KEY. Write the failure note to loop state (failure_notes) before ending." >&2
  exit 2
fi

# ---- GREEN close requirements ----
RECORD=$(sget last_record | tr -d '"')
if [ -z "$RECORD" ] || [ "$RECORD" = "null" ] || [ ! -f "$RECORD" ]; then
  echo "DevFlow gate: no decision record for iteration $ITER. Run /speckit-devflow-record-decision (or mark the iteration failed with a failure note) before ending." >&2
  exit 2
fi

# exactly one task newly checked this iteration
DONE_AT_START=$(sget tasks_done_at_start | tr -d '"')
DONE_NOW=$(grep -c '^- \[x\]' "$FDIR/tasks.md" 2>/dev/null || echo 0)
DELTA=$((DONE_NOW - DONE_AT_START))
if [ "$DELTA" -ne 1 ]; then
  echo "DevFlow gate: expected exactly 1 task to complete this iteration, found $DELTA. One task per iteration — mark exactly one done (or mark the iteration failed)." >&2
  exit 2
fi

# scoped tests green (command from config; empty command = misconfigured = block)
TEST_CMD=$(python3 - <<'PY'
import re
txt = open(".specify/extensions/devflow/devflow-config.yml").read()
m = re.search(r'^\s*test_scoped:\s*"(.*)"\s*$', txt, re.M)
print(m.group(1) if m else "")
PY
)
if [ -z "$TEST_CMD" ]; then
  echo "DevFlow gate: commands.test_scoped is not configured (devflow-config.yml). Run /speckit-devflow-onboard." >&2
  exit 2
fi
if ! bash -c "$TEST_CMD" > /tmp/devflow-scoped-test.log 2>&1; then
  echo "DevFlow gate: scoped tests are red (see /tmp/devflow-scoped-test.log). Fix them, or mark the iteration failed with a failure note." >&2
  exit 2
fi

# ---- GREEN close: commit + clear flag ----
git add -A
if ! git diff --cached --quiet; then
  git commit -q -m "iter ${ITER}: ${TASK//\"/} (devflow green close)" || {
    echo "DevFlow gate: auto-commit failed — resolve git state before ending." >&2; exit 2; }
fi
sset in_iteration false
sset iteration_outcome '"green"'
exit 0
```

- [ ] **Step 6: Run the three tests to verify they pass**

Run: `for t in 03 04 05; do bash tests/acceptance/test-$t-*.sh; done`
Expected: three PASS lines

- [ ] **Step 7: Commit**

```bash
git add components/extensions/devflow/scripts/bash/devflow-stop-gate.sh tests/acceptance/
git commit -m "feat: stop-gate close contract (GREEN/RED/scope) with tests"
```

---

### Task 4: PostToolUse critic + hooks fragment + settings merger

**Files:**
- Create: `components/extensions/devflow/scripts/bash/devflow-postedit.sh`
- Create: `components/extensions/devflow/assets/claude/settings-hooks.json`
- Create: `components/extensions/devflow/scripts/python/merge_settings.py`

**Interfaces:**
- Consumes: config `commands.lint` / `commands.typecheck`.
- Produces: `settings-hooks.json` (fragment with `PostToolUse` matcher `Edit|Write` and matcher-less `Stop`); `merge_settings.py <target settings.json> <fragment.json>` — idempotent merge (skips hook entries whose command already present).

- [ ] **Step 1: Write `devflow-postedit.sh`**

```bash
#!/usr/bin/env bash
# DevFlow PostToolUse critic: lint + typecheck after every Edit/Write.
# Exit 2 feeds stderr back to the agent (tool already ran). Inert when unconfigured.
set -uo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
cat > /dev/null || true
CFG=".specify/extensions/devflow/devflow-config.yml"
[ -f "$CFG" ] || exit 0
getcmd() { python3 -c '
import re,sys
m=re.search(r"^\s*"+sys.argv[2]+r":\s*\"(.*)\"\s*$", open(sys.argv[1]).read(), re.M)
print(m.group(1) if m else "")' "$CFG" "$1"; }
LINT=$(getcmd lint); TYPECHECK=$(getcmd typecheck)
errors=""
[ -n "$LINT" ] && ! out=$(bash -c "$LINT" 2>&1) && errors+="LINT FAILED:\n$out\n"
[ -n "$TYPECHECK" ] && ! out=$(bash -c "$TYPECHECK" 2>&1) && errors+="TYPECHECK FAILED:\n$out\n"
if [ -n "$errors" ]; then printf "%b" "$errors" >&2; exit 2; fi
exit 0
```

- [ ] **Step 2: Write `assets/claude/settings-hooks.json`** (fragment; Stop has NO matcher — verified unsupported)

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          { "type": "command", "command": "bash .specify/extensions/devflow/scripts/bash/devflow-postedit.sh" }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "bash .specify/extensions/devflow/scripts/bash/devflow-stop-gate.sh" }
        ]
      }
    ]
  }
}
```

- [ ] **Step 3: Write `merge_settings.py`**

```python
#!/usr/bin/env python3
"""Idempotently merge a DevFlow hooks fragment into .claude/settings.json.

Usage: merge_settings.py <settings.json path> <fragment.json path>
Creates the settings file if absent. A hook group is appended only if no
existing group in that event already runs the same command.
"""
import json, sys, os

def commands_of(group):
    return {h.get("command") for h in group.get("hooks", [])}

def main():
    target, fragment = sys.argv[1], sys.argv[2]
    frag = json.load(open(fragment))
    settings = {}
    if os.path.exists(target):
        with open(target) as f:
            settings = json.load(f)
    hooks = settings.setdefault("hooks", {})
    changed = False
    for event, groups in frag.get("hooks", {}).items():
        existing = hooks.setdefault(event, [])
        have = set()
        for g in existing:
            have |= commands_of(g)
        for g in groups:
            if commands_of(g) - have:
                existing.append(g)
                changed = True
    os.makedirs(os.path.dirname(target) or ".", exist_ok=True)
    with open(target, "w") as f:
        json.dump(settings, f, indent=2)
    print("merged" if changed else "already-present")

if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Test — merge is idempotent**

Run:
```bash
tmp=$(mktemp -d)
python3 components/extensions/devflow/scripts/python/merge_settings.py "$tmp/settings.json" components/extensions/devflow/assets/claude/settings-hooks.json
python3 components/extensions/devflow/scripts/python/merge_settings.py "$tmp/settings.json" components/extensions/devflow/assets/claude/settings-hooks.json
python3 -c "
import json,sys
s=json.load(open('$tmp/settings.json'))
assert len(s['hooks']['Stop'])==1 and len(s['hooks']['PostToolUse'])==1, 'duplicated hooks!'
assert 'matcher' not in s['hooks']['Stop'][0], 'Stop must have no matcher'
print('merge idempotent, Stop matcher-less')"
```
Expected: second run prints `already-present`; assertion prints `merge idempotent, Stop matcher-less`

- [ ] **Step 5: Commit**

```bash
git add components/ && git commit -m "feat: postedit critic, hooks fragment, idempotent settings merger"
```

---

### Task 5: Loop-status script (brakes + backstop) — TDD

**Files:**
- Create: `components/extensions/devflow/scripts/bash/devflow-loop-status.sh`
- Create: `tests/acceptance/test-06-loop-status-brakes.sh`

**Interfaces:**
- Consumes: state.json; config values.
- Produces: prints **JSON to stdout** `{"continue": bool, "reason": str, "open_tasks": n, "budget_used": n, "budget_total": n}` (consumed by the do-while condition as `steps.loop-status.output.data.continue`); side effects: **backstop** — if `in_iteration` is still true (dispatch died without closing), records a failed iteration (`attempts[current_task]++`, failure note, `in_iteration=false`); parks tasks whose attempts ≥ `max_attempts_per_task`; bumps `budget.used` per call; flips `continue=false` + `exit_reason` on any brake.

- [ ] **Step 1: Write failing test `test-06-loop-status-brakes.sh`** (spec §6-6 mechanical part)

```bash
#!/usr/bin/env bash
source "$(dirname "$0")/helpers.sh"
S=$(mktemp -d); make_scratch_project "$S"; install_devflow_assets "$S"
cd "$S"
LS=".specify/extensions/devflow/scripts/bash/devflow-loop-status.sh"
run_ls() { bash "$LS"; }

# Brake 1 — task exhaustion: all tasks done → continue=false, reason tasks_exhausted
python3 - <<'PY'
import pathlib
t = pathlib.Path("specs/012-demo/tasks.md")
t.write_text(t.read_text().replace("- [ ]", "- [x]"))
PY
write_state "$S" budget='{"used":1,"total":5}'
out=$(run_ls)
echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["continue"]==False and d["reason"]=="tasks_exhausted", d' || fail "exhaustion brake: $out"

# Brake 2 — budget: open tasks but budget.used >= total
make_scratch_project "$S"; install_devflow_assets "$S"; cd "$S"
write_state "$S" budget='{"used":5,"total":5}'
out=$(run_ls)
echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["continue"]==False and d["reason"]=="budget_exhausted", d' || fail "budget brake: $out"

# Brake 3 — time-box: started_at 5h ago with 4h box
write_state "$S" budget='{"used":1,"total":5}' started_at='"2020-01-01T00:00:00+00:00"'
out=$(run_ls)
echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["continue"]==False and d["reason"]=="time_box_exceeded", d' || fail "time-box brake: $out"

# Backstop — dispatch died mid-iteration: in_iteration still true → failed iteration recorded
write_state "$S" in_iteration=true current_task='"T1"' budget='{"used":1,"total":5}'
out=$(run_ls)
[ "$(read_state_key "$S" in_iteration)" = "false" ] || fail "backstop must clear in_iteration"
python3 -c '
import json;s=json.load(open("specs/012-demo/loop/state.json"))
assert s["attempts"].get("T1")==1, s["attempts"]
assert "T1" in s["failure_notes"], s["failure_notes"]' || fail "backstop must count attempt + note"

# Parking — attempts at cap → task parked, continue still true (other tasks open)
write_state "$S" budget='{"used":2,"total":9}' attempts='{"T1":2}'
out=$(run_ls)
python3 -c '
import json;s=json.load(open("specs/012-demo/loop/state.json"))
assert "T1" in s["parked"], s["parked"]' || fail "cap must park T1"
echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["continue"]==True, d' || fail "loop should continue past parked task"
pass "loop-status: three brakes + backstop + parking"
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash tests/acceptance/test-06-loop-status-brakes.sh`
Expected: FAIL (script missing)

- [ ] **Step 3: Write `devflow-loop-status.sh`**

```bash
#!/usr/bin/env bash
# DevFlow loop-status: the do-while's condition source + engine backstop.
# Prints JSON {"continue","reason","open_tasks","budget_used","budget_total"}.
set -euo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}"
FDIR=$(python3 -c 'import json;print(json.load(open(".specify/feature.json"))["dir"])')
STATE="$FDIR/loop/state.json"
CFG=".specify/extensions/devflow/devflow-config.yml"
python3 - "$STATE" "$FDIR/tasks.md" "$CFG" <<'PY'
import json, re, sys, datetime
state_p, tasks_p, cfg_p = sys.argv[1:4]
state = json.load(open(state_p))
cfg = open(cfg_p).read()
cap = int(re.search(r"max_attempts_per_task:\s*(\d+)", cfg).group(1))

# --- backstop: dispatch ended without a valid close ---
if state.get("in_iteration"):
    t = state.get("current_task") or "unknown"
    state["attempts"][t] = state["attempts"].get(t, 0) + 1
    state["failure_notes"][t] = state["failure_notes"].get(t) or \
        "iteration ended without a valid close (dispatch died or gate cap hit) — treated as failed"
    state["in_iteration"] = False
    state["iteration_outcome"] = "failed"

# --- parking ---
tasks_txt = open(tasks_p).read()
open_tasks = re.findall(r"^- \[ \] (\S+)", tasks_txt, re.M)
for t, n in state["attempts"].items():
    if n >= cap and t in open_tasks and t not in state["parked"]:
        state["parked"].append(t)
pickable = [t for t in open_tasks if t not in state["parked"]]

# --- budget bookkeeping: one call per loop pass ---
state["budget"]["used"] = state["budget"].get("used", 0) + 1

# --- brakes ---
reason = None
if not pickable:
    reason = "tasks_exhausted"
elif state["budget"]["used"] >= state["budget"]["total"]:
    reason = "budget_exhausted"
else:
    started = datetime.datetime.fromisoformat(state["started_at"])
    hours = (datetime.datetime.now(datetime.timezone.utc) - started).total_seconds() / 3600
    if hours >= float(state.get("time_box_hours", 4)):
        reason = "time_box_exceeded"

state["continue"] = reason is None
state["exit_reason"] = reason
json.dump(state, open(state_p, "w"), indent=2)
print(json.dumps({
    "continue": state["continue"], "reason": reason or "ok",
    "open_tasks": len(pickable),
    "budget_used": state["budget"]["used"], "budget_total": state["budget"]["total"],
}))
PY
```

> **Budget semantics note:** `budget.used` counts loop passes (one per dispatch), incremented here — not by iterate — so failed dispatches still spend budget (that's the point of a leash).

- [ ] **Step 4: Run test to verify it passes** → Expected: PASS line

- [ ] **Step 5: Commit**

```bash
git add components/ tests/ && git commit -m "feat: loop-status brakes, backstop, parking with tests"
```

---

### Task 6: init, leash, findings-conversion, review-check, stop2-prep scripts — TDD

**Files:**
- Create: `components/extensions/devflow/scripts/bash/devflow-init.sh`
- Create: `components/extensions/devflow/scripts/bash/devflow-compute-leash.sh`
- Create: `components/extensions/devflow/scripts/bash/devflow-convert-findings.sh`
- Create: `components/extensions/devflow/scripts/bash/devflow-check-review.sh`
- Create: `components/extensions/devflow/scripts/bash/devflow-stop2-prep.sh`
- Create: `tests/acceptance/test-08-verify-prereq.sh`
- Create: `tests/acceptance/test-09-convert-findings.sh`
- Create: `tests/acceptance/test-10-leash-math.sh`

**Interfaces:**
- Consumes: `.specify/feature.json`, tasks.md, config, `review/findings.json`.
- Produces:
  - `devflow-init.sh <mode>` → writes initial state.json (schema above; `mode` argument; `started_at` now-UTC) — idempotent (keeps attempts/parked if re-run mid-feature).
  - `devflow-compute-leash.sh` → counts open tasks, `total = ceil(n*factor)`, updates state.budget, writes human `.specify/devflow/leash.md` (budget, time-box, cap; STOP #1 `show_file` target).
  - `devflow-convert-findings.sh <cycle>` → appends fix-tasks (`- [ ] F<n> fix: <summary> (finding <id>)` + AC line) to tasks.md, sets `entry:"fix-tasks"`, `cycle:<cycle>`, recomputes fix budget `ceil(k*factor)` into state; no-op when findings.json status is `clean`.
  - `devflow-check-review.sh` → exit 0 iff findings.json exists ∧ status ∈ {clean, parked}; else exit 1 with reason (Verify prerequisite, spec §6-8).
  - `devflow-stop2-prep.sh` → writes `.specify/devflow/stop2.md` evidence summary (tasks done/parked, cycles used, findings status, verify verdict line, decision-record count) for STOP #2 `show_file`.

- [ ] **Step 1: Write failing test `test-10-leash-math.sh`** (spec §6-11 mechanical part)

```bash
#!/usr/bin/env bash
source "$(dirname "$0")/helpers.sh"
S=$(mktemp -d); make_scratch_project "$S"; install_devflow_assets "$S"
cd "$S"
bash .specify/extensions/devflow/scripts/bash/devflow-init.sh attended
[ -f specs/012-demo/loop/state.json ] || fail "init must create state.json"
[ "$(read_state_key "$S" mode)" = '"attended"' ] || fail "mode not recorded"
bash .specify/extensions/devflow/scripts/bash/devflow-compute-leash.sh
# fixture has 2 open tasks → ceil(2*2.5)=5
[ "$(read_state_key "$S" budget)" = '{"used": 0, "total": 5}' ] || fail "budget math wrong: $(read_state_key "$S" budget)"
grep -q "5 iterations" .specify/devflow/leash.md || fail "leash.md must state the budget"
grep -q "4h" .specify/devflow/leash.md || fail "leash.md must state the time-box"
pass "init + leash: state created, ceil(2×2.5)=5, leash.md written"
```

- [ ] **Step 2: Write failing test `test-08-verify-prereq.sh`** (spec §6-8 — the NEGATIVE case is the point)

```bash
#!/usr/bin/env bash
source "$(dirname "$0")/helpers.sh"
S=$(mktemp -d); make_scratch_project "$S"; install_devflow_assets "$S"
cd "$S"
CHK=".specify/extensions/devflow/scripts/bash/devflow-check-review.sh"
# missing findings.json → FAIL
set +e; bash "$CHK" 2>/dev/null; rc=$?; set -e
[ "$rc" -ne 0 ] || fail "must fail when findings.json is missing"
# status=findings (unresolved) → FAIL
echo '{"status":"findings","open":[{"id":"F1","severity":"high","file":"x.ts","summary":"SQLi"}],"cycle":1}' > specs/012-demo/review/findings.json
set +e; bash "$CHK" 2>/dev/null; rc=$?; set -e
[ "$rc" -ne 0 ] || fail "must fail when status=findings"
# clean → PASS ; parked → PASS
echo '{"status":"clean","open":[],"cycle":1}' > specs/012-demo/review/findings.json
bash "$CHK" || fail "clean must pass"
echo '{"status":"parked","open":[{"id":"F9","severity":"low","file":"y.ts","summary":"nit"}],"cycle":2}' > specs/012-demo/review/findings.json
bash "$CHK" || fail "parked must pass"
pass "verify prerequisite: blocks on missing/unresolved, passes clean/parked"
```

- [ ] **Step 3: Write failing test `test-09-convert-findings.sh`** (spec §6-9 mechanical part)

```bash
#!/usr/bin/env bash
source "$(dirname "$0")/helpers.sh"
S=$(mktemp -d); make_scratch_project "$S"; install_devflow_assets "$S"
cd "$S"
write_state "$S"
echo '{"status":"findings","open":[{"id":"F1","severity":"high","file":"src/a.ts","summary":"SQL injection in signup"}],"cycle":0}' > specs/012-demo/review/findings.json
bash .specify/extensions/devflow/scripts/bash/devflow-convert-findings.sh 1
grep -q '\- \[ \] F1 fix: SQL injection in signup (finding F1)' specs/012-demo/tasks.md || fail "fix-task not appended"
[ "$(read_state_key "$S" entry)" = '"fix-tasks"' ] || fail "entry not flipped"
[ "$(read_state_key "$S" cycle)" = "1" ] || fail "cycle not set"
# 1 fix-task → ceil(1*2.5)=3
python3 -c 'import json;s=json.load(open("specs/012-demo/loop/state.json"));assert s["budget"]["total"]==3 and s["budget"]["used"]==0, s["budget"]' || fail "fix budget wrong"
# clean findings → no-op
echo '{"status":"clean","open":[],"cycle":1}' > specs/012-demo/review/findings.json
before=$(md5 -q specs/012-demo/tasks.md 2>/dev/null || md5sum specs/012-demo/tasks.md | cut -d' ' -f1)
bash .specify/extensions/devflow/scripts/bash/devflow-convert-findings.sh 2
after=$(md5 -q specs/012-demo/tasks.md 2>/dev/null || md5sum specs/012-demo/tasks.md | cut -d' ' -f1)
[ "$before" = "$after" ] || fail "clean findings must be a no-op"
pass "convert-findings: fix-tasks appended, state flipped, clean no-op"
```

- [ ] **Step 4: Run the three tests → verify FAIL** (scripts missing)

- [ ] **Step 5: Write the five scripts**

`devflow-init.sh`:
```bash
#!/usr/bin/env bash
# Initialize (or refresh) DevFlow loop state for the current feature.
set -euo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}"
MODE="${1:-attended}"
FDIR=$(python3 -c 'import json;print(json.load(open(".specify/feature.json"))["dir"])')
mkdir -p "$FDIR/loop" "$FDIR/review" .specify/devflow docs/decisions
python3 - "$FDIR" "$MODE" <<'PY'
import json, sys, os, datetime, re
fdir, mode = sys.argv[1], sys.argv[2]
path = os.path.join(fdir, "loop", "state.json")
prev = json.load(open(path)) if os.path.exists(path) else {}
cfg = open(".specify/extensions/devflow/devflow-config.yml").read()
tb = float(re.search(r"time_box_hours:\s*([\d.]+)", cfg).group(1))
done = len(re.findall(r"^- \[x\]", open(os.path.join(fdir, "tasks.md")).read(), re.M)) \
       if os.path.exists(os.path.join(fdir, "tasks.md")) else 0
state = {
  "feature": os.path.basename(fdir), "feature_dir": fdir,
  "mode": mode, "entry": "tasks",
  "in_iteration": False, "iteration": prev.get("iteration", 0),
  "current_task": None, "tasks_done_at_start": done, "last_record": None,
  "iteration_outcome": None,
  "budget": prev.get("budget", {"used": 0, "total": 0}),
  "started_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
  "time_box_hours": tb,
  "attempts": prev.get("attempts", {}), "parked": prev.get("parked", []),
  "verdicts": prev.get("verdicts", {}), "failure_notes": prev.get("failure_notes", {}),
  "cycle": prev.get("cycle", 0), "continue": True, "exit_reason": None,
}
json.dump(state, open(path, "w"), indent=2)
print(f"devflow: state initialized for {fdir} (mode={mode})")
PY
```

`devflow-compute-leash.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}"
FDIR=$(python3 -c 'import json;print(json.load(open(".specify/feature.json"))["dir"])')
python3 - "$FDIR" <<'PY'
import json, math, re, sys
fdir = sys.argv[1]
cfg = open(".specify/extensions/devflow/devflow-config.yml").read()
factor = float(re.search(r"iteration_factor:\s*([\d.]+)", cfg).group(1))
cap = int(re.search(r"max_attempts_per_task:\s*(\d+)", cfg).group(1))
tb = re.search(r"time_box_hours:\s*([\d.]+)", cfg).group(1)
tasks = open(f"{fdir}/tasks.md").read()
n = len(re.findall(r"^- \[ \]", tasks, re.M))
total = math.ceil(n * factor)
sp = f"{fdir}/loop/state.json"
state = json.load(open(sp)); state["budget"] = {"used": 0, "total": total}
json.dump(state, open(sp, "w"), indent=2)
with open(".specify/devflow/leash.md", "w") as f:
    f.write(f"""# The leash for this run (approve at STOP #1)

- Open tasks: **{n}**
- Iteration budget: **{total} iterations** (= ceil({n} x {factor}))
- Time-box: **{tb}h** wall-clock
- Attempts per task before parking: **{cap}**

Between STOP #1 and STOP #2 the loop runs unattended within these limits.
Budget exhaustion is a clean park, not a failure — everything lands at STOP #2 with history.
""")
print(f"devflow: leash = {total} iterations / {tb}h (n={n}, factor={factor})")
PY
```

`devflow-convert-findings.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}"
CYCLE="${1:?usage: devflow-convert-findings.sh <cycle>}"
FDIR=$(python3 -c 'import json;print(json.load(open(".specify/feature.json"))["dir"])')
python3 - "$FDIR" "$CYCLE" <<'PY'
import json, math, re, sys
fdir, cycle = sys.argv[1], int(sys.argv[2])
fj = json.load(open(f"{fdir}/review/findings.json"))
if fj.get("status") != "findings" or not fj.get("open"):
    print("devflow: findings clean/parked — no conversion")
    raise SystemExit(0)
cfg = open(".specify/extensions/devflow/devflow-config.yml").read()
factor = float(re.search(r"iteration_factor:\s*([\d.]+)", cfg).group(1))
lines = []
for f in fj["open"]:
    lines.append(f"- [ ] {f['id']} fix: {f['summary']} (finding {f['id']})")
    lines.append(f"  - AC: finding {f['id']} no longer reproduces; regression test added")
with open(f"{fdir}/tasks.md", "a") as t:
    t.write("\n## Fix-tasks (review cycle %d)\n%s\n" % (cycle, "\n".join(lines)))
sp = f"{fdir}/loop/state.json"
state = json.load(open(sp))
state["entry"] = "fix-tasks"; state["cycle"] = cycle
state["budget"] = {"used": 0, "total": math.ceil(len(fj["open"]) * factor)}
state["continue"] = True; state["exit_reason"] = None
json.dump(state, open(sp, "w"), indent=2)
print(f"devflow: {len(fj['open'])} fix-task(s) appended (cycle {cycle}); budget {state['budget']['total']}")
PY
```

`devflow-check-review.sh`:
```bash
#!/usr/bin/env bash
# Verify-phase prerequisite (gap B): review artifact must exist and be clean-or-parked.
set -euo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}"
FDIR=$(python3 -c 'import json;print(json.load(open(".specify/feature.json"))["dir"])')
FJ="$FDIR/review/findings.json"
if [ ! -f "$FJ" ]; then
  echo "devflow: BLOCKED — Review has not produced $FJ. Verify cannot run (gap B guard)." >&2
  exit 1
fi
STATUS=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["status"])' "$FJ")
case "$STATUS" in
  clean|parked) echo "devflow: review artifact OK (status=$STATUS)";;
  *) echo "devflow: BLOCKED — findings.json status is '$STATUS' (need clean or parked)." >&2; exit 1;;
esac
```

`devflow-stop2-prep.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}"
FDIR=$(python3 -c 'import json;print(json.load(open(".specify/feature.json"))["dir"])')
python3 - "$FDIR" <<'PY'
import glob, json, re, sys, os
fdir = sys.argv[1]
state = json.load(open(f"{fdir}/loop/state.json"))
tasks = open(f"{fdir}/tasks.md").read()
done = len(re.findall(r"^- \[x\]", tasks, re.M)); open_t = len(re.findall(r"^- \[ \]", tasks, re.M))
fj_p = f"{fdir}/review/findings.json"
fstat = json.load(open(fj_p))["status"] if os.path.exists(fj_p) else "MISSING"
verdict = "not run"
vr = f"{fdir}/verify-report.md"
if os.path.exists(vr):
    m = re.search(r"^Judge verdict:\s*(\S+)", open(vr).read(), re.M)
    verdict = m.group(1) if m else "see report"
recs = len(glob.glob("docs/decisions/*.md"))
with open(".specify/devflow/stop2.md", "w") as f:
    f.write(f"""# STOP #2 — evidence summary

- Tasks: **{done} done**, {open_t} open, parked: {state['parked'] or 'none'}
- Iterations used: {state['budget']['used']}/{state['budget']['total']} (cycle {state['cycle']})
- Review: findings status = **{fstat}**
- Verify: judge verdict = **{verdict}** (full report: {fdir}/verify-report.md)
- Decision records in docs/decisions/: {recs}
- Loop exit reason: {state.get('exit_reason') or 'tasks complete'}

Choices: accept / accept-with-deviation / reject.
Accepting with ANY parked task or finding routes through reconcile-contract first (ADR-0016).
""")
print("devflow: stop2.md written")
PY
```

- [ ] **Step 6: Run the three tests → verify PASS**

Run: `for t in 08 09 10; do bash tests/acceptance/test-$t-*.sh; done`
Expected: three PASS lines

- [ ] **Step 7: Commit**

```bash
git add components/ tests/ && git commit -m "feat: init/leash/convert-findings/check-review/stop2-prep scripts with tests"
```

---

### Task 7: Judge seam test (verdict contract, fail-safe) — TDD

**Files:**
- Create: `tests/acceptance/test-07-judge-seam.sh`
- Create: `components/extensions/devflow/scripts/bash/devflow-judge.sh`

**Interfaces:**
- Produces: `devflow-judge.sh <diff-file> <criteria-file> <spec-slice-file>` — assembles `{"diff","criteria","spec_slice"}` JSON on stdin of `$DEVFLOW_JUDGE_CMD`, schema-validates stdout, prints normalized verdict JSON; **missing env or malformed output → exit 1 with reason (fail-safe = treated as FAIL by callers)**. Used by both iterate (per-iteration) and verify (whole diff) — one seam, two call sites (ADR-0014).

- [ ] **Step 1: Write failing test `test-07-judge-seam.sh`** (spec §6-7 mechanical part)

```bash
#!/usr/bin/env bash
source "$(dirname "$0")/helpers.sh"
S=$(mktemp -d); make_scratch_project "$S"; install_devflow_assets "$S"
cd "$S"
J=".specify/extensions/devflow/scripts/bash/devflow-judge.sh"
echo "diff" > d.txt; echo "crit" > c.txt; echo "slice" > s.txt

# 1. Missing DEVFLOW_JUDGE_CMD → exit 1, clear reason
set +e; err=$(DEVFLOW_JUDGE_CMD= bash "$J" d.txt c.txt s.txt 2>&1 >/dev/null); rc=$?; set -e
[ "$rc" -eq 1 ] || fail "missing judge cmd must exit 1"
echo "$err" | grep -q "DEVFLOW_JUDGE_CMD" || fail "reason must name the env var"

# 2. Malformed verdict JSON → exit 1 (fail-safe)
set +e; DEVFLOW_JUDGE_CMD="echo not-json" bash "$J" d.txt c.txt s.txt >/dev/null 2>&1; rc=$?; set -e
[ "$rc" -eq 1 ] || fail "malformed verdict must exit 1"

# 3. Valid PASS verdict → exit 0, normalized JSON on stdout; input actually reached the judge
cat > fake-judge.sh <<'EOF'
#!/usr/bin/env bash
input=$(cat)
echo "$input" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert set(d)=={"diff","criteria","spec_slice"}'
echo '{"verdict":"PASS","reason":"looks right","criteria":[{"name":"c1","pass":true,"note":""}]}'
EOF
chmod +x fake-judge.sh
out=$(DEVFLOW_JUDGE_CMD="./fake-judge.sh" bash "$J" d.txt c.txt s.txt)
echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["verdict"]=="PASS", d'

# 4. FAIL verdict → exit 0 (verdict delivered; caller decides), verdict FAIL in output
cat > fail-judge.sh <<'EOF'
#!/usr/bin/env bash
cat > /dev/null
echo '{"verdict":"FAIL","reason":"error paths leak state","criteria":[]}'
EOF
chmod +x fail-judge.sh
out=$(DEVFLOW_JUDGE_CMD="./fail-judge.sh" bash "$J" d.txt c.txt s.txt)
echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["verdict"]=="FAIL", d'
pass "judge seam: env fail-safe, schema validation, PASS/FAIL delivery"
```

- [ ] **Step 2: Run → verify FAIL** (script missing)

- [ ] **Step 3: Write `devflow-judge.sh`**

```bash
#!/usr/bin/env bash
# DevFlow judge seam (ADR-0014): role resolved by $DEVFLOW_JUDGE_CMD in the user's env.
# stdin to the judge: {"diff","criteria","spec_slice"}; stdout: verdict JSON (schema-validated).
# Fail-safe: missing env / malformed output = exit 1 (callers treat as FAIL/block).
set -uo pipefail
DIFF_F="${1:?diff file}"; CRIT_F="${2:?criteria file}"; SLICE_F="${3:?spec-slice file}"
if [ -z "${DEVFLOW_JUDGE_CMD:-}" ]; then
  echo "devflow-judge: DEVFLOW_JUDGE_CMD is not set. Configure your cross-family judge in your environment (never committed). See /speckit-devflow-onboard." >&2
  exit 1
fi
payload=$(python3 - "$DIFF_F" "$CRIT_F" "$SLICE_F" <<'PY'
import json, sys
print(json.dumps({
  "diff": open(sys.argv[1]).read(),
  "criteria": open(sys.argv[2]).read(),
  "spec_slice": open(sys.argv[3]).read(),
}))
PY
)
raw=$(printf '%s' "$payload" | bash -c "$DEVFLOW_JUDGE_CMD" 2>/tmp/devflow-judge.err) || {
  echo "devflow-judge: judge command failed (see /tmp/devflow-judge.err)" >&2; exit 1; }
printf '%s' "$raw" | python3 - <<'PY' || { echo "devflow-judge: malformed verdict JSON — treating as FAIL (fail-safe)" >&2; exit 1; }
import json, sys
d = json.load(sys.stdin)
assert d.get("verdict") in ("PASS", "FAIL"), "verdict must be PASS|FAIL"
assert isinstance(d.get("reason"), str), "reason must be a string"
assert isinstance(d.get("criteria"), list), "criteria must be a list"
print(json.dumps(d))
PY
```

- [ ] **Step 4: Run → verify PASS**

- [ ] **Step 5: Commit**

```bash
git add components/ tests/ && git commit -m "feat: judge seam script (verdict contract, fail-safe) with tests"
```

---

### Task 8: The eight extension commands (markdown prompts)

**Files:**
- Create: `components/extensions/devflow/commands/speckit.devflow.onboard.md`
- Create: `components/extensions/devflow/commands/speckit.devflow.iterate.md`
- Create: `components/extensions/devflow/commands/speckit.devflow.review.md`
- Create: `components/extensions/devflow/commands/speckit.devflow.verify.md`
- Create: `components/extensions/devflow/commands/speckit.devflow.record-decision.md`
- Create: `components/extensions/devflow/commands/speckit.devflow.reconcile-contract.md`
- Create: `components/extensions/devflow/commands/speckit.devflow.capture.md`
- Create: `components/extensions/devflow/commands/speckit.devflow.status.md`
- Create: `components/extensions/devflow/assets/claude/agents/devflow-checker.md`
- Create: `components/extensions/devflow/assets/claude/claude-md-protocol.md`

**Interfaces:**
- Consumes: every script from Tasks 3–7 (exact paths); state/findings schemas.
- Produces: layer-3 behavior. Format: frontmatter `description:` + body, matching the installed `git` extension convention. **Rules baked in:** checker invoked via `@devflow-checker` mention; the word "supervised" appears nowhere; commands reference scripts by exact path `.specify/extensions/devflow/scripts/bash/<name>.sh`.

Key content per file (write full markdown following these outlines — each numbered item becomes instruction text):

**`iterate.md`** (the core; frontmatter description: "Run exactly one build-loop iteration under the close contract"):
1. Read `.specify/feature.json` → feature dir; read `loop/state.json`, `tasks.md`, `devflow-config.yml`. Read CLAUDE.md's DevFlow protocol block (auto-loaded).
2. Set `in_iteration: true`, bump `iteration`, record `tasks_done_at_start` = count of `- [x]` in tasks.md, set `iteration_outcome: null`, `last_record: null` (use `devflow_state.py`).
3. Pick **exactly one** task: if `entry == "fix-tasks"`, prefer unchecked `F*` fix-tasks; skip anything in `parked`; if a verdict/failure note exists for a candidate, read it and target it. Write `current_task`.
4. Implement the task: whole-file edits preferred; per-edit lint/typecheck runs automatically (PostToolUse hook) — fix what it reports immediately.
5. Run scoped tests (`commands.test_scoped`). If red after honest effort within this session: set `iteration_outcome: "failed"`, write `failure_notes.<task>` (one paragraph: what failed, hypothesis, next approach), do NOT check the task off, end the session. (The Stop gate allows a RED close; the loop retries or parks.)
6. If green: invoke **@devflow-checker** to grade the diff against the task's AC line(s) from tasks.md. If checker rejects → treat as step 5 (failed, note).
7. Judge: write diff (`git diff`), criteria (task AC), spec slice (sections of spec.md the task references) to temp files; run `bash .specify/extensions/devflow/scripts/bash/devflow-judge.sh <diff> <criteria> <slice>`. FAIL verdict → write `verdicts.<task>` = {verdict, reason} to state, then step 5 path (failed + note = judge reason). PASS → continue (advisory).
8. Mark the task `- [x]` in tasks.md. Run `/speckit-devflow-record-decision`. Confirm state `last_record` points at the new file.
9. End the session. The Stop gate verifies the close and auto-commits. Never run `git commit` yourself.

**`onboard.md`**: validate git + claude on PATH; check semgrep MCP registered (`claude mcp list`) else run `claude mcp add semgrep --scope project uvx semgrep-mcp --metrics off`; detect project lint/typecheck/test commands (package.json scripts, Makefile, pyproject) and write them into `devflow-config.yml` `commands:` (ask the human to confirm); check `DEVFLOW_JUDGE_CMD` set → run `devflow-judge.sh` smoke test with a trivial diff; warn if judge appears same-family as maker (ask the human); create `.claude/agents/` and copy `assets/claude/agents/devflow-checker.md`; run `merge_settings.py .claude/settings.json .specify/extensions/devflow/assets/claude/settings-hooks.json`; append `assets/claude/claude-md-protocol.md` to CLAUDE.md if marker `<!-- devflow-protocol -->` absent; verify the spec-kit claude dispatch does not use `--bare`; print a checklist summary.

**`review.md`**: run `/code-review` style local review + Semgrep MCP scan + security review over the feature diff; write human `review/findings.md` AND machine `review/findings.json` (schema in Global Constraints) — **write both files before any reaction**; status = `clean` if no findings else `findings`; each finding gets id F1..Fn, severity, file, summary.

**`verify.md`**: run prerequisite `bash .../devflow-check-review.sh` (refuse if it fails); run `commands.test_full`; run judge over the WHOLE feature diff via `devflow-judge.sh`; write `verify-report.md` with a line `Judge verdict: PASS|FAIL` + reason + acceptance-test results; a FAIL verdict parks to STOP #2 with reject recommended (do not loop back — cycles are spent by now).

**`record-decision.md`**: next ADR number in docs/decisions/; template: `# NNNN: <title>` / Status / Context / Decision / Alternatives considered; if `entry == "fix-tasks"`, MUST include `Resolves finding: <id>`; write file, then `devflow_state.py set <state> last_record '"docs/decisions/<file>"'`.

**`reconcile-contract.md`**: read STOP #2 context (deviation described in verify-report.md and/or parked items in state + findings.json); EDIT the spec contract text (spec.md) to describe actual behavior / descoped items; write an ADR (via the record-decision template, standalone numbering) documenting why; both edits must exist before Ship.

**`capture.md`**: scan docs/decisions/*.md committed during this feature (git log range since feature branch start); propose vault-note candidates (title + one-line hook each) as a markdown list for human curation; never read chat history — files only.

**`status.md`**: render state.json compactly: iteration, budget used/total, clock elapsed vs box, current/parked tasks, last verdicts, one recommended next action.

**`devflow-checker.md`** (subagent def):
```markdown
---
name: devflow-checker
description: Independent DevFlow checker — grades one task's diff against its acceptance criteria; fresh context; never the session that made the change. Use PROACTIVELY when the iterate command requests grading.
tools: Read, Grep, Glob, Bash
---
You are the DevFlow checker: an independent, adversarial grader.
You receive: a task id, its acceptance criteria, and a diff (or file list).
Grade STRICTLY against the acceptance criteria — try to break the claim, not confirm it.
Check: does the implementation satisfy each AC? Are there obvious holes the AC implies
(error paths, edge cases named in the criteria)? Is the test real (asserts behavior,
not vacuous)?
Verdict format (your entire final message):
CHECKER: PASS — <one line why>   |   CHECKER: FAIL — <what specifically fails, actionable>
You never edit files. You never run the full pipeline. One task, one verdict.
```

**`claude-md-protocol.md`** (appended to consumer CLAUDE.md by onboard):
```markdown
<!-- devflow-protocol -->
## DevFlow loop protocol (invariants — apply in every iterate session)

- ONE task per session, from the current feature's tasks.md; never touch parked tasks.
- Durable state lives on disk (loop/state.json, tasks.md, docs/decisions/) — never in chat.
- You never grade your own work: the checker subagent and the judge do.
- You never run `git commit` — the Stop gate commits on a valid GREEN close.
- Every GREEN close needs a decision record; every RED close needs a failure note.
- Read failure notes / judge verdicts for your task before implementing — target them.
<!-- /devflow-protocol -->
```

- [ ] **Step 1: Write all 10 files per the outlines above** (full prose, no placeholders)
- [ ] **Step 2: Verify frontmatter + no retired vocabulary**

Run:
```bash
for f in components/extensions/devflow/commands/*.md; do head -1 "$f" | grep -q '^---$' || { echo "missing frontmatter: $f"; exit 1; }; done
grep -rIn "supervised" components/ && exit 1 || echo "vocabulary clean"
bash tests/acceptance/test-12-no-leaks.sh
```
Expected: `vocabulary clean`, leak test PASS

- [ ] **Step 3: Commit**

```bash
git add components/ && git commit -m "feat: devflow extension commands, checker subagent, CLAUDE.md protocol"
```

---

### Task 9: The devflow workflow YAML (unrolled pipeline) — TDD

**Files:**
- Create: `components/workflows/devflow/workflow.yml`
- Create: `tests/acceptance/test-11-workflow-structure.sh`

**Interfaces:**
- Consumes: scripts (Tasks 5–6) by exact path; command names (Task 8); verified engine rules (Global Constraints).
- Produces: installable workflow `devflow` v0.1.0.

- [ ] **Step 1: Write failing test `test-11-workflow-structure.sh`** (structural assertions — engine-validated separately in Task 11)

```bash
#!/usr/bin/env bash
source "$(dirname "$0")/helpers.sh"
W="$REPO_ROOT/components/workflows/devflow/workflow.yml"
[ -f "$W" ] || fail "workflow.yml missing"
python3 - "$W" <<'PY'
import sys, json, re
try:
    import yaml
except ImportError:
    sys.exit("pyyaml required for this test: pip install pyyaml")
d = yaml.safe_load(open(sys.argv[1]))
steps = d["steps"]
ids = [s["id"] for s in steps]
flat = json.dumps(d)

def find(sid):
    return next(s for s in steps if s["id"] == sid)

# STOP gates exist, options end with reject (EOF default), STOP1 aborts on reject
s1 = find("stop1"); assert s1["type"] == "gate" and s1["options"][-1] == "reject" and s1["on_reject"] == "abort"
s2 = find("stop2"); assert s2["type"] == "gate" and s2["options"] == ["accept", "accept-with-deviation", "reject"]
assert s1.get("show_file") == ".specify/devflow/leash.md"
assert s2.get("show_file") == ".specify/devflow/stop2.md"

# do-while loops: literal int max_iterations, condition reads loop-status data, iterate has continue_on_error
loops = [s for s in steps if s.get("type") == "do-while"]
assert len(loops) == 3, f"expected build + 2 fix loops, got {len(loops)}"
for lp in loops:
    assert isinstance(lp["max_iterations"], int), "max_iterations must be literal int"
    body_ids = [b["id"] for b in lp["steps"]]
    it = next(b for b in lp["steps"] if b.get("command", "").endswith("iterate"))
    assert it.get("continue_on_error") is True, "iterate needs continue_on_error"
    ls = next(b for b in lp["steps"] if b["id"].startswith("loop-status"))
    assert ls["type"] == "shell" and ls.get("output_format") == "json"
    assert "output.data.continue" in lp["condition"]

# routing is switch (never split-{{ }} if), on stop2 choice
sw = find("route-stop2"); assert sw["type"] == "switch"
assert sw["expression"] == "{{ steps.stop2.output.choice }}"
assert set(sw["cases"].keys()) == {"accept", "accept-with-deviation"}
# reject falls into default -> no ship steps
assert sw.get("default") == [] or all("ship" not in json.dumps(x) for x in sw.get("default", []))

# verify prerequisite shell step exists before verify command
pre_idx = ids.index("verify-prereq"); ver_idx = ids.index("verify")
assert pre_idx < ver_idx
assert "devflow-check-review.sh" in find("verify-prereq")["run"]

# mode input enum
mode = d["inputs"]["mode"]
assert mode["enum"] == ["attended", "attended-step", "autonomous"] and mode["default"] == "attended"

# forbidden vocabulary
assert "supervised" not in flat
print("workflow structural checks pass")
PY
pass "workflow.yml structure verified"
```

- [ ] **Step 2: Run → verify FAIL** (file missing)

- [ ] **Step 3: Write `components/workflows/devflow/workflow.yml`**

```yaml
schema_version: "1.0"
workflow:
  id: "devflow"
  name: "DevFlow Pipeline"
  version: "0.1.0"
  author: "Jrecos"
  description: "Frame -> Plan -> Analyze -> STOP#1 -> build loop -> Review (loopback x2, unrolled) -> Verify -> STOP#2 -> reconcile -> Ship -> Capture"

requires:
  speckit_version: ">=0.12.0"
  integrations:
    any: ["claude"]

inputs:
  feature:
    type: string
    required: true
    prompt: "Describe the feature to build"
  mode:
    type: string
    default: "attended"
    enum: ["attended", "attended-step", "autonomous"]
    prompt: "Loop mode (attended | attended-step | autonomous)"

steps:
  # ---------- Frame ----------
  - id: specify
    command: speckit.specify
    input: { args: "{{ inputs.feature }}" }
  - id: brainstorm
    command: speckit.superspec.brainstorm
    input: { args: "pressure-test the spec for edge cases and contradictions" }
  - id: clarify
    command: speckit.clarify
    continue_on_error: true          # clarify is optional-by-outcome
    input: { args: "" }

  # ---------- Plan ----------
  - id: plan
    command: speckit.plan
    input: { args: "" }
  - id: tasks
    command: speckit.tasks
    input: { args: "" }

  # ---------- Loop state + leash ----------
  - id: init-loop
    type: shell
    run: bash .specify/extensions/devflow/scripts/bash/devflow-init.sh {{ inputs.mode }}
  - id: compute-leash
    type: shell
    run: bash .specify/extensions/devflow/scripts/bash/devflow-compute-leash.sh

  # ---------- Analyze + STOP #1 ----------
  - id: analyze
    command: speckit.analyze
    input: { args: "" }
  - id: stop1
    type: gate
    message: "STOP #1 — review the plan, the failing acceptance tests, and the leash below. Approving hands the loop the keys until STOP #2."
    show_file: ".specify/devflow/leash.md"
    options: [approve, reject]
    on_reject: abort

  # ---------- Build loop ----------
  - id: build-loop
    type: do-while
    max_iterations: 50
    condition: "{{ steps.loop-status.output.data.continue }}"
    steps:
      - id: iterate
        command: speckit.devflow.iterate
        continue_on_error: true
        input: { args: "" }
      - id: loop-status
        type: shell
        output_format: json
        run: bash .specify/extensions/devflow/scripts/bash/devflow-loop-status.sh

  # ---------- Review (cycle 0) ----------
  - id: review
    command: speckit.devflow.review
    input: { args: "" }

  # ---------- Loopback cycle 1 (unrolled) ----------
  - id: findings-check-1
    type: shell
    output_format: json
    run: python3 -c "import json;d=json.load(open('.specify/feature.json'));f=json.load(open(d['dir']+'/review/findings.json'));print(json.dumps({'status':f['status']}))"
  - id: fix-cycle-1
    type: if
    condition: "{{ steps.findings-check-1.output.data.status == 'findings' }}"
    then:
      - id: convert-1
        type: shell
        run: bash .specify/extensions/devflow/scripts/bash/devflow-convert-findings.sh 1
      - id: fix-loop-1
        type: do-while
        max_iterations: 25
        condition: "{{ steps.loop-status-f1.output.data.continue }}"
        steps:
          - id: iterate-f1
            command: speckit.devflow.iterate
            continue_on_error: true
            input: { args: "" }
          - id: loop-status-f1
            type: shell
            output_format: json
            run: bash .specify/extensions/devflow/scripts/bash/devflow-loop-status.sh
      - id: re-review-1
        command: speckit.devflow.review
        input: { args: "full re-review, cycle 1" }

  # ---------- Loopback cycle 2 (unrolled) ----------
  - id: findings-check-2
    type: shell
    output_format: json
    run: python3 -c "import json;d=json.load(open('.specify/feature.json'));f=json.load(open(d['dir']+'/review/findings.json'));print(json.dumps({'status':f['status']}))"
  - id: fix-cycle-2
    type: if
    condition: "{{ steps.findings-check-2.output.data.status == 'findings' }}"
    then:
      - id: convert-2
        type: shell
        run: bash .specify/extensions/devflow/scripts/bash/devflow-convert-findings.sh 2
      - id: fix-loop-2
        type: do-while
        max_iterations: 25
        condition: "{{ steps.loop-status-f2.output.data.continue }}"
        steps:
          - id: iterate-f2
            command: speckit.devflow.iterate
            continue_on_error: true
            input: { args: "" }
          - id: loop-status-f2
            type: shell
            output_format: json
            run: bash .specify/extensions/devflow/scripts/bash/devflow-loop-status.sh
      - id: re-review-2
        command: speckit.devflow.review
        input: { args: "full re-review, cycle 2 (final)" }
      # cap spent: surviving findings are parked with history
      - id: park-findings
        type: shell
        run: >-
          python3 -c "import json;d=json.load(open('.specify/feature.json'));p=d['dir']+'/review/findings.json';f=json.load(open(p));
          f['status']='parked' if f['status']=='findings' else f['status'];json.dump(f,open(p,'w'),indent=2);print(f['status'])"

  # ---------- Verify (gap-B prerequisite, then the phase) ----------
  - id: verify-prereq
    type: shell
    run: bash .specify/extensions/devflow/scripts/bash/devflow-check-review.sh
  - id: verify
    command: speckit.devflow.verify
    input: { args: "" }

  # ---------- STOP #2 + routing ----------
  - id: stop2-prep
    type: shell
    run: bash .specify/extensions/devflow/scripts/bash/devflow-stop2-prep.sh
  - id: stop2
    type: gate
    message: "STOP #2 — the evidence is below. Ship happens only past this gate. Accepting with parked items routes through reconcile-contract."
    show_file: ".specify/devflow/stop2.md"
    options: [accept, accept-with-deviation, reject]
    on_reject: abort
  - id: route-stop2
    type: switch
    expression: "{{ steps.stop2.output.choice }}"
    cases:
      accept:
        # plain accept still reconciles when anything is parked (ADR-0016)
        - id: reconcile-if-parked
          type: shell
          output_format: json
          run: >-
            python3 -c "import json;d=json.load(open('.specify/feature.json'));s=json.load(open(d['dir']+'/loop/state.json'));
            f=json.load(open(d['dir']+'/review/findings.json'));
            print(json.dumps({'needs': bool(s['parked']) or f['status']=='parked'}))"
        - id: reconcile-parked
          type: if
          condition: "{{ steps.reconcile-if-parked.output.data.needs }}"
          then:
            - id: reconcile-a
              command: speckit.devflow.reconcile-contract
              input: { args: "descope: document parked tasks/findings in the contract" }
        - id: ship-a
          command: speckit.git.validate
          input: { args: "" }
        - id: ship-commit-a
          command: speckit.git.commit
          input: { args: "" }
        - id: capture-a
          command: speckit.devflow.capture
          input: { args: "" }
      accept-with-deviation:
        - id: reconcile-b
          command: speckit.devflow.reconcile-contract
          input: { args: "accepted deviation: update contract text + ADR" }
        - id: ship-b
          command: speckit.git.validate
          input: { args: "" }
        - id: ship-commit-b
          command: speckit.git.commit
          input: { args: "" }
        - id: capture-b
          command: speckit.devflow.capture
          input: { args: "" }
    default: []   # unreachable: reject aborts at the gate
```

> **Note on attended-step:** the per-iteration blocking pause is NOT a gate inside the do-while (verified: a paused nested gate re-runs the whole body on resume). v0.1 implements `attended-step` in the **iterate command**: when `state.mode == "attended-step"`, iterate's final instruction tells the operator the loop pauses via the engine's normal gate at the *next* natural boundary; full engine-level step-pause is documented as a v0.2 item in the bundle README. (MANUAL.md exercises this.)

- [ ] **Step 4: Run test → verify PASS**; also `python3 -c "import yaml; yaml.safe_load(open('components/workflows/devflow/workflow.yml')); print('yaml ok')"`

- [ ] **Step 5: Commit**

```bash
git add components/workflows tests/ && git commit -m "feat: devflow workflow (unrolled loopback, verified engine constraints)"
```

---

### Task 10: Plan-hardening preset + final bundle.yml

**Files:**
- Create: `components/presets/devflow-plan-hardening/preset.yml`
- Create: `components/presets/devflow-plan-hardening/README.md`
- Create: `components/presets/devflow-plan-hardening/commands/speckit.plan.md`
- Create: `components/presets/devflow-plan-hardening/commands/speckit.tasks.md`
- Modify: `bundle/bundle.yml` (full rewrite to verified schema)
- Modify: `bundle/README.md`

**Interfaces:**
- Consumes: verified preset/bundle schemas (ADR-0015); lean preset as template-format reference.
- Produces: preset `devflow-plan-hardening` 0.1.0 (replaces core plan/tasks templates with hardened versions); bundle manifest listing all five components.

> **Preset semantics note (verified):** spec-kit presets *replace* command templates via `provides.templates[].replaces`. The bundle-level `strategy: append` / `priority: 10` control catalog resolution order, not text merging — so our templates are **full replacements** that keep core behavior and add the hardening requirements.

- [ ] **Step 1: Write `preset.yml`**

```yaml
schema_version: "1.0"

preset:
  id: "devflow-plan-hardening"
  name: "DevFlow Plan Hardening"
  version: "0.1.0"
  description: "Hardens plan/tasks outputs for the DevFlow loop: failing acceptance tests at plan time, per-task acceptance criteria, and a machine-countable task list"
  author: "Jrecos"
  repository: "https://github.com/Jrecos/speckit-devflow"
  license: "MIT"

requires:
  speckit_version: ">=0.12.0"

provides:
  templates:
    - type: "command"
      name: "speckit.plan"
      file: "commands/speckit.plan.md"
      description: "Plan with required failing acceptance tests"
      replaces: "speckit.plan"
    - type: "command"
      name: "speckit.tasks"
      file: "commands/speckit.tasks.md"
      description: "Tasks with required per-task acceptance criteria in DevFlow's countable format"
      replaces: "speckit.tasks"

tags: ["devflow", "planning", "tdd", "acceptance-tests"]
```

- [ ] **Step 2: Write the two command templates.** Base them on the lean preset's structure (read `.specify/feature.json` → load context → produce artifact). Hardening additions:
  - `speckit.plan.md` adds a REQUIRED section: *"Write failing acceptance tests NOW (red), one per major requirement, under the project's test tree; list their paths in plan.md under `## Acceptance tests (red)`. Planning is not complete until they exist and fail."*
  - `speckit.tasks.md` adds REQUIRED format rules: *"Every task line must be exactly `- [ ] T<n> <short name>` followed by an indented `  - AC: <verifiable criterion>` line (one or more). The DevFlow loop counts `^- [ ]`/`^- [x]` lines and the checker grades against AC lines — deviations break the harness. End the file with nothing after the last task section."*

- [ ] **Step 3: Rewrite `bundle/bundle.yml`** (verified schema; replaces the draft entirely)

```yaml
schema_version: "1.0"

bundle:
  id: devflow
  name: DevFlow
  version: 0.1.0
  role: developer
  description: >-
    Autonomous, spec-driven development workflow: two human STOPs, a one-task-per-iteration
    build loop with maker/checker/judge verification, a documented review loopback, close-contract
    auto-commits, and a knowledge track that ends with guaranteed-populated decision records.
    Claude Code first.
  author: Jrecos
  license: MIT

integration:
  id: claude

requires:
  speckit_version: ">=0.12.0"
  tools: [git, claude]
  mcp: [semgrep]

provides:
  extensions:
    - id: git
      version: "1.0.0"
    - id: superspec
      version: "1.0.1"
    - id: devflow
      version: "0.1.0"
  presets:
    - id: devflow-plan-hardening
      version: "0.1.0"
      priority: 10
      strategy: append
  steps: []
  workflows:
    - id: devflow
      version: "0.1.0"

tags: [development, autonomous, spec-driven, verification, knowledge-base]
```

- [ ] **Step 4: Update `bundle/README.md`** — author flow (install components locally with `--dev`, then `specify bundle validate --path bundle` → `build`), consumer flow (`bundle install devflow` + `/speckit-devflow-onboard` + `specify workflow run devflow`), the judge env seam, mode names, and the pointer to the design spec.

- [ ] **Step 5: Test — YAML validity + leak scan**

Run: `python3 -c "import yaml;[yaml.safe_load(open(f)) for f in ['components/presets/devflow-plan-hardening/preset.yml','bundle/bundle.yml']];print('yaml ok')" && bash tests/acceptance/test-12-no-leaks.sh`
Expected: `yaml ok`, PASS

- [ ] **Step 6: Commit**

```bash
git add components/ bundle/ && git commit -m "feat: plan-hardening preset + final bundle manifest (verified schema)"
```

---

### Task 11: Bundle validate + build against real spec-kit — TDD

**Files:**
- Create: `tests/acceptance/test-01-bundle-validate.sh`
- Create: `tests/acceptance/test-02-bundle-build.sh`

**Interfaces:**
- Consumes: everything; the real `specify` CLI (0.12.11+ on PATH).
- Produces: green `specify bundle validate`; built artifact `dist/devflow-0.1.0.zip`; proof local components install with real primitives.

- [ ] **Step 1: Write `test-01-bundle-validate.sh`** (spec §6-1)

```bash
#!/usr/bin/env bash
source "$(dirname "$0")/helpers.sh"
command -v specify >/dev/null || fail "specify CLI not on PATH"
S=$(mktemp -d)
( cd "$S" && specify init . --ai claude --ignore-agent-tools --no-git >/dev/null 2>&1 ) \
  || fail "specify init failed (check flags with 'specify init --help')"
cd "$S"
# install our three authored components from the repo working tree
specify extension add "$REPO_ROOT/components/extensions/devflow" --dev || fail "devflow extension install"
specify preset add --dev "$REPO_ROOT/components/presets/devflow-plan-hardening" || fail "preset install"
specify workflow add "$REPO_ROOT/components/workflows/devflow/workflow.yml" || fail "workflow install (also engine-validates the YAML)"
# with components resolvable locally, the manifest must validate (git/superspec resolve via catalog/bundled)
cp -R "$REPO_ROOT/bundle" ./bundle
specify bundle validate --path ./bundle || fail "bundle validate"
pass "components install with real primitives; bundle validates"
```

> If any CLI flag differs on the installed version, adjust from `--help` output and note the correction in the commit message — do not fake the step.

- [ ] **Step 2: Write `test-02-bundle-build.sh`** (spec §6-2)

```bash
#!/usr/bin/env bash
source "$(dirname "$0")/helpers.sh"
command -v specify >/dev/null || fail "specify CLI not on PATH"
S=$(mktemp -d)
( cd "$S" && specify init . --ai claude --ignore-agent-tools --no-git >/dev/null 2>&1 )
cd "$S"
specify extension add "$REPO_ROOT/components/extensions/devflow" --dev >/dev/null
specify preset add --dev "$REPO_ROOT/components/presets/devflow-plan-hardening" >/dev/null
specify workflow add "$REPO_ROOT/components/workflows/devflow/workflow.yml" >/dev/null
cp -R "$REPO_ROOT/bundle" ./bundle
specify bundle build --path ./bundle --output ./dist || fail "bundle build"
ls dist/devflow-0.1.0.zip >/dev/null || fail "artifact missing"
pass "bundle builds: dist/devflow-0.1.0.zip"
```

- [ ] **Step 3: Run both** → Expected: PASS, PASS. Fix whatever the real CLI rejects (this is the step that catches every remaining schema mismatch — treat CLI errors as the source of truth and update components accordingly).

- [ ] **Step 4: Run the full suite**

Run: `bash tests/acceptance/run-all.sh`
Expected: `ALL ACCEPTANCE TESTS PASS`

- [ ] **Step 5: Commit**

```bash
git add tests/ && git commit -m "test: bundle validate + build against real spec-kit CLI"
```

---

### Task 12: MANUAL.md dogfood checklist + docs sync

**Files:**
- Create: `tests/acceptance/MANUAL.md`
- Modify: `README.md` (repo root — Status section)
- Modify: `HANDOFF.md` (mark brainstorm/authoring done; next = dogfood)

**Interfaces:** none new — documentation truth-up.

- [ ] **Step 1: Write `MANUAL.md`** — the live-Claude checks automation can't cover, each with exact commands + expected observation:
  1. (§6-3 live) In a scratch project with hooks installed and `in_iteration:true` staged, run `claude -p "edit a file and finish"` → observe the Stop-gate block message in the transcript, then compliance.
  2. (§6-6 live) Full `specify workflow run devflow --input feature="tiny demo" --input mode=attended` on a toy repo through STOP #2 (gates pause; `specify workflow resume` in a TTY).
  3. (§6-7 live) Set `DEVFLOW_JUDGE_CMD` to a real second-family CLI; verify verdicts flow into state and a seeded FAIL causes a retry that references the verdict.
  4. (§6-10 live) At STOP #2 choose accept-with-deviation → confirm reconcile edits spec.md + writes the ADR before git.validate runs.
  5. attended-step: confirm the pause behavior at iteration boundaries; note v0.2 engine-level plan.
  6. `--bare` guard: confirm the spec-kit claude dispatch invocation contains no `--bare` (inspect `specify workflow run` output/verbose).

- [ ] **Step 2: Update root `README.md` Status** — check off "Brainstorm the bundle design" and "Author the components"; add "next: dogfood run (MANUAL.md) → publish".

- [ ] **Step 3: Update `HANDOFF.md`** — brief postscript: design + authoring complete (ADRs 0006–0016, spec, plan); open work = manual dogfood + catalog publication.

- [ ] **Step 4: Final full run + commit**

Run: `bash tests/acceptance/run-all.sh`
Expected: `ALL ACCEPTANCE TESTS PASS`

```bash
git add -A && git commit -m "docs: manual dogfood checklist; status truth-up across README/HANDOFF"
```

---

## Plan self-review (done at authoring time)

- **Spec coverage:** §2 consumer UX → Tasks 8–9; §3 manifest → Task 10; §4.1 extension → Tasks 2–8; §4.2 workflow + schemas → Tasks 5–6, 9; §4.3 preset → Task 10; §5 footprint → onboard (Task 8) + install tests (Task 11); §6 acceptance 1→T11, 2→T11, 3→T3, 4→T3, 5→T3, 6→T5+MANUAL, 7→T7(+MANUAL live), 8→T6, 9→T6(+MANUAL live loopback), 10→T9 switch topology(+MANUAL live), 11→T6, 12→T1; §7 non-goals — nothing here implements them; §8 risks — factor in config (T2), gate quality (T3 tests), pins exact (T10).
- **Notable deviations from spec (intentional, argued inline):** three extra commands (`review`, `verify`, `capture`) because those phases need devflow-owned dispatch targets (spec §4.2 references them implicitly); `attended-step`'s engine-level pause deferred to v0.2 with behavior documented (verified engine constraint: nested gate resume re-runs the loop body); preset templates are full replacements (verified preset semantics) rather than literal "appends".
- **Type consistency:** state keys, script paths, command names, and schema fields are identical across Tasks 3–9 (single source: Global Constraints block).

