#!/usr/bin/env bash
# Cut a DevFlow bundle release: bump the version-literal set in lockstep, validate,
# build the 3 release assets, smoke-test a clean install, then (real runs only)
# commit, tag, push, and publish a GitHub release. See docs/releasing.md.
#
# Usage: scripts/release.sh <version> [--dry-run]
#   <version>   semver, e.g. 0.1.2 (a leading "v" is stripped if present)
#   --dry-run   bump + validate + build + smoke, then restore the working tree.
#               No commit, no tag, no push, no GitHub release — dist/ is left
#               behind for inspection.
#
# Any failure before the commit step auto-restores the working tree (see the
# EXIT trap below), so a failed run never leaves a half-bumped repo behind.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

GH_REPO="Jrecos/speckit-devflow"
GH_HTTPS="https://github.com/$GH_REPO.git"
GH_ACCOUNT="${GH_REPO%%/*}"          # the gh account that owns/pushes this repo
PRIOR_GH_ACCOUNT=""; SWITCHED_ACCOUNT=0   # for restoring the user's active account on exit

# ---- args ----
DRY_RUN=0
VERSION=""
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -*) echo "release: unknown flag: $arg" >&2; exit 1 ;;
    *) VERSION="$arg" ;;
  esac
done
[ -n "$VERSION" ] || { echo "usage: scripts/release.sh <version> [--dry-run]" >&2; exit 1; }
VERSION="${VERSION#v}"
echo "$VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$' \
  || { echo "release: version must be semver X.Y.Z (got: $VERSION)" >&2; exit 1; }

# ---- the version-literal set (bumped together, lockstep) ----
BUMPED_FILES=(
  bundle/bundle.yml
  components/extensions/devflow/extension.yml
  components/presets/devflow-plan-hardening/preset.yml
  components/workflows/devflow/workflow.yml
  tests/acceptance/test-02-bundle-build.sh
  README.md
)

# Only THESE files need to be pristine going in — they're the only ones this script ever
# `git add`s or `git checkout --`s. Unrelated untracked/dirty files elsewhere in the repo
# (e.g. other in-flight work) are none of this script's business and must not block a release.
dirty_bumped_files="$(git status --porcelain -- "${BUMPED_FILES[@]}")"
[ -z "$dirty_bumped_files" ] || {
  echo "release: the version-literal files already have uncommitted changes — commit or stash first:" >&2
  echo "$dirty_bumped_files" >&2
  exit 1
}

# DIRTY flips to 1 once the bump has actually touched files. Any non-zero exit
# while DIRTY=1 restores BUMPED_FILES to HEAD — the tree only stays dirty
# across a successful run's own commit, or a --dry-run's deliberate stop.
DIRTY=0
restore_tree() {
  # Restore from HEAD, not the index. In the real-run window between `git add` and the
  # commit, a bare `git checkout -- ` would reproduce the STAGED bumped content;
  # `git checkout HEAD -- ` resets both the index and the working tree to HEAD, so the
  # restore is complete and unstaged even if a commit/tag fails mid-flight (validator finding).
  git checkout HEAD -- "${BUMPED_FILES[@]}" 2>/dev/null || true
}
on_exit() {
  local ec=$?
  if [ "$DIRTY" = 1 ] && [ "$ec" -ne 0 ]; then
    echo "release: aborting (exit $ec) — restoring working tree" >&2
    restore_tree
  fi
  # Leave the user's gh active-account as we found it (we may have switched it to push).
  if [ "$SWITCHED_ACCOUNT" = 1 ] && [ -n "$PRIOR_GH_ACCOUNT" ]; then
    gh auth switch --user "$PRIOR_GH_ACCOUNT" >/dev/null 2>&1 || true
  fi
}
trap on_exit EXIT

echo "== release: bumping version literals to $VERSION =="
# Context-keyed, not a blind replace: each substitution is anchored to the line
# shape (indent/quoting) or the preceding "- id: <x>" line, so bundle.yml's
# pinned git (1.0.0) / superspec (1.0.1) provides entries are never touched.
# All substitutions are computed in memory first; nothing is written unless
# every expected hit-count matched (atomic — no partial bump on a mismatch).
python3 - "$VERSION" <<'PY'
import re, sys, pathlib

new = sys.argv[1]
cache = {}   # path -> in-memory text, written to disk only if every sub() below succeeds

def load(path):
    if path not in cache:
        cache[path] = pathlib.Path(path).read_text()
    return cache[path]

