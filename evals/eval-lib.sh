#!/usr/bin/env bash
# Shared library for DevFlow behavioral evals. Source me.
#
# An *eval* differs from an acceptance test (tests/acceptance/): the acceptance suite is
# hermetic and checks scripts + prompt TEXT (test-15 freezes the wording). An eval runs the
# actual command through a fresh Claude session and grades what the AGENT DID — the behavior
# the prompt is supposed to produce. It is the net that would have caught the dogfood findings
# before a user did (roadmap candidate #2).
#
# Driver seam (mirrors the judge seam, devflow-judge.sh): the model that runs a case is
# resolved from $DEVFLOW_EVAL_DRIVER; unset → live `claude -p`. Swap it to route evals through
# a cheaper or cross-family model. The deterministic self-test (run-evals.sh --self-test) never
# calls a live model at all — it drives each case's sim_pass / sim_revert hooks, exactly as
# test-07 injects a fake judge instead of a real one.
set -uo pipefail

EVAL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$EVAL_ROOT/.." && pwd)"
DEVFLOW_SRC="$REPO_ROOT/components/extensions/devflow"
export EVAL_ROOT REPO_ROOT DEVFLOW_SRC

efail() { echo "FAIL: $*" >&2; return 1; }
epass() { echo "PASS: $*"; }
enote() { echo "  · $*" >&2; }

# Portable bounded run (no `timeout` on macOS): kill <cmd> if it outlives <secs>.
# Used to guard the `specify` bootstrap — a hang there must never wedge the runner, since
# _eval_install_assets already makes the scratch self-sufficient.
_bounded() { # <secs> <cmd...>
  local secs="$1"; shift
  "$@" & local pid=$!
  ( sleep "$secs"; kill -0 "$pid" 2>/dev/null && kill "$pid" 2>/dev/null ) & local w=$!
  wait "$pid" 2>/dev/null; local rc=$?
  kill "$w" 2>/dev/null; wait "$w" 2>/dev/null
  return $rc
}

# The fixture feature every case scaffolds into (matches tests/acceptance/helpers.sh).
EVAL_FEATURE="012-demo"
EVAL_FDIR="specs/012-demo"
export EVAL_FEATURE EVAL_FDIR

# dot-name → dashed slash-command slug (speckit.devflow.iterate → speckit-devflow-iterate),
# matching how spec-kit installs these (the prompts cross-reference the dashed form).
_slug() { basename "$1" .md | tr '.' '-'; }

# Copy devflow scripts, config, checker subagent, hooks, and the command docs (as dashed
# slash-commands) into <dir>. This is the floor: it runs with or without the `specify` CLI so
# the framework works in a bare CI. eval_bootstrap layers the real-CLI install on top when
# `specify` is present.
_eval_install_assets() {
  local dir="$1"
  mkdir -p "$dir/.specify/extensions/devflow" "$dir/.claude/commands" "$dir/.claude/agents"
  cp -R "$DEVFLOW_SRC/scripts" "$dir/.specify/extensions/devflow/"
  cp "$DEVFLOW_SRC/config-template.yml" "$dir/.specify/extensions/devflow/devflow-config.yml"
  cp "$DEVFLOW_SRC/assets/claude/agents/devflow-checker.md" "$dir/.claude/agents/"
  chmod +x "$dir/.specify/extensions/devflow/scripts/bash/"*.sh 2>/dev/null || true
  # slash commands under their dashed slugs so `/speckit-devflow-*` resolves in a claude -p run
  local f slug
  for f in "$DEVFLOW_SRC/commands/"*.md; do
    slug="$(_slug "$f")"
    cp "$f" "$dir/.claude/commands/$slug.md"
  done
  # hooks pack (Stop gate + PostToolUse) — best-effort, only matters for live iterate
  python3 "$DEVFLOW_SRC/scripts/python/merge_settings.py" \
    "$dir/.claude/settings.json" \
    "$DEVFLOW_SRC/assets/claude/settings-hooks.json" >/dev/null 2>&1 || true
}

# Path to an installed slash-command copy inside a scratch (what revert.sh mutates).
eval_cmd_path() { echo "$1/.claude/commands/$(_slug "$2").md"; }

# Real-CLI bootstrap: a fresh spec-kit + devflow project at <dir>, git-initialised, with a
# toy feature scaffolded. Uses `specify` when available (same path as test-01), then guarantees
# the asset floor. Pass EVAL_LIGHT=1 to skip `specify` (offline self-test).
eval_bootstrap() {
  local dir="$1"
  rm -rf "$dir"; mkdir -p "$dir"
  ( cd "$dir"
    git init -q -b main
    git config user.email "eval@example.com"; git config user.name "DevFlow Eval"
    if [ -z "${EVAL_LIGHT:-}" ] && command -v specify >/dev/null 2>&1; then
      # real-CLI install; bounded so a hang/prompt can't wedge the run (asset floor below covers it)
      _bounded "${EVAL_SPECIFY_TIMEOUT:-90}" specify init . --integration claude --ignore-agent-tools >/dev/null 2>&1 || true
      _bounded "${EVAL_SPECIFY_TIMEOUT:-90}" specify extension add "$DEVFLOW_SRC" --dev >/dev/null 2>&1 || true
    fi
  )
  _eval_install_assets "$dir"
  _eval_scaffold_feature "$dir"
  ( cd "$dir" && git add -A && git commit -qm "eval: bootstrap scratch" )
}

# A minimal spec-kit feature the cases operate on: feature.json + spec.md + tasks.md.
_eval_scaffold_feature() {
  local dir="$1"
  mkdir -p "$dir/$EVAL_FDIR/loop" "$dir/$EVAL_FDIR/review" "$dir/docs/decisions" "$dir/.specify/devflow" "$dir/.eval"
  printf '{"feature_directory": "%s"}\n' "$EVAL_FDIR" > "$dir/.specify/feature.json"
  cat > "$dir/$EVAL_FDIR/spec.md" <<'EOF'
# Spec: demo feature
## Refresh
Sessions use a fixed refresh window.
EOF
  cat > "$dir/$EVAL_FDIR/tasks.md" <<'EOF'
# Tasks
- [ ] T1 first thing
  - AC: does the first thing
- [x] T0 scaffolding
  - AC: repo builds
EOF
}

# Dispatch a case prompt through the driver, in <dir> as cwd, capturing the transcript to <out>.
# Live driver = `claude -p`. $DEVFLOW_EVAL_DRIVER overrides (receives: prompt, out, cwd as $1 $2 $3).
eval_dispatch() {
  local dir="$1" prompt="$2" out="$3"
  mkdir -p "$(dirname "$out")"
  if [ -n "${DEVFLOW_EVAL_DRIVER:-}" ]; then
    bash -c "$DEVFLOW_EVAL_DRIVER" _ "$prompt" "$out" "$dir"
  else
    command -v claude >/dev/null 2>&1 || { echo "eval_dispatch: no 'claude' CLI for the live driver; set DEVFLOW_EVAL_DRIVER or install claude" >&2; return 2; }
    # A case may drop .eval/env.sh to inject env into the session (e.g. the iterate case's
    # DEVFLOW_JUDGE_CMD judge-recorder). Source it inside the run so the agent's shells inherit it.
    ( cd "$dir"; [ -f .eval/env.sh ] && source .eval/env.sh; claude -p "$prompt" ) >"$out" 2>&1
  fi
}
