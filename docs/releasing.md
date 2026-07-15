# Releasing the DevFlow bundle

How to cut a release, what `scripts/release.sh` does on your behalf, and how to diagnose it
when a step fails. Background: [roadmap.md](roadmap.md) dogfood finding #2 (a release once
shipped a tag whose manifests weren't actually bumped) and finding #7 (an upstream tool's
subcommand silently disappeared underneath a pinned dependency) are exactly the two failure
classes this tooling exists to make structurally impossible.

## Prerequisites

- `specify` (Spec Kit CLI, `>=0.12.0`), `semgrep`, `gh` on `PATH`.
- `gh` authenticated as an account with push access to `Jrecos/speckit-devflow` (working
  account: `Jrecos`). Run `gh auth setup-git` once so git itself uses `gh`'s credentials —
  `scripts/release.sh` also runs this before pushing.
- A clean working tree. `scripts/release.sh` refuses to start otherwise (a dirty tree would
  either get swept into the release commit or clobbered by the failure-path restore).

## The version-literal set

A release bumps **seven** literals across **six files**, all to the same `<version>`, in one
atomic step:

| File | What |
|---|---|
| `bundle/bundle.yml` | `bundle.version` (top-level) |
| `bundle/bundle.yml` | `provides.extensions[devflow].version` |
| `bundle/bundle.yml` | `provides.presets[devflow-plan-hardening].version` |
| `bundle/bundle.yml` | `provides.workflows[devflow].version` |
| `components/extensions/devflow/extension.yml` | `extension.version` |
| `components/presets/devflow-plan-hardening/preset.yml` | `preset.version` |
| `components/workflows/devflow/workflow.yml` | `workflow.version` |
| `tests/acceptance/test-02-bundle-build.sh` | the hardcoded `dist/devflow-<version>.zip` artifact-name assertion |
| `README.md` | the `# → devflow-<version>.zip` build-output comment |

`bundle/bundle.yml`'s `provides` block also pins `git` (`1.0.0`) and `superspec` (`1.0.1`) —
upstream primitives this bundle depends on, **never** touched by a release.

The bump is context-keyed (anchored to line shape or the preceding `- id: <x>` line), not a
blind find-and-replace, so it can't accidentally touch the pinned `git`/`superspec` lines even
if their version numbers ever happened to collide with the bundle's own. A **grep-guard**
re-reads every file from disk afterward and asserts each literal now equals `<version>` — if
the bump and the guard ever disagree, the script prints the offenders and exits non-zero
before touching git.

## Cutting a release

```bash
scripts/release.sh 0.1.2 --dry-run   # rehearse: bump → validate → build → smoke → restore tree
scripts/release.sh 0.1.2             # the real thing: also commits, tags, pushes, publishes
```

Full flow:

