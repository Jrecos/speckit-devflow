# ADR-0024: authority order — user decision > spec.md > tests > current code

**Status:** Accepted (qualifies [ADR-0003](0003-tests-primary-oracle-judge-secondary.md)'s
"tests are the primary oracle"; preserves the finding-6 fix's outside-diff rule)

**Context:** DevFlow's whole verification chain leans on the scoped tests: the maker makes
them green, the judge's fallback prompt weighs the `TESTS:` line as the primary oracle, and
the Stop-gate re-runs them itself before committing GREEN. That is correct *while the tests
are correct*. When a test is **wrong** — contradicting spec.md — every layer conspires in the
test's favor: nothing anywhere told any component to doubt a test, so a maker that "fixes"
code (or the test itself) to satisfy a spec-contradicting assertion would sail through
checker, judge, and gate, and the error would be GREEN-committed. A wrong test was the one
case where the loop failed *coordinately*.

External evidence (smoke-grade, recorded honestly): the fable-method eval program
(`docs/research/loop-methods-analysis.md`) measured this exact failure **at DevFlow's own
model tier** — a Sonnet control flagged a spec-vs-test conflict 2/2 runs but *acted* wrong
2/2 (one rewrote the README to match the bad test); with an explicit authority order it acted
ideally 2/2. n=2 per cell — smoke evidence, but it is the only external technique measured to
fail at frontier tier, and the structural gap it names (no ordering anywhere in DevFlow) was
verified by direct inspection.

**Decision:** The authority order is `user decision > spec.md > tests > current code`, stated
at four surfaces:

1. **iterate.md** — a Standing rule (the order itself) plus a **conflict artifact at the
   action point**: before editing any existing test, its justification must trace to a spec
   section; a failing test that contradicts spec.md triggers the existing RED close with the
   failure note `CONFLICT: test <name> expects <X>; spec §<section> says <Y>`. The artifact
   rides an action the maker already takes (the RED close), which is the transfer-proven form
   (fable: rules-as-prose fail, artifacts-at-the-action-point transfer; artifacts requiring
   the model to *notice an absence* do not — this design needs neither).
2. **devflow-judge.sh fallback prompt** — rule (4): if the diff **changes or deletes a test**
   and that change contradicts the criteria or spec_slice, FAIL even though the TESTS line is
   green. Scoped to tests modified *in the diff*, so it cannot reopen the finding-6 fix
   (rule 2, outside-diff subjects still pass).
3. **devflow-checker.md** — a changed or deleted test in the diff is suspect until its
   justification traces to the spec/AC.
4. **verify.md** — verdict-reading exception: an authority-order FAIL is a real defect, never
   a scope artifact.

The conflict resolution itself is **the human's** (`user decision` outranks spec): the
CONFLICT note reaches the STOP via `failure_notes` → retry/parking → STOP evidence. DevFlow
never auto-edits a test or the spec to resolve a contradiction.

**Enforcement:** test-15 freezes the tokens at all four surfaces (static net). The behavioral
net is `evals/cases/iterate-authority-conflict/` — a fixture whose committed scoped test
contradicts spec.md; graded on `loop/state.json` (RED close + `CONFLICT:` note), untouched
test/spec hashes, and no GREEN close; `--self-test` deterministic, `--revert` strips the rule
and expects the grader red.

**Consequences:** A spec-contradicting test now costs an iteration (RED close + human STOP)
instead of silently corrupting the feature — the right trade: the loop's budget machinery
already absorbs RED closes, and a human decision is exactly what a spec conflict requires.
The judge clause deliberately does NOT ask the judge to re-derive spec conformance for
untouched tests (that stays with the primary oracle per ADR-0003); only in-diff test edits
lose the benefit of the doubt.
