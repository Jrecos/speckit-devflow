# DevFlow roadmap & dogfood log

Where the bundle is going and what real runs have taught us. Two lists: **candidate
improvements** (ideas earning their priority from evidence, not memory) and the
**dogfood findings log** (concrete issues real runs surfaced, and what was done).

Principle (from the runs themselves): the architecture is proven (21 automated tests, the
three-layer model holds). What sets priority is **runs, not features** — a candidate gets
promoted when a pain repeats across features, not on first sighting. Premature harness-
building is the "orchestration over interface" trap the research warned against.

---

## Shipped — the v0.2.0 hardening (one dogfood run promoted these off "candidate")

The konexo run surfaced 7 findings (below); five were prompt/driver fragilities found by
hand. That crossed the "pain repeats" bar, so the v0.2.0 effort built the machinery to catch
the whole class before a user does:

- **Release tripwire + CI** (findings 2, 7 → *version drift* & *upstream drift*):
  `scripts/release.sh` (atomic version bump across all 7 literal sites + grep-guard +
  validate + suite + build + smoke + tag + publish), `scripts/onboard-smoke.sh` (clean-machine
  install from the *packaged* assets — catches upstream drift like the semgrep-mcp deprecation),
  and GitHub Actions (`ci.yml` on push/PR, `release.yml` on tag). Runbook: `docs/releasing.md`.
- **Eval harness** (candidate #2, now BUILT): `tests/acceptance/test-15` (deterministic static
  net freezing all 7 findings) + `evals/` (live behavioral framework, 3 seed evals, artifact/state
  grading, `--self-test` for CI, live-proven). This is roadmap candidate #2 delivered.
- **Prose→script extraction** (ADR-0023, Track C): the guarantees that used to depend on an
  agent typing the right prose — feature-diff scoping, judge-criteria assembly, the status
  decision-ladder, ADR numbering, iteration-open, the `tasks.md` count primitive — now live in
  scripts both drivers call, behavior-identical (validated), each backed by a mechanical test.
  Directly attacks the driver-parity fragility class (findings 4, 5).

All shipped behavior-identical or additive; the acceptance suite went 14 → 20 tests.

---

## Candidate improvements (still unbuilt — ranked by current gut, re-ranked by evidence)

