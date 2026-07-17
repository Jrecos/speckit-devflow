#!/usr/bin/env bash
# DevFlow flow guard (ADR-0019): the mechanical ledger behind /speckit-devflow-start.
# Phases flip to done ONLY when their exit artifacts exist on disk — the flow file
# cannot claim progress the disk does not show, and phases complete strictly in order.
#
# Usage:
#   devflow-flow.sh init <mode>                      # create flow file (idempotent)
#   devflow-flow.sh start <phase>                    # mark phase active
#   devflow-flow.sh complete <phase> [--decision X]  # verify artifacts, then mark done
#   devflow-flow.sh status                           # human-readable ledger
#   devflow-flow.sh next                             # print the next pending phase
set -euo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}"

CMD="${1:?usage: devflow-flow.sh init|start|complete|status|next ...}"; shift || true
# Machinery preflight (finding 9): the ledger must never be created in a degraded tree.
if [ "$CMD" = "init" ]; then
  bash .specify/extensions/devflow/scripts/bash/devflow-preflight.sh >/dev/null
fi
FDIR=$(python3 -c 'import json;print(json.load(open(".specify/feature.json"))["feature_directory"])')
FLOW="$FDIR/devflow-flow.json"

python3 - "$CMD" "$FLOW" "$FDIR" "$@" <<'PY'
import json, os, re, subprocess, sys, datetime

cmd, flow_p, fdir = sys.argv[1], sys.argv[2], sys.argv[3]
args = sys.argv[4:]

PHASES = ["frame", "plan", "leash", "analyze", "stop1", "build",
          "review", "fix-cycle-1", "fix-cycle-2", "verify", "stop2",
          "reconcile", "ship", "capture"]
# phases that may be skipped when their entry condition doesn't hold
SKIPPABLE = {"fix-cycle-1", "fix-cycle-2", "reconcile"}
STOPS = {"stop1": ["approve", "reject"],
         "stop2": ["accept", "accept-with-deviation", "reject"]}

def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()

def load():
    return json.load(open(flow_p))

def save(flow):
    json.dump(flow, open(flow_p, "w"), indent=2)

def die(msg):
    print(f"devflow-flow: BLOCKED — {msg}", file=sys.stderr)
    sys.exit(1)

def exists(p):
    return os.path.exists(os.path.join(fdir, p)) if not p.startswith("/") else os.path.exists(p)

def state():
    return json.load(open(os.path.join(fdir, "loop", "state.json")))

# ---- exit-artifact verifiers: phase -> error string or None ----
def v_frame():
    if not exists("spec.md"): return "frame needs spec.md (run specify/brainstorm/clarify first)"
def v_plan():
    if not exists("plan.md"): return "plan needs plan.md"
    if not exists("tasks.md"): return "plan needs tasks.md"
    t = open(os.path.join(fdir, "tasks.md")).read()
    if not re.search(r"^- \[[ x]\] \S+", t, re.M): return "tasks.md has no countable task lines"
    if "AC:" not in t: return "tasks.md has no AC: criteria lines (plan-hardening format)"
def v_leash():
    if not exists("loop/state.json"): return "leash needs loop/state.json (run devflow-init.sh + devflow-compute-leash.sh)"
    if not os.path.exists(".specify/devflow/leash.md"): return "leash needs .specify/devflow/leash.md"
    if state()["budget"]["total"] < 1: return "budget not computed (compute-leash)"
def v_analyze():
    return None  # analyze emits a report in-conversation; ordering is the guard here
def v_build():
    s = state()
    if s.get("continue") is not False: return "build loop has not exhausted (state.continue != false) — keep iterating or let a brake fire"
def v_review():
    if not exists("review/findings.json"): return "review needs review/findings.json"
    if not exists("review/findings.md"): return "review needs review/findings.md"
def v_fix1():
    # Cycle 1 is not the cap: remaining findings after its re-review legitimately flow to
    # cycle 2, so completion is ordering-only. Verify's clean-or-parked prereq is the backstop.
    return None
def v_fix2():
    # Cycle 2 IS the cap (ADR-0012): survivors are PARKED here, mirroring workflow.yml's
    # park-findings step, so the two drivers are equivalent and Verify's prereq passes.
    p = os.path.join(fdir, "review/findings.json")
    fj = json.load(open(p))
    if fj.get("status") == "findings":
        fj["status"] = "parked"
        json.dump(fj, open(p, "w"), indent=2)
    return None
