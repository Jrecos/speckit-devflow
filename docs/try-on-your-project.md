# Try DevFlow on a real project

A hands-on playbook for running DevFlow against one of your own repos for the first time.
This is deliberately practical — copy-paste commands, what to expect at each step, the
failure modes you'll actually hit, and a feedback template at the bottom so anything that
goes sideways comes back as something fixable.

> **Status honesty (read this first).** DevFlow v0.1's *mechanical* layer (hook scripts,
> flow guard, brakes, state contracts) is covered by 20 automated tests. Its *prompt*
> layer (the commands driving Claude through the phases) is validated only by real runs —
> **this guide IS that validation.** Expect rough edges in the conversational flow; the
> guarantees underneath (no un-reviewed ship, no un-recorded decision, no runaway loop)
> are the tested part. See [ADR-0020](decisions/0020-claude-sufficient-options-not-mandates.md).

---

## 0 · What you need

- **A real project** you're comfortable letting an agent modify (start on a branch).
- **Claude Code** installed and working (`claude` on your PATH).
- **Spec Kit CLI ≥ 0.12** (`specify --version`).
- **This repo cloned somewhere** — call it `$DEVFLOW` (e.g.
  `git clone https://github.com/Jrecos/speckit-devflow ~/src/speckit-devflow`).
  DevFlow isn't in a public Spec Kit catalog yet, so you install its components from your
  clone (the `specify bundle install devflow` one-liner is a post-publication convenience).
- *Optional but recommended:* a **second model CLI** for the cross-family judge (any tool
  that reads/writes JSON on stdin/stdout — e.g. a Gemini/Codex/Ollama CLI). Without one,
  DevFlow falls back to Claude judging Claude, which works but warns
  ([ADR-0018](decisions/0018-judge-fallback-same-family.md)).

## 1 · Make your project a Spec Kit project (if it isn't)

```bash
cd /path/to/your/project
git checkout -b devflow-trial        # keep the trial on a branch

specify init . --integration claude  # scaffolds .specify/ + .claude/ ; skip if already a spec-kit project
```

## 2 · Install the prerequisites + DevFlow components

First the pinned prerequisites (from the community catalog):

```bash
specify extension add git
specify extension add superspec       # brainstorm/review bridge; best with obra/superpowers installed
```

Then DevFlow's own three components. **Two ways — pick one:**

**(a) From the published release — no clone needed** (recommended for a real project).
These URLs always resolve to the **newest** release, so you get fixes automatically:

```bash
BASE=https://github.com/Jrecos/speckit-devflow/releases/latest/download
specify extension add devflow --from "$BASE/devflow-extension.zip"
specify preset add     --from "$BASE/devflow-plan-hardening.zip"
specify workflow add "$BASE/devflow-workflow.yml"
```

To pin a specific version instead, swap `latest/download` for
`download/v0.1.1` (or any tag).

