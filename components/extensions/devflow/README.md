# devflow extension

The DevFlow loop engine: one task per fresh-context iteration, maker/checker/judge
verification, a close-contract Stop gate with auto-commit, and the pipeline commands
(review / verify / reconcile-contract / capture) the `devflow` workflow dispatches.

## What installs where

The extension directory is copied wholesale to `.specify/extensions/devflow/` —
including `assets/` and `scripts/`. Spec-kit never writes into `.claude/`;
**`/speckit-devflow-onboard` merges the Claude-side pieces into place**:

- `assets/claude/settings-hooks.json` → merged into `.claude/settings.json`
  (PostToolUse lint/typecheck critic + the matcher-less Stop gate)
- `assets/claude/agents/devflow-checker.md` → `.claude/agents/`
- `assets/claude/claude-md-protocol.md` → appended to `CLAUDE.md`

## The judge seam

The cross-family judge is referenced **by role only**. Your environment resolves it:

```bash
export DEVFLOW_JUDGE_CMD='<any command that reads {"diff","criteria","spec_slice"} JSON on stdin and prints a verdict JSON>'
```

Verdict contract: `{"verdict":"PASS"|"FAIL","reason":"...","criteria":[{"name","pass","note"}]}`.
Missing env or malformed output fails safe (treated as FAIL). No endpoint, host, or
model name ever ships in this repo.

## Modes (ADR-0013)

`attended` (live output, base allowlist, never waits) · `attended-step` (blocking pause
per iteration boundary) · `autonomous` (headless, pre-approved allowlist via
`SPECKIT_INTEGRATION_CLAUDE_EXTRA_ARGS`). Gates, brakes, and the close contract are
identical in all three.

Design record: `docs/decisions/` ADRs 0006–0016 and
`docs/superpowers/specs/2026-07-13-devflow-bundle-design.md` in the repo root.
