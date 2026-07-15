#!/usr/bin/env bash
# C4 (ADR-0023): the next-ADR-number computation now lives in devflow-next-adr.sh, shared by
# record-decision and reconcile-contract. Byte-identical to the prose: highest NNNN + 1.
source "$(dirname "$0")/helpers.sh"
S=$(mktemp -d); make_scratch_project "$S"; install_devflow_assets "$S"
cd "$S"
NA=".specify/extensions/devflow/scripts/bash/devflow-next-adr.sh"
mkdir -p docs/decisions

[ "$(bash "$NA")" = "0001" ] || fail "empty decisions dir must yield 0001"

touch docs/decisions/0001-a.md docs/decisions/0002-b.md docs/decisions/0005-c.md
[ "$(bash "$NA")" = "0006" ] || fail "next after 0005 must be 0006 (highest+1)"

touch docs/decisions/README.md   # non-numeric prefix ignored
[ "$(bash "$NA")" = "0006" ] || fail "non-numeric md must be ignored"

touch docs/decisions/0023-x.md   # gap-tolerant: highest+1, not count+1
[ "$(bash "$NA")" = "0024" ] || fail "must be highest+1 (0024), not count-based"

pass "next-adr: highest NNNN + 1, zero-padded; empty→0001; ignores non-numeric; gap-tolerant"
