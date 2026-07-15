---
description: "Validates and installs every DevFlow prerequisite at project scope: tool checks, semgrep MCP, project lint/typecheck/test commands into config, judge seam smoke-test, hooks pack, checker subagent, CLAUDE.md protocol, gitignore hygiene. Use once per project after bundle install, or re-run anytime to re-validate — it is idempotent. Keywords: onboard, setup, install hooks, prerequisites, configure devflow, workflow-ready."
---

# DevFlow Onboard — make this project workflow-ready

## Standing rules

- Idempotent by design: every step checks before it changes; re-running is always
  safe. Never duplicate hook entries, CLAUDE.md blocks, or gitignore lines.
- Config values you write are **double-quoted** — the hook scripts parse quoted
  values only; an unquoted value reads as empty and disables the hook.

## Progress checklist (copy into your response; check off as you go)

```
- [ ] 1. tools        - [ ] 6. checker subagent
- [ ] 2. semgrep MCP  - [ ] 7. CLAUDE.md protocol
- [ ] 3. commands     - [ ] 8. dispatch sanity
- [ ] 4. judge seam   - [ ] 9. script permissions
- [ ] 5. hooks pack   - [ ] 10. gitignore
```

## Steps

1. **Tools** (REQUIRED): `command -v git` and `command -v claude` both resolve; the
   directory is a git repo with ≥1 commit. *Any missing:* abort with the exact
   install instruction — nothing later works without these.
2. **Semgrep MCP** (for Review's Semgrep pass): if `claude mcp list` doesn't show
   `semgrep`, register it — handling these known pitfalls rather than trusting one literal:
   - semgrep-mcp's protobuf extension crashes under Python 3.14 → pin `uvx --python 3.12`.
   - there is **no `--metrics` flag**; disable telemetry with env `SEMGREP_SEND_METRICS=off`.
   - if the `semgrep` CLI itself is missing, `uv tool install semgrep`, then pass
     `--semgrep-path "$(command -v semgrep)"`.
   A form verified to work (adapt versions/paths to the machine):
   `claude mcp add semgrep -s project -e SEMGREP_SEND_METRICS=off -- uvx --python 3.12 semgrep-mcp --semgrep-path "$(command -v semgrep)"`
   Confirm it connects (`claude mcp list`). Note `.mcp.json` is commonly gitignored, so
   this registration is per-clone — other clones/machines re-run this step.
3. **Project commands** (REQUIRED — hooks are inert without them): detect lint /
   typecheck / scoped-test / full-test commands (package.json scripts, Makefile,
   pyproject.toml…). Present proposals to the human, **wait for confirmation**, then
   write the confirmed values — double-quoted — into
   `.specify/extensions/devflow/devflow-config.yml` under `commands:`.
4. **Judge seam**: is `DEVFLOW_JUDGE_CMD` set?
   - **Set** → smoke-test: trivial diff/criteria/slice temp files through
     `bash .specify/extensions/devflow/scripts/bash/devflow-judge.sh <d> <c> <s>`;
     require a schema-valid verdict. Ask what model family stands behind it; warn
     clearly if same-family as the maker (Claude) — the documented weak layer
     (ADR-0003). Checklist: `judge ✓ (cross-family)` or `judge ⚠ (same-family by choice)`.
   - **Unset** → the seam falls back to Claude (ADR-0018). Smoke-test the fallback
     the same way and tell the human plainly: *"No DEVFLOW_JUDGE_CMD set — running
     with the same-family Claude fallback. Recommended upgrade: one env var pointing
     at any cross-family model."* Checklist: `judge ⚠ fallback (same-family)`.
   - Only if neither the env var nor a `claude` CLI resolves: `judge ✗` (loop
     cannot run).
5. **Hooks pack**: run exactly
   `python3 .specify/extensions/devflow/scripts/python/merge_settings.py .claude/settings.json .specify/extensions/devflow/assets/claude/settings-hooks.json`
   (idempotent merge; prints `merged` or `already-present`).
6. **Checker subagent**: `mkdir -p .claude/agents`, copy
   `.specify/extensions/devflow/assets/claude/agents/devflow-checker.md` there
   (skip if identical content already present).
7. **CLAUDE.md protocol**: if `CLAUDE.md` lacks the marker
   `<!-- devflow-protocol -->`, append the contents of
   `.specify/extensions/devflow/assets/claude/claude-md-protocol.md`.
8. **Dispatch sanity**: confirm the claude dispatch carries no `--bare` (it would
   disable hooks, skills, and CLAUDE.md — the whole enforcement layer): check
   `SPECKIT_INTEGRATION_CLAUDE_EXTRA_ARGS` and project config.
9. **Script permissions**: `chmod +x .specify/extensions/devflow/scripts/bash/*.sh`
10. **Gitignore hygiene** (ADR-0017): ensure `.gitignore` contains
    `CLAUDE.local.md`, `.claude/settings.local.json`, `.env`, `.env.*` — append any
    missing, never remove existing lines. Do NOT ignore `loop/state.json` or
    `review/findings.json` (committed on feature branches by design).

## Done when

Every checklist line reports ✓ (or an explicit, explained ⚠). Print the final
table: tools · semgrep · commands · judge (+family note) · hooks · checker ·
CLAUDE.md · dispatch · permissions · gitignore. Any ✗ = the project is NOT
workflow-ready; the line's step names the fix.

## Handoff

A fully-✓ project runs `specify workflow run devflow --input feature="..."` or
`/speckit-devflow-start <feature>` — tell the user both options.