offenders = []

def sub(path, pattern, repl, expect, flags=0):
    text = load(path)
    text2, n = re.subn(pattern, repl, text, count=0, flags=flags)
    if n != expect:
        offenders.append(f"{path}: expected {expect} hit(s) for /{pattern}/, found {n}")
        return
    cache[path] = text2

b = "bundle/bundle.yml"
# bundle.version: top-level, 2-space indent, unquoted
sub(b, r'(?m)^(  version: )[\d.]+$', r'\g<1>' + new, 1)
# provides mirrors, keyed by the preceding "- id: <x>" line. extensions.devflow and
# workflows.devflow are byte-identical two-line stanzas, so one pattern -> 2 hits.
sub(b, r'(- id: devflow\n      version: )"[\d.]+"', r'\1"' + new + '"', 2)
sub(b, r'(- id: devflow-plan-hardening\n      version: )"[\d.]+"', r'\1"' + new + '"', 1)

sub("components/extensions/devflow/extension.yml",
    r'(?m)^(  version: )"[\d.]+"$', r'\g<1>"' + new + '"', 1)
sub("components/presets/devflow-plan-hardening/preset.yml",
    r'(?m)^(  version: )"[\d.]+"$', r'\g<1>"' + new + '"', 1)
sub("components/workflows/devflow/workflow.yml",
    r'(?m)^(  version: )"[\d.]+"$', r'\g<1>"' + new + '"', 1)

sub("tests/acceptance/test-02-bundle-build.sh",
    r'devflow-[\d.]+\.zip', 'devflow-' + new + '.zip', 1)
# README's build-output comment — keyed to the comment marker itself so it self-heals
# even though it's currently stale (says 0.1.0 while the manifests say 0.1.1).
sub("README.md", r'(# → devflow-)[\d.]+(\.zip)', r'\g<1>' + new + r'\2', 1)

if offenders:
    print("release: version-literal bump FAILED (no files written):", file=sys.stderr)
    for o in offenders:
        print(f"  - {o}", file=sys.stderr)
    sys.exit(1)

for path, text in cache.items():
    pathlib.Path(path).write_text(text)
print(f"release: bumped {len(cache)} files to {new}")
PY
DIRTY=1

echo "== release: grep-guard =="
# Independent re-read from disk: every literal in the set now equals $VERSION,
# and the untouched pins (git/superspec) are still exactly where they were.
python3 - "$VERSION" <<'PY'
import re, sys, pathlib

new = sys.argv[1]
checks = [
    ("bundle/bundle.yml", rf'(?m)^  version: {re.escape(new)}$'),
    ("bundle/bundle.yml", rf'- id: devflow\n      version: "{re.escape(new)}"'),
    ("bundle/bundle.yml", rf'- id: devflow-plan-hardening\n      version: "{re.escape(new)}"'),
    ("components/extensions/devflow/extension.yml", rf'(?m)^  version: "{re.escape(new)}"$'),
    ("components/presets/devflow-plan-hardening/preset.yml", rf'(?m)^  version: "{re.escape(new)}"$'),
    ("components/workflows/devflow/workflow.yml", rf'(?m)^  version: "{re.escape(new)}"$'),
    ("tests/acceptance/test-02-bundle-build.sh", rf'devflow-{re.escape(new)}\.zip'),
    ("README.md", rf'# → devflow-{re.escape(new)}\.zip'),
]
offenders = [f"{path}: missing literal for version {new}"
             for path, pattern in checks if not re.search(pattern, pathlib.Path(path).read_text())]

bundle_text = pathlib.Path("bundle/bundle.yml").read_text()
for pinned_id, pinned_version in [("git", "1.0.0"), ("superspec", "1.0.1")]:
    if not re.search(rf'- id: {pinned_id}\n      version: "{re.escape(pinned_version)}"', bundle_text):
        offenders.append(f"bundle/bundle.yml: pinned {pinned_id}@{pinned_version} was disturbed")

if offenders:
    print("release: grep-guard FAILED — version literals out of lockstep:", file=sys.stderr)
    for o in offenders:
        print(f"  - {o}", file=sys.stderr)
    sys.exit(1)
print(f"release: grep-guard OK — every literal == {new}")
PY

