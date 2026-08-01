# ADR-0027: A real cross-family judge via the existing env seam

**Status:** Accepted (realizes [ADR-0003](0003-maker-plus-cross-family-judge.md) in practice through
[ADR-0014](0014-judge-wiring-role-env-seam.md); closes the gap [ADR-0018](0018-judge-fallback-same-family.md)
warns about)

**Context:** ADR-0003 made cross-family judging the recommended topology; ADR-0018 shipped a
same-family Claude fallback so the bundle works out of the box, warning loudly that same-family
self-checking is the documented weak layer. Until now nothing in practice supplied the cross-family
judge — every run took the fallback. With a local reasoning-family maker (ADR-0025), a local
judge of a *different* family (e.g. a Gemma-family model) is genuinely cross-family relative to the
maker, and the seam to use it already exists (`$DEVFLOW_JUDGE_CMD`). No bundle code changes.

**Decision:** Wire `$DEVFLOW_JUDGE_CMD` to a command that runs a **cross-family local model** as the
judge, reusing the bundle's exact contract and rubric:

- stdin `{diff, criteria, spec_slice}` → stdout `{verdict, reason, criteria[]}`, schema-validated by
  the bundle's `devflow-judge.sh` downstream (the adapter only generates and strips fences).
- The adapter reuses the **identical rubric text** from `devflow-judge.sh`'s fallback prompt, so the
  local judge and the Claude fallback judge by the same ADR-0003 rules (tests are the primary oracle;
  don't fail on out-of-diff code; spec beats a test the diff modifies).
- **Infra-fail ≠ code-fail** (the cross-family review's second finding): if the judge's backend is
  unreachable, the adapter must degrade to the Claude fallback — NOT return FAIL. A set-but-unreachable
  judge returning FAIL would, in autonomous mode, park every task blaming the code for an outage. The
  adapter detects backend-down and falls back to a fresh-context Claude verdict with a warning.

**Consequences:**
- **The recommended topology becomes the actual one.** Onboard reports `judge ✓ (cross-family)`
  instead of `⚠ fallback`; the maker's output is graded by a different model family, which is the
  whole point of ADR-0003. This is not a benchmark of judge accuracy — it closes the gap in practice,
  not in measurement.
- **Zero bundle change, low risk.** The seam, schema validation, and fail-safe are unchanged; only an
  environment variable now points at a cross-family command. Unset still falls back to Claude
  (ADR-0018) exactly as before.
- **Latency is real.** A reasoning-heavy local judge can take minutes per verdict; the adapter carries
  a generous timeout. That cost is the operator's to accept and is documented alongside the wiring
  (homelab `services/pi/`), not in the public bundle.
- Like the maker, the judge's host/vendor/endpoint live entirely in the environment; the bundle only
  ever declares the role.
