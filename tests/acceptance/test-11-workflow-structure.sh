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
# ADR-0028: build-loop + ONE fix-loop (inside the single native review-loop while).
# Was 3 (build + 2 unrolled fix-loops); the review unroll collapsed to a `while`.
assert len(loops) == 2, f"expected build + 1 fix loop, got {len(loops)}"
whiles = [s for s in allsteps if s.get("type") == "while"]
assert len(whiles) == 1 and whiles[0]["id"] == "review-loop", f"expected one review-loop while, got {[w['id'] for w in whiles]}"
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

# cap-park + accept-with-parked reconcile routing exist (spec §6-9/§6-10 structural halves).
# ADR-0028: the review loopback is one native `while` (review-loop) capped at review.cycles,
# with park-findings as a top-level trailing step (was inside the unrolled fix-cycle-2).
rl = find("review-loop")
assert rl["type"] == "while", "review-loop must be a native while (ADR-0028)"
assert isinstance(rl.get("max_iterations"), int) and rl["max_iterations"] >= 1, "review-loop needs an int cap"
assert any(x["id"] == "park-findings" for x in allsteps), "park-findings (trailing) missing"
assert not any(s["id"] in ("fix-cycle-1", "fix-cycle-2") for s in allsteps), "unrolled fix-cycles must be gone"
# gap-D backstop after the build loop (FIX-4): a forced park if the do-while cap exits with continue=true
assert any(s["id"] == "build-loop-backstop" for s in allsteps), "build-loop-backstop (gap-D) missing"
accept_case = find("route-stop2")["cases"]["accept"]
accept_ids = [x["id"] for x in accept_case]
assert "reconcile-if-parked" in accept_ids and "reconcile-parked" in accept_ids, accept_ids

# time-box clock re-stamps AFTER stop1 (a paused gate must not eat the box)
assert ids.index("start-clock") == ids.index("stop1") + 1, "start-clock must directly follow stop1"
assert "started_at" in find("start-clock")["run"]

# attended-step: every loop body carries a conditional step-gate (mode comparison in ONE {{ }})
for lp in loops:
    pause = next((b for b in lp["steps"] if b.get("type") == "if" and "attended-step" in str(b.get("condition"))), None)
    assert pause is not None, f"loop {lp['id']} missing attended-step pause"
    assert pause["condition"].count("{{") == 1, "mode comparison must live inside one {{ }} block"
    gate = pause["then"][0]
    assert gate["type"] == "gate" and gate["options"][-1] == "reject"

# feature.json contract: only feature_directory is read, never 'dir'
assert "feature_directory" in flat and "d['dir']" not in flat

# forbidden vocabulary
assert "supervised" not in flat
print("workflow structural checks pass")
PY
pass "workflow.yml structure verified"
