#!/usr/bin/env bash
# DevFlow internal agent-context refresh (ADR-0029): replicates the essential behavior of the
# external speckit.agent-context.update command so DevFlow depends only on spec-kit core.
# Refreshes a managed block in the agent context file(s) (CLAUDE.md / AGENTS.md) so the maker and
# checker sessions see a pointer to the CURRENT feature's plan. Idempotent: replaces the managed
# block in place, never duplicates it.
#
# Usage: devflow-agent-context.sh [plan_path]
#   plan_path optional; when omitted, uses the active feature's plan.md.
set -euo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}"

START="<!-- DEVFLOW-CONTEXT START -->"
END="<!-- DEVFLOW-CONTEXT END -->"

# Resolve the plan path.
PLAN="${1:-}"
if [ -z "$PLAN" ]; then
  FDIR=$(python3 -c 'import json;print(json.load(open(".specify/feature.json"))["feature_directory"])' 2>/dev/null || true)
  [ -n "$FDIR" ] && [ -f "$FDIR/plan.md" ] && PLAN="$FDIR/plan.md"
fi
[ -n "$PLAN" ] || { echo "[devflow] no plan to point at; nothing to do"; exit 0; }

BLOCK="$START
DevFlow active feature plan: \`$PLAN\`
(managed block — refreshed by devflow-agent-context.sh; edits here are overwritten)
$END"

# Update each existing agent-context file in place (or create CLAUDE.md if none exist).
updated=0
for f in CLAUDE.md AGENTS.md .github/copilot-instructions.md; do
  [ -f "$f" ] || continue
  if grep -qF "$START" "$f"; then
    python3 - "$f" "$START" "$END" "$BLOCK" <<'PY'
import sys, re
f, start, end, block = sys.argv[1:5]
txt = open(f).read()
new = re.sub(re.escape(start) + r".*?" + re.escape(end), lambda _: block, txt, flags=re.S)
open(f, "w").write(new)
PY
  else
    printf '\n%s\n' "$BLOCK" >> "$f"
  fi
  echo "[devflow] refreshed agent context in $f"
  updated=1
done
if [ "$updated" = "0" ]; then
  printf '%s\n' "$BLOCK" > CLAUDE.md
  echo "[devflow] created CLAUDE.md with the managed context block"
fi
