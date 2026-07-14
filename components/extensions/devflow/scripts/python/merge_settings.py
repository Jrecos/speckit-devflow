#!/usr/bin/env python3
"""Idempotently merge a DevFlow hooks fragment into .claude/settings.json.

Usage: merge_settings.py <settings.json path> <fragment.json path>
Creates the settings file if absent. A hook group is appended only if no
existing group in that event already runs the same command.
"""
import json, sys, os

def commands_of(group):
    return {h.get("command") for h in group.get("hooks", [])}

def main():
    target, fragment = sys.argv[1], sys.argv[2]
    frag = json.load(open(fragment))
    settings = {}
    if os.path.exists(target):
        with open(target) as f:
            settings = json.load(f)
    hooks = settings.setdefault("hooks", {})
    changed = False
    for event, groups in frag.get("hooks", {}).items():
        existing = hooks.setdefault(event, [])
        have = set()
        for g in existing:
            have |= commands_of(g)
        for g in groups:
            if commands_of(g) - have:
                existing.append(g)
                changed = True
    os.makedirs(os.path.dirname(target) or ".", exist_ok=True)
    with open(target, "w") as f:
        json.dump(settings, f, indent=2)
    print("merged" if changed else "already-present")

if __name__ == "__main__":
    main()
