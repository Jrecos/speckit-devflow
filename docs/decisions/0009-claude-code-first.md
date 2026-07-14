# ADR-0009: Claude Code first — native harness enforcement over portable prompts

**Status:** Accepted

**Context:** Spec-kit workflows dispatch commands to any integration (`claude -p`,
`copilot`, `gemini`, …), so a portable bundle is possible. But the retro's hardest gaps
(C: decisions unrecorded; E: no auto-commit) failed precisely because they were
prompt-enforced. Claude Code exposes native harness primitives other integrations lack:
lifecycle **hooks** (fire mechanically, agent cannot skip them), **subagents** (fresh
independent context per role), headless-mode flags injectable via spec-kit's sanctioned
`SPECKIT_INTEGRATION_CLAUDE_EXTRA_ARGS` env var, deterministic **CLAUDE.md** context
loading, and project-scoped **MCP** config. We use Claude Code for all real work today.

**Decision:** DevFlow v0.x targets **Claude Code only**: `integration: claude` is pinned
in `bundle.yml` (installs refuse on non-Claude projects rather than degrade silently).
The bundle leans on native Claude features as the *primary* enforcement layer:

- **Hooks pack** (project `.claude/settings.json`, installed by onboarding):
  - `PostToolUse` on Edit/Write → per-edit lint/typecheck (mechanical critic in-harness).
  - Iteration-exit enforcement → block completion until the decision record exists
    (gap C) and auto-commit on green (gap E).
- **Checker/judge as subagents** with their own context (maker never self-grades,
  ADR-0003), spawned by the iterate/verify commands.
- **Loop modes** (ADR-0013 naming) map to native flags: `attended` = default permissions
  (un-allowlisted actions prompt the human; the loop itself never waits); `attended
  --step` = same + a blocking pause at each iteration boundary;
  `autonomous` = pre-approved tool allowlist + permission mode via extra-args.
- **CLAUDE.md** carries the loop-protocol invariants so every fresh iteration reloads
  them deterministically.

Portability to other integrations is deferred, not rejected: the markdown command layer
spec-kit renders per-integration stays intact, so a later ADR can relax the pin and add
prompt-enforced fallbacks for the hook layer.

**Consequences:** Gaps C and E are fixed by the harness itself — the strongest available
enforcement, matching the research's "interface/guardrail details beat orchestration
sophistication." Cost: smaller audience for v0.x and a Claude-specific hooks artifact to
maintain; accepted while we dogfood. Amends ADR-0001's "agnostic integration" consequence
(the bundle model still expresses it; we choose to pin).
