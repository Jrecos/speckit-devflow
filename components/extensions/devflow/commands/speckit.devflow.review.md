---
description: "Runs the DevFlow Review phase — local code review + Semgrep scan + security review over the whole feature diff; writes findings.md and machine-readable findings.json BEFORE anything reacts. Use when the build loop has exhausted and the pipeline reaches Review, or for a full re-review after a fix cycle. Keywords: review, code review, security, semgrep, findings, re-review."
---

# DevFlow Review — the unskippable gate (its own phase, never a loop iteration)

## Standing rules

- You **find**; the loop **fixes** (ADR-0012). Do not fix anything in this session.
- Both artifacts are written **before any reaction** — findings exist on disk first.
- A re-review runs the FULL gate — never a lighter pass because "only F1 changed".

## Steps

1. **Scope the diff** (REQUIRED): read `.specify/feature.json` → `feature_directory`
   (`<fdir>`). Read `<fdir>/loop/state.json` → `base_commit` (stamped at loop start).
   The review surface is `git diff <base_commit> HEAD` — a **deterministic** base, robust
   to stacked-branch topology (do NOT use `merge-base`: if this feature branched off an
   unmerged one, merge-base picks a stale point and floods the diff with prior features'
   changes). If `base_commit` is null (older state), fall back to the first commit that
   touched `<fdir>/` and say so in findings.md.
2. **Three passes** over that surface:
   - **Code quality** (judgment): correctness, error handling, edge cases, test
     honesty — do the tests assert behavior or pass vacuously?
   - **Semgrep** (mechanical): scan the changed files with the semgrep MCP tools —
     dataflow/taint analysis an LLM read can miss. *If the semgrep MCP is not
     available:* STOP and report — run `/speckit-devflow-onboard` to install it;
     do not substitute your own reading and call it a scan.
   - **Security** (judgment): injection, authz/authn holes, secrets in code, unsafe
     deserialization, path traversal — on the changed surface only.
3. **Write both artifacts** (REQUIRED, before anything else happens):
   - `<fdir>/review/findings.md` — human-readable: one section per finding with
     severity, file, explanation, suggested fix.
   - `<fdir>/review/findings.json` — exactly this schema:
     `{"status": "clean" | "findings", "open": [{"id": "F1", "severity": "high|medium|low", "file": "<path>", "summary": "<one line>"}], "cycle": <state.cycle>}`
     `status` is `clean` iff `open` is empty. Number findings F1, F2, …
     **continuing across cycles** (read the previous findings.json first).
4. **Re-review only:** mark resolved findings in findings.md (strike-through +
   `resolved by <decision-record>`) and remove them from `open` in findings.json.

## Done when

Both files exist and agree: `findings.json` parses, its `status` matches whether
`open` is empty, and every open finding has id/severity/file/summary. Verify by
running: `python3 -c "import json,sys;f=json.load(open('<fdir>/review/findings.json'));assert (f['status']=='clean')==(not f['open']);print('findings artifact OK')"`
— if it fails, fix the JSON before ending.

## Handoff

The workflow (or orchestrator) reads `findings.json`: `clean` → Verify;
`findings` → convert-findings + a fix cycle. You do not trigger either — end after
the artifacts are verified.
