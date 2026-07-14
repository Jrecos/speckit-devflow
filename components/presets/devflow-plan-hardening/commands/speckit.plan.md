---
description: Create a plan and store it in plan.md — with the failing acceptance tests DevFlow requires.
---

## User Input

```text
$ARGUMENTS
```

## Outline

1. Read `.specify/feature.json` to get the feature directory path
   (key: `feature_directory`).

2. **Load context**: `.specify/memory/constitution.md` and `<feature_directory>/spec.md`.

3. Create an implementation plan and store it in `<feature_directory>/plan.md`:
   - Technical context: tech stack, dependencies, project structure
   - Design decisions, architecture, file structure
   - Testing strategy

4. **REQUIRED — write the failing acceptance tests NOW (DevFlow hardening):**
   - One acceptance test per major requirement of the spec, under the project's
     test tree.
   - Run them: every one must FAIL (red) — they describe behavior that does not
     exist yet. A test that passes before implementation is not an acceptance test.
   - List their paths in plan.md under a heading exactly: `## Acceptance tests (red)`
   - **Planning is not complete until these tests exist and fail.** They are the
     build loop's visible target and Verify's final oracle.

5. Report the plan location and the count of red acceptance tests.
