# foureyes token savings — nothing is typed twice

Spec path: `docs/foureyes/specs/2026-11-14-foureyes-token-savings-design.md`. Chosen approach: entry 2 of the pool (the drafter writes its own file; scripts own the mirrors; the HTML page is opt-in), extended to build, review and investigate by the user's scope answer.

## Purpose

The user reads only what agents print in the terminal. They never open the spec, the HTML page, the approaches file or any other artifact. Today the coordinator spends most of its output re-typing documents that a subagent already produced or that a script could derive. This spec removes every such copy that has no reader, in all four skills, and keeps every file that a script or a later stage reads.

Three kinds of waste are cut:

1. **A file a model re-types.** The author (a subagent) or a script writes it directly.
2. **A whole document pulled into the coordinator's context.** The coordinator gets a path and a short index.
3. **An artifact nobody reads.** It is produced only on request.

## Evidence

Sizes marked "estimate" are a line share of a measured file, not a byte count.

| Waste today | Where | Size on the 2026-11-14 efficiency run |
|---|---|---|
| Coordinator re-types the full spec after the draft and after each revision | brainstorm `SKILL.md:418-421`, `:434-435` | 47,708 B x 3, about 143 KB of coordinator output (figure from the approaches file, `...token-savings-approaches.md:15`) |
| Drafter returns the full spec again on each revision | `agents/foureyes-drafter.md:45-49` | up to about 95 KB of drafter output |
| Coordinator types `.tasks.json` by hand | brainstorm `SKILL.md:440-446` | 40,299 B |
| Coordinator copies both proposers' output into `## Proposed` | brainstorm `SKILL.md:292-305` | 13,191 B |
| Build re-types `## Global Constraints` and `## Cross-Task Contracts` into every implementer and reviewer prompt | build `SKILL.md:222-227`, `:293-296` | those sections are lines 495-515 and 342-494 of a 732-line, 47,708 B spec, about 11 KB per prompt (estimate). 8 implementer and 7 reviewer prompts: about 170 KB |
| Build re-types every task three times (TaskCreate, implementer prompt, reviewer prompt) | build `SKILL.md:174-175`, `:222`, `:294` | task sections are lines 516-732, about 14 KB (estimate), so about 42 KB |
| Build reads the 40 KB mirror and the spec into its own context | build `SKILL.md:174`, `:225-226` | about 88 KB that stays in context for the whole run |
| Review coordinator re-types Codex's findings into `codex.json` and each single finding into a refute prompt | review `SKILL.md:115-118`, `:127-135` | not measured: no review run exists in this repo |
| Investigate coordinator types all scout reports twice per round | investigate `SKILL.md:107-114` | not measured: no investigation exists in this repo |

Readers verified before deciding what to keep:

- **Critique log: keep.** `scripts/sol-ledger.mjs:75-82` collects every `*-critique.md`.
- **`.tasks.json`: keep, script-derived.** Read by build E1 (`SKILL.md:174`) and by `scripts/pipeline-stats.mjs:60-83`, which also reads each task's `status`.
- **HTML page: opt-in.** No script, test or agent reads `<spec>.md.html`. It is written at `plan-viz.mjs:430-431` and mentioned only in brainstorm `SKILL.md:8,448-455,474-479`, build `SKILL.md:89,137` and `README.md:106`.
- **Approaches file: compact.** No file under `scripts/`, `tests/` or `skills/*/lib` reads it.
- **Native task descriptions: cut to a pointer.** Implementers work from their prompt (`agents/foureyes-implementer.md:25-29`); reviewers get the task in their assignment (`agents/foureyes-task-reviewer.md:26-31`).
- **Review `report.md`, `bucket.json`, `refutations.json`, `meta.json`: keep.** `review-synth.mjs:113-127` reads or writes them at no model cost.
- **Investigation report: keep.** It is typed once and is the brief the user hands to build.

Two facts constrain the design:

