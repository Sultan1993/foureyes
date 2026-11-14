# foureyes-token-savings — approaches

BRIEF (verbatim): can you also start investigatin with foureyes where we can save up tokens? for example...i never read any of the files of brainstorm...lets say html we dont need at all (i can ask if needed ot produce). i dont myself manually check any artifacts, only rely on terminal output from agents describing the work

## Proposed

### 1 — Drop the page, keep everything else
WHAT: Do what the brief literally asks. `/Users/sultan/Development/lazypowers/skills/foureyes-brainstorm/lib/plan-viz.mjs` keeps running because it is also the structural linter, but writes no HTML unless called with a new `--html` flag, so the page stays available on request. The page is removed from `/Users/sultan/Development/lazypowers/skills/foureyes-brainstorm/SKILL.md` (description line 8, Step 4 lines 448-465, Step 5 lines 474-479) and from `/Users/sultan/Development/lazypowers/skills/foureyes-build/SKILL.md` (lines 89 and 137). The Step 5 report becomes the stated deliverable.
COST: No new dependencies and no new files. Touches two SKILL.md files, `plan-viz.mjs` and `plan-viz.test.mjs`, and possibly `/Users/sultan/Development/lazypowers/tests/prose-contracts.test.sh` (its line 170 comment mentions HTML). Nothing gets harder later.
GIVES UP: Almost all of the saving. `plan-viz.mjs` lines 415-441 show the page costs no model output: one node call, one path printed. The coordinator still hand-writes every other artifact.
CHECKED: n/a, no external capability. Read `plan-viz.mjs` main (lines 415-441): `--json` mode already runs the checks without writing HTML.

### 2 — Nothing is typed twice: the drafter writes its own file
WHAT: B, plus `agents/foureyes-drafter.md` gains `Write` and `Edit` (its line 7 has neither today). On Assignment A the drafter writes the spec to the path the coordinator gives it and returns only its `DRAFTER-STATS` line, the path, and any `## Unresolved`. On a revision it edits the file in place and does not return the whole spec again. The coordinator then checks `git status --porcelain` shows only that one path changed, runs the `plan-viz.mjs` lint, and passes the path to Sol as it does now. Assignment A0 is unchanged; approaches are still returned as content. The spill and overflow handling in brainstorm SKILL.md Step 0.4c (lines 196-209) shrinks to the A0 case.
COST: No new dependencies. Rewrites the top of `agents/foureyes-drafter.md` ("you author, the coordinator transcribes", "On a REVISION, return the full spec") and brainstorm SKILL.md Steps 0.4b-4c, 2 and 3, on top of B's files. It needs new `prose-contracts.test.sh` checks for the write guard. Today's spec is 47,708 B and went through a draft and two revisions that both changed it, so this removes about 143 KB of coordinator output, up to about 95 KB of drafter output on revisions, and the same bytes sitting twice in the coordinator's context for the rest of the run. The coordinator's malformed-spec check (Step 2, lines 421-424) has to become heading greps plus the lint, because it no longer holds the content.
GIVES UP: The guarantee that the drafter cannot touch the repo. It becomes prose plus an after-the-fact `git status` check, because a plugin agent cannot carry its own hooks. In-place edits can leave a stale passage that a full rewrite would have replaced. Sol's round 2 catches that for the first revision; the final revision is unread, as it is today.
CHECKED: Plugin subagents honour `tools` and `disallowedTools` but silently drop `hooks`, `mcpServers` and `permissionMode` (search summary of code.claude.com/docs/en/sub-agents and code.claude.com/docs/en/plugins/components; pages not opened). Write-capable plugin agents already work in this plugin: `agents/foureyes-implementer.md` line 9 lists `Write, Edit`. Not checked: the savings are byte counts of today's files on disk, not token counts from the session transcripts, and the earlier drafts may have been smaller than the final 47.7 KB.

(Note: "B" in entry 2 refers to entry 3 of this pool.)

### 3 — Scripts own the mirrors, coordinator still transcribes the spec
WHAT: A, plus the two copies that need no model. (1) `plan-viz.mjs` derives `<spec>.md.tasks.json` from the spec markdown itself. Its `parsePlanMarkdown` (lines 194-209) already extracts each task's heading, body and `json:metadata` fence, and the fence carries `blockedBy`. Step 4 of the brainstorm skill (lines 440-446) becomes one node call, not a model-written JSON file. (2) The approaches file keeps `## Decisions` and one line per pooled entry (title, proposer, merged or dropped and why), not a verbatim copy of both proposers' output (brainstorm SKILL.md lines 292-305). Build keeps its drift check at Step 0.5 for specs that arrive hand-edited.
COST: No new dependencies. One new mode in `plan-viz.mjs` with tests in `plan-viz.test.mjs`, two SKILL.md files, and the drafter's last line at `/Users/sultan/Development/lazypowers/agents/foureyes-drafter.md` line 251. Saves about 40 KB of coordinator output per run for tasks.json (40,299 B on disk today) and about 10 KB for the pool (13,191 B today). It also makes the `plan-tasks-*-mismatch` class unreachable from brainstorm, because the mirror can no longer be mistyped.
GIVES UP: The largest sink stays: the coordinator still re-emits the full spec after the draft and after each revision. The approaches file stops being able to show that an entry was reworded when merged, which is the audit the current prose defends. Nothing reads that file today (no script references it).
CHECKED: n/a, no external capability. The tasks.json shape that build and `pipeline-stats.mjs` consume is in `plan-viz.mjs` lines 17-24. The 0-based id versus 1-based fence numbering is confirmed by today's critique log, line 5.

