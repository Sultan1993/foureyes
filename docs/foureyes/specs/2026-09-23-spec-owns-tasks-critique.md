# Critique log — spec-owns-tasks

## spec · round 1 · 2026-09-23 · 241s
- [Important] fixed — prose tests 14e/14g extract the report section by `^## Step 7`; Task 4 renumbers it to Step 5. Pinned the Step 5 heading and order in Cross-Task Contracts; Task 8 moves the helper to `^## Step 5`.
- [Important] fixed — Task 8's Verify was `bash tests/run.sh`, red until the join, so the implementer could not report real evidence. Verify is now a syntax + presence check; the integrated suite is the coordinator's E6 barrier.
- [Important] fixed — pipeline-stats imports plan-viz, so Tasks 6–7 share a build unit and the test policy wrongly claimed none. Scaffold rule refined: a scaffold is needed only when a shared name does not yet exist; these imports exist and are declared unchanged.
- [Important] fixed — "legacy plans still run" was false: their Steps carry material nothing else does. `has-steps` now STOPS build with a one-line explanation; legacy plans are re-brainstormed. Success criterion 6 and Task 5 updated.
- [Minor] fixed — 64000 tokens described as a fixed ceiling. Reworded as the observed failure; the limit is `CLAUDE_CODE_MAX_OUTPUT_TOKENS`; test 22j kept.

## spec · round 2 · 2026-09-23 · 167s
- [Important] fixed — Task 8's Verify banned `TASKS-PER-PART`/`spliceTasks`/`plan-critic` from the test source while requiring assertions that name them; and `grep "^## Step 5"` could not match the helper's embedded pattern. Verify now checks the negative assertions exist and uses fixed-string matches on `/^## Step 5/`.
- [Important] fixed — Task 5's Verify rejected the word `Steps` file-wide while Step 0.5 must name the field to explain the stop. Prohibition scoped to the E2 assignment line (`Verify / Steps` absent); Task 8(e) matches.
- [Important] fixed — Task 5's metadata still said "old plans still run". Replaced with: a legacy plan stops at Step 0.5 on `has-steps` with a one-line explanation and dispatches nothing.

## code · round 1 · 2026-09-23 · 193s
- [Critical] fixed — code critic's description and check 1 named spec conformance but not `## Cross-Task Contracts`; both now require every pinned declaration honoured.
- [Critical] fixed — prose assertion 29e grepped the whole build file, so it passed even when E2 dropped the forwarded sections or has-steps became report-and-continue. Scoped to the E2 section; new 29e2 pins has-steps in Step 0.5's STOP row.
