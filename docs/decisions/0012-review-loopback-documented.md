# ADR-0012: Review findings loop back into Build — every hop documented

**Status:** Accepted

**Context:** When the Review phase (/code-review + Semgrep + /security-review) finds
problems, someone must fix them. Candidates: (A) findings auto-convert to fix-tasks and
control re-enters the Build loop until Review is clean; (B) findings park at STOP #2 for
human triage; (C) severity-split — mechanical findings loop back, security/architectural
ones park. Risk analysis: A can ping-pong (fix → new finding → fix) and burns budget
invisibly; B costs a human decision for trivia and re-enters Build *after* the gate;
C puts an *agent* in charge of classifying what the human sees — uncomfortably close to
gap B's original failure (the loop deciding review was "handled").

**Decision:** **Option A — auto-loopback — made safe by documentation and a cap** (the
operator's call, explicitly tying it to spec-kit core doctrine: files before control):

1. Review's **first act is writing findings to the review artifact**
   (`specs/<feature>/review/findings.md`) — findings exist on disk before anything reacts.
2. Findings convert to **fix-tasks in `tasks.md`**, each linking its finding.
3. The Build loop **re-enters** scoped to fix-tasks only, with a re-entry budget from the
   ADR-0011 formula (`fix_task_count × 2.5`). Every fix follows the full iteration
   protocol: record-decision (rationale references the finding) + auto-commit.
4. **Re-review runs the full gate** (never a lighter pass); resolved findings are marked
   in the artifact.
5. **Re-entry cap: 2 cycles** (`review_cycles: 2`, config). Findings that survive the cap
   are **parked at STOP #2** with the complete finding → fix → re-finding history.
   This cap is what kills the ping-pong risk.
6. **Verify has a hard prerequisite** (workflow shell-step check, layer 1): the review
   artifact must exist and report clean-or-parked. Review is structurally unskippable
   (gap B) regardless of what happens inside the loopback.

The paper trail: finding documented → fix-task documented → fix documented (decision
record + commit) → resolution documented. Capture reads all of it.

**Consequences:** STOP #2 sees either clean work or a fully-documented impasse — never
silent rework. Maximum autonomy preserved (trivial findings never cost a human decision).
Cost: Build→Review can cycle up to twice before a human hears about it — bounded by the
cap and the loop's own budget; accepted. Rejected: (B) as the default — too much human
ceremony for mechanical findings (kept as the post-cap fallback, so B still exists inside
A); (C) — agent-graded severity on a security gate repeats gap B's failure shape.