### 1 · Assumptions harness / verification-strategy declaration
**Gap:** the agent resolves underspecified situations by *assuming* (e.g. "no test
framework → build+visual is an acceptable oracle") and stating it in **chat** — which
breaks the durable-state-on-disk rule and slips a load-bearing choice past both STOPs
without explicit human sign-off.
**Shape:** make **assumptions** the third disk-backed, human-gated artifact alongside
decisions (record-decision) and deviations (reconcile-contract) — logged to
`assumptions.md`, surfaced at STOP #1, human must acknowledge each. Sharpest piece: a
**verification-strategy declaration** at Plan (`unit|integration|build-only|visual|human`)
that STOP #1 makes the human explicitly approve ("build-only oracle — accept?"). Mechanical
part: the phase must emit the artifact (guard checks existence); human part: confirm.
**Status:** #1 candidate; on-thesis; cheap (same pattern as decisions/deviations). Needs
≥2–3 runs of evidence on *how often* agents assume silently before building.

### 2 · Eval harness for the command prompts — ✅ BUILT (v0.2.0)
**Gap:** every prompt-layer bug so far (`$FLOW` word-splitting, the phantom `--metrics`
flag, loop-status misuse) was found *by hand in a live run*. There's no regression net for
the markdown commands — ADR-0021 prescribed eval-driven maintenance but deferred it.
**Delivered:** `test-15` (static net freezing all 7 findings, in the acceptance suite) +
`evals/` (live behavioral framework on the skill-creator pattern — artifact/state grading, a
deterministic `--self-test`, `--revert` sensitivity proof, 3 live-proven seed evals). See the
Shipped section above. **Next growth:** add per-command live evals incrementally, and wire the
live layer into a nightly CI job.

### 3 · Visual-verification ladder
**Gap:** the verification stack assumes a mechanical test oracle; UI/visual features may
have none, so "green" degrades to "builds clean".
**Shape (ladder):** detect visual work → prefer an existing visual suite (Playwright/
Storybook/Percy) → screenshot + vision-judge (extends the judge seam; Claude has vision) →
scaffold a render-smoke test → human visual gate at STOP #2.
**Status:** a *special case* of #1 (it's one assumption the agent makes); likely falls out
of the assumptions harness rather than needing its own build. Watch whether it recurs.

---

## Dogfood findings log (real runs → fixes)

First real run: **konexo `003-voltpulse-module-foundation`, feature 004** (a UI catalog +
one constructible landing), driven by `/speckit-devflow-start`, 2026-07-15.

| # | Finding | Layer | Fix | Commit |
|---|---|---|---|---|
| 1 | onboard's semgrep line broke on-machine: phantom `--metrics off` flag; `uvx` Python-3.14 protobuf crash; missing semgrep CLI | prompt | corrected to `-e SEMGREP_SEND_METRICS=off`, `uvx --python 3.12`, `uv tool install semgrep` + `--semgrep-path`; troubleshooting row added | `2b9aa48` |
| 2 | release install reported `v0.1.0` — tag was bumped but manifest `version:` fields weren't | release process | bump component + bundle versions atomically with the tag; verify a clean install reports the new number | `305c7eb` |
| 3 | `start.md`'s `FLOW` shorthand read as a shell var — zsh doesn't word-split it, and the Bash tool's fresh-shell-per-call means a var never survives anyway | prompt | clarified `FLOW` is a doc-shorthand for the literal `bash …/devflow-flow.sh` path, not a variable | `b8014f9` |
| 4 | `loop-status` looks read-only but mutates + spent budget per *call* → a "peek" before the first dispatch burned phantom budget | script + prompt | budget keyed to **iteration advancement** (`last_counted_iteration`), so spurious/early calls can't inflate it; start.md §6 marks loop-status as a once-per-dispatch advance step and points inspection at read-only `/speckit-devflow-status` | `ac719ae` |
| 5 | Review/verify diff scoping used `merge-base dev..HEAD`; on a branch stacked off an unmerged feature (004 off 003) that base was stale → 170 files / 12k lines of prior-feature churn, not 004's surface. Agent had to hand-scope. | script + prompt | init stamps `base_commit = HEAD` **once at loop start**; review.md + verify.md diff `base_commit..HEAD` (deterministic, topology-proof) with a first-touch fallback for old state | `3d58be6` |
| 6 | Verify judge returned **FAIL** on two criteria it could not confirm — `PageIcon kind="voltpulse"` and `.dash-card-title` live in *unchanged* files (added in S1), invisible in the diff. A green 36/36 suite already proved them. Per ADR-0016 the FAIL parked to STOP #2 (design worked), but it was a **scope false-negative** that forced a human decision. | script + prompt | judge fallback prompt rewritten (ADR-0003): tests are the primary oracle, do NOT FAIL for code outside the diff or already covered by a green suite — FAIL only for defects *in* the diff or subjective-quality gaps; verify.md/iterate.md now prepend a `TESTS:` line to the criteria so the judge can weigh the oracle | `3d58be6` |
| 7 | Review's mechanical Semgrep pass was unavailable: the standalone `semgrep-mcp` uvx package (which finding #1's onboard line installed) is **deprecated** — the MCP server moved into the `semgrep` binary, so the old server now only returns a deprecation notice, not scan tools. Review had no dataflow/taint pass. | prompt | onboard registers the **built-in** server (`claude mcp add semgrep … -- semgrep mcp -t stdio`), drops the dead `uvx semgrep-mcp`/`--semgrep-path`; review.md treats a notice-only server as "unavailable"; adoption-guide troubleshooting row updated | `86ed4b5` |
| 8 | **The v0.2.0 self-release** 403'd at the push: `release.sh` ran `gh auth setup-git` but never ensured the *right* account was active, and a shell profile re-sets the active gh account to a different org account on every new shell — so the release run (one shell) inherited the wrong account. All 20 tests/build/smoke had passed; the commit + tag were made; only the push failed (clean recoverable state, nothing published). | release tooling | `release.sh` now switches to the repo-owner account (`${GH_REPO%%/*}`) for the push, **forces** gh's credential helper (`-c 'credential.helper=!gh auth git-credential'`) so a stale keychain token can't win, and restores the prior active account on exit; troubleshooting row updated | `512d3b1` |
| 9 | **A session ran silently degraded** (observed in a konexo/voltpulse session, 2026-07-17, on spec-kit machinery of the same shape as ours): the working tree sat on a `promote/*` branch that doesn't carry `.claude/skills/`, so the rendered skill layer and the current CLAUDE.md were simply *absent* — every command kept "working" without its machinery, and only a human noticed. DevFlow had the same hole: nothing verified the loop's own assets exist before starting. | script | `devflow-preflight.sh` — mechanical assert (config, core scripts, checker agent, all 9 rendered commands in either `.claude/skills/` or `.claude/commands/` form) wired into `devflow-init.sh` and `devflow-flow.sh init`; a degraded tree now **blocks loudly** at loop entry instead of running without guarantees; behavior-tested by test-21 | *(this change)* |

