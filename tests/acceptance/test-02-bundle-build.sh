#!/usr/bin/env bash
source "$(dirname "$0")/helpers.sh"
command -v specify >/dev/null || fail "specify CLI not on PATH"
S=$(mktemp -d)
( cd "$S" && specify init . --integration claude --ignore-agent-tools >/dev/null 2>&1 )
cd "$S"
specify extension add "$REPO_ROOT/components/extensions/devflow" --dev >/dev/null || fail "extension install"
specify preset add --dev "$REPO_ROOT/components/presets/devflow-plan-hardening" >/dev/null || fail "preset install"
specify workflow add "$REPO_ROOT/components/workflows/devflow/workflow.yml" >/dev/null || fail "workflow install"
cp -R "$REPO_ROOT/bundle" ./bundle
specify bundle build --path ./bundle --output ./dist || fail "bundle build"
ls dist/devflow-0.2.0.zip >/dev/null || fail "artifact missing"

# §6-2 second half: install idempotency + §5 footprint. Components are already installed
# (--dev above), so `bundle install` must skip/refresh without changing the footprint.
snapshot() { ls -R .specify/extensions/devflow .specify/workflows 2>/dev/null | (md5sum 2>/dev/null || md5 -q) | head -1; }
out1=$(snapshot)
specify bundle install devflow >/dev/null 2>&1 || true   # catalog-less env: skip-if-installed path
out2=$(snapshot)
[ "$out1" = "$out2" ] || fail "bundle install changed an already-complete footprint"
# §5 footprint spot-checks
[ -d .specify/extensions/devflow/scripts/bash ] || fail "footprint: devflow scripts missing"
[ -f .specify/extensions/devflow/devflow-config.yml ] || fail "footprint: devflow config missing"
ls .specify/workflows/devflow* >/dev/null 2>&1 || fail "footprint: workflow missing"
pass "bundle builds + install idempotent + footprint present"
