# ADR-0018: Judge fallback — Claude by default when no cross-family judge is configured

**Status:** Accepted (amends [ADR-0014](0014-judge-wiring-role-env-seam.md); scopes
[ADR-0003](0003-maker-plus-cross-family-judge.md))

**Context:** ADR-0014 made `DEVFLOW_JUDGE_CMD` mandatory (`judge.required: true` — no judge,
no loop). That guarantees verification independence but also makes DevFlow unusable
out-of-the-box for anyone without a second model family wired up — a real adoption wall for
a public bundle. The operator's call: make the env var optional, falling back to Claude.

**Decision:** `DEVFLOW_JUDGE_CMD` becomes **optional**. When unset, `devflow-judge.sh`
falls back to **Claude as the judge** (`claude -p` with a strict verdict prompt), with
guardrails:

- **Loud, every time:** the fallback prints a stderr warning on every invocation
  ("same-family fallback — cross-family judging is the recommended topology"), and
  onboard's checklist reports `judge: ⚠ fallback (same-family)` instead of ✓.
- **Isolated from the harness:** the fallback runs `claude -p` from a **temp directory**,
  never the project root — inside an iterate session `in_iteration` is true, and a
  project-cwd subprocess would arm our own Stop-gate against the judge call (and load
  project hooks/CLAUDE.md into what must be an independent context).
- **Independent-context, not independent-family:** the fallback is still a fresh context
  with an adversarial prompt and the same schema-validated verdict contract — strictly
  better than maker self-grading, strictly weaker than cross-family. The verification
  stack degrades one notch; it does not collapse.
- **Fail-safe unchanged:** if neither `DEVFLOW_JUDGE_CMD` nor a `claude` CLI is available,
  or output is malformed, the script exits non-zero and the iteration blocks — a judge
  verdict is still required for every iteration (`judge.required: true` keeps that
  meaning; what changed is how the role resolves).

**Consequences:** Zero-config adoption works (install → onboard → run), and the upgrade
path is one env var. Cost: default installs run same-family judging — the exact weak layer
ADR-0003 documents — mitigated by the per-invocation warning, the onboard ⚠, and the
unchanged recommendation. ADR-0003's flagged evidence gap (cross-family superiority is
design reasoning, not benchmarked) makes this an acceptable default rather than a reckless
one. Revisit if real runs show fallback judges rubber-stamping maker output.
