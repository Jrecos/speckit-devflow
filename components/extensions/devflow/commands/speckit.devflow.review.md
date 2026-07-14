---
description: "Review phase: local code review + Semgrep + security review; write findings.md and machine-readable findings.json FIRST"
---

# DevFlow Review — the unskippable gate (its own phase, never a loop iteration)

Local-only review of the whole feature diff. Your FIRST act after analysis is
writing the findings artifacts — findings exist on disk before anything reacts.

## Steps

1. Read `.specify/feature.json` → `feature_directory` (`<fdir>`). Determine the
   feature diff: `git log --oneline` since the feature's first commit; `git diff`
   against the pre-feature base.
2. Run three review passes over the diff:
   - **Code quality:** correctness, error handling, edge cases, test honesty
     (do tests assert behavior or just pass vacuously?).
   - **Semgrep:** use the semgrep MCP tools to scan the changed files
     (dataflow/taint analysis an LLM review can miss).
   - **Security:** injection, authz/authn holes, secrets in code, unsafe
     deserialization, path traversal — on the changed surface.
3. **Write both artifacts BEFORE any reaction:**
   - `<fdir>/review/findings.md` — human-readable: one section per finding with
     severity, file, explanation, suggested fix.
   - `<fdir>/review/findings.json` — machine-readable, exactly this schema:
     `{"status": "clean" | "findings", "open": [{"id": "F1", "severity": "high|medium|low", "file": "<path>", "summary": "<one line>"}], "cycle": <state.cycle>}`
   - `status` is `clean` when `open` is empty, else `findings`. Number findings
     F1, F2, … continuing across cycles (read the previous findings.json if any).
4. On a re-review (the workflow passes "re-review" in your arguments): run the FULL
   gate again — never a lighter pass. Mark resolved findings in findings.md
   (strike-through with a `resolved by <decision-record>` note) and remove them
   from `open` in findings.json.
5. Do not fix anything yourself. Review finds; the loop fixes (ADR-0012).
