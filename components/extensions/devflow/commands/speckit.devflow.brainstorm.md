---
description: "Pressure-test the drafted spec for edge cases, ambiguities, and contradictions before planning, then revise spec.md in place. DevFlow-internal (ADR-0029) so the bundle depends only on spec-kit core. Use in the Frame phase right after specify. Keywords: brainstorm, pressure-test, edge cases, spec review, adversarial spec."
---

# DevFlow Brainstorm — pressure-test the spec before planning

Stress the freshly-drafted `spec.md` the way a skeptical reviewer would, then fold what you
find back into the spec. This is the Frame-phase hardening step: a spec that survives it
produces a plan that doesn't collapse on the first edge case. DevFlow-internal so the bundle
carries no external `superspec` dependency (ADR-0029).

## Standing rules

- You edit **only** `spec.md` (the contract). You do not write plan, tasks, or code here.
- Every change you make must be a spec-level clarification — a rule, a boundary, an acceptance
  condition — never an implementation detail.
- If you cannot resolve an ambiguity from the spec + the user's intent, record it as an open
  question in the spec rather than inventing an answer.

## Steps

1. **Read** `spec.md` in full (resolve the feature dir from `.specify/feature.json` →
   `feature_directory`). Treat it as a claim to be broken, not a document to admire.

2. **Pressure-test** along these axes, in order:
   - **Edge cases** — empty inputs, maximum sizes, concurrent actors, the zero/one/many
     boundaries, the first and last item, time zones, permissions denied.
   - **Contradictions** — two requirements that cannot both hold; a happy-path that violates a
     stated invariant; an example that disagrees with the prose.
   - **Ambiguity** — any requirement a reasonable engineer could implement two incompatible ways.
   - **Missing acceptance conditions** — behavior described with no observable pass/fail.
   - **Unstated assumptions** — auth, data retention, error surfaces, idempotency.

3. **Revise `spec.md` in place** for each real issue: tighten the wording, add the missing
   boundary, resolve the contradiction (favoring the user's intent), or add an explicit open
   question. Keep the spec readable — clarifications, not bloat.

4. **Report** a short summary: what you hardened, what contradictions you resolved and how, and
   any open questions you left for the human. This report is for the run log; the durable output
   is the revised `spec.md`.

## Done when

`spec.md` has been read, pressure-tested on the axes above, and revised in place for every real
issue found (or a clean bill of health stated explicitly), with a one-paragraph summary of the
changes and any open questions.

## Handoff

None — the pipeline proceeds to `clarify` then `plan`, which read the hardened `spec.md`.
