# ADR-0013: Loop modes — attended / attended --step / autonomous

**Status:** Accepted

**Context:** ADR-0007 named the two loop modes `supervised` and `autonomous`. Reviewing the
flowchart, the operator read "supervised" as "needs my input per iteration" — which the mode
deliberately does not do (ADR-0002: the middle runs unattended; per-iteration approval
destroys autonomy). A mode name that promises input it never requests is a UX bug, and the
misreading surfaced a real need: sometimes a truly blocking, step-through run *is* wanted
(first runs, engine hardening, low-trust features — the Ralph literature's "watch the loop"
discipline).

**Decision:** Rename and split into three behaviors:

- **`attended`** (replaces `supervised`) — runs in the operator's terminal: live output,
  Claude Code default permissions (un-allowlisted actions prompt the human mid-iteration),
  read-only pulse between iterations, Ctrl+C/resume. **Never blocks waiting for approval.**
- **`attended --step`** (new) — same, but the between-iterations pulse **blocks**: the
  workflow pauses at each iteration boundary until the operator resumes. The honest form of
  "needs my input." Implemented on the existing pulse checkpoint (a gate that pauses), so
  it costs almost nothing to add.
- **`autonomous`** — headless: pre-approved tool allowlist via
  `SPECKIT_INTEGRATION_CLAUDE_EXTRA_ARGS`, no prompts, no pulse stop; the operator returns
  at STOP #2 (or on park/brake).

Mode changes neither gates nor protocol: STOPs, brakes, hooks, judge, record/commit are
identical in all three. Modes only change *human presence and permission posture*.

**Terminology (normative for all DevFlow docs and components):**

- **`attended` / `autonomous`** describe **human presence and permission posture** — is a
  human watching the terminal, and do un-allowlisted actions prompt them?
- **"unattended"** (as used by ADR-0002: "Build → Review → Verify runs unattended")
  describes **approval flow** — no human *approval* is required between the two STOPs.
  This holds in **every** mode, including `attended`: a watching human is not an approving
  human. Only `--step` inserts approval-like pauses, and those are iteration-boundary
  resumes, not phase gates.
- Reserve **"supervised"** for nothing — the word is retired to avoid re-importing the
  ambiguity ("supervision" read as per-step approval) that prompted this ADR.

**Consequences:** Names now match behavior; the step-through need has a first-class home
instead of ad-hoc Ctrl+C; `--step` gives new users a low-trust on-ramp that ADR-0002's
model otherwise lacks. Amends ADR-0007's mode names (`supervised` → `attended`; semantics
unchanged; 0007 and 0009 annotated in place). Visuals and future component docs use the
new names; the retired word must not reappear in component prompts, config keys, or docs.