1. **Bump** the version-literal set (above) + grep-guard.
2. **Validate**: `specify bundle validate --path bundle --offline` (fast structural/schema
   check — see the note below on why it's `--offline`), then the full acceptance suite
   (`bash tests/acceptance/run-all.sh`, 15 tests — includes the real reference-resolution
   validate in `test-01`, the real `specify bundle build` in `test-02`, and the leak-scan in
   `test-12`).
3. **Build** the 3 release assets into a fresh `dist/` (see below).
4. **Smoke-test**: `scripts/onboard-smoke.sh dist` — a clean-machine install from the
   *packaged* assets (see below).
5. **`--dry-run` stops here**: `git checkout --` restores the bumped files (dist/ is left for
   inspection — it's gitignored, so there's nothing to restore), prints `DRY RUN — tree
   restored, no release cut`, exits 0. Nothing else in the flow ran.
   **A real run continues**: `git add` + `git commit -m "release: v<version>"` + `git tag
   v<version>`, then `gh auth setup-git` and a push over the explicit HTTPS remote URL
   (`https://github.com/Jrecos/speckit-devflow.git` — never the bare `origin` shorthand, per
   the project's git-push convention), then `gh release create v<version>` with the 3 assets
   attached.
6. **Best-effort verify**: installs the extension into a throwaway temp project straight from
   the just-published GitHub release URL and checks it reports `v<version>`. If this fails
   it's a warning, not an abort — GitHub's asset CDN can lag a few seconds right after
   publish; the warning includes the exact command to re-check by hand.

**Any failure between step 1 and the commit in step 5 auto-restores the working tree** (an
`EXIT` trap watches a dirty flag), so a failed run never leaves a half-bumped repo behind —
you don't have to remember to clean up after a broken `--dry-run` or a validate/test failure.

### Why `--offline` for the first validate

A bare `specify bundle validate --path bundle`, run from the repo root, **always** fails: the
bundle's own components (`devflow` the extension/preset/workflow) only resolve once they're
registered somewhere the CLI can see — installed into a project (`--dev`) or listed in a
catalog — neither of which is true of the bare source tree. `--offline` runs the schema/
well-formedness check without needing either, which is exactly what you want as a fast
sanity gate right after a version bump: it'll still catch a corrupted or malformed edit
immediately. The *real* reference-resolution validate — proving `devflow`/
`devflow-plan-hardening`/`devflow` actually resolve — happens for real in
`tests/acceptance/test-01-bundle-validate.sh`, which spins up a proper scratch project first.
`run-all.sh` (step 2b above) runs it right after.

## The 3 release assets

`specify` has no per-component build command, so `release.sh` builds these by hand into a
fresh `dist/` (rebuilt every run — `dist/` is gitignored):

| Asset | How it's built |
|---|---|
| `dist/devflow-extension.zip` | `(cd components/extensions && zip -r ../../dist/devflow-extension.zip devflow)` — archive root is `devflow/` |
| `dist/devflow-plan-hardening.zip` | same, from `components/presets`, archive root `devflow-plan-hardening/` |
| `dist/devflow-workflow.yml` | verbatim copy of `components/workflows/devflow/workflow.yml` |

These are what `gh release create` attaches, and what an end user actually downloads via
`specify extension add --from <url>` / `specify preset add --from <url>` / `specify workflow
add <url>`. They are distinct from `dist/devflow-<version>.zip`, the whole-bundle archive
`specify bundle build` produces — that one is exercised by `test-02` as part of the
acceptance suite but is not a GitHub release asset.

## Clean-machine smoke test (`scripts/onboard-smoke.sh`)

```bash
scripts/onboard-smoke.sh          # uses <repo>/dist
scripts/onboard-smoke.sh dist     # or an explicit dist dir — standalone-runnable
```

Installs the 3 **packaged** assets into a fresh scratch project the way a real user would —
critically, via `specify extension/preset add --from <url>`, **not** `--dev` straight from
source. `--dev` bypasses the zip entirely, so it would never catch a packaging bug (a stale
file left out of the zip, a broken archive root, …). Since `--from` requires HTTPS except for
localhost, the script serves `dist/` over a throwaway `python3 -m http.server` on an ephemeral
localhost port — this exercises the real download path with no network access and no
published release required.

It then asserts:
- `specify extension list` reports the version currently in
  `components/extensions/devflow/extension.yml` (the packaging/version-bump drift check).
- Exactly 9 `speckit-devflow-*` skills rendered under `.claude/skills/`.
- **Upstream-drift check** (roadmap.md finding #7): `semgrep mcp --help` exits 0 — DevFlow's
  Review phase depends on semgrep's *built-in* MCP server subcommand (the standalone
  `semgrep-mcp` package is deprecated and, if present, only returns a deprecation notice).
  `semgrep` missing entirely only **warns** (it's an optional local tool); `semgrep` present
  but missing the `mcp` subcommand **fails** — that's the exact drift shape that bit us once
  already.

Implementation note: `specify extension list`'s output is captured via command substitution
(`out=$(specify extension list ...)`) rather than piped straight into `grep`. Piping it
directly was observed to be intermittently flaky in testing — likely Rich's non-TTY output
rendering racing a fast-exiting `grep -q` reader — capturing the full buffer first made the
check deterministic across repeated runs.

## CI

- **`.github/workflows/ci.yml`** — every push/PR to `main`: installs `specify`/`semgrep`, runs
  `specify bundle validate --path bundle --offline` + the full acceptance suite. Catches
  manifest/component breakage before merge; does not build or publish release assets.
- **`.github/workflows/release.yml`** — on pushing a `v*` tag: builds the 3 release assets and
  publishes a GitHub release, using the built-in `GITHUB_TOKEN`. This is the safety net if a
  release is ever tagged by hand instead of via `scripts/release.sh` (which already publishes
  as part of its own flow). It is **idempotent**: it checks `gh release view` first and, if the
  release already exists (e.g. `release.sh` just created it on the same tag push), uploads the
  assets with `--clobber` instead of failing — so it's correct whether the tag was cut by the
  script or by hand, and re-running it never errors on an existing release.

## Troubleshooting

- **`gh` push fails with "Repository not found"** — the active `gh` account lacks access;
  `gh auth switch --user Jrecos` and retry.
- **Grep-guard fails after a bump** — a manifest's `version:` line shape changed (indentation,
  quoting) since this runbook was written, so the context-keyed regex in `scripts/release.sh`
  no longer matches. Update the regex in the bump step to match the new shape; don't loosen it
  to a blind replace.
- **`onboard-smoke.sh` fails the semgrep check** — read the failure message: "not installed"
  is a warning you can ignore locally (CI always installs it); "lacks the mcp subcommand"
  means semgrep shipped a breaking change and the onboarding instructions
  (`components/extensions/devflow/commands/speckit.devflow.onboard.md`) likely need updating
  too — see roadmap.md finding #7 for the last time this happened.
- **Best-effort propagation verify warns after a real release** — expected occasionally; wait
  a few seconds and re-run the `specify extension add --from https://github.com/…` command
  the warning prints.
