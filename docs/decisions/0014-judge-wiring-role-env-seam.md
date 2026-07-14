# ADR-0014: Judge wiring — role in the bundle, resolution in the environment

**Status:** Accepted

**Context:** ADR-0003 settled *that* a cross-family judge gates each iteration (PASS
advisory, FAIL hard-block) and the whole diff at Verify. Open was the plumbing (HANDOFF
Q6), under a hard constraint: this repo is public — no endpoints, hostnames, or model
names may ship in it. Candidates: (A) checker as a Claude subagent + judge via an
env-defined shell command; (B) a dedicated judge MCP server in `requires.mcp`; (C) the
judge as a second spec-kit integration dispatched by the workflow engine.

**Decision:** **Option A** — split by visibility:

- **Public (in the bundle):** the judge is referenced **by role only**. `devflow-config.yml`
  declares `judge: {role: cross-family-judge, required: true, votes: 1}` and
  `checker: {role: independent-checker, independent: true}`, plus the **verdict contract**:
  `{"verdict": "PASS"|"FAIL", "reason": str, "criteria": [{name, pass, note}]}` — written
  to loop state (iterations) or `verify-report.md` (Verify), so retry iterations and
  humans consume verdicts from disk.
- **Private (user env, never committed):** `DEVFLOW_JUDGE_CMD` — a command that reads
  `{diff, criteria, spec-slice}` on stdin and emits verdict JSON on stdout. Anything can
  stand behind it (another family's CLI, an MCP bridge, a local runtime); the bundle
  neither knows nor cares. `.gitignore` already blocks `.env*`.
- **Checker** = native Claude subagent (fresh context, zero config) — same-family but
  context-independent; it guards done-criteria drift, while the judge guards family-level
  blind spots.
- **One mechanism, two call sites:** the same `DEVFLOW_JUDGE_CMD` seam serves the
  per-iteration exit gate and Verify's whole-diff pass — no drift between them.
- **Onboarding validates the seam:** role resolvable → smoke-test one verdict → warn if
  judge and maker are the same family. In `autonomous` mode the judge command is added to
  the pre-approved allowlist (ADR-0009/0013).

**Consequences:** Zero topology leaks into the public repo; any environment can supply any
judge with a one-line env var; no new artifacts to maintain. Costs: a shell-escape seam
(mitigated: the command is user-defined in their own env, allowlisted explicitly, and its
output is schema-validated before use) and stdin/stdout parsing (mitigated by the pinned
JSON contract — malformed output = judge failure = iteration blocks, fail-safe). Rejected:
(B) requires building/maintaining an MCP server — against "stay minimal"; (C) the engine
only reaches phase granularity, but the judge gates *inside* iterations — same structural
reason Python step types were rejected (ADR-0010).
