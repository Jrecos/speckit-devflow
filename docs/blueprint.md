# DevFlow blueprint

Distilled from [`research/loop-architecture-research.md`](research/loop-architecture-research.md).
Every choice here is tied to evidence in that report.

## The pipeline

```
Frame → Plan → Analyze
  → [HUMAN STOP #1]
  → Build loop  → Review → Verify
  → [HUMAN STOP #2]
  → Ship → Capture
```

- **Outer pipeline** (Spec Kit phases): each phase is a **separate session** consuming the
  previous phase's artifact. Review and Verify are *not* iterations of the build loop and
  cannot be reached into or skipped by it.
- **Inner Build loop** (Ralph-style): pick **one task** from `tasks.md` → implement → run
  scoped tests/typecheck (cheap mechanical critic, in-loop) → `record-decision` → auto-commit
  → exit iteration. Loop until `tasks.md` is exhausted or a budget/time-box hits.
  Target **40–60% context utilization**, one task per iteration — the single most-replicated
  finding in the literature, and the exact rule the over-scoped run (gap A) violated.

## Gate model — two human STOPs

Two camps in the evidence gate different granularities; adopt both:

- **STOP #1 — after Plan/Analyze, before Build.** Highest-leverage minutes in the pipeline:
  spec errors compound downstream, and the costliest documented failures are upstream
  (a bad spec word cost ~a month). A cheap human read of the plan (+ the failing acceptance
  tests) pays for itself.
- **Build → Verify runs unattended.** Automated gates only — per-edit lint/typecheck, tests,
  judge. Per-iteration human review destroys autonomy.
- **STOP #2 — after Verify, before Ship.** Non-negotiable: agents overstate completion, test
  oracles are gameable, expect "~90% done." **Ship sits behind the accept.**

Not "build→verify→ship then one accept." Not a gate on every phase.

## Verification stack (weakest → strongest; layer them, don't pick one)

1. **Mechanical critic per edit** — lint/typecheck *inside* every action. Cheapest, and
   ablations show removing it measurably degrades results.
2. **Tests as the primary oracle** — the strongest signal in the corpus. Write **failing
   acceptance tests at Plan time**; making them a visible target nearly doubled success in
   one study. Known hole: tests can be gamed / under-specified.
3. **Independent judge** for what tests can't express — a **cross-family** model maximizes
   independence (same-family self-checking is the documented weak layer). Because judge
   verdicts are themselves non-deterministic: **judge PASS = advisory into Review, judge
   FAIL = hard block back into the loop.**
4. **Human for intent** — the two STOPs.

Never let the maker declare itself done.

## Model topology

**Local maker + cross-family judge.** Supported by three evidence-backed patterns: role-split
beats peer-swarm; independent selection improves outcomes; same-model self-checking is weak.
Caveats: (a) a weaker local maker needs a *stronger harness* — tighter task decomposition,
maximal mechanical backpressure, whole-file edit format; (b) the judge gates **subjective**
criteria only — tests remain the primary oracle. (Cross-family superiority is design
reasoning, not benchmarked — flagged as a gap in the research.)

## Multi-agent stance

No evidence multi-agent beats single-agent for coding. Role-split pays (maker / judge /
editor / selector / read-scout); peer-swarms sharing mutable state on one task don't. Validates
maker + judge; rules out swarms.

## Harness stance

Stay minimal. "An agent is ~300 lines + tokens"; interface/guardrail details move success more
than orchestration sophistication. Durable state lives **on disk** (committed files), not in the
session. **Auto-commit is table stakes** — wire it so the agent cannot forget it.
