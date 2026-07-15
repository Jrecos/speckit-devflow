#!/usr/bin/env bash
# Clean-machine tripwire: install the 3 PACKAGED release assets (the zips/yaml a
# real end user downloads) into a fresh scratch project, the way a user actually
# would — not `--dev` straight from source, which would never exercise packaging
# bugs or catch upstream drift in a pinned tool (roadmap.md dogfood finding #7).
#
# Usage: scripts/onboard-smoke.sh [dist-dir]   (default: <repo>/dist)
#
# Standalone-runnable; also invoked by scripts/release.sh after it builds dist/.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../tests/acceptance/helpers.sh"   # REPO_ROOT, fail(), pass()

DIST_DIR="${1:-$REPO_ROOT/dist}"
[ -d "$DIST_DIR" ] || fail "dist dir not found: $DIST_DIR (build release assets first, e.g. via scripts/release.sh)"
for f in devflow-extension.zip devflow-plan-hardening.zip devflow-workflow.yml; do
  [ -f "$DIST_DIR/$f" ] || fail "missing release asset: $DIST_DIR/$f"
done
command -v specify >/dev/null || fail "specify CLI not on PATH"

EXPECTED_VERSION=$(python3 -c '
import re
text = open("'"$REPO_ROOT"'/components/extensions/devflow/extension.yml").read()
print(re.search(r"(?m)^  version: \"([\d.]+)\"$", text).group(1))
')

# Serve dist/ over local HTTP: `specify extension/preset add --from` requires HTTPS
# except for localhost, which is exactly the loophole that lets this test the real
# --from download path (as opposed to --dev, which bypasses the zip entirely) without
# any network access or a published release.
PORT=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')
( cd "$DIST_DIR" && exec python3 -m http.server "$PORT" --bind 127.0.0.1 >/tmp/onboard-smoke-http.log 2>&1 ) &
HTTP_PID=$!
SCRATCH=""
cleanup() {
  kill "$HTTP_PID" >/dev/null 2>&1 || true
  wait "$HTTP_PID" 2>/dev/null || true
  [ -n "$SCRATCH" ] && rm -rf "$SCRATCH"
}
trap cleanup EXIT

for _ in $(seq 1 25); do
  curl -sf "http://127.0.0.1:$PORT/devflow-workflow.yml" -o /dev/null 2>/dev/null && break
  sleep 0.2
done
curl -sf "http://127.0.0.1:$PORT/devflow-workflow.yml" -o /dev/null \
  || fail "local smoke HTTP server on port $PORT never came up (see /tmp/onboard-smoke-http.log)"

SCRATCH=$(mktemp -d)
( cd "$SCRATCH" && specify init . --integration claude --ignore-agent-tools >/dev/null 2>&1 ) \
  || fail "specify init failed (check flags with 'specify init --help')"
cd "$SCRATCH"

echo y | specify extension add devflow --from "http://127.0.0.1:$PORT/devflow-extension.zip" \
  >/tmp/onboard-smoke-ext.log 2>&1 \
  || fail "extension install from packaged zip failed (see /tmp/onboard-smoke-ext.log)"
echo y | specify preset add --from "http://127.0.0.1:$PORT/devflow-plan-hardening.zip" \
  >/tmp/onboard-smoke-preset.log 2>&1 \
  || fail "preset install from packaged zip failed (see /tmp/onboard-smoke-preset.log)"
specify workflow add "http://127.0.0.1:$PORT/devflow-workflow.yml" \
  >/tmp/onboard-smoke-workflow.log 2>&1 \
  || fail "workflow install from packaged file failed (see /tmp/onboard-smoke-workflow.log)"

# captured via command substitution, not piped straight into grep: specify's Rich-based
# output rendering raced a live pipe reader and intermittently truncated (observed empirically) —
# capturing the full buffer first makes the check deterministic.
ext_list_out=$(specify extension list 2>/dev/null)
printf '%s' "$ext_list_out" | grep -q "v$EXPECTED_VERSION" \
  || fail "extension list does not report v$EXPECTED_VERSION after a clean install (packaging/version-bump drift)"

skill_count=$(find .claude/skills -maxdepth 1 -type d -name 'speckit-devflow-*' 2>/dev/null | wc -l | tr -d ' ')
[ "$skill_count" -eq 9 ] || fail "expected 9 speckit-devflow-* skills rendered at .claude/skills/, found $skill_count"

# Upstream-drift check (roadmap.md dogfood finding #7): DevFlow depends on the
# semgrep binary's BUILT-IN `mcp` subcommand (the standalone semgrep-mcp package is
# deprecated). semgrep itself is an optional local tool, so its total absence only
# warns; but if it's installed and has silently lost the `mcp` subcommand, that is
# exactly the drift class this check exists to catch, and it fails hard.
if ! command -v semgrep >/dev/null 2>&1; then
  echo "onboard-smoke: WARN — semgrep not installed; skipping upstream MCP drift check (optional tool)" >&2
elif semgrep mcp --help </dev/null >/tmp/onboard-smoke-semgrep.log 2>&1; then
  echo "onboard-smoke: semgrep mcp subcommand present (built-in MCP server) — OK"
else
  fail "upstream drift: 'semgrep mcp --help' failed — the built-in MCP server may have moved/been removed upstream (see /tmp/onboard-smoke-semgrep.log; cf. docs/roadmap.md dogfood finding #7)"
fi

pass "onboard smoke: clean install reports v$EXPECTED_VERSION, 9 skills rendered, semgrep MCP present"
