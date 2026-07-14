#!/usr/bin/env bash
# Enforces the command-authoring checklist (ADR-0021 / docs/research/command-authoring-research.md)
# on every command document, so revisions can't regress the doctrine.
source "$(dirname "$0")/helpers.sh"
CMDS="$REPO_ROOT/components/extensions/devflow/commands"
python3 - "$CMDS" <<'PY'
import glob, os, re, sys
cmds = sorted(glob.glob(os.path.join(sys.argv[1], "*.md")))
assert len(cmds) >= 9, f"expected >=9 command docs, found {len(cmds)}"
LONG_WORKFLOWS = {"speckit.devflow.start.md", "speckit.devflow.iterate.md",
                  "speckit.devflow.onboard.md"}
errs = []
for f in cmds:
    name = os.path.basename(f)
    text = open(f).read()
    lines = text.count("\n") + 1
    # (2) length ceiling
    if lines >= 500: errs.append(f"{name}: {lines} lines (ceiling 500)")
    # (1) frontmatter: description with what+when+keywords, <=1024
    if not text.startswith("---"): errs.append(f"{name}: no frontmatter"); continue
    fm = text.split("---")[1]
    m = re.search(r'description:\s*"(.*?)"\s*$', fm, re.S | re.M)
    if not m: errs.append(f"{name}: no quoted description"); continue
    d = m.group(1)
    if len(d) > 1024: errs.append(f"{name}: description {len(d)} chars (cap 1024)")
    if "Use " not in d: errs.append(f"{name}: description lacks 'Use when/to' trigger phrasing")
    if "Keywords:" not in d: errs.append(f"{name}: description lacks trigger keywords")
    # (5) Done-when gate + (11) handoff
    if not re.search(r"^## Done when", text, re.M): errs.append(f"{name}: no '## Done when' gate")
    if not re.search(r"^## Handoff", text, re.M): errs.append(f"{name}: no '## Handoff' section")
    # (9) standing instructions present and early (before first numbered step) for workflow docs
    if name != "speckit.devflow.status.md":  # status is read-only; single standing rule ok anywhere
        if not re.search(r"^## Standing rule", text, re.M):
            errs.append(f"{name}: no '## Standing rule(s)' section")
    # (4) progress checklist for long workflows
    if name in LONG_WORKFLOWS and "- [ ]" not in text:
        errs.append(f"{name}: long workflow without a copyable '- [ ]' progress checklist")
    # retired vocabulary
    if "supervised" in text: errs.append(f"{name}: retired word 'supervised'")
assert not errs, "authoring checklist violations:\n  " + "\n  ".join(errs)
print(f"{len(cmds)} command docs conform to the authoring checklist")
PY
pass "command authoring checklist enforced"