echo "== release: bundle validate (offline structural check) =="
# NOTE: a bare `specify bundle validate --path bundle` ALWAYS fails from the repo
# root — devflow/devflow-plan-hardening/devflow (our own components) resolve only
# once registered into a project (--dev install) or a catalog; git/superspec need
# catalog access. --offline runs the schema/well-formedness check without either,
# so it still catches a corrupted bump immediately. The real reference-resolution
# validate happens for real in tests/acceptance/test-01 (a proper scratch-project
# bootstrap), which run-all.sh runs next.
specify bundle validate --path bundle --offline

echo "== release: acceptance suite =="
bash tests/acceptance/run-all.sh

echo "== release: building release assets =="
rm -rf dist
mkdir -p dist
( cd components/extensions && zip -rq ../../dist/devflow-extension.zip devflow -x '*.DS_Store' )
( cd components/presets && zip -rq ../../dist/devflow-plan-hardening.zip devflow-plan-hardening -x '*.DS_Store' )
cp components/workflows/devflow/workflow.yml dist/devflow-workflow.yml
echo "release: built $(ls dist | tr '\n' ' ')"

echo "== release: onboarding smoke test =="
bash scripts/onboard-smoke.sh dist

if [ "$DRY_RUN" = 1 ]; then
  restore_tree
  DIRTY=0
  # Verify the claim rather than asserting it: a swallowed restore failure must not print success.
  leftover="$(git status --porcelain -- "${BUMPED_FILES[@]}")"
  [ -z "$leftover" ] || { echo "release: WARNING — dry-run restore left changes in the version-literal files:" >&2; printf '%s\n' "$leftover" >&2; exit 1; }
  echo "DRY RUN — tree restored, no release cut"
  exit 0
fi

echo "== release: committing + tagging =="
git add "${BUMPED_FILES[@]}"
git commit -m "release: v$VERSION"
DIRTY=0   # committed — the tree is clean now; any later failure (tag/push/publish) must
          # NOT trigger a working-tree restore (there is nothing dirty to restore, and the
          # commit stands — the operator re-runs the tag/push by hand).
git tag "v$VERSION"

echo "== release: pushing (gh HTTPS, not raw origin — see CLAUDE.md) =="
# The active gh account can drift to another repo's account; a wrong active account 403s the
# push (observed cutting v0.2.0). Switch to THIS repo's owner account for the push (restored on
# exit by the trap), and force gh's credential helper so a stale osxkeychain token for a
# different account can't win over it.
PRIOR_GH_ACCOUNT="$(gh api user -q .login 2>/dev/null || true)"
if [ "$PRIOR_GH_ACCOUNT" != "$GH_ACCOUNT" ]; then
  if gh auth switch --user "$GH_ACCOUNT" >/dev/null 2>&1; then
    SWITCHED_ACCOUNT=1
  else
    echo "release: WARNING — could not switch gh to '$GH_ACCOUNT'; push may 403 if the active account lacks access" >&2
  fi
fi
gh auth setup-git
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
push_gh() { git -c credential.helper= -c 'credential.helper=!gh auth git-credential' push "$GH_HTTPS" "$1"; }
push_gh "$CURRENT_BRANCH"
push_gh "v$VERSION"

echo "== release: creating GitHub release =="
gh release create "v$VERSION" --repo "$GH_REPO" \
  --title "v$VERSION" \
  --notes "DevFlow bundle release v$VERSION. See docs/releasing.md." \
  dist/devflow-extension.zip dist/devflow-plan-hardening.zip dist/devflow-workflow.yml

echo "== release: verifying propagation (best-effort) =="
V="$(mktemp -d)"
if ( cd "$V" \
     && specify init . --integration claude --ignore-agent-tools >/dev/null 2>&1 \
     && echo y | specify extension add devflow \
          --from "https://github.com/$GH_REPO/releases/download/v$VERSION/devflow-extension.zip" \
          >/tmp/release-verify.log 2>&1 \
     && specify extension list 2>/dev/null | grep -q "v$VERSION" ); then
  echo "release: verified — clean install reports v$VERSION"
else
  echo "release: WARNING — could not verify the clean-install version yet." >&2
  echo "  Asset propagation on GitHub's CDN can lag right after publish; re-check manually with:" >&2
  echo "  specify extension add devflow --from https://github.com/$GH_REPO/releases/download/v$VERSION/devflow-extension.zip" >&2
  echo "  (log: /tmp/release-verify.log)" >&2
fi
rm -rf "$V"

echo "release: v$VERSION cut — https://github.com/$GH_REPO/releases/tag/v$VERSION"
