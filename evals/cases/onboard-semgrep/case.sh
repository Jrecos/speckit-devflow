#!/usr/bin/env bash
# Eval case: onboard-semgrep  (dogfood findings 1 & 7)
#
# Behavior under test: when the agent runs the onboard Semgrep step, it registers the
# BUILT-IN server (`claude mcp add … -- semgrep mcp -t stdio`, telemetry off via env) and
# NOT the deprecated standalone `uvx semgrep-mcp` package (with its phantom `--metrics off`
# and `--semgrep-path` flags). The graded artifact is the project-scoped `.mcp.json` the
# agent writes into the scratch cwd.

case_meta() { echo "onboard-semgrep | findings 1,7 | onboard registers built-in 'semgrep mcp -t stdio', never the dead uvx package"; }

case_prompt() {
  cat <<'EOF'
/speckit-devflow-onboard

Scope for this run: perform ONLY step 2 (Semgrep MCP) against THIS project — register the
semgrep MCP server at project scope with `claude mcp add`. Do not run any other onboard step,
do not install tools, do not verify the live connection. Register the server and then stop.
EOF
}

# Reproduce finding 7's on-machine condition: a STALE standalone `uvx semgrep-mcp`
# registration is already present (the package that only prints a deprecation notice now).
# A correct onboard run detects it as notice-only and REPLACES it with the built-in server.
case_bootstrap() { # <scratch>
  cat > "$1/.mcp.json" <<'EOF'
{"mcpServers":{"semgrep":{"type":"stdio","command":"uvx","args":["semgrep-mcp"],"env":{}}}}
EOF
}

case_grade() { # <scratch> <transcript>
  local dir="$1"
  local mcp="$dir/.mcp.json"
  [ -f "$mcp" ] || { enote "no .mcp.json written — agent never registered a server"; return 1; }
  python3 - "$mcp" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
s = (data.get("mcpServers") or {}).get("semgrep")
if not s:
    print("no 'semgrep' server in .mcp.json", file=sys.stderr); sys.exit(1)
blob = json.dumps(s)
cmd = (s.get("command") or "").split("/")[-1]
args = s.get("args") or []
env  = s.get("env") or {}
bad = [t for t in ("uvx", "semgrep-mcp", "--semgrep-path", "--metrics") if t in blob]
ok = (
    cmd == "semgrep"
    and "mcp" in args
    and "stdio" in blob
    and "SEMGREP_SEND_METRICS" in env
    and not bad
)
if not ok:
    print(f"semgrep registration is not the built-in server: command={cmd!r} args={args} "
          f"metrics_env={'SEMGREP_SEND_METRICS' in env} forbidden={bad}", file=sys.stderr)
    sys.exit(1)
print("built-in semgrep server registered (semgrep mcp -t stdio, telemetry off)")
PY
}

# Revert finding 1 & 7's fix in the INSTALLED onboard prompt back to the PRE-fix step 2:
# register the standalone uvx package with the phantom flags, and neutralise the deprecation
# guard so the reverted prompt is coherent (else a capable agent notices the self-contradiction
# and "corrects" it, masking the regression). A live run after this must go RED.
case_revert() { # <scratch>
  local f; f="$(eval_cmd_path "$1" speckit.devflow.onboard.md)"
  perl -0pi -e 's/the standalone `semgrep-mcp` uvx package is \*\*deprecated\*\* \(it only\s+prints a notice pointing here; do not register it\)/the standalone `semgrep-mcp` uvx package is the server to register/s' "$f"
  perl -0pi -e 's/register the built-in server:/register it:/g' "$f"
  perl -0pi -e 's/-- semgrep mcp -t stdio/-- uvx semgrep-mcp --semgrep-path \$(command -v semgrep)/g' "$f"
  perl -0pi -e 's/SEMGREP_SEND_METRICS=off/--metrics off/g' "$f"
}

# --- deterministic sims for --self-test (stand in for the live agent) -------------------
case_sim_pass() { # a correct agent's .mcp.json
  cat > "$1/.mcp.json" <<'EOF'
{"mcpServers":{"semgrep":{"type":"stdio","command":"semgrep","args":["mcp","-t","stdio"],"env":{"SEMGREP_SEND_METRICS":"off"}}}}
EOF
}
case_sim_revert() { # a reverted-prompt agent's .mcp.json (the pre-fix dead package)
  cat > "$1/.mcp.json" <<'EOF'
{"mcpServers":{"semgrep":{"type":"stdio","command":"uvx","args":["semgrep-mcp","--metrics","off","--semgrep-path","/usr/bin/semgrep"],"env":{}}}}
EOF
}
