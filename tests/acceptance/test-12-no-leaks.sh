#!/usr/bin/env bash
source "$(dirname "$0")/helpers.sh"
# Forbidden strings: infra/personal references. Author handle Jrecos is allowed.
# ".local" targets mDNS-style hostnames; the official Claude local-pair filenames
# (settings.local.json, CLAUDE.local.md) are legitimate and filtered back out.
patterns='jreco[^s]|/Users/|alliedstone|aig-|git-asi|192\.168\.|10\.0\.|\.local[^h]|ssh://'
hits=$(grep -RInE "$patterns" "$REPO_ROOT/components" "$REPO_ROOT/bundle" 2>/dev/null \
  | grep -v 'Binary' | grep -v 'settings\.local\.json\|CLAUDE\.local\.md' || true)
[ -z "$hits" ] || fail "leak-like strings found:
$hits"
pass "no personal/client/infra strings in components/ or bundle/"
