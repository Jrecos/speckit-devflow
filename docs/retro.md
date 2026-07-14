# Retro — the first real run

We ran the spec-driven pipeline (Spec Kit + a build loop + a knowledge track) on a real feature,
end-to-end. **It shipped.** But running it for real — not a dry run — surfaced five structural
gaps. Each maps to a fix now baked into the bundle (see [`blueprint.md`](blueprint.md)).

## A · Build loop was over-scoped

- **What happened:** the loop's done-criteria bundled build + e2e + verification + review +
  human sign-off into **one iteration budget**. Partway through, the remaining criteria were
  heterogeneous (some need a running server + test DB, one is a human gate) and couldn't fit
  the remaining iterations — the loop hit a budget/mode-collision wall.
- **Fix:** split the **inner Build loop** (one task/iteration) from the **outer pipeline**
  (phases as separate sessions). Review/Verify/Ship are phases, not loop iterations.

## B · Review / security gate was skipped

- **What happened:** the loop's checker ran build + lint + adversarial reasoning and called
  that "verified" — but the formal Review (`/code-review` + Semgrep + `/security-review`)
  never ran in that pass. On a security-sensitive feature, the security gate nearly didn't
  happen; it only ran because the gap was caught and inserted by hand.
- **Fix:** Review is its own phase whose **output artifact is a prerequisite** the *harness*
  checks before Verify — not something the agent can conflate away.

## C · Decisions weren't recorded inline

- **What happened:** durable decisions landed in code with **no record**; ADRs were backfilled
  at the gate, not written as the work was done. Capture reads the repo, not the chat — so it
  nearly produced an empty proposal.
- **Fix:** a `record-decision` step, **mandatory on every iteration's exit**. Capture then
  reads guaranteed-populated files.

## D · An accepted deviation left the contract stale

- **What happened:** a deliberate deviation from the contract was accepted, but the contract
  **text** still described the old behavior — a live spec ↔ code mismatch that the consistency
  check would re-flag next cycle. Nothing forced the reconciliation.
- **Fix:** accepting a deviation **is a spec edit** → a `reconcile-contract` step updates the
  contract text and writes an ADR before the loop continues.

## E · Fully hand-cranked, wrong topology

- **What happened:** a human was the message bus between sessions (check → run → check); WIP
  stacked several iterations deep uncommitted because nothing auto-committed on green; and the
  whole run used one cloud model as both maker and checker — none of the intended local-maker /
  cross-family-judge topology, and none of the autonomy.
- **Fix:** auto-commit (hook, so the agent can't forget) + durable on-disk state + the local
  maker / cross-family judge topology, with the loop driving itself between the two human STOPs.
