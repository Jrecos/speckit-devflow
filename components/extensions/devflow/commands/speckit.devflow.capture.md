---
description: "Capture phase: scan committed decision records and propose durable knowledge notes for human curation"
---

# DevFlow Capture — feed the knowledge track

Read the repo, never the chat. The loop guarantees `docs/decisions/` is populated
(every GREEN close required a record) — harvest it.

## Steps

1. Read `.specify/feature.json` → `feature_directory`; find the feature's commit
   range (`git log --oneline` — from the feature's first commit to HEAD).
2. Collect the decision records written in that range
   (`git log --diff-filter=A --name-only -- docs/decisions/` within the range),
   plus the reconcile ADR if one exists.
3. For each record, judge durability: would this decision matter to a DIFFERENT
   feature or project? (Patterns, tradeoff rationales, gotchas — yes.
   Feature-local mechanics — no.)
4. Propose vault-note candidates as a markdown list:
   `- **<title>** — <one-line hook> (source: docs/decisions/<file>)`
   Aim for the few that compound; nothing durable → say so explicitly
   ("nothing durable this cycle — skip is a success").
5. STOP after proposing. The human curates and merges; you never write to a vault.
