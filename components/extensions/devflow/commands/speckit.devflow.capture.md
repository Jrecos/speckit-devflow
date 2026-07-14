---
description: "DevFlow Capture phase: scan the feature's committed decision records and propose durable knowledge notes for human curation — reads the repo, never the chat. Use after Ship as the pipeline's final phase, or standalone to harvest a finished feature. Keywords: capture, knowledge, vault notes, harvest decisions, curate."
---

# DevFlow Capture — feed the knowledge track

## Standing rules

- Read the repo, **never** this conversation — the loop guaranteed `docs/decisions/`
  is populated (every GREEN close required a record).
- You propose; the human curates and merges. You never write to a vault, and you
  STOP after presenting candidates.

## Steps

1. Read `.specify/feature.json` → `feature_directory`; find the feature's commit
   range (`git log --oneline` from the feature's first commit to HEAD).
2. Collect the decision records created in that range — run:
   `git log --diff-filter=A --name-only --pretty=format: <base>..HEAD -- docs/decisions/`
   — plus the reconcile ADR if one exists.
   *If the list is empty:* report exactly that ("no decision records this feature —
   the loop should have enforced them; check the Stop-gate hook installation") and
   end; do not scrape substitutes from commit messages.
3. For each record, judge durability (judgment step): would this matter to a
   DIFFERENT feature or project? Patterns, tradeoff rationales, gotchas → yes.
   Feature-local mechanics → no.
4. Present the candidates as a markdown list, one line each:
   `- **<title>** — <one-line hook> (source: docs/decisions/<file>)`
   Aim for the few that compound. Nothing durable → say so explicitly:
   **"nothing durable this cycle — skip is a success."**

## Done when

Every collected record has been either proposed or explicitly passed over, and the
candidate list (or the explicit skip) is in your final message. Then STOP — ask the
user which candidates to keep; the merge into their vault is theirs.

## Handoff

None — Capture is the pipeline's last phase. The human's curation closes the loop;
next feature's Frame starts smarter.
