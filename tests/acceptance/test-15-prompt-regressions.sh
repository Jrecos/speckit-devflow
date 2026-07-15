#!/usr/bin/env bash
source "$(dirname "$0")/helpers.sh"
# Static prompt-regression net: freezes the prompt-layer fix for each of the 7 dogfood
# findings (docs/roadmap.md dogfood-findings log) so a revision can't silently revert one.
# Every assertion pins the exact token that exists ONLY because of the fix — reintroduce
# the pre-fix wording and the matching line goes red. Deterministic; no fixtures needed.

CMDS="$REPO_ROOT/components/extensions/devflow/commands"
ONBOARD="$CMDS/speckit.devflow.onboard.md"
START="$CMDS/speckit.devflow.start.md"
REVIEW="$CMDS/speckit.devflow.review.md"
VERIFY="$CMDS/speckit.devflow.verify.md"
ITERATE="$CMDS/speckit.devflow.iterate.md"
CAPTURE="$CMDS/speckit.devflow.capture.md"

for f in "$ONBOARD" "$START" "$REVIEW" "$VERIFY" "$ITERATE" "$CAPTURE"; do
  [ -f "$f" ] || fail "missing command doc: $f"
done

# --- findings 1 & 7: onboard's semgrep registration -------------------------------------
# Fix: register the built-in server (`-- semgrep mcp -t stdio`) with telemetry off via env,
# and drop the deprecated standalone `uvx semgrep-mcp` package + its `--semgrep-path`/phantom
# `--metrics off` flags. Presence guards catch the built-in line vanishing; absence guards
# catch the dead package/flags being pasted back.
grep -q 'semgrep mcp -t stdio'    "$ONBOARD" || fail "finding 7: onboard no longer registers the built-in 'semgrep mcp -t stdio' server"
grep -q 'SEMGREP_SEND_METRICS=off' "$ONBOARD" || fail "finding 1: onboard dropped the 'SEMGREP_SEND_METRICS=off' telemetry env"
! grep -q 'uvx semgrep-mcp' "$ONBOARD" || fail "finding 7: onboard reintroduced the dead 'uvx semgrep-mcp' package"
! grep -q -- '--metrics off'  "$ONBOARD" || fail "finding 1: onboard reintroduced the phantom '--metrics off' flag"
! grep -q -- '--semgrep-path' "$ONBOARD" || fail "finding 7: onboard reintroduced the dead '--semgrep-path' flag"

# --- finding 3: start.md's FLOW is a literal path, not a shell variable ------------------
# Fix: FLOW is doc-shorthand for the literal `bash …/devflow-flow.sh` path — spelling out
# that it is NOT a variable (zsh won't word-split it; a var won't survive per-call shells).
grep -q 'literal path'         "$START" || fail "finding 3: start.md no longer declares FLOW is a literal path"
grep -q 'NOT a shell variable' "$START" || fail "finding 3: start.md no longer warns FLOW is NOT a shell variable"

# --- finding 4: start.md routes read-only inspection off the mutating loop-status --------
# Fix: loop-status is a once-per-dispatch advance step (it mutates/spends budget); peeks go
# to the read-only `/speckit-devflow-status` instead.
grep -q '/speckit-devflow-status'      "$START" || fail "finding 4: start.md no longer routes inspection to read-only /speckit-devflow-status"
grep -q 'one dispatch, one loop-status' "$START" || fail "finding 4: start.md no longer marks loop-status once-per-dispatch"

# --- finding 5: review/verify/capture delegate the diff surface to devflow-diff-surface.sh ---
# Post-ADR-0023 (C1): the base_commit-not-merge-base invariant + null→first-touch fallback now
# live IN devflow-diff-surface.sh (behavior-tested by test-16). The commands must INVOKE it
# rather than hand-roll `git diff merge-base`; reverting a caller to a hand-scoped merge-base
# drops the invocation token → red. (The guarantee moved from grep-on-prose to grep-on-
# invocation + a script-behavior test — strictly stronger.)
grep -q 'devflow-diff-surface.sh diff'         "$REVIEW"  || fail "finding 5: review.md no longer invokes devflow-diff-surface.sh for the review surface"
grep -q 'devflow-judge-prep.sh --diff feature' "$VERIFY"  || fail "finding 5: verify.md no longer scopes the judge diff to the feature surface (judge-prep --diff feature → base_commit, not merge-base)"
grep -q 'devflow-diff-surface.sh first-commit' "$CAPTURE" || fail "finding 5: capture.md no longer invokes devflow-diff-surface.sh for its range base"

# --- finding 6: verify.md + iterate.md route the judge through devflow-judge-prep.sh --------
# Post-ADR-0023 (C2): the TESTS:-line-first guarantee now lives in devflow-judge-prep.sh
# (behavior-tested by test-17). Both callers must INVOKE it (with their diff mode) rather than
# hand-assemble the criteria; hand-rolling criteria without the TESTS: line drops the
# invocation token → red. (grep-on-prose → grep-on-invocation + script-behavior test.)
grep -q 'devflow-judge-prep.sh --diff feature' "$VERIFY"  || fail "finding 6: verify.md no longer assembles the judge criteria via devflow-judge-prep.sh (TESTS: oracle line)"
grep -q 'devflow-judge-prep.sh --diff working' "$ITERATE" || fail "finding 6: iterate.md no longer assembles the judge criteria via devflow-judge-prep.sh (TESTS: oracle line)"

pass "prompt-regression net: 7 findings guarded"
