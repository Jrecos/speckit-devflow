# ADR-0021: Command-authoring doctrine — the verified checklist, applied and enforced

**Status:** Accepted

**Context:** DevFlow's prompt layer (the 9 command documents) carries all behavior while
the mechanical layer carries all guarantees (ADR-0010/0020). The operator asked how to make
those documents as reliable as prompt-layer material can be. A deep-research pass
(2026-07-15; 18 sources, 25 claims adversarially verified, 23 confirmed — full report:
[`docs/research/command-authoring-research.md`](../research/command-authoring-research.md))
established the 2025–2026 authoring doctrine from primary sources (Anthropic docs,
agentskills.io spec, spec-kit templates): ≤500-line bodies (dilution is a documented
failure mode), keyword-rich what+when descriptions (the only preloaded activation signal),
imperative numbered steps with copyable progress checklists, machine-checkable "Done when"
gates ("without a check it can run, 'looks done' is the only signal"), calibrated failure
paths (silent-skip / abort-with-instruction / STOP-and-ask), freedom matched to fragility,
standing instructions stated early (the file is rendered once, never re-read), sparing
emphasis, explicit handoffs, and eval-driven maintenance.

**Decision:** The research report's §10 checklist is **normative** for every DevFlow
command document. All 9 commands were revised to conform:

- **Done-when gates everywhere** — each command ends with a machine-checkable pass/fail
  self-check (file-existence probes, grep patterns, one-line python asserts) mirroring,
  where one exists, the mechanical check the harness runs anyway (Stop-gate, flow guard).
- **Standing rules first** — session-wide invariants extracted into a `## Standing rules`
  section at the top of each document, phrased as invariants, not steps.
- **Progress checklists** in the long workflows (start, iterate, onboard).
- **Descriptions rewritten** to what + when-to-use + trigger keywords (≤1024 chars).
- **Failure paths calibrated** per precondition (e.g. review's semgrep-missing → STOP with
  the fix command, never "read the code and call it a scan"; capture's empty-records →
  report the anomaly, never scrape substitutes).
- **Explicit handoffs** — every command names what runs next and who triggers it.
- **Enforcement:** `tests/acceptance/test-14-command-authoring.sh` mechanically checks the
  checkable subset (length, description shape, Done-when, Standing rules, Handoff,
  checklists, retired vocabulary) on every run — the doctrine can't silently regress.

**Consequences:** The prompt layer's floor rises: every command now tells the model when
it applies, how to verify its own completion, and what to do when preconditions fail —
the three highest-leverage reliability levers in the verified corpus. Costs: slightly
longer documents (all remain ≤150 lines, well under the ceiling) and one more acceptance
test to keep green. **Deferred:** checklist item 12 (eval-driven maintenance — ≥3 evals
per command, fresh-session baselines, blind A/B) is prescribed but not yet implemented;
it needs an eval-runner harness and is scoped as follow-up work alongside the MANUAL.md
dogfood. Open questions from the research (quantitative length effects, emphasis
saturation, cross-vendor generality) are recorded in the report.
