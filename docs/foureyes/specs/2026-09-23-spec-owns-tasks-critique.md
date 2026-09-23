# Critique log — spec-owns-tasks

## spec · round 1 · 2026-09-23 · 241s
- [Important] fixed — prose tests 14e/14g extract the report section by `^## Step 7`; Task 4 renumbers it to Step 5. Pinned the Step 5 heading and order in Cross-Task Contracts; Task 8 moves the helper to `^## Step 5`.
- [Important] fixed — Task 8's Verify was `bash tests/run.sh`, red until the join, so the implementer could not report real evidence. Verify is now a syntax + presence check; the integrated suite is the coordinator's E6 barrier.
- [Important] fixed — pipeline-stats imports plan-viz, so Tasks 6–7 share a build unit and the test policy wrongly claimed none. Scaffold rule refined: a scaffold is needed only when a shared name does not yet exist; these imports exist and are declared unchanged.
- [Important] fixed — "legacy plans still run" was false: their Steps carry material nothing else does. `has-steps` now STOPS build with a one-line explanation; legacy plans are re-brainstormed. Success criterion 6 and Task 5 updated.
- [Minor] fixed — 64000 tokens described as a fixed ceiling. Reworded as the observed failure; the limit is `CLAUDE_CODE_MAX_OUTPUT_TOKENS`; test 22j kept.
