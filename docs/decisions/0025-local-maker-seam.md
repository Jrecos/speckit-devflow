# ADR-0025: Local maker seam — role in the bundle, resolution in the environment

**Status:** Accepted (un-defers the maker half of [ADR-0003](0003-maker-plus-cross-family-judge.md);
mirrors [ADR-0014](0014-judge-wiring-role-env-seam.md); honors the three-layer rule of
[ADR-0010](0010-fix-enforcement-layers.md))

**Context:** ADR-0003 chose a local maker + cross-family judge, but ADR-0009/0016 **deferred maker
locality** — v0.x pinned Claude as the maker (cloud). Only the judge had an env seam. The judge
pattern (ADR-0014) proved out: a role named in the bundle, resolved by `$DEVFLOW_JUDGE_CMD` in the
environment, with a fail-safe fallback to Claude. A measured bake-off (Pi + a local reasoning model
vs. cloud Claude, quality-judged) showed a local maker is viable when the harness stays strong. So
the maker seam is now built — additively, so that unset = exact status quo.

**Decision:** Add a **maker seam** mirroring the judge seam, at the one injection point that keeps
every layer-2 guarantee: the iterate command's *Implement* step. The dispatch stays `claude -p
/iterate` (hooks, Stop-gate, checker, CLAUDE.md all intact). Inside that session, the maker may
generate the code; **Claude always applies it with its Write tool**, so the PostToolUse
lint/typecheck hook and the Stop-gate close contract fire exactly as before. The local model does
the heavy typing; Claude keeps the guarantees.

- **Public = role.** `devflow-config.yml` declares `maker: {role: local-maker, required: false,
  edit_format: whole-file, escalation: {...}}`. No host, no vendor, no endpoint — the bundle never
  knows your topology.
- **Private = `$DEVFLOW_MAKER_CMD`.** A command that reads the maker payload on stdin
  (`{task_id, instruction, criteria, spec_slice, files:[{path,content}], constraints}`, assembled by
  `devflow-maker-prep.sh`) and prints `{"files":[{path,content}], "notes"?}` on stdout.
- **Exit contract** (the design decision that differs from the judge):
  - `0` → valid files JSON; the caller applies each file with Write.
  - `3` → no maker configured (or the last tier, or the adapter signals a dead backend): the caller
    types the code itself — **Claude-sufficient** (ADR-0020), not a failure, no warning.
  - `1` → a configured maker ran but produced bad/empty/malformed output: a **failed attempt** that
    feeds the escalation ladder (ADR-0026), never a silent success.
- **Whole-file edit format** (ADR-0003): a weaker local model is unreliable at exact-match diffs;
  it rewrites whole files, and the payload carries the current file contents so it can preserve them.
- **Mechanical anti-regression (layer 2, not prose).** Passing current contents is only input
  shaping. `devflow-maker.sh` also *rejects* (exit 1) any output that (a) writes a path the maker was
  never shown, or (b) shrinks an existing file past a threshold — turning "a weak model silently
  deleted prior code" (the observed worst failure) into a mechanical check, per ADR-0010.
- **Tolerates real deviations.** Local models sometimes emit a stray `{"notes": ...}` object inside
  the `files` array; the seam salvages the note and normalizes the files rather than failing.

**Consequences:**
- **Additive and fail-safe.** With `DEVFLOW_MAKER_CMD` unset the loop is byte-for-byte the old
  behavior (Claude types). A misbehaving maker degrades to Claude or to a failed attempt — never a
  bad commit.
- **Layer discipline held.** The prompt (layer 3) only *routes* typing; every guarantee (lint,
  one-task GREEN close, auto-commit, anti-regression) lives in hooks/scripts (layer 2). If the prompt
  is ignored, worst case Claude types the task — the benign fallback.
- **The judge's independence still matters more.** A local maker graded by a same-family checker and
  a cross-family judge (ADR-0026/0027) is the intended topology; the maker being local strengthens
  the case for a genuinely cross-family judge.
- Homelab wiring (Pi → LiteLLM → local models, golden rule) lives outside this repo; the bundle only
  ever sees the generic env var.