- **Any write under `.git` is a protected-path write, whichever tool makes it.** The Write and Edit tools and a Bash output redirect are treated alike: a redirect target is checked like a direct write (https://code.claude.com/docs/en/permissions#redirections). `.git` is a protected path: a write there prompts in `default`, `acceptEdits` and `plan`, goes to the classifier in `auto`, is denied in `dontAsk`, and passes unasked only in `bypassPermissions` (https://code.claude.com/docs/en/permission-modes#protected-paths). The coordinator opened both pages for round 1; the round-1 revision re-checked the mode table by search summary only, and nothing has re-checked it since. Bash redirection is therefore not a way around the prompt, and the earlier draft's claim that it was is withdrawn. What follows from it:
  - Build and review already depend on such writes today and this spec does not change that: build creates its run directory with `mkdir -p` (`SKILL.md:165`) and redirects each task diff into it (`:256-258`); review does the same (`SKILL.md:87`, `:113`, `:122`). `.git/foureyes-build/28b78c9/task-*.diff` exist in this checkout, so those writes are approved or allowed here. This spec adds files to those two existing directories and adds no new protected location.
  - Investigate has no run directory under `.git` today, and this spec does not give it one (Design 6).
  - No subagent is asked to write under `.git`.
- `agents/foureyes-review-critic.md` and `agents/foureyes-refute-critic.md` are also the prompts Codex runs under `codex exec -s read-only` (build `SKILL.md:27`, `tests/prose-contracts.test.sh:45-50`). They cannot be told to write a file.

## Assumptions

Each line is a decision made for the user, then what breaks if it is wrong.

- **A stray write by the drafter is reported, not stopped on.** The coordinator cannot tell the drafter's write from another session's edit in the same checkout, and nothing in brainstorm commits. If you want a hard stop, the run continues past a write you would have blocked.
- **The write guard has two blind spots.** `git status` cannot see an edit to a file that was already modified or untracked before the dispatch, or to an ignored path. If the drafter edits such a file, nothing reports it.
- **If the drafter cannot write (permission denied), the run stops.** It does not fall back to returning the spec as content. If your permission mode blocks subagent writes, brainstorm stops at Step 2 until you allow them. Build already needs the same permission for implementers.
- **The approaches file's `## Chosen` section holds the chosen entry and everything it builds on, verbatim.** The approach text you picked asked only for one line per entry. On this run's pool the chosen entry 2 builds on 3, which builds on 1, so three of four entries stay verbatim and the file shrinks by about 2 KB only. The file gets small only when the chosen entry stands alone. If you want it smaller regardless, the drafter loses inherited requirements. An entry the chosen one only compares itself with ("unlike A") is not copied; if you wanted the drafter to see what it was compared against, it sees one line under `## Pool` and no more.
- **A completed task keeps its status across a re-derive only when nothing it was built against changed.** Three things reset it: its own section changed; `## Global Constraints` or `## Cross-Task Contracts` changed, which resets every task; or a task it is blocked by is no longer completed. The comparison is byte-exact, so a typo fix in a shared section resets the whole build. Build's resume rule then shows the committed work task by task and asks; "mark it done" restores each. If that is too many questions after a small contracts edit, the alternative is the stale completion this rule exists to prevent.
- **A change to design prose alone resets nothing.** What binds an implementer is its task section, the constraints and the contracts. If you change the design and want tasks rebuilt, the change has to reach their criteria or a shared section.
- **Build re-derives the mirror at every start.** A spec edited by hand after a partial build is therefore judged by the same status rule. If you edited the mirror by hand and expected build to trust it over the spec, it no longer does.
- **Mirrors typed by hand before this change reset completely on their first derive.** They carry no `sharedHash`, so every task becomes `pending`, and that first derive now happens at the next build start. The reset is in the safe direction: build's existing resume rule (E1) shows the committed work and asks.
- **Every implementer and reviewer gets the whole design, not a selection.** A brief holds the spec minus the other tasks' sections. On the efficiency spec that is about 22 KB (estimate, lines 1-341 of 732) more input per dispatch than a task-only brief. It is subagent input read once, traded for coordinator output; if that input turns out to matter, the fix is an explicit task-to-section mapping in the fence, which this spec does not add.
- **Build and review keep their run directories under the git directory.** In a mode that blocks `.git` writes, both already fail at their first `mkdir -p` today; this spec leaves that as it is and says STOP when a script cannot write there.
- **Investigate's scout file sits beside the report and is left there.** It is one more untracked file under `docs/foureyes/investigations/` per run. In `default` mode without an allow rule, the run's first write prompt moves from Step 6 to Step 3.
- **The implementer's report still travels inline to the reviewer.** Moving it to a file needs a subagent write under `.git`, a protected path. If reports turn out large, that copy remains.
- **Review still types Claude's findings into `claude.json` once.** The reviewer prompt is shared with read-only Codex. That copy remains.
- **The investigation report file stays, and review's five-line digest stays as it is.** If you want review findings in full in the terminal, that is a separate change that adds output.
- **Build's Step F report is unchanged.** It is the one thing you read, so its per-criterion evidence list is not shortened.
- **Existing `.html` pages under `docs/foureyes/` are left in place.**
- **Not verified:** whether a subagent inherits the session's permission mode; whether a write that a script makes itself (node `fs`) under `.git` gets the protected-path check (the design does not depend on the answer: a denied or failed write is handled either way); and the review and investigate savings (no run artifacts to measure).

## Design

### 1. `plan-viz.mjs`: derive the mirror, write briefs, page on request

`skills/foureyes-brainstorm/lib/plan-viz.mjs` stays the structural linter and gains four things. The command lines are in Cross-Task Contracts.

- **`--derive`** builds `<spec>.md.tasks.json` from the spec markdown and writes it, then lints as usual. The shape is the one build and `pipeline-stats.mjs` already read (`plan-viz.mjs:17-24`, brainstorm `SKILL.md:441-446`): 0-based `id`, `subject` equal to the heading text, `description` equal to the whole task section including its fence, 0-based `blockedBy` (the fence's task numbers minus one). It adds one top-level field, `sharedHash`, which no existing reader looks at (`scripts/pipeline-stats.mjs:69-83` reads only `tasks`). Because the fence is copied verbatim, the `plan-tasks-*` drift problems cannot occur after a derive.
  - **Status.** A derived task is `completed` only when all three of these hold. Every other task is `pending`.
    1. *Shared requirements unchanged.* `sharedHash` is a digest of the spec's `## Global Constraints` and `## Cross-Task Contracts` sections, the same last-unfenced sections the briefs carry. The old mirror's `sharedHash` must equal the new one. An old mirror without the field fails this test, so every task resets.
    2. *Own section unchanged.* The old mirror holds a `completed` task whose `description` is byte-identical to the new one. The description is the whole task section, heading included, so any change to a task's criteria, files, verify command or fence resets it.
    3. *Prerequisites still completed.* Every task it is blocked by is `completed` in the new mirror. A changed task therefore resets every task that depends on it, directly or through another.
  - A reset task then meets build's existing resume rule (build `SKILL.md:186-191`), which shows the user the committed work and asks. Design prose outside the three closing sections is not part of the test.
  - A spec with no task section is refused and the old mirror is left untouched, so a truncated spec cannot empty a good mirror.
- **No HTML by default.** The page is written only with `--html`. Without it the tool prints lint problems on stderr in today's format, or one line saying there are none.
- **`--briefs <dir>`** writes one file per task, `task-<N>.md`, holding everything that task's implementer and reviewer need: the task section, `## Global Constraints`, `## Cross-Task Contracts`, and the whole design, meaning all spec text outside the three closing sections. No section is selected or dropped by matching, so a design section that describes a component by name ("Spec critic") without a file path still reaches every task. It prints an index on stdout, one JSON line per task. The closing sections are found fence-aware and by their last occurrence, because a spec can quote these headings in examples (`docs/foureyes/specs/2026-09-23-spec-owns-tasks-design.md` has `## Global Constraints` at lines 52, 286 and 345). The same lookup feeds `sharedHash`.
- **`--complete <N>`** marks task N completed in the mirror and refreshes `lastUpdated`.

Existing exports and `--json` output are unchanged, so `scripts/pipeline-stats.mjs:20` keeps working untouched.

### 2. The drafter writes the spec file

`agents/foureyes-drafter.md` gains `Write` and `Edit` in its `tools:` line.

- **Assignment A, first draft.** The dispatch carries `SPEC_PATH` and `APPROACHES_FILE`. The drafter reads `## Chosen` from the approaches file, writes the spec to `SPEC_PATH`, and returns only its stats line, the path and any `## Unresolved`. A long spec is written in several tool calls (design sections first, then the three closing sections appended), so no single call nears the output ceiling and an interrupted dispatch leaves a usable partial file.
- **An inherited entry the drafter cannot read stops it.** If an entry under `## Chosen` builds on a pool entry that is not under `## Chosen`, meaning it takes over that entry's content as Design 3 defines, the drafter writes nothing and returns only `## Unresolved` naming the missing entry. The test is whether the spec can be written without the absent entry's text. It never guesses what an absent entry said.
- **A mention that only compares does not stop it.** "Unlike A" or "cheaper than 3" needs nothing from the entry it names. The drafter writes the spec, does not ask for that entry, and does not list it under `## Unresolved`.
- **Assignment A, revision.** The drafter edits the file in place and returns a `DISPOSITIONS:` list, one line per finding, saying `fixed` or `intentional`. The coordinator needs those lines for the critique log and for Sol's re-review note, because it no longer holds the spec. After editing, the drafter greps the spec for every name or number it changed and fixes the other mentions. This is the guard against the stale passage that a full rewrite used to replace.
- **Write nothing except `SPEC_PATH`.** This is prose, not a tool restriction.
- **Assignment A0 is unchanged.** Approaches are still returned as content. The sections about returning the full spec and about an overflowing reply now apply to A0 only. The shared template block and every phrase an existing test greps for stay as they are.

### 3. Brainstorm stops transcribing

Changes to `skills/foureyes-brainstorm/SKILL.md`:

- **Approaches file (Step 1.2 and 1.3).** It is written once, after the user picks (or at a stop). Layout: the brief, `## Chosen`, `## Pool` (one line per pooled entry: number, title, proposer, outcome), `## Decisions` as today, then the `CHOSEN:` line. Entries are still numbered `1..N` alphabetically by title. `## Proposed` and the rule to write it before deciding are removed. What this gives up is the ability to show that an entry was reworded when merged.
- **`## Chosen` is the chosen entry plus every entry it builds on.** An entry builds on another when its text takes over that entry's content by its proposer's letter, its pool number or its title ("B, plus", "on top of A's files", "as in 3"). The rule is applied again to each entry it adds, until no entry under `## Chosen` builds on one that is absent. Each entry is copied verbatim under its pool number, including an entry the pool dropped or merged. Each letter is resolved in a note line under the entry that uses it, in the form the current file already uses (`...token-savings-approaches.md:19`, `:27`).
- **A mention that only compares adds no entry.** "Unlike A" is not inheritance: the entry it names stays as its one line under `## Pool`, and its letter is still resolved in a note line. When it is unclear which kind a mention is, the entry is included.
- **The drafter's stop rule in Design 2 is the check on this step, and it fires on inheritance only.** If the drafter returns a missing entry, the coordinator adds that entry and whatever it builds on, and re-dispatches once. It never adds an entry because of a comparison.
- **Step 2, draft.** Before the dispatch the coordinator records `git status --porcelain --untracked-files=all`. After the return it runs four checks, none of which reads the spec whole:
  1. *Write guard.* Run the same command again. Any new line must be `SPEC_PATH`. A stray path is shown to the user at once and again in Step 5; nothing is reverted and the run continues.
  2. *Derive and lint.* `node "$VIZ" "<spec>" --derive`. Exit 1 (no file, or no tasks) means a malformed draft.
  3. *Headings.* A grep for `## Cross-Task Contracts`, `## Global Constraints` and `## Tasks`, which must all be present in that order, and for `## Assumptions` when unknowns were passed.
  4. *Content.* A grep for `success criteria` (at least one hit) and for `TBD` or `TODO`. The coordinator reads only the matching lines and rejects real placeholders.
  
  A failed check is a malformed draft: re-dispatch once naming the check, as today. The coordinator still never patches the spec. It then records `git hash-object <spec>`.
- **Step 3, revision.** The dispatch carries Sol's surviving findings verbatim, any lint problems from the last derive (labelled `LINT:`, not logged in the critique log), and `SPEC_PATH`. Afterwards the coordinator repeats checks 1 to 3 and compares `git hash-object`. An unchanged file with a `fixed` disposition is malformed. To fact-check a finding it reads only the lines the finding cites.
- **Step 4.** The mirror is already current, because derive ran after the last write. The page is produced only when the user asks: `node "$VIZ" "<spec>" --html`.
- **Step 5.** The report is the deliverable. It prints the spec, mirror, critique-log and approaches paths (no HTML path), and lists the spec's assumptions by reading only that section.
- **Steps 0.4b and 0.4c.** Stripping the stats line and reading a spilled return apply to A0 only. If an Assignment A dispatch aborts and `SPEC_PATH` exists, re-dispatch once telling the drafter the file is partial and to finish it.
- **Description and `README.md:106,231`.** The page is described as available on request.

### 4. Build dispatches by brief file

Changes to `skills/foureyes-build/SKILL.md` and three agents:

- **Step 0.5 and Step B.** The lint call writes nothing; the HTML mentions go.
- **E1.** Run `node "$VIZ" "<spec>" --derive --briefs "<RUN>"` and read the index it prints. The derive applies the status rule of Design 1 at every build start, so a spec edited by hand after a partial build cannot keep a stale completion. This matters for the shared sections, which Step 0.5's drift lint does not cover. Step 0.5 has already stopped on order, count and fence drift; whatever else differs, the derive resets by the status rule. The coordinator reads neither the mirror nor the spec whole. It creates one native task per index line that is not completed, with the subject and a one-line description pointing at the brief file. `blockedBy` in the index is 1-based task numbers; a dependency on a completed task is dropped, as today. The resume rule about committed partial work stays word for word. A task the user marks done at that question is recorded with `--complete <N>`, so the next derive keeps it.
- **A denied or failed call stops the run.** `<RUN>` is the directory E0 already creates and E4 already redirects diffs into, so a permission mode that blocks it has stopped build before this change. If the call exits non-zero, build prints the tool's message, which names the path that failed, and dispatches nothing. If the call itself is denied, build prints one line naming `<RUN>` and saying writes under the git directory are blocked, and dispatches nothing. There is no fallback to inline prompts: one dispatch path only.
- **E2.** The implementer prompt is `BRIEF_FILE: <RUN>/task-<N>.md`, plus anything the coordinator adds for a re-dispatch. The rule against sending an implementer to the spec file stays: the brief is the spec without the other tasks.
- **E3.** `NEEDS_CONTEXT` is handled as today. The brief already holds the whole design, so what is missing is outside the spec; the coordinator supplies it from what the implementer names.
- **E5.** The reviewer prompt is `BRIEF_FILE`, the implementer's report inline, `DIFF_FILE` and the range. For a `files: []` gate the coordinator reads that task's brief to check the criteria. Status sync becomes `node "$VIZ" "<spec>" --complete <N>`.
- **Agents.** `foureyes-implementer.md` and `foureyes-implementer-frontier.md` (bodies stay byte-identical) say to read `BRIEF_FILE` first and work from it. `foureyes-task-reviewer.md` says the task, constraints, contracts and design arrive in `BRIEF_FILE`. None gains a tool. The reviewer already reads `DIFF_FILE` from the same directory, so reads there are known to work.

### 5. Review: a script extracts what Codex wrote

`skills/foureyes-review/lib/review-synth.mjs` gains two subcommands; `skills/foureyes-review/SKILL.md` uses them.

- **`extract`** turns `codex.out`, which is already on disk, into `codex.json`. Exit 3 means no findings object could be parsed: it writes an empty findings file and the coordinator records Codex as down, as today.
- **`refute-inputs`** writes one refute input file per single finding and prints a one-line index per finding. Codex reads its input from the file. The Claude refuter is told to read the file. The coordinator no longer reads `bucket.json` and no longer types a finding into a prompt.
- **A denied or failed write stops the run.** Both subcommands write into `$RUN`, the directory review already creates and already writes `codex.out`, `bucket.json` and `report.md` into. If either call is denied or exits with any code other than 0 or `extract`'s 3, review prints one line naming `$RUN` and stops; it could not write its report there either.

The coordinator still writes `claude.json`, `meta.json` and `refutations.json`. With `--post` it reads `report.md` at Step 7 for the comment bodies.

### 6. Investigate: scout findings are typed once

Changes to `skills/foureyes-investigate/SKILL.md` only:

- Step 1 fixes the `<topic>` slug that Step 6 already uses in the report name, so one name serves the whole run.
- After the scouts return, the coordinator writes their reports once, with the Write tool, to `docs/foureyes/investigations/YYYY-MM-DD-<topic>-scouts.md`. This is the directory where the skill already writes its report and critique log (`SKILL.md:183`, `:209`), so the write needs the same permission the run needs anyway for its report, and nothing goes under `.git`. Sol receives the file through `cat` in the pipe; the investigator is told to read it. In round 2 the ruled-out findings are appended to the same file.
- **A denied or failed write degrades, it does not stop.** The coordinator does not retry and does not ask. For the rest of that run it passes the scout reports inline in both proposer inputs, as today, and says so in one line. This follows the skill's own rule that failures degrade and continue.
- The file is left in place beside the report. `sol-ledger.mjs` collects only `*-critique.md`, so it is not picked up.
- The opening rule about which files the command creates names three files: the report, the critique log and the scout findings.
- The last line prints the status, the cause and the report path, so the conclusion is in the terminal.

## Data flow

**Brainstorm.** Proposers return approaches as content. The user picks. The coordinator writes the approaches file once, with the chosen entry and what it builds on. The drafter reads `## Chosen` and writes the spec. `plan-viz --derive` writes the mirror and lints. Sol reads the spec by path. The drafter edits in place and returns dispositions. The coordinator reports.

**Build.** `plan-viz --derive --briefs` re-derives the mirror, writes one brief per task and prints the index. Implementers and reviewers read their brief. `plan-viz --complete` records each finished task.

**Review.** Codex output goes to disk, `extract` makes `codex.json`, `bucket` runs, `refute-inputs` writes the input files, `render` writes the report and prints the digest.

**Investigate.** Scouts return reports. The coordinator writes the scout file once. Both proposers read it.

## Error handling

| Situation | What happens |
|---|---|
| `--derive` on a missing spec or one with no tasks | exit 1, message on stderr, existing mirror untouched |
| `--derive` on a spec where a completed task's section changed | that task and every task that depends on it become `pending`; build's E1 resume rule shows their committed work and asks |
| `--derive` after `## Global Constraints` or `## Cross-Task Contracts` changed | every task becomes `pending`; same resume rule |
| `--derive` over a mirror that has no `sharedHash` (typed by hand before this change) | every task becomes `pending`; same resume rule |
| `--derive` after only design prose changed | no status changes |
| Lint or `--briefs` without a mirror and without `--derive` | exit 1 naming the missing path, no stack trace |
| `--complete <N>` out of range | exit 1, mirror untouched |
| Build's E1 call exits non-zero (mirror or brief unwritable, no tasks) | build prints the tool's message naming the path and STOPs, nothing dispatched |
| Build's E1 call is denied | build STOPs with one line naming `<RUN>`, nothing dispatched |
| Drafter writes a path other than `SPEC_PATH` | reported at once and in Step 5; not reverted; run continues |
| Drafter returns but the spec is missing, has no tasks, or lacks a required heading | malformed: re-dispatch once naming the check; a second failure follows the existing Opus fallback rule |
| Drafter returns an entry the chosen approach builds on that is missing from `## Chosen` | coordinator adds the entry and what it builds on, re-dispatches once; a second such return is malformed |
| A `## Chosen` entry only compares itself with an absent entry | nothing: the drafter writes the spec and the absent entry stays one line under `## Pool` |
| Revision returns `fixed` but the file hash is unchanged | malformed, same rule |
| Drafter reports it cannot write | STOP; tell the user to allow Write for subagents |
| Assignment A dispatch aborts with a partial file | re-dispatch once to finish the file; with no file, the existing three-attempt retry rule |
| `extract` cannot parse Codex's output | exit 3, empty findings written, review continues one-model with the existing note |
| `extract` or `refute-inputs` is denied or cannot write | exit 1 naming the path; review STOPs with one line naming `$RUN` |
| Investigate's scout file write is denied or fails | no retry, no question; scout reports go inline for the rest of the run; one line says so |
| A hand-written spec lacks constraints or contracts | the brief omits that part; build proceeds |

## Non-goals

- No token counting or usage attribution. The unbuilt `2026-11-14-foureyes-efficiency-design.md` owns that. This spec touches none of its files: `scripts/pipeline-stats.mjs`, `scripts/sol-ledger.mjs`, `tests/run.sh`, `skills/foureyes-ledger/SKILL.md`.
- No change to how many times Sol runs, to any critic prompt, or to `scripts/codex-critic.sh`.
- No hook or sandbox for the drafter. A plugin agent cannot carry hooks; the guard is prose plus `git status`.
- No write access for scouts, reviewers, refuters or investigators.
- No new location under `.git`, and no moving of build's or review's run directories out of it.
- No task-to-section mapping in the fence, and no selection of design sections per task.
- No reset of a task because design prose outside the three closing sections changed.
- No new lint problem kind for a stale mirror; build derives at E1 instead.
- No marker in the approaches file that classifies a mention as comparison or inheritance; the drafter applies the test itself.
- No deletion of existing artifacts, of the scout file, or of the HTML renderer.
- No file for the implementer's report or for the task reviewer's verdict.
- No shortening of build's Step F report or of review's digest.

## Success criteria

1. After a brainstorm run, the coordinator's transcript contains no Write or Edit call on the spec or on `.tasks.json`, and no `.html` exists beside a new spec unless the user asked for it.
2. `node plan-viz.mjs <spec> --derive` followed by `--json` reports no `plan-tasks-*` problem on any spec.
3. After a re-derive, a completed task is `pending` when its own section changed, when `## Global Constraints` or `## Cross-Task Contracts` changed, or when a task it is blocked by is `pending`. In every other case it stays `completed`.
4. In a build run, no implementer or reviewer prompt contains the text of `## Global Constraints` or `## Cross-Task Contracts`; each contains a `BRIEF_FILE` line, and each brief contains every design section of the spec.
5. No skill gains a write under `.git` outside the run directory it already creates.
6. Task 9's gate command prints `GATE-PASS`, which includes the one full run of `bash tests/run.sh` with the new prose-contract group in place.
7. When the chosen entry only compares itself with an entry that is not under `## Chosen`, the drafter returns a `SPEC:` line and the approaches file is not rewritten.

## Cross-Task Contracts

No scaffold task: the wave-1 tasks touch independent files, and the names below are the only things they share.

**Test policy.** The full suite, `bash tests/run.sh`, runs exactly once for this change: in Task 9. That is the PR's one full-suite run. No other task, no wave barrier and no closing step runs it. Until then each task runs only what it touches:

| Task | Runs | Expected green |
|---|---|---|
| 1, 2 | `plan-viz.test.mjs` only | at the end of each task |
| 3 | `review-synth.test.mjs` only | at the end of the task |
| 4, 5, 6, 7 | greps on their own files, no suite | at the end of each task |
| 8 | `tests/prose-contracts.test.sh` only | at the end of the task |
| 9 | `bash tests/run.sh`, once | at the gate |

Task 4 changes check 7c in the same task that makes the old check false, and does not run the suite. Task 8 is the first run of the prose suite. If that run fails on an existing check about a file outside Task 8's Files, Task 8 reports the check name as `BLOCKED` and edits nothing else; the coordinator re-dispatches the task that owns the file.

**Command lines**

```
node plan-viz.mjs <spec.md> [--derive] [--json] [--html] [--briefs <dir>]
node plan-viz.mjs <spec.md> --complete <N>
node review-synth.mjs extract <raw.out> <out.json>
node review-synth.mjs refute-inputs <bucket.json> <outDir> <worktree> <base> <head>
```

- Flags combine. `--derive` runs first, so `--briefs` and `--json` in the same call see the derived mirror.
- `plan-viz.mjs` stdout: with `--json` the existing object; with `--html` the page path; with `--briefs` the index; otherwise empty. Lint problems go to stderr in the existing format. With no problems, stderr carries one line that starts `plan-viz:` and contains `no structural problems`.
- `plan-viz.mjs` exit codes: 0 on success, including when lint problems exist; 1 for usage, an unreadable spec, a missing mirror without `--derive`, a spec with no tasks under `--derive`, `--complete` out of range, or a mirror or brief that cannot be written. Every exit 1 prints one message naming the path and no stack trace.
- `--complete` stdout: `task <N> completed`.
- The mirror is written with `JSON.stringify(value, null, 2)` and a trailing newline.
- `review-synth.mjs extract` exit codes: 0 parsed; 3 unparseable, after writing `{"findings":[]}` to `<out.json>`; 1 for usage, an unreadable `<raw.out>` or an unwritable output, with a message naming the path.
- `refute-inputs` writes `<outDir>/refute-<k>.in`, where `k` is the 1-based position in `bucket.single`, and prints one JSON line per file: `{"k","id","raisedBy","severity","title","file","line"}`. Exit 1 for usage or an unwritable output, with a message naming the path.

**Exports** (existing exports unchanged)

```js
// skills/foureyes-brainstorm/lib/plan-viz.mjs
export function deriveTasksJson(specPath, src, prev = null)  // -> {planPath, sharedHash, tasks, lastUpdated}; throws when src has no unfenced "### Task" section
export function buildBrief(src, n)                           // -> string; n is the 1-based task number
export function taskIndex(tasksJson)                         // -> [{n, status, tier, model, blockedBy, files, subject}]
export function markCompleted(tasksJson, n)                  // -> tasksJson; throws RangeError when n is out of range

// skills/foureyes-review/lib/review-synth.mjs
export function extractFindings(rawText)                     // -> object with a findings array, or null
export function refuteInputs(bucket, { worktree, base, head }) // -> [{k, id, raisedBy, severity, title, file, line, input}]
```

**Derived task** (one element of `tasks` in the mirror)

```
{"id":0,"subject":"Task 1: ...","description":"### Task 1: ...<whole section, fence included>","blockedBy":[],"status":"pending"}
```

**`sharedHash`** (top level of the mirror) is the SHA-256 hex digest, from `node:crypto`, of the last unfenced `## Global Constraints` section followed by the last unfenced `## Cross-Task Contracts` section, each exactly as the brief file carries it. A section the spec lacks contributes empty text. Only `plan-viz.mjs` reads it, and only for equality.

**Status rule.** `status` is `completed` only when all three hold; otherwise `pending`:

1. `prev.sharedHash` equals the new `sharedHash`. A null `prev`, or one without the field, fails.
2. `prev` holds a task with `status` `completed` and a byte-identical `description`.
3. Every task named in its `blockedBy` is `completed` in the mirror being derived. A `blockedBy` entry that names no task, or a dependency cycle, leaves the task `pending`.

From `prev`, only `sharedHash` and each task's `status` and `description` are read. `markCompleted` changes one task's `status` and `lastUpdated` and nothing else.

**Index line** (`--briefs` stdout, one compact JSON object per task, in task order)

```
{"n":1,"status":"pending","tier":"standard","model":null,"blockedBy":[],"files":["a/b.mjs"],"subject":"Task 1: ..."}
```

`status` is `completed` or `pending`. `blockedBy` holds 1-based task numbers. `model` is the fence's pin or `null`.

**Brief file** `<dir>/task-<N>.md`, parts in this order, each under a top-level heading

```
# TASK                  the task section verbatim, from its "### Task N:" line, fence included
# GLOBAL CONSTRAINTS    the last unfenced "## Global Constraints" section verbatim
# CROSS-TASK CONTRACTS  the last unfenced "## Cross-Task Contracts" section verbatim
# DESIGN                all spec text outside the three closing sections, verbatim, in spec order
```

A closing section is `## Cross-Task Contracts`, `## Global Constraints` or `## Tasks`, each taken from its last unfenced heading to the next unfenced `## ` heading or the end of the file. `# DESIGN` is never filtered by task. A part with nothing to show is omitted with its heading. Task 1 writes the closing-section lookup for `sharedHash`; Task 2's `buildBrief` uses that same code.

**Drafter return, Assignment A**

```
DRAFTER-STATS: ...
SPEC: <the path written>
DISPOSITIONS:
- <fixed|intentional> — <the finding, one line> — <section changed, or why kept>
## Unresolved
- ...
```

`DISPOSITIONS:` appears on a revision only. `## Unresolved` appears only when there are gaps. When the drafter cannot write, or an entry under `## Chosen` builds on an absent entry, the return is the stats line and `## Unresolved` only, with no `SPEC:` line. A mention that only compares with an absent entry is not a gap and never produces that return.

**Dispatch keys:** `SPEC_PATH`, `APPROACHES_FILE` (to the drafter); `BRIEF_FILE`, `DIFF_FILE` (to implementers and the reviewer).

**Approaches file headings, in order:** `## Chosen`, `## Pool`, `## Decisions`, then the `CHOSEN:` line.

```
## Chosen
### <n> — <title>
<the chosen entry verbatim: WHAT, COST, GIVES UP, CHECKED>
(Note: "<letter>" in entry <n> refers to entry <m> of this pool.)
### <m> — <title>
<each entry the chosen one builds on, directly or through another, verbatim, with its own note lines>
## Pool
- <n> — <title> — <fable|sol|both> — <kept | merged into <n> | dropped: <reason>>
```

An entry that is only compared against appears under `## Pool` and not under `## Chosen`.

**Run paths:** `<gitdir>/foureyes-build/<short-sha>/task-<N>.md` (briefs, in build's existing run directory); `$RUN/codex.out`, `$RUN/codex.json`, `$RUN/refute-<k>.in` (review's existing run directory); `docs/foureyes/investigations/YYYY-MM-DD-<topic>-scouts.md` (investigate, in the worktree beside the report).

**Strings each file must contain after its task**

| File | Must contain | Must not contain |
|---|---|---|
| `agents/foureyes-drafter.md` | `Write` and `Edit` on the `tools:` line; `SPEC_PATH`; `APPROACHES_FILE`; `DISPOSITIONS:`; `Write nothing except`; `only compares` | `return the full spec`; `It never writes` |
| `skills/foureyes-brainstorm/SKILL.md` | `--untracked-files=all`; `git hash-object`; `--derive`; `--html`; `## Pool`; `## Chosen`; `every entry it builds on`; `only compares`; `SPEC_PATH` | `## Proposed`; `YOU write it`; `write over the file`; `Derive it ONCE`; `writes <spec>.md.html` |
| `skills/foureyes-build/SKILL.md` | `--derive`; `--briefs`; `--complete`; `BRIEF_FILE` inside the E2 block | `carrying its description verbatim`; `writes the HTML page`; `generates the HTML` |
| both implementer agents, `foureyes-task-reviewer.md` | `BRIEF_FILE` | |
| `skills/foureyes-review/SKILL.md` | `"$SYNTH" extract`; `"$SYNTH" refute-inputs` | |
| `skills/foureyes-investigate/SKILL.md` | `-scouts.md`; `Print the status, the cause and the report path` | `gitdir` |

**Phrases that must survive** (existing checks grep for them)

- Brainstorm: `DRAFTER-STATS`; `persisted-output`; `Read that path`; `64000 output` and `do NOT re-dispatch` on one line; `pipeline-stats.mjs`; `Do not quote a number from this file`; `ask NOTHING`; in Step 5, `--continue` before `print the paths`; `standalone` followed by `STOP` on one line; at least two mentions of `foureyes-drafter`; `3 attempts in total`.
- Build: the E2 block names `Cross-Task Contracts` and `Global Constraints` and never `Verify / Steps`; `implementers never commit`; `<gitdir>/foureyes-build/`; `Never silently re-implement over a partial`; the `unknown-key` and `Has Sol ever read this spec` passages unchanged.
- Implementers: `never commit`; `outside your assignment's Files list`; `Cross-Task Contracts`; no `Steps`; bodies byte-identical (check 27d).
- Investigate: `This command changes NO CODE`; `Do not fix anything`; never `no new files in the worktree`.
- Drafter: everything checks 7a, 11c, 18a-18d, 18g, 22j, 29b and 29c grep for, and the shared template block byte-for-byte.
- `plan-viz.mjs`: `export const FENCE_KEYS`; `unknown-key`; never `spliceTasks` (checks 19a, 29g).

**Test names, `plan-viz.test.mjs`**

- `derive mirrors every task with 0-based ids and blockedBy`
- `derive copies the fence verbatim so no drift is reported`
- `derive keeps a completed status when nothing it was built against changed`
- `derive resets status when criteria change under an identical heading`
- `derive resets every task when a shared section changes`
- `derive resets a task whose prerequisite was reset`
- `derive ignores a Task heading inside a code fence`
- `derive refuses a spec with no tasks`
- `CLI writes no HTML unless --html is passed`
- `brief holds the task, constraints, contracts and the whole design`
- `brief design keeps a section that names none of the task's files`
- `brief takes the last unfenced Global Constraints section`
- `index reports status, tier, model pin, 1-based blockedBy and files`
- `markCompleted sets status and refreshes lastUpdated`
- `markCompleted rejects an out-of-range task number`

**Test names, `review-synth.test.mjs`**

- `extract finds the findings object inside prose and a code fence`
- `extract returns null when there is no findings object`
- `refute inputs carry worktree, range and finding, one per single`

**Prose-contract checks, `tests/prose-contracts.test.sh`**

- `7c the drafter writes the spec itself` (replaces `7c the drafter has no write tools`)
- Group heading: `--- nothing is typed twice ---`
- `30a the drafter returns a path, not the spec`
- `30b brainstorm guards the drafter's writes`
- `30c brainstorm never transcribes the spec`
- `30d tasks.json is derived by the script`
- `30e the HTML page is opt-in`
- `30f the approaches file keeps the chosen entry and what it builds on`
- `30g build dispatches by brief file`
- `30h build syncs status through the script`
- `30i <agent> reads the brief file` (one per implementer, implementer-frontier, task-reviewer)
- `30j review extracts Codex findings and refute inputs by script`
- `30k investigate writes scout findings once, beside its report`
- `30l investigate's last line names the cause`

Each check asserts the matching row of the strings table.

## Global Constraints

- Node scripts stay zero-dependency: `node:` built-ins only, ES modules, no `package.json`.
- Do not change any existing export, the `--json` output shape, or the lint problem kinds of `plan-viz.mjs`.
- Do not touch `scripts/pipeline-stats.mjs`, `scripts/sol-ledger.mjs`, `scripts/codex-critic.sh`, `tests/run.sh` or `skills/foureyes-ledger/SKILL.md`.
- Do not add or remove a `"$WRAP"` call site in any `SKILL.md`, and do not change a call's mode word.
- Keep every phrase listed under "Phrases that must survive".
- Edit `agents/foureyes-implementer.md` and `agents/foureyes-implementer-frontier.md` identically; their bodies must stay byte-identical.
- No agent other than `foureyes-drafter` gains `Write` or `Edit`.
- Add no write under the git directory to any skill, except files that `plan-viz.mjs --briefs` and `review-synth.mjs` put into the run directory that skill already creates. Never describe Bash redirection as a way to avoid a permission prompt.
- Prose edits are surgical: change the passages this spec names and leave the rest of each file as it is, including its wrapping and its comments.
- Run only the test command in your task's Verify line. Never run `bash tests/run.sh` outside Task 9: the full suite runs once per PR.
- Run tests through `builder run ...`; never run `node --test` or `bash tests/...` locally. Plain `grep` runs locally.
- Verify commands run under zsh: never use `status`, `path`, `argv` or `options` as a variable name.
- No emojis in any file. Commit subjects follow the repo's `type(scope): subject` form.

## Tasks

### Task 1: plan-viz: derive the mirror, page only on request

**Goal:** `plan-viz.mjs` writes `.tasks.json` from the spec markdown with `--derive`, keeps a completed status only for a task whose own section, shared sections and prerequisites are all unchanged, and writes the HTML page only with `--html`.

**Files:**
- Modify: `skills/foureyes-brainstorm/lib/plan-viz.mjs`
- Modify: `skills/foureyes-brainstorm/lib/plan-viz.test.mjs`

**Acceptance Criteria:**
- `deriveTasksJson` is exported with the contract signature and returns 0-based `id`, `subject` equal to the heading text, `description` equal to the task section from its heading line including the fence, `blockedBy` equal to the fence's numbers minus one (`[]` when the fence is missing), and a top-level `sharedHash` as the contracts define it.
- `analyze(deriveTasksJson(...), parsePlanMarkdown(src).tasks)` reports no `plan-tasks-*` problem for every fixture in the test file.
- A derived task is `completed` only when the three conditions of the contract's status rule hold; every other task is `pending`, including every task when `prev` is null or carries no `sharedHash`.
- The test `derive resets status when criteria change under an identical heading` derives a spec, marks a task completed, changes one acceptance criterion while leaving the heading as it is, derives again with the old mirror as `prev`, and asserts that task is `pending` while an untouched completed task stays `completed`.
- The test `derive resets every task when a shared section changes` marks two tasks completed and asserts both are `pending` after one line changes under `## Global Constraints`, and again after one line changes under `## Cross-Task Contracts`; it also asserts both stay `completed` after a change to design prose that includes a fenced example quoting `## Global Constraints`.
- The test `derive resets a task whose prerequisite was reset` uses three tasks chained by `blockedBy` plus one independent task, all completed, changes a criterion of the first, and asserts the three chained tasks are `pending` and the independent one stays `completed`.
- `deriveTasksJson` throws on a spec with no unfenced `### Task` section; the CLI then exits 1 and leaves an existing mirror byte-identical.
- With no flags the CLI writes no `.html`; with `--html` it writes `<spec>.html` and prints that path on stdout.
- With no problems, stderr has one line starting `plan-viz:` that contains `no structural problems`.
- A missing mirror without `--derive` exits 1 with a message naming the path and no stack trace.
- The nine `derive ...` and `CLI ...` tests named in the contracts exist and pass; every existing test passes unchanged.

**Verify:** `builder run node --test skills/foureyes-brainstorm/lib/plan-viz.test.mjs`

```json:metadata
{"files": ["skills/foureyes-brainstorm/lib/plan-viz.mjs", "skills/foureyes-brainstorm/lib/plan-viz.test.mjs"], "modelTier": "standard", "verifyCommand": "builder run node --test skills/foureyes-brainstorm/lib/plan-viz.test.mjs", "acceptanceCriteria": ["deriveTasksJson is exported with the contract signature and returns 0-based id, heading-text subject, full-section description, fence blockedBy minus one, and a top-level sharedHash as the contracts define it", "analyze over a derived mirror reports no plan-tasks-* problem for every fixture", "a derived task is completed only when the three conditions of the contract's status rule hold; every other task is pending, including every task when prev is null or carries no sharedHash", "the test derive resets status when criteria change under an identical heading changes one criterion under an unchanged heading and asserts that task is pending while an untouched completed task stays completed", "the test derive resets every task when a shared section changes asserts two completed tasks are pending after a line changes under Global Constraints and again under Cross-Task Contracts, and stay completed after a change to design prose that includes a fenced example quoting the Global Constraints heading", "the test derive resets a task whose prerequisite was reset chains three tasks by blockedBy plus one independent task, changes a criterion of the first, and asserts the three chained tasks are pending and the independent one stays completed", "deriveTasksJson throws on a spec with no unfenced Task section; the CLI exits 1 and leaves an existing mirror byte-identical", "no flags writes no .html; --html writes <spec>.html and prints the path on stdout", "with no problems stderr has one line starting plan-viz: containing no structural problems", "a missing mirror without --derive exits 1 naming the path, no stack trace", "the nine derive and CLI tests named in the contracts exist and pass; existing tests pass unchanged"], "blockedBy": []}
```

### Task 2: plan-viz: brief files, task index, completion

**Goal:** `plan-viz.mjs` writes one brief file per task with `--briefs`, each holding the whole design, prints the task index, and marks a task completed with `--complete`.

**Files:**
- Modify: `skills/foureyes-brainstorm/lib/plan-viz.mjs`
- Modify: `skills/foureyes-brainstorm/lib/plan-viz.test.mjs`

**Acceptance Criteria:**
- `buildBrief`, `taskIndex` and `markCompleted` are exported with the contract signatures.
- A brief has the parts `# TASK`, `# GLOBAL CONSTRAINTS`, `# CROSS-TASK CONTRACTS`, `# DESIGN` in that order, each verbatim from the spec, and omits a part that has nothing to show.
- Constraints and contracts are taken from the last unfenced occurrence of their heading; a heading inside a code fence is ignored. `buildBrief` finds them with the same code `deriveTasksJson` uses for `sharedHash`; the file holds one closing-section lookup, not two.
- `# DESIGN` holds all spec text outside the three closing sections, in spec order, and is identical for every task of one spec.
- The test `brief design keeps a section that names none of the task's files` builds a brief from a spec whose design has a section that mentions no file path and asserts that section's heading and body are in the brief.
- A brief contains no other task's `### Task` section.
- `--briefs <dir>` creates the directory if needed, writes `task-<N>.md` for every task, and prints one index line per task in the contract format; a brief that cannot be written exits 1 with a message naming the path and no stack trace.
- `--derive --briefs <dir>` in one call derives first, so the index it prints carries the derived statuses.
- `--complete <N>` sets that task's `status` to `completed`, refreshes `lastUpdated`, leaves every other field of the mirror as it was (`sharedHash` included), and prints `task <N> completed`; an out-of-range N exits 1 and leaves the mirror byte-identical.
- The six `brief ...`, `index ...` and `markCompleted ...` tests named in the contracts exist and pass.

**Verify:** `builder run node --test skills/foureyes-brainstorm/lib/plan-viz.test.mjs`

```json:metadata
{"files": ["skills/foureyes-brainstorm/lib/plan-viz.mjs", "skills/foureyes-brainstorm/lib/plan-viz.test.mjs"], "modelTier": "standard", "verifyCommand": "builder run node --test skills/foureyes-brainstorm/lib/plan-viz.test.mjs", "acceptanceCriteria": ["buildBrief, taskIndex and markCompleted are exported with the contract signatures", "a brief has the four parts TASK, GLOBAL CONSTRAINTS, CROSS-TASK CONTRACTS, DESIGN in contract order, verbatim, omitting empty parts", "constraints and contracts come from the last unfenced occurrence of their heading, found with the same code deriveTasksJson uses for sharedHash; the file holds one closing-section lookup, not two", "DESIGN holds all spec text outside the three closing sections, in spec order, identical for every task of one spec", "the test brief design keeps a section that names none of the task's files asserts such a section's heading and body are in the brief", "a brief contains no other task's Task section", "--briefs creates the directory, writes task-<N>.md for every task and prints one contract-format index line per task; an unwritable brief exits 1 naming the path, no stack trace", "--derive --briefs in one call derives first, so the index carries the derived statuses", "--complete sets status completed, refreshes lastUpdated, leaves every other mirror field as it was including sharedHash, and prints task <N> completed; out-of-range exits 1 with the mirror byte-identical", "the six brief, index and markCompleted tests named in the contracts exist and pass"], "blockedBy": [1]}
```

### Task 3: review: script extracts findings and refute inputs

**Goal:** The review coordinator no longer types Codex's findings or any refute prompt; `review-synth.mjs` produces both from files on disk.

**Files:**
- Modify: `skills/foureyes-review/lib/review-synth.mjs`
- Modify: `skills/foureyes-review/lib/review-synth.test.mjs`
- Modify: `skills/foureyes-review/SKILL.md`

**Acceptance Criteria:**
- `extractFindings` and `refuteInputs` are exported with the contract signatures.
- `extract` writes the parsed object and exits 0; on unparseable input it writes `{"findings":[]}` and exits 3; on an unreadable input or unwritable output it exits 1 with a message naming the path.
- `refute-inputs` writes `refute-<k>.in` for every entry of `bucket.single`, each holding the `WORKTREE`, `BASE_SHA`, `HEAD_SHA` and `FINDING` lines of today's refute input, and prints one contract-format index line per file; an unwritable output exits 1 with a message naming the path.
- The usage message lists all four subcommands.
- `SKILL.md` Step 3 runs `"$SYNTH" extract` on `$RUN/codex.out` and treats exit 3 as Codex down; Step 4 runs `"$SYNTH" refute-inputs` and no longer tells the coordinator to read `bucket.json`; Step 5 feeds Codex from `$RUN/refute-<k>.in` and tells the Claude refuter to read that file; Step 7 reads `report.md` for comment bodies.
- `SKILL.md` says that if either new call is denied or exits with a code other than 0 (or 3 for `extract`), review prints one line naming `$RUN` and stops.
- The number of `"$WRAP"` occurrences in `SKILL.md` is unchanged.
- The three tests named in the contracts exist and pass; existing tests pass unchanged.

**Verify:** `builder run node --test skills/foureyes-review/lib/review-synth.test.mjs`

```json:metadata
{"files": ["skills/foureyes-review/lib/review-synth.mjs", "skills/foureyes-review/lib/review-synth.test.mjs", "skills/foureyes-review/SKILL.md"], "modelTier": "standard", "verifyCommand": "builder run node --test skills/foureyes-review/lib/review-synth.test.mjs", "acceptanceCriteria": ["extractFindings and refuteInputs are exported with the contract signatures", "extract writes the parsed object and exits 0; on unparseable input writes {\"findings\":[]} and exits 3; on an unreadable input or unwritable output exits 1 naming the path", "refute-inputs writes refute-<k>.in for every single with the four input lines and prints one contract-format index line per file; an unwritable output exits 1 naming the path", "the usage message lists all four subcommands", "SKILL.md Steps 3, 4, 5 and 7 use extract, refute-inputs, the .in files and report.md as the spec describes", "SKILL.md says a denied call or an exit code other than 0 (or 3 for extract) prints one line naming $RUN and stops", "the number of \"$WRAP\" occurrences in SKILL.md is unchanged", "the three tests named in the contracts exist and pass; existing tests pass unchanged"], "blockedBy": []}
```

### Task 4: drafter writes the spec file itself

**Goal:** `foureyes-drafter` writes and revises the spec at `SPEC_PATH` and returns a path and dispositions instead of the document.

**Files:**
- Modify: `agents/foureyes-drafter.md`
- Modify: `tests/prose-contracts.test.sh`

**Acceptance Criteria:**
- The `tools:` line lists `Write` and `Edit`; the frontmatter description no longer says the drafter never writes files.
- Assignment A says: read `## Chosen` from `APPROACHES_FILE`; write the spec to `SPEC_PATH`; write a long spec in several tool calls; write nothing except `SPEC_PATH`; return in the contract's Assignment A format.
- Assignment A says: if an entry under `## Chosen` builds on a pool entry that is not under `## Chosen` (takes over its content, so the spec cannot be written without that entry's text), write nothing and return only `## Unresolved` naming the missing entry.
- Assignment A says: a mention that only compares with an absent entry does not stop the drafter; it writes the spec and does not list that entry under `## Unresolved`.
- The revision rule says: edit in place, return `DISPOSITIONS:` with one line per finding, then grep the spec for every changed name or number and fix the other mentions.
- A drafter that cannot write says so under `## Unresolved` and returns nothing else.
- The full-spec return rule and the overflow section are scoped to Assignment A0; Assignment A0 and the shared template block are byte-identical to before.
- The file satisfies its row of the strings table.
- In `tests/prose-contracts.test.sh`, check 7c is renamed to the contract name and asserts `Write` and `Edit` on the `tools:` line; no other check changes. No test suite is run in this task.

**Verify:** `grep -q '^tools:.*Write.*Edit' agents/foureyes-drafter.md && grep -q 'SPEC_PATH' agents/foureyes-drafter.md && grep -q 'APPROACHES_FILE' agents/foureyes-drafter.md && grep -q 'DISPOSITIONS:' agents/foureyes-drafter.md && grep -q 'Write nothing except' agents/foureyes-drafter.md && grep -q 'only compares' agents/foureyes-drafter.md && ! grep -q 'return the full spec' agents/foureyes-drafter.md && grep -q '7c the drafter writes the spec itself' tests/prose-contracts.test.sh && echo PASS`

```json:metadata
{"files": ["agents/foureyes-drafter.md", "tests/prose-contracts.test.sh"], "modelTier": "standard", "verifyCommand": "grep -q '^tools:.*Write.*Edit' agents/foureyes-drafter.md && grep -q 'SPEC_PATH' agents/foureyes-drafter.md && grep -q 'APPROACHES_FILE' agents/foureyes-drafter.md && grep -q 'DISPOSITIONS:' agents/foureyes-drafter.md && grep -q 'Write nothing except' agents/foureyes-drafter.md && grep -q 'only compares' agents/foureyes-drafter.md && ! grep -q 'return the full spec' agents/foureyes-drafter.md && grep -q '7c the drafter writes the spec itself' tests/prose-contracts.test.sh && echo PASS", "acceptanceCriteria": ["the tools line lists Write and Edit and the description no longer says the drafter never writes files", "Assignment A says to read ## Chosen from APPROACHES_FILE, write to SPEC_PATH in several tool calls, write nothing else, and return in the contract format", "Assignment A says an entry under ## Chosen that builds on an absent pool entry, so the spec cannot be written without that entry's text, means write nothing and return only ## Unresolved naming it", "Assignment A says a mention that only compares with an absent entry does not stop the drafter; it writes the spec and does not list that entry under ## Unresolved", "the revision rule says edit in place, return DISPOSITIONS, then grep for every changed name or number", "a drafter that cannot write says so under ## Unresolved and returns nothing else", "the full-spec return rule and overflow section are scoped to A0; A0 and the shared template block are byte-identical to before", "the file satisfies its row of the strings table", "check 7c is renamed to the contract name and asserts Write and Edit; no other check changes; no test suite is run in this task"], "blockedBy": []}
```

### Task 5: brainstorm: stop transcribing, compact approaches

**Goal:** The brainstorm coordinator never types the spec, the mirror or the raw pool, keeps every inherited entry of the chosen approach and no entry it is merely compared with, and produces the HTML page only on request.

**Files:**
- Modify: `skills/foureyes-brainstorm/SKILL.md`
- Modify: `README.md`

**Acceptance Criteria:**
- Step 1.2 and 1.3 describe the approaches file as written once after the pick (or at a stop), with `## Chosen`, `## Pool`, `## Decisions` and `CHOSEN:` in the contract layout; `## Proposed` and the write-before-deciding rule are gone; the rule that the coordinator adds no approach stays.
- The `## Chosen` rule says: the chosen entry plus every entry it builds on, by letter, pool number or title, applied again to each added entry until none builds on an absent one; each copied verbatim under its pool number, dropped and merged entries included; each letter resolved in a note line; an unclear mention is included.
- The `## Chosen` rule says: a mention that only compares adds no entry; the entry it names stays as one line under `## Pool`.
- Step 2 says: when the drafter returns an inherited entry that is missing from `## Chosen`, add that entry and what it builds on to the file and re-dispatch once; never add an entry because of a comparison.
- Step 2 records `git status --porcelain --untracked-files=all` before the dispatch, passes `SPEC_PATH` and `APPROACHES_FILE`, and runs the four checks of Design section 3 afterwards; it states that a stray path is reported, not reverted, and the run continues; it records `git hash-object`.
- Step 3 passes findings verbatim, `LINT:` problems and `SPEC_PATH`; repeats checks 1 to 3; treats an unchanged hash with a `fixed` disposition as malformed; builds Sol's re-review note and the critique-log dispositions from `DISPOSITIONS:`; reads only cited lines when fact-checking.
- Step 4 no longer derives by hand or renders the page; it gives the `--html` command for a user who asks.
- Step 5 lists no HTML path and reads the spec's assumptions section only.
- Steps 0.4b and 0.4c are scoped to A0 and add the partial-file re-dispatch rule; the cannot-write STOP is stated.
- The frontmatter description and `README.md` lines 106 and 231 describe the page as available on request.
- The file satisfies its row of the strings table and keeps every brainstorm phrase under "Phrases that must survive".

**Verify:** `f=skills/foureyes-brainstorm/SKILL.md; grep -q -- '--untracked-files=all' $f && grep -q 'git hash-object' $f && grep -q -- '--derive' $f && grep -q -- '--html' $f && grep -q '## Pool' $f && grep -q '## Chosen' $f && grep -q 'every entry it builds on' $f && grep -q 'only compares' $f && grep -q 'SPEC_PATH' $f && ! grep -q '## Proposed' $f && ! grep -q 'YOU write it' $f && ! grep -q 'write over the file' $f && ! grep -q 'Derive it ONCE' $f && grep -q 'persisted-output' $f && grep -q 'ask NOTHING' $f && echo PASS`

```json:metadata
{"files": ["skills/foureyes-brainstorm/SKILL.md", "README.md"], "modelTier": "frontier", "verifyCommand": "f=skills/foureyes-brainstorm/SKILL.md; grep -q -- '--untracked-files=all' $f && grep -q 'git hash-object' $f && grep -q -- '--derive' $f && grep -q -- '--html' $f && grep -q '## Pool' $f && grep -q '## Chosen' $f && grep -q 'every entry it builds on' $f && grep -q 'only compares' $f && grep -q 'SPEC_PATH' $f && ! grep -q '## Proposed' $f && ! grep -q 'YOU write it' $f && ! grep -q 'write over the file' $f && ! grep -q 'Derive it ONCE' $f && grep -q 'persisted-output' $f && grep -q 'ask NOTHING' $f && echo PASS", "acceptanceCriteria": ["Steps 1.2 and 1.3 describe the approaches file in the contract layout, written once after the pick; ## Proposed and write-before-deciding are gone; the no-invented-approach rule stays", "the ## Chosen rule says the chosen entry plus every entry it builds on by letter, pool number or title, applied again until none builds on an absent entry, each verbatim under its pool number with letters resolved in note lines, unclear mentions included", "the ## Chosen rule says a mention that only compares adds no entry and the entry it names stays as one line under ## Pool", "Step 2 says an inherited entry the drafter returns as missing from ## Chosen is added with what it builds on and the drafter is re-dispatched once, and that no entry is added because of a comparison", "Step 2 records git status before the dispatch, passes SPEC_PATH and APPROACHES_FILE, runs the four checks, reports a stray path without reverting, and records git hash-object", "Step 3 passes findings, LINT problems and SPEC_PATH, repeats checks 1 to 3, treats an unchanged hash with a fixed disposition as malformed, and uses DISPOSITIONS for the re-review note and critique log", "Step 4 no longer derives by hand or renders the page and gives the --html command", "Step 5 lists no HTML path and reads only the assumptions section", "Steps 0.4b and 0.4c are scoped to A0, add the partial-file re-dispatch rule, and the cannot-write STOP is stated", "the description and README lines 106 and 231 describe the page as available on request", "the file satisfies its strings-table row and keeps every brainstorm phrase that must survive"], "blockedBy": []}
```

### Task 6: build: dispatch by brief file

**Goal:** The build coordinator hands each implementer and reviewer a brief file path, re-derives the mirror at every start, and never holds the spec or the mirror in its own context.

**Files:**
- Modify: `skills/foureyes-build/SKILL.md`
- Modify: `agents/foureyes-implementer.md`
- Modify: `agents/foureyes-implementer-frontier.md`
- Modify: `agents/foureyes-task-reviewer.md`

**Acceptance Criteria:**
- Step 0.5's command comment says the call lints and writes nothing; Step B no longer mentions HTML.
- E1 runs `--derive --briefs "<RUN>"`, reads the index, creates native tasks with a subject and a one-line pointer to the brief, maps 1-based `blockedBy` to native ids, and skips completed lines; it says not to read the mirror or the spec whole; the resume rule about committed partial work is unchanged.
- E1 says: a task the user marks done at the resume question is recorded with `--complete <N>`.
- E1 says: if the call exits non-zero, print the tool's message, dispatch nothing and stop; if the call is denied, print one line naming `<RUN>` and saying writes under the git directory are blocked, dispatch nothing and stop; it gives no inline fallback.
- E2's prompt is `BRIEF_FILE` plus re-dispatch additions; the block still names `Global Constraints` and `Cross-Task Contracts` (as contents of the brief), says the brief also holds the whole design, and keeps the rule against sending an implementer to the spec file.
- E5 passes `BRIEF_FILE`, the report inline, `DIFF_FILE` and the range; a gate's criteria are read from its brief; status sync is `--complete <N>`.
- Both implementer agents say to read `BRIEF_FILE` first and work from it, and their bodies are byte-identical.
- `foureyes-task-reviewer.md` says the task, constraints, contracts and design arrive in `BRIEF_FILE`; its `tools:` line is unchanged.
- No sentence in any of the four files describes Bash redirection as avoiding a permission prompt.
- Every file satisfies its row of the strings table and keeps its phrases that must survive.

**Verify:** `f=skills/foureyes-build/SKILL.md; grep -q -- '--derive' $f && grep -q -- '--briefs' $f && grep -q -- '--complete' $f && sed -n '/^\*\*E2 /,/^\*\*E3 /p' $f | grep -q 'BRIEF_FILE' && ! grep -q 'carrying its description verbatim' $f && ! grep -q 'writes the HTML page' $f && ! grep -q 'generates the HTML' $f && grep -q 'Never silently re-implement over a partial' $f && grep -q 'BRIEF_FILE' agents/foureyes-implementer.md && grep -q 'BRIEF_FILE' agents/foureyes-implementer-frontier.md && grep -q 'BRIEF_FILE' agents/foureyes-task-reviewer.md && echo PASS`

```json:metadata
{"files": ["skills/foureyes-build/SKILL.md", "agents/foureyes-implementer.md", "agents/foureyes-implementer-frontier.md", "agents/foureyes-task-reviewer.md"], "modelTier": "frontier", "verifyCommand": "f=skills/foureyes-build/SKILL.md; grep -q -- '--derive' $f && grep -q -- '--briefs' $f && grep -q -- '--complete' $f && sed -n '/^\\*\\*E2 /,/^\\*\\*E3 /p' $f | grep -q 'BRIEF_FILE' && ! grep -q 'carrying its description verbatim' $f && ! grep -q 'writes the HTML page' $f && ! grep -q 'generates the HTML' $f && grep -q 'Never silently re-implement over a partial' $f && grep -q 'BRIEF_FILE' agents/foureyes-implementer.md && grep -q 'BRIEF_FILE' agents/foureyes-implementer-frontier.md && grep -q 'BRIEF_FILE' agents/foureyes-task-reviewer.md && echo PASS", "acceptanceCriteria": ["Step 0.5's command comment says the call lints and writes nothing; Step B no longer mentions HTML", "E1 runs --derive --briefs, reads the index, creates native tasks with a subject and a pointer, maps 1-based blockedBy, skips completed lines, says not to read the mirror or spec whole, and keeps the resume rule about committed partial work unchanged", "E1 says a task the user marks done at the resume question is recorded with --complete <N>", "E1 says a non-zero exit prints the tool's message and a denied call prints one line naming <RUN>; either way nothing is dispatched and the run stops, with no inline fallback", "E2's prompt is BRIEF_FILE plus re-dispatch additions, still names Global Constraints and Cross-Task Contracts, says the brief also holds the whole design, and keeps the no-spec-file rule", "E5 passes BRIEF_FILE, the report inline, DIFF_FILE and the range; gate criteria come from the brief; status sync is --complete", "both implementer agents say to read BRIEF_FILE first and their bodies are byte-identical", "the task reviewer says the task, constraints, contracts and design arrive in BRIEF_FILE and its tools line is unchanged", "no sentence in the four files describes Bash redirection as avoiding a permission prompt", "every file satisfies its strings-table row and keeps its phrases that must survive"], "blockedBy": []}
```

### Task 7: investigate: scout findings typed once

**Goal:** The investigate coordinator writes the scout reports to one file beside its report that both proposers read, and prints the cause in its last line.

**Files:**
- Modify: `skills/foureyes-investigate/SKILL.md`

**Acceptance Criteria:**
- Step 1 fixes the `<topic>` slug and says Step 6 reuses it.
- After Step 2 the coordinator writes all scout reports once, with the Write tool, to `docs/foureyes/investigations/YYYY-MM-DD-<topic>-scouts.md`; the text says this is the directory the report already goes to and that nothing is written under the git directory.
- Step 3's Sol command pipes its header lines and `cat` of that file into the same `"$WRAP" investigate` call; the investigator's assignment names the file to read.
- Round 2 appends ruled-out findings to the same file.
- The text says: if the write is denied or fails, do not retry and do not ask; pass the scout reports inline in both proposer inputs for the rest of the run and say so in one line.
- The opening rule about created files names the report, the critique log and the scout findings file.
- The final instruction reads `Print the status, the cause and the report path`.
- The number of `"$WRAP"` occurrences is unchanged, `This command changes NO CODE` and `Do not fix anything` are still present, and the file does not contain `gitdir`.

**Verify:** `f=skills/foureyes-investigate/SKILL.md; grep -q -- '-scouts.md' $f && grep -q 'Print the status, the cause and the report path' $f && grep -q 'This command changes NO CODE' $f && grep -q 'Do not fix anything' $f && ! grep -q 'gitdir' $f && echo PASS`

```json:metadata
{"files": ["skills/foureyes-investigate/SKILL.md"], "modelTier": "standard", "verifyCommand": "f=skills/foureyes-investigate/SKILL.md; grep -q -- '-scouts.md' $f && grep -q 'Print the status, the cause and the report path' $f && grep -q 'This command changes NO CODE' $f && grep -q 'Do not fix anything' $f && ! grep -q 'gitdir' $f && echo PASS", "acceptanceCriteria": ["Step 1 fixes the topic slug and says Step 6 reuses it", "after Step 2 the scout reports are written once with the Write tool to docs/foureyes/investigations/YYYY-MM-DD-<topic>-scouts.md, and the text says this is the report's directory and nothing is written under the git directory", "Step 3's Sol command pipes the header and cat of that file into the same \"$WRAP\" investigate call and the investigator is told to read the file", "round 2 appends ruled-out findings to the same file", "the text says a denied or failed write is not retried or asked about; scout reports go inline for the rest of the run and one line says so", "the opening rule about created files names the report, the critique log and the scout findings file", "the final instruction reads Print the status, the cause and the report path", "the number of \"$WRAP\" occurrences is unchanged, the two NO CODE phrases are still present, and the file does not contain gitdir"], "blockedBy": []}
```

### Task 8: prose contracts for the new shape

**Goal:** `tests/prose-contracts.test.sh` enforces that no skill drifts back to re-typing a document.

**Files:**
- Modify: `tests/prose-contracts.test.sh`

**Acceptance Criteria:**
- A group headed `--- nothing is typed twice ---` is added before the final summary lines, holding checks 30a to 30l with the exact names in the contracts.
- Each check asserts its file's row of the strings table: required strings present and forbidden strings absent. 30g scopes `BRIEF_FILE` to the E2 block, reusing the existing `e2` helper.
- No existing check is removed or weakened; the group has a short comment saying what the checks guard.
- `bash tests/prose-contracts.test.sh` exits 0. Only this suite is run; `tests/run.sh` is not.
- If an existing check fails on a file outside this task's Files, the task reports that check's name as `BLOCKED` and changes nothing outside `tests/prose-contracts.test.sh`.

**Verify:** `builder run bash tests/prose-contracts.test.sh`

```json:metadata
{"files": ["tests/prose-contracts.test.sh"], "modelTier": "standard", "verifyCommand": "builder run bash tests/prose-contracts.test.sh", "acceptanceCriteria": ["a group headed --- nothing is typed twice --- is added before the final summary lines with checks 30a to 30l named exactly as in the contracts", "each check asserts its strings-table row; 30g scopes BRIEF_FILE to the E2 block using the existing e2 helper", "no existing check is removed or weakened and the group has a short comment saying what it guards", "bash tests/prose-contracts.test.sh exits 0; only this suite is run, tests/run.sh is not", "an existing check failing on a file outside this task's Files is reported by name as BLOCKED and nothing outside tests/prose-contracts.test.sh is changed"], "blockedBy": [3, 4, 5, 6, 7]}
```

### Task 9: Gate: scripts on a real spec, one full-suite run

**Goal:** Show on a copy of a committed spec that derive, lint, briefs, completion and status reset work end to end, and run the full suite once.

**Files:**
- (none)

**Acceptance Criteria:**
- The Verify command exits 0 and its last output line is `GATE-PASS`. Every step in it runs under `set -e`, so `GATE-PASS` is printed only when each one held.
- Its output never contains `DRIFT`, which would mean `--json` reported a `plan-tasks-*` problem after `--derive` on the copy of `docs/foureyes/specs/2026-09-23-spec-owns-tasks-design.md`.
- `GATE-PASS` proves the brief for task 1 contains the line `### Spec critic`, a design section that names none of that task's files.
- `GATE-PASS` proves that after `--complete` on tasks 1 to 9 and an unchanged `--derive --briefs`, all nine index lines read `completed`; and that after a line is appended to task 9's section and the same call runs again, exactly eight read `completed` and task 9 reads `pending`.
- The line before `GATE-PASS` is the `run.sh:` summary and reads `0 failed`. This is the only run of `bash tests/run.sh` in the whole change; it runs `plan-viz.test.mjs`, so the shared-section and prerequisite reset tests of Task 1 are part of it.
- `git status --porcelain` is identical before and after the command.

**Verify:** `builder sh -c 'set -e; v=skills/foureyes-brainstorm/lib/plan-viz.mjs; d=$(mktemp -d); cp docs/foureyes/specs/2026-09-23-spec-owns-tasks-design.md "$d/s.md"; node "$v" "$d/s.md" --derive; test ! -e "$d/s.md.html"; node "$v" "$d/s.md" --json > "$d/lint.json"; if grep -q plan-tasks- "$d/lint.json"; then echo DRIFT; exit 1; fi; node "$v" "$d/s.md" --briefs "$d/b" > "$d/idx"; test "$(wc -l < "$d/idx")" -eq 9; test "$(ls "$d/b" | wc -l)" -eq 9; grep -q "^## Global Constraints" "$d/b/task-1.md"; grep -q "^### Spec critic" "$d/b/task-1.md"; for n in 1 2 3 4 5 6 7 8 9; do node "$v" "$d/s.md" --complete $n; done; node "$v" "$d/s.md" --derive --briefs "$d/b" > "$d/idx"; test "$(grep -c "status.:.completed" "$d/idx")" -eq 9; printf "\nextra line\n" >> "$d/s.md"; node "$v" "$d/s.md" --derive --briefs "$d/b" > "$d/idx"; test "$(grep -c "status.:.completed" "$d/idx")" -eq 8; tail -1 "$d/idx" | grep -q "status.:.pending"; bash tests/run.sh > "$d/run.log" 2>&1 || { tail -20 "$d/run.log"; exit 1; }; tail -1 "$d/run.log"; echo GATE-PASS'`

```json:metadata
{"files": [], "modelTier": "mechanical", "verifyCommand": "builder sh -c 'set -e; v=skills/foureyes-brainstorm/lib/plan-viz.mjs; d=$(mktemp -d); cp docs/foureyes/specs/2026-09-23-spec-owns-tasks-design.md \"$d/s.md\"; node \"$v\" \"$d/s.md\" --derive; test ! -e \"$d/s.md.html\"; node \"$v\" \"$d/s.md\" --json > \"$d/lint.json\"; if grep -q plan-tasks- \"$d/lint.json\"; then echo DRIFT; exit 1; fi; node \"$v\" \"$d/s.md\" --briefs \"$d/b\" > \"$d/idx\"; test \"$(wc -l < \"$d/idx\")\" -eq 9; test \"$(ls \"$d/b\" | wc -l)\" -eq 9; grep -q \"^## Global Constraints\" \"$d/b/task-1.md\"; grep -q \"^### Spec critic\" \"$d/b/task-1.md\"; for n in 1 2 3 4 5 6 7 8 9; do node \"$v\" \"$d/s.md\" --complete $n; done; node \"$v\" \"$d/s.md\" --derive --briefs \"$d/b\" > \"$d/idx\"; test \"$(grep -c \"status.:.completed\" \"$d/idx\")\" -eq 9; printf \"\\nextra line\\n\" >> \"$d/s.md\"; node \"$v\" \"$d/s.md\" --derive --briefs \"$d/b\" > \"$d/idx\"; test \"$(grep -c \"status.:.completed\" \"$d/idx\")\" -eq 8; tail -1 \"$d/idx\" | grep -q \"status.:.pending\"; bash tests/run.sh > \"$d/run.log\" 2>&1 || { tail -20 \"$d/run.log\"; exit 1; }; tail -1 \"$d/run.log\"; echo GATE-PASS'", "acceptanceCriteria": ["the Verify command exits 0 and its last output line is GATE-PASS", "its output never contains DRIFT", "GATE-PASS proves the brief for task 1 contains the line ### Spec critic, a design section naming none of that task's files", "GATE-PASS proves all nine index lines read completed after --complete on tasks 1 to 9 and an unchanged --derive --briefs, and that exactly eight read completed and task 9 reads pending after a line is appended to task 9's section and the same call runs again", "the line before GATE-PASS is the run.sh summary and reads 0 failed; this is the only run of bash tests/run.sh in the whole change, and it includes the shared-section and prerequisite reset tests of Task 1", "git status --porcelain is identical before and after the command"], "blockedBy": [2, 8]}
```

