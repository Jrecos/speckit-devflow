# DevFlow bundle

The Spec Kit bundle manifest for DevFlow. Components live in `../components/`
(devflow extension, devflow workflow, devflow-plan-hardening preset); `git` and
`superspec` are pinned upstream prerequisites, called at their command seams.

## Author flow (this repo)

```bash
# install the authored components into a spec-kit project so references resolve:
specify extension add ../components/extensions/devflow --dev
specify preset add --dev ../components/presets/devflow-plan-hardening
specify workflow add ../components/workflows/devflow/workflow.yml

specify bundle validate --path .                # structural + reference checks
specify bundle build    --path . --output ../dist/   # versioned .zip artifact
```

Automated checks: `bash ../tests/acceptance/run-all.sh`
Live-Claude dogfood checklist: `../tests/acceptance/MANUAL.md`

## Consumer flow

```bash
specify bundle install devflow      # idempotent, confined to project root
claude                              # then, inside the project:
/speckit-devflow-onboard            # validates+installs hooks, checker, config, judge seam
specify workflow run devflow --input feature="..." --input mode=attended
```

- **Modes** (ADR-0013): `attended` (live output, base allowlist, never waits) ·
  `attended-step` (a blocking gate at every iteration boundary — resume continues
  with exactly the next iteration) · `autonomous` (headless allowlist via
  `SPECKIT_INTEGRATION_CLAUDE_EXTRA_ARGS`, set by the operator).
- **Two human decisions per feature:** STOP #1 (plan + red tests + leash) and
  STOP #2 (accept / accept-with-deviation / reject, full evidence).
- **The judge seam** (ADR-0014): set `DEVFLOW_JUDGE_CMD` in your environment to any
  command that reads `{"diff","criteria","spec_slice"}` on stdin and prints
  `{"verdict":"PASS"|"FAIL","reason":...,"criteria":[...]}`. No endpoint or model
  name ships in this repo; onboard smoke-tests the seam and warns on same-family judges.

## What to commit (and what never to)

DevFlow generates process artifacts on purpose — most belong in your repo
([ADR-0017](../docs/decisions/0017-artifact-versioning-policy.md), grounded in
Spec Kit, MADR, and Anthropic guidance):

| Commit | Gitignore |
|---|---|
| `specs/NNN/*` (spec, plan, tasks — maintain, never prune) | `CLAUDE.local.md` |
| `.specify/` scaffolding | `.claude/settings.local.json` |
| `docs/decisions/*.md` (supersede, never delete) | `.env*` (judge/env config) |
| `CLAUDE.md` / `AGENTS.md` + shared `.claude/` (settings, agents) | session transcripts, scratch dirs |
| `loop/state.json` + `review/findings.json` — **on feature branches** (the loop's on-disk coordination contract and audit trail; squash-merge keeps them out of main's linear history) | |

`/speckit-devflow-onboard` adds the gitignore entries for you.

Design record: `../docs/decisions/` (ADRs 0001–0017) and
`../docs/superpowers/specs/2026-07-13-devflow-bundle-design.md`.
