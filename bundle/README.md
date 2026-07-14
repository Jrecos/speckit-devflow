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

Design record: `../docs/decisions/` (ADRs 0001–0016) and
`../docs/superpowers/specs/2026-07-13-devflow-bundle-design.md`.