(Note: "A" in entry 3 refers to entry 1 of this pool.)

### 4 — Terminal-first output with measured token reductions
WHAT: Make HTML opt-in in `skills/foureyes-brainstorm/SKILL.md` and `skills/foureyes-build/SKILL.md`, retaining structural validation through the existing `plan-viz.mjs --json` mode. Keep the spec, task data, and critique records: build consumes them for assignments, dependencies, resume, and review history. Replace the coordinator's model-generated `.tasks.json` transcription with deterministic extraction using `skills/foureyes-brainstorm/lib/plan-viz.mjs`. Make terminal summaries carry the chosen direction, assumptions, verification evidence, and unresolved findings. Extend `scripts/pipeline-stats.mjs` and `skills/foureyes-ledger/SKILL.md` to investigate actual Claude/Codex usage, distinguishing cached input, uncached input, and output; rank full-spec rewrites, repeated reads, and model calls by measured cost before recommending further cuts.
COST: No new dependencies or artifact migrations; approximately nine files across the named skills, two scripts/libraries, their existing tests, `tests/prose-contracts.test.sh`, and `README.md`. Historical accounting requires joining dispatches to available usage records and reporting gaps honestly. Existing build inputs remain compatible.
GIVES UP: Automatic HTML and file-path-heavy handoffs. Removing every brainstorm artifact would break build and resume; cutting critics immediately would trade away independent checks without evidence. Neither alternative is needed to address unread presentation work.
CHECKED: Local inspection confirmed HTML generation is deterministic, `--json` returns structural problems without writing HTML, and build reads `.tasks.json` directly. Brainstorm currently delegates JSON derivation to the coordinator; the existing library already parses task headings and metadata. Sampled Claude sidechain logs contain usage records, contradicting `pipeline-stats.mjs`'s blanket claim that subagent transcripts are unavailable; sampled Codex sessions contain token totals and cached-input counts. The four inspected installed files match this checkout. No external capability required. No builds, tests, or savings benchmark run; the amount of token savings remains unquantified.

UNKNOWNS (pooled):
- Is this run limited to brainstorm's artifacts plus build's one call to the page, or should it also cover what build, review and investigate write (for example the report under `docs/foureyes/investigations/`)? (one proposer raised it; default: brainstorm only)

## Decisions

- Provenance: 1, 2, 3 — Fable; 4 — Sol. Both proposers ran.
- Proposers' own picks: Fable → 2 ("the tokens go on the coordinator re-typing files that Fable or a script could produce … the largest step reverses the drafter's no-write-tools rule"). Sol → 4 ("eliminating [HTML] alone offers little direct token saving"; measure before cutting further).
- Both proposers independently found the HTML page itself costs almost nothing (it is a zero-dependency node render, one Bash call). The real cost is model-typed copies of files.
- Re-verified (load-bearing for 2 and 3/4): `agents/foureyes-drafter.md:7` tools are Read/Grep/Glob/WebSearch/context7 only; `agents/foureyes-implementer.md:9` already carries Write/Edit, so write-capable plugin agents work here; `plan-viz.mjs:2-4,416` has `--json` mode with no HTML write; `parsePlanMarkdown` exists at `plan-viz.mjs:194`; no file under `scripts/` or `skills/*/lib` reads an approaches file. All true.
- Merges: none. 3 and 4 share "HTML opt-in + script-derived tasks.json"; 3 adds compacting the approaches file, 4 adds richer terminal summaries and a usage-measurement layer. Kept separate.
- Dropped: 1 — every other entry includes it, and both proposers measured its saving as near zero. Dominated, not wrong.
- Note: 4's measurement layer overlaps the unbuilt `2026-11-14-foureyes-efficiency-design.md` (Sol-call attribution and allowance reporting in `pipeline-stats.mjs`).
- Ranking: 2 > 3 > 4. 2 removes the largest sink (the full spec re-typed after draft and each revision, ~143 KB coordinator output per run); 3 is the same cut without giving the drafter write access; 4 defers the big cut behind measurement that an existing spec already plans.
- Recommendation: 2.
- Unknown kept: scope (brainstorm-only vs also build/review/investigate). All survivors are brainstorm-scoped, so the pick does not settle it — asked independently.
- arbiter: claude-opus-5-5

CHOSEN: 2 — user
UNKNOWN answered: scope — all four skills (brainstorm, build, review, investigate)
