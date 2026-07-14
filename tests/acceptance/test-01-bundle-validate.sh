#!/usr/bin/env bash
source "$(dirname "$0")/helpers.sh"
command -v specify >/dev/null || fail "specify CLI not on PATH"
S=$(mktemp -d)
( cd "$S" && specify init . --integration claude --ignore-agent-tools >/dev/null 2>&1 ) \
  || fail "specify init failed (check flags with 'specify init --help')"
cd "$S"
# install our three authored components from the repo working tree
specify extension add "$REPO_ROOT/components/extensions/devflow" --dev || fail "devflow extension install"
specify preset add --dev "$REPO_ROOT/components/presets/devflow-plan-hardening" || fail "preset install"
specify workflow add "$REPO_ROOT/components/workflows/devflow/workflow.yml" || fail "workflow install (also engine-validates the YAML)"
# with components resolvable locally, the manifest must validate (git/superspec resolve via catalog/bundled)
cp -R "$REPO_ROOT/bundle" ./bundle
specify bundle validate --path ./bundle || fail "bundle validate"
pass "components install with real primitives; bundle validates"
