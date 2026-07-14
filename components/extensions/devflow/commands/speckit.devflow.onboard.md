---
description: "Validate and install every DevFlow prerequisite at project scope: commands config, semgrep MCP, judge seam, hooks pack, checker subagent, CLAUDE.md protocol"
---

# DevFlow Onboard — make this project workflow-ready

Validate and install every prerequisite. Report a checklist at the end; a repo
where every line is ✓ can run `specify workflow run devflow` immediately.

## Steps

1. **Tools:** verify `git` and `claude` are on PATH (`command -v`). Verify this is
   a git repo with at least one commit.
2. **Semgrep MCP:** run `claude mcp list`; if `semgrep` is absent, run:
   `claude mcp add semgrep --scope project -- uvx semgrep-mcp --metrics off`
   (the `--` separates the server command from claude's own flags).
3. **Project commands:** detect the project's lint / typecheck / scoped-test /
   full-test commands (inspect package.json scripts, Makefile, pyproject.toml,
   etc.). Present your proposals to the human, then write the confirmed values
   into `.specify/extensions/devflow/devflow-config.yml` under `commands:` —
   **keep each value double-quoted** (`test_scoped: "npm test"`): the hook
   scripts parse quoted values only; an unquoted value reads as empty.
   These power the hooks — with empty values the PostToolUse critic is inert and
   the Stop gate blocks every GREEN close.
4. **Judge seam:** check whether `DEVFLOW_JUDGE_CMD` is set.
   - **Set:** smoke-test it — create trivial diff/criteria/slice temp files, run
     `bash .specify/extensions/devflow/scripts/bash/devflow-judge.sh <d> <c> <s>`,
     require a schema-valid verdict. Ask the human what model family stands behind
     it; **warn clearly if it is the same family as the maker (Claude)** —
     same-family self-checking is the documented weak layer (ADR-0003).
     Checklist: `judge ✓ (cross-family)` or `judge ⚠ (same-family by choice)`.
   - **Unset:** the seam falls back to **Claude as judge** (ADR-0018) — still an
     independent fresh context, but same-family. Smoke-test the fallback the same
     way; tell the human plainly: *"No DEVFLOW_JUDGE_CMD set — running with the
     same-family Claude fallback. Recommended upgrade: one env var pointing at any
     cross-family model."* Checklist: `judge ⚠ fallback (same-family)`.
   A verdict per iteration remains required either way; only if neither the env
   var nor a `claude` CLI resolves does the line become ✗ (loop cannot run).
5. **Hooks pack:** run
   `python3 .specify/extensions/devflow/scripts/python/merge_settings.py .claude/settings.json .specify/extensions/devflow/assets/claude/settings-hooks.json`
   (idempotent — safe to re-run).
6. **Checker subagent:** `mkdir -p .claude/agents` then copy
   `.specify/extensions/devflow/assets/claude/agents/devflow-checker.md` into it
   (skip if identical content already present).
7. **CLAUDE.md protocol:** if `CLAUDE.md` lacks the marker `<!-- devflow-protocol -->`,
   append the contents of
   `.specify/extensions/devflow/assets/claude/claude-md-protocol.md` to it.
8. **Dispatch sanity:** confirm the project's spec-kit claude integration dispatch
   does not pass `--bare` (which would disable hooks, skills, and CLAUDE.md):
   check `SPECKIT_INTEGRATION_CLAUDE_EXTRA_ARGS` and any project config for it.
9. **Script permissions:** `chmod +x .specify/extensions/devflow/scripts/bash/*.sh`
10. **Gitignore hygiene (ADR-0017):** ensure `.gitignore` contains these entries
    (append any that are missing; never remove existing lines):
    - `CLAUDE.local.md` and `.claude/settings.local.json` (the official local-pair
      convention — personal config stays out of the shared repo)
    - `.env` and `.env.*` (where `DEVFLOW_JUDGE_CMD` and other secrets live)
    Do NOT gitignore `loop/state.json` or `review/findings.json` — they are the
    loop's on-disk coordination contract and audit trail, committed on feature
    branches by design (squash-merge keeps them out of main's linear history).
11. **Report** the checklist: tools ✓/✗ · semgrep ✓/✗ · commands ✓/✗ · judge ✓/✗
    (+family warning if any) · hooks ✓/✗ · checker ✓/✗ · CLAUDE.md ✓/✗ ·
    dispatch ✓/✗ · gitignore ✓/✗.
