#!/usr/bin/env bash
# DevFlow internal git operations (ADR-0029): replicates the essential behavior of the external
# speckit.git.* commands so DevFlow depends ONLY on spec-kit core — no bundled git extension.
# git the binary is still a system prerequisite; the spec-kit *extension* is not.
#
# Usage:
#   devflow-git.sh feature "<description>"   -> create + switch to a numbered feature branch
#   devflow-git.sh validate                  -> assert we're on a feature branch (naming + spec dir)
#   devflow-git.sh commit "<message>"        -> stage all + commit (skips cleanly if nothing to commit)
set -euo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}"

_git_ok() { git rev-parse --is-inside-work-tree >/dev/null 2>&1; }

case "${1:-}" in
  feature)
    desc="${2:-feature}"
    _git_ok || { echo "[devflow] Warning: not a git repo; skipped branch creation" >&2; exit 0; }
    # Honor an explicit override, else derive a sequential number + slug.
    if [ -n "${GIT_BRANCH_NAME:-}" ]; then
      branch="$GIT_BRANCH_NAME"
    else
      # highest NNN- prefix under specs/ (or existing branches), + 1, zero-padded to 3
      last=$(ls -1 specs 2>/dev/null | grep -oE '^[0-9]{3,}' | sort -n | tail -1 || true)
      num=$(printf '%03d' $(( ${last:-0} + 1 )))
      slug=$(printf '%s' "$desc" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' \
             | sed -E 's/^-+|-+$//g' | cut -c1-40)
      branch="${num}-${slug:-feature}"
    fi
    if git rev-parse --verify "$branch" >/dev/null 2>&1; then
      git checkout "$branch"
    else
      git checkout -b "$branch"
    fi
    echo "[devflow] on feature branch: $branch"
    ;;

  validate)
    _git_ok || { echo "[devflow] Warning: not a git repo; skipped branch validation" >&2; exit 0; }
    branch=$(git rev-parse --abbrev-ref HEAD)
    if printf '%s' "$branch" | grep -qE '^[0-9]{3,}-' || printf '%s' "$branch" | grep -qE '^[0-9]{8}-[0-9]{6}-'; then
      echo "[devflow] ✓ on feature branch: $branch"
      prefix=$(printf '%s' "$branch" | grep -oE '^[0-9]+' || true)
      if [ -n "$prefix" ] && ! ls -d "specs/${prefix}"* >/dev/null 2>&1; then
        echo "[devflow] note: no specs/${prefix}* directory found for this branch" >&2
      fi
    else
      echo "[devflow] ✗ not on a feature branch ('$branch' — expected NNN-name or timestamp)" >&2
      exit 1
    fi
    ;;

  commit)
    msg="${2:?commit message required}"
    _git_ok || { echo "[devflow] Warning: not a git repo; skipped commit" >&2; exit 0; }
    git add -A
    if git diff --cached --quiet; then
      echo "[devflow] nothing to commit (tree clean)"
    else
      git commit -qm "$msg"
      echo "[devflow] committed: $msg"
    fi
    ;;

  *)
    echo "usage: devflow-git.sh feature|validate|commit [arg]" >&2; exit 2 ;;
esac
