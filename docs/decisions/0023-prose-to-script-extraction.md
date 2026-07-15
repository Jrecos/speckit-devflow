# ADR-0023: prose→script extraction — guarantee-bearing prose becomes shared scripts

**Status:** Accepted (extends [ADR-0010](0010-fix-enforcement-layers.md)'s "each guarantee at
the strongest layer that can hold it"; motivated by the dogfood findings and the B1/B2 nets)

**Context:** ADR-0010 set the rule *behavior lives in prompts; each guarantee lives at the
strongest layer that can hold it*. [ADR-0019](0019-claude-native-orchestrator.md) then added a
**second driver** — the Claude-native `/speckit-devflow-start` orchestrator — beside the engine
workflow. Both drivers dispatch the **same** command markdown, so any invariant re-stated in
prose is re-stated in *N* command docs and must be kept in sync by hand.

Two dogfood findings were exactly this failure mode. Finding 5 (the feature diff must be
`base_commit..HEAD`, never `merge-base`) was prose in `review.md`, `verify.md`, and `capture.md`.
Finding 6 (the judge criteria must begin with a `TESTS:` oracle line) was prose in `iterate.md`
and `verify.md`. A prose invariant is only "enforced" by a **static grep on wording** (test-15):
that catches a deleted sentence, but it cannot prove the invariant actually *holds* at runtime —
only that the words are present. Every prose-layer bug we shipped was a re-statement drift.

**Decision:** Guarantee-bearing prose that **both drivers rely on** is extracted into **one
script the command markdown invokes**. The prompt keeps a short behavior description (for the
human/agent reader), but the **guarantee moves into the script** — one implementation, one place
to test, shared by both drivers.

| # | Script | Guarantee (was prose) | Callers |
|---|---|---|---|
| C1 | `devflow-diff-surface.sh` | the `base_commit`-not-`merge-base` feature diff + null→first-touch fallback (finding 5) | review, verify (via C2), capture |
| C2 | `devflow-judge-prep.sh` | assembles the judge's 3 files; the `TESTS:` oracle line is always criteria line 1 (finding 6) | iterate (`--diff working`), verify (`--diff feature`) |
| C3 | `devflow-status.sh` | read-only state render + the 6-branch next-action ladder (the mechanical choice) | status; users/orchestrator |
| C4 | `devflow-next-adr.sh` | the next ADR number (highest `NNNN` + 1, `0001` if none) | record-decision, reconcile-contract |
| C5 | `devflow-open-iteration.sh` + `devflow_tasks.py` | the fixed 5-command open-iteration transition; and the ONE `- [x]`/`- [ ]` count primitive | open-iteration → iterate; the count helper → init, compute-leash, loop-status, stop-gate, stop2-prep, status |

`devflow-judge.sh` stays dumb — it still just reads the three files. Judgment steps (code review,
deviation analysis) are **not** extracted: they are not mechanizable and belong at layer 3.
`workflow.yml` needs no rewire: it dispatches iterate/review/verify as commands that already call
these scripts, so both drivers share one implementation. Its remaining inline `python3 -c` steps
(clock-start, findings-status reads, park-findings, reconcile-if-parked) are engine-branching glue,
not extracted primitives; the park-findings parallel with `devflow-flow.sh` v_fix2 is a pre-existing
driver-parity item, a candidate for a later extraction, not part of C1–C5.

**Testing doctrine shift (strictly stronger):** the guarantee moves from *grep-on-prose* to
*grep-on-invocation* **plus** a *script-behavior test*.
- test-15 now asserts each command **invokes** the extracted script (a caller reverting to
  hand-rolled `merge-base` / hand-assembled criteria drops the invocation token → red).
- test-16 / test-17 prove the invariant **mechanically**: test-16 asserts `diff` is byte-identical
  to `git diff base_commit HEAD` and excludes prior-feature churn; test-17 asserts the criteria's
  first line is always `TESTS:`. A prose grep could never prove `base_commit` was *used* — only
  that the word appeared.

**Consequences:** One definition shared by both drivers — no re-statement drift; a fix lands
once. Behavior is preserved byte-for-byte where it was mechanical (test-16/17 assert it). The
one place prose was *ambiguous* — capture's "the feature's first commit" — is now pinned
deterministically to the first commit touching `<fdir>/`. Cost: a few more small scripts to
install, and a command that forgets to call its script is caught only by test-15's invocation
guard (acceptable — the same guard shape already protects every other script call). Bound: extract
only guarantee-bearing prose shared across drivers; leave single-caller mechanics and judgment in
the prompt.
