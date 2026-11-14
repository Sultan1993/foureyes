## approach · round 1 · 2026-11-14
- (none)

## spec · round 1 · 2026-11-14 · 290s
- [Critical] fixed — Changed tasks retain completed status: `--derive` preserves status by subject alone, so a task whose criteria change under the same heading is skipped by build
- [Critical] fixed — Brief files include design sections only on a full-path match, so implementers miss requirements and cannot know to report NEEDS_CONTEXT
- [Critical] fixed — Bash heredoc under `.git` does not avoid protected-path approval; redirect targets are checked like direct writes
- [Important] fixed — Compact approaches `## Chosen` follows references only by number, losing entries inherited by letter (chosen entry 2 builds on B, which builds on A)
- [Important] fixed — Full suite at every wave barrier and again in Tasks 8–9 contradicts the user's run-the-full-suite-once-per-PR rule

## spec · round 2 · 2026-11-14 · 244s
- [Important] fixed — Drafter's missing-entry stop fires on comparison-only references ("unlike A"), contradicting the inheritance rule and re-copying unchosen entries
- [Important] fixed — Completed status survives changes to Global Constraints, Cross-Task Contracts or a prerequisite task, so build skips work done against superseded requirements
