# The baseline workflow (what DevFlow automates)

This is the spec-driven development workflow we designed and ran by hand — a **16-step,
6-phase** loop with a parallel knowledge track. The DevFlow bundle exists to **provision and
automate this**, with the five structural fixes from [`retro.md`](retro.md) baked in.

Rationale for the design lives in [ADR-0005](decisions/0005-baseline-workflow-rationale.md).

- `gate` = stop & check · `👤` = human judgment / sign-off

## Set up once (per repo)

| | What | Command |
|---|---|---|
| 1 | Onboard — validate & install every prerequisite at project scope | `/dev-workflow:onboarding` |
| 2 | Loop extension (**required**) + friends | `specify extension add loop` (also superspec, aide, ralph, git) |
| 3 | Semgrep MCP (local security/static analysis) | `claude mcp add semgrep --scope project uvx semgrep-mcp --metrics off` |
| 4 | Vault mapping (enables prime + capture) | `.claude/vault-mapping.yml` (`vault_repo` / `project_path` / `client`) |
| 5 | Constitution — the project's non-negotiables | `/speckit.constitution` |
| 6 | *(optional)* product layer | `/speckit.aide.create-vision → create-roadmap → create-item` |

## Per feature — the loop

### Phase 1 · Frame (what & why)
| # | Step | Command | Notes |
|---|---|---|---|
| 1 | Prime from vault | `/dev-workflow:prime-from-vault` | pull prior decisions/patterns into context — start informed |
| 2 | Specify | `/speckit.specify` | precise, testable spec (the contract) — `gate` |
| 3 | Brainstorm | `/speckit.superspec.brainstorm` | pressure-test edge cases; loop Specify↔Brainstorm — `gate` `👤` |
| 4 | Clarify | `/speckit.clarify` | ~5 targeted questions; optional |

### Phase 2 · Plan (how)
| # | Step | Command | Notes |
|---|---|---|---|
| 5 | Plan | `/speckit.plan` | approach + artifacts — last cheap place to change your mind — `gate` `👤` |
| 6 | Tasks | `/speckit.tasks` (`/speckit.taskstoissues` opt) | ordered, independently-testable tasks |
| 7 | **Analyze — the gate** | `/speckit.analyze` | cross-check spec ↔ plan ↔ tasks — `gate` |

### Phase 3 · Build
| # | Step | Command | Notes |
|---|---|---|---|
| 8 | Implement — the Loop (make) | `/speckit.loop.define` + `/speckit.loop.run` | set done-criteria, build one increment; the maker **never self-grades** |
| 9 | Record decisions → files | ADR stub · plan note · commit msg | jot each durable decision into a committed file — **continuous** |

### Phase 4 · Check
| # | Step | Command | Notes |
|---|---|---|---|
| 10 | Review — quality + security | `/code-review` + Semgrep MCP (+ `/security-review`) | local = NDA-safe; source never leaves the machine — `gate` |
| 11 | Verify — does it actually work? | `/speckit.loop.check` + `/speckit.loop.guard` | adversarial checker in a **fresh session**; `loop.guard` is the only path to done — `gate` `👤` (most-skipped) |

### Phase 5 · Ship
| # | Step | Command | Notes |
|---|---|---|---|
| 12 | Validate — ready to ship? | `/speckit.git-validate` | branch clean / convention gate — `gate` `👤` |
| 13 | Ship | `/speckit.git-commit` | commit / PR / merge |

### Phase 6 · Capture (feed the brain)
| # | Step | Command | Notes |
|---|---|---|---|
| 14 | Capture — scan & propose | `/dev-workflow:capture-to-vault` | scan committed files for durable decisions, draft notes |
| 15 | Curate — keep / edit / drop | review the proposal | the human filter — `gate` `👤` |
| 16 | Merge to vault | PR → review → merge | you are the sole merger, the vault's firebreak — `gate` `👤` |

## The knowledge track (runs in parallel)

Not one step — a thread alongside the whole cycle so a second brain both feeds and gets fed.
**Files are the source of truth (Kepano); the LLM does the bookkeeping (Karpathy).**

- **start · read → Prime** (step 1): pull prior art into context.
- **during · record → Decisions to files** (step 9): jot each durable decision as you build;
  Capture reads the repo, never the chat.
- **end · write → Capture → Curate → Merge** (steps 14–16): scan, curate, merge into the vault
  via PR. Nothing durable → skip is a success.

## Engine swap

**Loop** (steps 8 & 11) is the careful default. **Ralph** (`/speckit.ralph.run`) is the hands-off
alternative — it grinds autonomously and its own completion gate replaces Verify. Pick per feature.

---

*A visual HTML playbook of this workflow also exists (kept in a separate, private ops repo). It can
be ported here and scrubbed of infra references if a rendered version is wanted in this repo.*
