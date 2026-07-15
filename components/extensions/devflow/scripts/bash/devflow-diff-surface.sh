#!/usr/bin/env bash
# DevFlow diff surface (ADR-0023 extraction; the invariant behind finding 5).
# The ONE definition of a feature's review/verify/capture base + diff, shared by both drivers
# so no prompt has to re-derive it. Encodes: the base is `base_commit` stamped ONCE at loop
# start (devflow-init.sh) — deterministic and topology-proof; NEVER `merge-base` (which, on a
# branch stacked off an unmerged feature, picks a stale point and floods the diff with prior
# features). Null base_commit (older state) falls back to the first commit that touched <fdir>/.
#
# Usage:
#   devflow-diff-surface.sh base           # print the review/verify base commit (with fallback)
#   devflow-diff-surface.sh diff           # print `git diff <base> HEAD` — the review/verify surface
#   devflow-diff-surface.sh first-commit   # print the first commit touching <fdir>/ (capture's range base)
set -euo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}"

CMD="${1:?usage: devflow-diff-surface.sh base|diff|first-commit}"
FDIR=$(python3 -c 'import json;print(json.load(open(".specify/feature.json"))["feature_directory"])')

first_touch() { git log --reverse --format=%H -- "$FDIR" 2>/dev/null | head -1; }

resolve_base() {
  local b
  b=$(python3 -c 'import json,sys
try:
    print(json.load(open(sys.argv[1])).get("base_commit") or "")
except Exception:
    print("")' "$FDIR/loop/state.json" 2>/dev/null || true)
  if [ -z "$b" ]; then
    b=$(first_touch)
    [ -n "$b" ] && echo "devflow-diff-surface: base_commit unset — falling back to first commit touching $FDIR/ ($b)" >&2
  fi
  [ -n "$b" ] || { echo "devflow-diff-surface: cannot resolve a base commit (no base_commit and no commit touches $FDIR/)" >&2; return 1; }
  printf '%s\n' "$b"
}

case "$CMD" in
  base)
    resolve_base ;;
  diff)
    base=$(resolve_base) || exit 1
    git diff "$base" HEAD ;;
  first-commit)
    fc=$(first_touch)
    [ -n "$fc" ] || { echo "devflow-diff-surface: no commit touches $FDIR/" >&2; exit 1; }
    printf '%s\n' "$fc" ;;
  *)
    echo "devflow-diff-surface: unknown command '$CMD' (base|diff|first-commit)" >&2; exit 2 ;;
esac
