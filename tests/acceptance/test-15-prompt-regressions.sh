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

for f in "$ONBOARD" "$START" "$REVIEW" "$VERIFY" "$ITERATE"; do
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

# --- finding 5: review.md + verify.md scope the diff to base_commit, never merge-base ----
# Fix: diff surface is `base_commit..HEAD` (stamped once at loop start) with an explicit
# do-NOT-use-merge-base guard (merge-base goes stale on a stacked branch). Assert BOTH the
# base_commit surface AND the guard text — "merge-base" itself lives inside the guard, so we
# check the guard's presence, not the bare token's absence.
grep -q 'base_commit'            "$REVIEW" || fail "finding 5: review.md no longer scopes the diff to base_commit"
grep -q 'NOT use `merge-base`'   "$REVIEW" || fail "finding 5: review.md dropped the do-NOT-use-merge-base guard"
grep -q 'base_commit'            "$VERIFY" || fail "finding 5: verify.md no longer scopes the diff to base_commit"
grep -q 'NOT use `merge-base`'   "$VERIFY" || fail "finding 5: verify.md dropped the do-NOT-use-merge-base guard"

# --- finding 6: verify.md + iterate.md feed the test oracle to the judge -----------------
# Fix: prepend a `TESTS:` line to the judge criteria so the judge weighs the green suite as
# the primary oracle and doesn't FAIL on code outside the diff (ADR-0003).
grep -q 'TESTS:' "$VERIFY"  || fail "finding 6: verify.md no longer prepends a TESTS: line to the judge criteria"
grep -q 'TESTS:' "$ITERATE" || fail "finding 6: iterate.md no longer prepends a TESTS: line to the judge criteria"

pass "prompt-regression net: 7 findings guarded"
