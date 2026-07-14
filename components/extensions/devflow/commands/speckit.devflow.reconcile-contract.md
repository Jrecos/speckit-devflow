---
description: "Accepted deviation or descoped/parked items: edit the spec contract text and write an ADR before Ship"
---

# DevFlow Reconcile Contract — accepting a deviation IS a spec edit

Invoked by the workflow after STOP #2 when the human chose `accept-with-deviation`,
or chose `accept` while parked tasks/findings exist. The contract text must describe
reality before Ship runs (gap D: a stale contract re-flags next cycle).

## Steps

1. Read `.specify/feature.json` → `feature_directory` (`<fdir>`). Gather what needs
   reconciling:
   - Deviations listed in `<fdir>/verify-report.md` (`## Deviations from spec`).
   - Parked tasks in `<fdir>/loop/state.json` (`parked`, with their failure notes).
   - Parked findings in `<fdir>/review/findings.json` (status `parked`, `open` list).
2. **Edit `<fdir>/spec.md`** so the contract text describes actual shipped behavior:
   - Deviation: rewrite the relevant section to the implemented behavior.
   - Descoped/parked item: mark it explicitly out of scope for this release
     (e.g., a "## Descoped in this release" section listing each item and why).
3. **Write an ADR** to `docs/decisions/` (next NNNN number) using the ADR-lite
   template (see /speckit-devflow-record-decision): title names the deviation or
   descope; Context = what was accepted at STOP #2 and why; Decision = the spec
   edit made; include `**Resolves finding:** <id>` / task ids where applicable.
4. Confirm both edits exist on disk. Report the spec sections changed and the ADR
   path. Ship runs only after this command completes (workflow topology).