def v_verify():
    r = subprocess.run(["bash", ".specify/extensions/devflow/scripts/bash/devflow-check-review.sh"],
                       capture_output=True, text=True)
    if r.returncode != 0: return f"verify prerequisite failed: {r.stderr.strip()}"
    if not exists("verify-report.md"): return "verify needs verify-report.md"
def v_reconcile():
    # spec must have been touched at least as recently as the verify report
    spec_m = os.path.getmtime(os.path.join(fdir, "spec.md"))
    vr = os.path.join(fdir, "verify-report.md")
    if os.path.exists(vr) and spec_m < os.path.getmtime(vr):
        return "reconcile requires editing spec.md (contract text) — spec.md is older than verify-report.md"
def v_ship():
    r = subprocess.run(["git", "status", "--porcelain"], capture_output=True, text=True)
    if r.stdout.strip(): return "ship needs a clean tree (commit/PR done)"
def v_capture():
    return None  # human curation; ordering is the guard

VERIFIERS = {"frame": v_frame, "plan": v_plan, "leash": v_leash, "analyze": v_analyze,
             "build": v_build, "review": v_review,
             "fix-cycle-1": v_fix1, "fix-cycle-2": v_fix2,
             "verify": v_verify, "reconcile": v_reconcile, "ship": v_ship,
             "capture": v_capture}

# ---- commands ----
if cmd == "init":
    mode = args[0] if args else "attended"
    if os.path.exists(flow_p):
        print(f"devflow-flow: ledger exists ({flow_p}) — resuming")
    else:
        save({"feature_dir": fdir, "mode": mode, "created_at": now(),
              "phases": {p: {"status": "pending", "at": None, "decision": None} for p in PHASES}})
        print(f"devflow-flow: ledger created ({flow_p}, mode={mode})")
    sys.exit(0)

flow = load()

if cmd == "status":
    icons = {"pending": "·", "active": "▶", "done": "✓", "skipped": "○"}
    for p in PHASES:
        ph = flow["phases"][p]
        d = f"  decision={ph['decision']}" if ph.get("decision") else ""
        print(f"{icons[ph['status']]} {p:12s} {ph['status']}{d}")
    sys.exit(0)

if cmd == "next":
    for p in PHASES:
        if flow["phases"][p]["status"] in ("pending", "active"):
            print(p); sys.exit(0)
    print("complete"); sys.exit(0)

phase = args[0] if args else die("phase argument required")
if phase not in PHASES: die(f"unknown phase '{phase}' (valid: {', '.join(PHASES)})")

if cmd == "start":
    # strict order: every earlier phase must be done or skipped
    for p in PHASES[:PHASES.index(phase)]:
        if flow["phases"][p]["status"] not in ("done", "skipped"):
            die(f"cannot start '{phase}': '{p}' is {flow['phases'][p]['status']} (phases complete in order)")
    flow["phases"][phase].update(status="active", at=now())
    save(flow); print(f"devflow-flow: {phase} active")
    sys.exit(0)

if cmd == "complete":
    decision = None
    if "--decision" in args:
        decision = args[args.index("--decision") + 1]
    if "--skip" in args:
        if phase not in SKIPPABLE: die(f"'{phase}' is not skippable")
        flow["phases"][phase].update(status="skipped", at=now())
        save(flow); print(f"devflow-flow: {phase} skipped"); sys.exit(0)
    for p in PHASES[:PHASES.index(phase)]:
        if flow["phases"][p]["status"] not in ("done", "skipped"):
            die(f"cannot complete '{phase}': '{p}' is {flow['phases'][p]['status']}")
    if phase in STOPS:
        if not decision: die(f"'{phase}' is a human gate: pass --decision <choice> AFTER the human chose")
        if decision not in STOPS[phase]: die(f"'{phase}' decision must be one of {STOPS[phase]}")
        if decision == "reject": die(f"'{phase}' rejected — the pipeline stops here (re-plan or abandon; the ledger keeps the record)")
        if phase == "stop1" and decision == "approve":
            # Start the time-box clock AFTER approval, matching the engine driver's
            # start-clock step (workflow.yml) — human deliberation must not eat the box.
            sp = os.path.join(fdir, "loop", "state.json")
            if os.path.exists(sp):
                st = json.load(open(sp))
                st["started_at"] = now()
                json.dump(st, open(sp, "w"), indent=2)
    else:
        err = VERIFIERS[phase]()   # STOP phases have no artifact verifier: the decision IS the artifact
        if err: die(err)
    flow["phases"][phase].update(status="done", at=now(), decision=decision)
    save(flow); print(f"devflow-flow: {phase} done" + (f" (decision={decision})" if decision else ""))
    sys.exit(0)

die(f"unknown command '{cmd}'")
PY
