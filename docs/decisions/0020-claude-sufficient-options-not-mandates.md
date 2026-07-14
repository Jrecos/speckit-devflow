# ADR-0020: Claude-sufficient by default — options, not mandates

**Status:** Accepted (names the principle behind ADR-0018 and ADR-0019; scopes the
validation caveat for prompt-layer components)

**Context:** Two recent decisions share a shape the design had not named: the judge
fallback (ADR-0018: no `DEVFLOW_JUDGE_CMD` → Claude judges) and the Claude-native driver
(ADR-0019: `/speckit-devflow-start` as a peer to the engine path). Both exist so that a
developer whose only tool is Claude Code is **not locked out of any part of the
lifecycle**. The operator's call: make that the explicit policy.

**Decision:**

1. **Claude-sufficient by default.** Every role and every driver in DevFlow must resolve
   with nothing but Claude Code installed:
   - maker — Claude (ADR-0009);
   - checker — Claude subagent, fresh context (ADR-0003/0016);
   - judge — `DEVFLOW_JUDGE_CMD` when set, **Claude fallback when not** (ADR-0018);
   - driver — `specify workflow run devflow` (engine) or `/speckit-devflow-start`
     (Claude-native, ADR-0019), full peers.
   A missing external tool may only ever degrade the topology (with a loud warning and a
   recorded tradeoff), never block the workflow — with one deliberate exception: the
   fail-safe blocks (malformed verdict, missing artifacts, the Stop-gate) stay hard,
   because those protect correctness, not topology.

2. **Options, not mandates.** Stronger topologies remain one configuration away and are
   always the documented recommendation (cross-family judge = one env var; engine driver
   for headless/CI). DevFlow's job is to make the strongest available setup easy and the
   minimal setup honest — never to gatekeep the workflow on tooling the developer
   doesn't have.

3. **The validation caveat, on the record.** DevFlow's mechanical layer (guard scripts,
   hooks, brakes, state contracts) is verified by the automated acceptance suite. Its
   **prompt layer** (the orchestrator driving phases, commands steering sessions,
   in-conversation gates) is by nature validated only by **live runs** — that is what
   `tests/acceptance/MANUAL.md` exists for, and it is a property of every prompt-driven
   system, not a DevFlow defect. Consequence of the layering rule (ADR-0010): because
   prompts carry no guarantees, an unvalidated prompt layer can degrade the *experience*
   but cannot silently break a *guarantee* — those live in the tested layers beneath.

**Consequences:** Zero-external-dependency adoption is a supported, first-class path, so
the audience is "anyone with Claude Code" rather than "anyone with a multi-model setup."
Costs, accepted knowingly: the default topology is same-family-judged (warned, ADR-0018),
and prompt-layer polish lands through dogfooding rather than CI. Future components follow
the same test: *if it can't run Claude-only, it ships with a Claude-only degradation path
or it doesn't ship.*
