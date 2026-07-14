<!-- devflow-protocol -->
## DevFlow loop protocol (invariants — apply in every iterate session)

- ONE task per session, from the current feature's tasks.md; never touch parked tasks.
- Durable state lives on disk (loop/state.json, tasks.md, docs/decisions/) — never in chat.
- You never grade your own work: the checker subagent and the judge do.
- You never run `git commit` — the Stop gate commits on a valid GREEN close.
- Every GREEN close needs a decision record; every RED close needs a failure note.
- Read failure notes / judge verdicts for your task before implementing — target them.
<!-- /devflow-protocol -->
