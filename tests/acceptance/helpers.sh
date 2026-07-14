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
    # NOTE: real spec-kit writes key "feature_directory" (verified: core_pack/commands/specify.md,
    # common.sh read_feature_json_feature_directory) — never "dir".
    printf '{"feature_directory": "specs/012-demo"}\n' > .specify/feature.json
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

# Write a state.json into the fixture feature. Args: dir, then key=value JSON overrides.
write_state() {
  local dir="$1"; shift
  python3 - "$dir/specs/012-demo/loop/state.json" "$@" <<'PY'
import json, sys, os
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
os.makedirs(os.path.dirname(path), exist_ok=True)
json.dump(state, open(path, "w"), indent=2)
PY
}

read_state_key() { # dir key -> prints JSON value
  python3 -c 'import json,sys;print(json.dumps(json.load(open(sys.argv[1]))[sys.argv[2]]))' \
    "$1/specs/012-demo/loop/state.json" "$2"
}
