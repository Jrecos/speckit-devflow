#!/usr/bin/env python3
"""Tiny JSON state CLI used by DevFlow bash scripts (stdlib only).

Usage:
  devflow_state.py get  <state.json> <key>            # dotted keys ok: budget.used
  devflow_state.py set  <state.json> <key> <json>     # value parsed as JSON
  devflow_state.py bump <state.json> <key>            # integer += 1
"""
import json, sys

def resolve(d, dotted, create=False):
    parts = dotted.split(".")
    for p in parts[:-1]:
        if create and p not in d:
            d[p] = {}
        d = d[p]
    return d, parts[-1]

def main():
    op, path, key = sys.argv[1], sys.argv[2], sys.argv[3]
    with open(path) as f:
        state = json.load(f)
    if op == "get":
        d, k = resolve(state, key)
        print(json.dumps(d.get(k)))
        return
    if op == "set":
        d, k = resolve(state, key, create=True)
        d[k] = json.loads(sys.argv[4])
    elif op == "bump":
        d, k = resolve(state, key, create=True)
        d[k] = int(d.get(k, 0)) + 1
    else:
        sys.exit(f"unknown op {op!r}")
    with open(path, "w") as f:
        json.dump(state, f, indent=2)

if __name__ == "__main__":
    main()
