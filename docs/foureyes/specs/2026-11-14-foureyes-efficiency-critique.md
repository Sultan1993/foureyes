## approach · round 1 · 2026-11-14
- (none)

## spec · round 1 · 2026-11-14 · 373s
- [Critical] rejected — Task dependencies form self-cycles under 0-based indexing; checked agents/foureyes-drafter.md:207: the json:metadata fence uses 1-based task numbers, only the derived tasks.json is 0-based, so Task 4's [1,3] means Tasks 1 and 3
- [Critical] fixed — CodexRun contract drops window_minutes, plan_type and observation time needed by the allowance report
- [Critical] fixed — Failed/timed-out candidates excluded from recall with no completion threshold or control-recall floor, so `holds` can be reached on easy cases
- [Important] fixed — joinRuns matches on time proximity only; no seam/input identity, so runs can swap across buckets or attach wrong inputs
- [Important] fixed — Wrapper marker anywhere in a session line counts incidental mentions as wrapper executions
- [Important] fixed — Family-substring rates misprice GPT-6 Sol and GPT-5.6 Sol against the official per-model table
- [Important] fixed — Credit savings treated as subscription savings; credits are only a proxy for Pro Lite allowance
- [Important] fixed — Code cases only check SPEC_DOC exists today; the clone at HEAD_SHA may lack the spec
- [Important] fixed — Resume identity keyed on candidate position, so a changed --candidates list can reuse the wrong output
- [Important] fixed — Credit attachment has no attempt identity (no start/end timestamps or session id per attempt)
- [Important] fixed — Task 7 Verify greps away the rows it must check and its `;` chain can pass after a failure

## spec · round 2 · 2026-11-14 · 342s
- [Critical] fixed — `unique` joins carry no identity evidence yet become replay cases; an orphan call can attach to an unrelated subagent's run
- [Important] fixed — allowanceByModel orders by completion and ignores overlapping runs, so another model's usage leaks into a stretch
- [Important] fixed — Efficiency verdict uses last-attempt seconds/credits only, so retries and timeouts vanish
- [Important] fixed — Credit medians drop unmatched sessions per arm independently; no common priced cohort or coverage threshold
- [Important] fixed — Paired worse/equal/better outcome undefined beyond failed calls
- [Important] fixed — Spec claims Claude-side subagent tokens are unmeasurable, but subagents/ transcripts carry model and usage