**All 7 findings' prompt/script fixes shipped in v0.1.2** (the fast patch, cut via the new
`release.sh`). The larger machinery they motivated shipped in **v0.2.0** (see Shipped above).

**Meta-signal:** findings 1, 3, 4, 5, 6 were *all found by hand in one live run* — the evidence
that promoted **candidate #2 (eval harness)** to the highest-leverage investment and got it
**built** this cycle: it now catches this whole class before a user does. Findings 4 and 5
reinforced the driver-parity theme (the orchestrator manually reproducing engine behavior —
budget accounting, diff scoping — is where fragility clusters); ADR-0023's prose→script
extraction attacks that class at the root. Finding 6 is different in kind: not a prompt typo
but the **judge-context seam** — a judge that sees only the diff is blind to the codebase the
diff depends on. The shipped fix (defer to the test oracle, don't FAIL on outside-diff)
mitigates it; a fuller answer (letting the judge *read* referenced unchanged files) stays a
candidate to watch if the false-negative recurs.

Finding 7 is a **third class: upstream drift** — a dependency we pin (the semgrep MCP)
changed shape underneath us. Neither an eval harness nor a code test catches this; only a
real run against current tooling does. It argues for a periodic "onboard against a clean
machine" smoke check as part of release, not just the offline acceptance suite.

**Opportunity surfaced by finding 7:** the built-in `semgrep mcp` also exposes *agent hook*
modes (`-k post-tool-cli-scan`, `stop-cli-scan`, `inject-secure-defaults`). That maps
directly onto DevFlow's layer-2 hook seam — a candidate for moving the Semgrep pass from a
Review-time prompt step to a guaranteed PostTool/Stop hook. Watch, don't build yet.

Finding 9 is a **fourth class: working-tree / asset-integrity drift** — distinct from
finding 7's upstream drift. The assets can be correct *and installed* yet absent from the
tree you're standing in (branch topology, partial checkouts, un-onboarded clones), and
prompt-layer machinery degrades silently because prose can't notice its own absence
(exactly the forced-artifact boundary documented in `docs/research/loop-methods-analysis.md`:
models reliably annotate actions they take, and reliably fail to notice what's missing).
The fix is the pattern ADR-0010 prescribes: a mechanical existence gate at loop entry.

**Adopted from the loop-methods deep analysis** (`docs/research/loop-methods-analysis.md`,
2026-07-17): the **authority order** `user decision > spec.md > tests > current code`
(ADR-0024) — the one external technique with a measured failure at our own model tier.
Stated at four surfaces (iterate standing rule + CONFLICT: RED-close artifact, judge
fallback rule 4, checker changed-test rule, verify verdict-reading exception), frozen by
test-15, behavior-tested by `evals/cases/iterate-authority-conflict/`. Its watch-list
survivors (cost sidecar, gate-integrity write-boundary, TWINS line, tier eval matrix)
stay in that document with named triggers — build on evidence, per the principle above.

**Process rule — now enforced, not just adopted:** a release = bump manifest versions **and**
tag **and** re-upload assets, then verify a clean install reports the new number — atomically,
not the tag alone. This is no longer a discipline to remember: `scripts/release.sh` does it in
one atomic guarded run and `ci.yml`/`release.yml` back it. Patch releases are still cut per
fix-batch (v0.1.2 was the first via the script), so the `latest/download` install stays current.
