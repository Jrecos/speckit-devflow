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
# unanchored: config values carry trailing "# comments"
m=re.search(r"^\s*"+sys.argv[2]+r":\s*\"([^\"]*)\"", open(sys.argv[1]).read(), re.M)
print(m.group(1) if m else "")' "$CFG" "$1"; }
LINT=$(getcmd lint); TYPECHECK=$(getcmd typecheck)
errors=""
if [ -n "$LINT" ]; then
  if ! out=$(bash -c "$LINT" 2>&1); then errors+="LINT FAILED:\n$out\n"; fi
fi
if [ -n "$TYPECHECK" ]; then
  if ! out=$(bash -c "$TYPECHECK" 2>&1); then errors+="TYPECHECK FAILED:\n$out\n"; fi
fi
if [ -n "$errors" ]; then printf "%b" "$errors" >&2; exit 2; fi
exit 0
