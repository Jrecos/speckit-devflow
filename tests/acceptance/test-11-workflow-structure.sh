#!/usr/bin/env bash
source "$(dirname "$0")/helpers.sh"
W="$REPO_ROOT/components/workflows/devflow/workflow.yml"
[ -f "$W" ] || fail "workflow.yml missing"
python3 - "$W" <<'PY'
import sys, json
try:
    import yaml
except ImportError:
    sys.exit("pyyaml required for this test: pip install pyyaml")
d = yaml.safe_load(open(sys.argv[1]))
steps = d["steps"]
ids = [s["id"] for s in steps]
flat = json.dumps(d)

def find(sid):
    return next(s for s in steps if s["id"] == sid)

# STOP gates exist, options end with reject (EOF default), STOP1 aborts on reject
s1 = find("stop1"); assert s1["type"] == "gate" and s1["options"][-1] == "reject" and s1["on_reject"] == "abort"
s2 = find("stop2"); assert s2["type"] == "gate" and s2["options"] == ["accept", "accept-with-deviation", "reject"]
assert s1.get("show_file") == ".specify/devflow/leash.md"
assert s2.get("show_file") == ".specify/devflow/stop2.md"

# do-while loops: literal int max_iterations, condition reads loop-status data, iterate has continue_on_error
def walk(steps_):
    for s in steps_:
        yield s
        for key in ("steps", "then", "else"):
            if key in s: yield from walk(s[key])
        for case in s.get("cases", {}).values(): yield from walk(case)
        if s.get("default"): yield from walk(s["default"])
allsteps = list(walk(steps))
loops = [s for s in allsteps if s.get("type") == "do-while"]
assert len(loops) == 3, f"expected build + 2 fix loops, got {len(loops)}"
for lp in loops:
    assert isinstance(lp["max_iterations"], int), "max_iterations must be literal int"
    it = next(b for b in lp["steps"] if str(b.get("command", "")).endswith("iterate"))
    assert it.get("continue_on_error") is True, "iterate needs continue_on_error"
    ls = next(b for b in lp["steps"] if b["id"].startswith("loop-status"))
    assert ls["type"] == "shell" and ls.get("output_format") == "json"
    assert f"steps.{ls['id']}.output.data.continue" in lp["condition"], (lp["id"], lp["condition"])

# routing is switch (never split-{{ }} if), on stop2 choice
sw = find("route-stop2"); assert sw["type"] == "switch"
assert sw["expression"] == "{{ steps.stop2.output.choice }}"
assert set(sw["cases"].keys()) == {"accept", "accept-with-deviation"}
assert sw.get("default") == [], "reject must fall to empty default (gate aborts first)"

# verify prerequisite shell step exists before verify command
pre_idx = ids.index("verify-prereq"); ver_idx = ids.index("verify")
assert pre_idx < ver_idx
assert "devflow-check-review.sh" in find("verify-prereq")["run"]

# mode input enum
mode = d["inputs"]["mode"]
assert mode["enum"] == ["attended", "attended-step", "autonomous"] and mode["default"] == "attended"

# integration wiring: input exists with default auto; EVERY command step carries it (dispatch fails without)
assert d["inputs"]["integration"]["default"] == "auto"
cmds = [s for s in allsteps if "command" in s]
missing = [s["id"] for s in cmds if s.get("integration") != "{{ inputs.integration }}"]
assert not missing, f"command steps missing integration wiring: {missing}"

# cap-park + accept-with-parked reconcile routing exist (spec §6-9/§6-10 structural halves)
fix2 = find("fix-cycle-2")
assert any(x["id"] == "park-findings" for x in fix2["then"]), "park-findings missing from cycle 2"
accept_case = find("route-stop2")["cases"]["accept"]
accept_ids = [x["id"] for x in accept_case]
assert "reconcile-if-parked" in accept_ids and "reconcile-parked" in accept_ids, accept_ids

# feature.json contract: only feature_directory is read, never 'dir'
assert "feature_directory" in flat and "d['dir']" not in flat

# forbidden vocabulary
assert "supervised" not in flat
print("workflow structural checks pass")
PY
pass "workflow.yml structure verified"
