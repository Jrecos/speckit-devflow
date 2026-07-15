# DevFlow behavioral evals

The acceptance suite (`tests/acceptance/`) is hermetic: it checks the **scripts** and, in
`test-15`, the prompt **text** — freezing the wording of every dogfood-finding fix. But text
frozen in place is not the same as an agent *behaving* correctly. An **eval** closes that gap:
it runs a real command through a fresh Claude session and grades **what the agent did** — the
behavior the prompt is supposed to produce. This is the net that would have caught the dogfood
findings before a user hit them (roadmap candidate #2 — "eval harness for the command prompts").

```
tests/acceptance/test-15   →  the FIX WORDING is present in the prompt   (static, hermetic, every commit)
evals/                     →  the WORDING actually drives the behavior    (behavioral, live model, on-demand)
```

The two are complementary. test-15 is cheap and runs in CI on every change; the evals are the
expensive behavioral confirmation you run when a prompt changes or before a release.

## Running

```bash
evals/run-evals.sh --list          # the cases and the finding each guards
evals/run-evals.sh --self-test     # deterministic, no model — the CI-safe validity check
evals/run-evals.sh                 # LIVE: dispatch each case through claude -p, grade the result
evals/run-evals.sh --revert        # LIVE red-on-revert: revert each fix, require the eval to go RED
evals/run-evals.sh --case onboard-semgrep   # one case
```

### `--self-test` (deterministic, run this in CI)

No model is called. For each case the runner proves the eval is **well-formed**:

1. the grader **passes** the case's `sim_pass` — the artifacts/state a *correct* agent produces;
2. the grader goes **red** on `sim_revert` — the artifacts/state a *reverted-prompt* agent produces;
3. `revert.sh` genuinely **mutates the installed prompt** (so the live red-on-revert has teeth).

This is the same trick `tests/acceptance/test-07` uses for the judge seam: inject a fake instead
of paying for a live model, and assert the machinery discriminates. It guards the *graders*; it
does not exercise the model.

### Live runs (`run-evals.sh` / `--revert`)

The real eval. Each case is bootstrapped into a throwaway spec-kit + DevFlow project (via the
`specify` CLI — "real-CLI bootstrap"), the command is dispatched with `claude -p` in that fresh
context, and the grader reads the artifacts/state the agent left behind. `--revert` first applies
`revert.sh` to the installed prompt and then **requires** the grader to go red — this is the
positive proof that the eval is sensitive to the fix, not passing for unrelated reasons.

Live runs cost tokens, are non-deterministic, and have side effects (they may install/register
things in the throwaway project). Run them deliberately — on a prompt change or before a release —
not on every commit. That is why the acceptance suite (`run-all.sh`) does **not** discover them.

## The driver seam

Which model runs a case is resolved exactly like the judge seam (`devflow-judge.sh`):

| env | behavior |
|---|---|
| `DEVFLOW_EVAL_DRIVER` unset | live `claude -p` (default) |
| `DEVFLOW_EVAL_DRIVER="<cmd>"` | run `<cmd>` instead, receiving `$1=prompt $2=transcript-out $3=cwd` |

Swap the driver to route evals through a cheaper or cross-family model. The `--self-test` mode
bypasses the driver entirely (it drives each case's `sim_*` hooks), so grader validation never
needs a model or a network.

## The seed cases

| case | finding(s) | behavior graded | graded artifact/state |
|---|---|---|---|
| `onboard-semgrep` | 1, 7 | registers the built-in `semgrep mcp -t stdio` server, not the dead `uvx semgrep-mcp` package | project `.mcp.json` |
| `start-flow-literal` | 3 | treats `FLOW` as the literal `devflow-flow.sh` path, so the guard actually runs | `<fdir>/devflow-flow.json` ledger advanced |
| `iterate-judge-tests-line` | 6 | prepends a `TESTS:` line to the judge criteria | criteria captured via a `DEVFLOW_JUDGE_CMD` recorder |

## Adding a case

Create `cases/<name>/case.sh` defining these functions (all cases share the same names; the
runner sources each in its own subshell):

| function | contract |
|---|---|
| `case_meta` | one line: `name \| finding # \| what behavior is under test` |
| `case_prompt` | echo the prompt to dispatch (usually a `/speckit-devflow-*` invocation, scoped) |
| `case_bootstrap <scratch>` | case-specific setup beyond the shared bootstrap (seed state, config, recorders) |
| `case_grade <scratch> <transcript>` | grade artifacts/state; **exit 0 = pass**, non-zero = red. Notes to stderr. |
| `case_revert <scratch>` | mutate the **installed** prompt copy (`eval_cmd_path`) back to its pre-fix wording |
| `case_sim_pass <scratch>` | deterministically seed the artifacts/state a *correct* agent would produce |
| `case_sim_revert <scratch>` | deterministically seed the artifacts/state a *reverted-prompt* agent would produce |

Design rule (same as test-15): the grader must key on the **specific** signal that exists only
because of the fix, and `sim_pass`/`sim_revert` must be an honest pair (correct vs pre-fix
behavior) so `--self-test` proves real discrimination. Then verify live with `--case <name>` and
`--case <name>` under `--revert`.
