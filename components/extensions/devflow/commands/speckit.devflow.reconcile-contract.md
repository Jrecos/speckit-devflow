---
description: "Reconcile the spec contract after STOP #2: edit spec.md to describe actual shipped behavior (accepted deviations, descoped/parked items) and write an ADR — both before Ship can run. Use when the human chose accept-with-deviation, or accept while parked tasks/findings exist. Keywords: reconcile, deviation, descope, spec edit, contract, stale spec."
---

# DevFlow Reconcile Contract — accepting a deviation IS a spec edit

## Standing rule

The contract text must describe reality before Ship (gap D: a stale contract
re-flags next cycle). Both outputs — the spec edit AND the ADR — must exist before
this session ends; Ship is topologically behind this command.

## Steps

1. **Gather what needs reconciling** (REQUIRED): read `.specify/feature.json` →
   `feature_directory` (`<fdir>`), then:
   - deviations from `<fdir>/verify-report.md` (`## Deviations from spec`);
   - parked tasks from `<fdir>/loop/state.json` (`parked`, with their
     `failure_notes`);
   - parked findings from `<fdir>/review/findings.json` (status `parked`, `open`).
   *If all three are empty:* STOP and report "nothing to reconcile" — the caller
   should have skipped this phase; do not invent edits.
2. **Edit `<fdir>/spec.md`** so the contract matches shipped behavior:
   - each accepted deviation → rewrite the relevant section to the implemented
     behavior;
   - each descoped/parked item → list it under a `## Descoped in this release`
     section with one line of why.
3. **Write the ADR** to `docs/decisions/` (next NNNN number, ADR-lite template as in
   /speckit-devflow-record-decision): title names the deviation/descope; Context =
   what was accepted at STOP #2 and why; Decision = the spec edits made; include
   `**Resolves finding:** <id>` / task ids where applicable.
4. Report the spec sections changed and the ADR path.

## Done when

Both hold — verify before ending:
- `spec.md` is newer than `verify-report.md`
  (`python3 -c "import os;assert os.path.getmtime('<fdir>/spec.md') > os.path.getmtime('<fdir>/verify-report.md');print('spec touched')"`) —
  the flow guard runs this same check;
- the new ADR file exists and covers every gathered item from step 1.

## Handoff

Ship runs next (git.validate → git.commit), triggered by the workflow or
orchestrator — not by you.