**(b) From a local clone** (recommended if you'll be editing DevFlow itself). Set
`DEVFLOW` to your clone path first — an unset variable is why
`$DEVFLOW/components/...` resolves to `/components/...` and errors out:

```bash
export DEVFLOW=~/src/speckit-devflow            # <-- your actual clone path
specify extension add "$DEVFLOW/components/extensions/devflow" --dev
specify preset add   --dev "$DEVFLOW/components/presets/devflow-plan-hardening"
specify workflow add "$DEVFLOW/components/workflows/devflow/workflow.yml"
```

> Two confirmation prompts are expected and safe to accept: `specify init .` on an
> existing (non-empty) project asks "continue? [y/N]", and `specify extension add --from`
> asks "Continue with installation? [y/N]" — answer **y** to both. If any sub-command
> rejects a flag, run it with `--help` — the CLI evolves. The forms above are verified
> against 0.12.11 (the release path was installed end-to-end into a clean project).

## 3 · Onboard the project

Open Claude in the project and run:

```
/speckit-devflow-onboard
```

It validates tools, adds the semgrep MCP, **detects your lint/typecheck/test commands and
asks you to confirm them**, smoke-tests the judge, installs the hooks pack + checker
subagent + CLAUDE.md protocol, and fixes `.gitignore`. It ends with a ✓/✗ checklist.

**The one line you must get right:** the `commands:` block in
`.specify/extensions/devflow/devflow-config.yml`. If `test_scoped` / `lint` / `typecheck`
are empty or wrong, the per-edit critic is inert and **every green iteration gets blocked
by the Stop-gate** ("commands.test_scoped is not configured"). Confirm they actually run
in your project before proceeding:

```bash
# whatever onboard proposed — sanity-check each by hand:
npm run lint    # or your real lint
npm test        # or your real scoped-test command
```

## 4 · Configure the judge (optional, one line)

```bash
# any command that reads {"diff","criteria","spec_slice"} on stdin and prints
# {"verdict":"PASS"|"FAIL","reason":"...","criteria":[...]}
export DEVFLOW_JUDGE_CMD='<your cross-family judge>'
```

Skip it and Claude judges (same-family, warns every run). Either way a verdict is required
per iteration — see [the judge seam](../README.md#the-judge-seam).

## 5 · Run your first feature

**Pick something small and self-contained** for the first run — one endpoint, one helper,
a focused refactor. You want 3–6 tasks, not 20, while you learn the rhythm.

Two ways to drive it (same protocol, same gates underneath):

```
# Option B — inside Claude, conversational gates (recommended for your first run):
/speckit-devflow-start add a /health endpoint that returns build info

# Option A — from the terminal, engine-driven (better for headless/CI later):
specify workflow run devflow --input feature="add a /health endpoint" --input mode=attended
```

What happens, and where **you** act:

1. **Frame → Plan → Tasks → Analyze** run; the plan includes *failing* acceptance tests.
2. **STOP #1** — you read the plan, the red tests, and the leash (budget = ⌈tasks × 2.5⌉,
   4h box). **Approve** or reject. *This is your highest-leverage moment* — a wrong spec
   here is the most expensive bug.
3. The **build loop** grinds unattended: one task per fresh session, tests + checker +
   judge each iteration, auto-commit on green, park after 2 failed attempts. Watch with
   `/speckit-devflow-status` in another turn.
4. **Review → (fix cycles) → Verify** run automatically.
5. **STOP #2** — you read the evidence and choose `accept` / `accept-with-deviation` /
   `reject`. Ship happens only past this gate.
6. **Capture** proposes durable notes; you curate.

The [complete phase-by-phase reference](development-workflow.md) has the full table.

## 6 · How to tell it's working

- Each green iteration produces **one commit** (`git log --oneline`) and **one decision
  record** (`ls docs/decisions/`) — that pairing is the core guarantee.
- `specs/<feature>/loop/state.json` shows iteration/budget/parked/verdicts live.
- The Stop-gate should **refuse** to end an iteration that lacks a decision record — if it
  doesn't, the hooks aren't installed (re-run onboard).
- Verify should **refuse** to run if Review hasn't produced clean-or-parked findings.

## 7 · Troubleshooting (the failure modes you'll actually hit)

| Symptom | Likely cause → fix |
|---|---|
| Every iteration blocks: "commands.test_scoped is not configured" | `commands:` in devflow-config.yml empty/wrong → re-run onboard, confirm the commands run by hand (§3). |
| Iterations end but nothing commits | hooks pack not merged into `.claude/settings.json` → re-run onboard step 5; confirm `claude` dispatch has no `--bare`. |
| "DEVFLOW_JUDGE_CMD is not set… no claude CLI" | judge unresolvable → set the env var, or ensure `claude` is on PATH for the fallback ([ADR-0018](decisions/0018-judge-fallback-same-family.md)). |
| A workflow gate "pauses" and nothing happens (headless) | `gate` paused for lack of TTY → `specify workflow resume <run-id>` in an interactive terminal. |
| `/speckit-devflow-start` refuses a phase ("cannot complete X") | the flow guard is doing its job — the phase's artifact doesn't exist yet. Do the work; don't hand-edit `devflow-flow.json`. |
| superspec brainstorm feels thin | superspec bridges to obra/superpowers skills; install those, or lean on `/speckit-clarify`. |
| semgrep MCP only shows a "deprecated / moved to the semgrep binary" notice, or won't start | The standalone `semgrep-mcp` uvx package is deprecated — the MCP server now ships **inside** the `semgrep` binary. Remove any old registration (`claude mcp remove semgrep`) and re-add the built-in one: `claude mcp add semgrep -s project -e SEMGREP_SEND_METRICS=off -- semgrep mcp -t stdio` (there's no `--metrics` flag; use the env var). Need a recent CLI — `uv tool upgrade semgrep` if `semgrep mcp --help` fails. Onboard now does this; `.mcp.json` is per-clone. |
| A task keeps failing | it parks after 2 attempts and the loop moves on; you triage it at STOP #2 with its failure history. |

## 8 · Known v0.1 limitations (so nothing surprises you)

- **Prompt layer is unvalidated at scale** — you're the first real run; the conversational
  driving may stumble even though the guarantees hold.
- **`attended-step`** blocks at each iteration via an in-loop gate; the fully-polished
  engine-level step-pause is a v0.2 item ([ADR-0013](decisions/0013-loop-modes-attended-step-autonomous.md)).
- **Worker commands are auto-invocable** — Claude *could* fire `iterate`/`record-decision`
  mid-chat; they're guarded so a mis-fire STOPs harmlessly, but the clean fix
  (`disable-model-invocation`) is deferred pending live validation
  ([ADR-0022](decisions/0022-skills-and-subagents-doctrine.md), MANUAL.md item 6b).
- **Not catalog-published** — hence the local `--dev` install (§2).
- **Maker is cloud Claude** — local-maker topology is deferred; the *review gate* stays
  fully local/NDA-safe ([ADR-0016](decisions/0016-verification-corrections.md)).

## 9 · Give feedback that I can act on

When something is wrong or awkward, capture this — it turns "it didn't work" into a fix:

```
FEATURE:      <one line — what you asked it to build>
DRIVER:       /speckit-devflow-start   |   specify workflow run   (which one)
MODE:         attended | attended-step | autonomous
PHASE:        which phase (frame/plan/leash/analyze/stop1/build/review/verify/stop2/…)
WHAT I EXPECTED:
WHAT HAPPENED:
ATTACH (if relevant):
  - specs/<feature>/loop/state.json
  - specs/<feature>/review/findings.json  (if past Review)
  - specs/<feature>/devflow-flow.json     (if using /speckit-devflow-start)
  - the exact gate/error message, verbatim
  - git log --oneline for the feature range
SEVERITY:     blocked | annoying | cosmetic
```

Bring that back and I'll trace it to the layer (workflow / hook / prompt), fix it against
ground truth, add a test if it's mechanical, and record the change as an ADR — the same
loop we've been running to build this.
