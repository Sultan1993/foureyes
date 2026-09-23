# Spec: The spec owns the tasks — delete the implementation plan

**Date:** 2026-09-23
**Approaches file:** none — direction settled in conversation (fold tasks into the spec, drop Steps, keep contracts)
**Chosen approach:** one document seam; tasks without code; contracts in code form; scaffold wave when parallelism shares a build unit

## Purpose

Brainstorm today produces two documents and runs two Astra loops: a design spec,
then an implementation plan whose tasks carry a `Steps` field. The drafter is
told that Steps must be "complete enough that the assigned tier can execute
without judgment gaps — for mechanical tasks that means the code itself". So the
plan is the feature implemented once in markdown, read twice by Astra, then
implemented again in files by a Sonnet. Measured on the plans in this repo,
49–56% of plan lines are code fences. The plan seam costs 33–73 minutes per
brainstorm, and its long tail (a 51-minute dispatch that hit the output ceiling)
is the reason the drafter carries a part-splitting protocol, `TASKS-PER-PART`,
halving, `REVISION: sections` and a task splicer.

This change deletes the plan. The design spec ends with a `## Tasks` section in
the existing task format minus Steps. Nobody writes code before build. Build is
unchanged in behavior: it still reads a `.tasks.json`, computes waves, routes by
tier, reviews per task and commits per task.

Three mitigations ship with it, because dropping pre-written code has one real
regression — names shared between concurrent implementers are no longer pinned
by construction:

1. **Contracts in code form.** The spec pins every shared name as a declaration
   (signature, type, path, flag, env var, exit code, test name). Never a body.
2. **A scaffold task** when a wave wider than one shares a build unit: one serial
   task creates the files and declares the contracts so the tree compiles before
   the parallel wave starts.
3. **A spec-critic rule**: every name a task references from a sibling, and every
   name a verify command references outside the task's own files, must appear in
   the contracts section.

Expected result: brainstorm drops from roughly 65–80 minutes to 35–40; the
overflow tail disappears; build wall clock unchanged.

## Design

### The spec document

`docs/foureyes/specs/YYYY-MM-DD-<topic>-design.md` keeps everything it has today
(purpose, design, data flow, error handling, non-goals, success criteria,
`## Assumptions` when unknowns were not put to the user) and gains three
trailing sections, in this order:

```
## Cross-Task Contracts
## Global Constraints
## Tasks
```

**`## Cross-Task Contracts`** — declarations only. Function and type signatures,
file paths, CLI flags, env vars, exit codes, exact test names, section headings
other tasks grep for. Written as code blocks in the target language where one
exists. A body, an implementation, or a "for example" implementation is a
defect. Also carries the test policy when tasks share a build unit (which task
runs the shared suite, and when it is expected green). Present even when
empty-ish: a wave of width one still has to say "no shared names".

**`## Global Constraints`** — one line each, the project-wide requirements every
task implicitly carries: version floors, dependency limits, naming rules,
platform requirements, implementer discipline. Build passes this section
verbatim to every implementer and reviewer, so it is written for them, not for
the reader of the design.

**`## Tasks`** — `### Task N: <subject ≤ 60 chars>` sections numbered from 1,
each carrying exactly:

```
**Goal:** one sentence.
**Files:** exact Create/Modify paths.
**Acceptance Criteria:** bullet list, each one checkable.
**Verify:** one runnable command.
```

followed by a `json:metadata` fence holding `{"files": [...], "modelTier":
"mechanical|standard|frontier", "verifyCommand": "...", "acceptanceCriteria":
[...], "blockedBy": [task numbers]}`.

There is no `Steps` field. A task that carries one is reported by plan-viz as
`has-steps` and the field is never forwarded to an implementer.

Rules the drafter follows for the task section (these move from Assignment B to
Assignment A, minus everything about Steps):

- Files disjoint within a wave; shared steps (codegen, wiring, cleanup) become
  barrier tasks after the wave. `blockedBy` only for real dependencies.
- A verify-only task declares `"files": []`.
- A verify command or acceptance criterion may reference only: paths in the
  task's own Files, names in `## Cross-Task Contracts`, or names that already
  exist in the repo. Anything else is a contract the drafter forgot to pin.
- **Scaffold rule.** If any wave has width > 1 and its tasks share a build unit
  (same package, module, compilation unit, or one imports from another), the
  first task is a scaffold: create the files named in the contracts, declare the
  signatures with stub bodies so the tree compiles or loads, no logic. Tier
  `mechanical`. Every task of that wave lists it in `blockedBy`. Independent
  files (a bash script and a YAML, two unrelated markdown files) need no
  scaffold.
- **Tier rule.** `mechanical` only when the task is fully determined by the
  contracts plus its criteria — scaffold tasks, renames, copying bytes the spec
  already verified. `standard` when the implementer writes code from a goal.
  `frontier` when the task needs design judgment the spec does not capture. No
  blanket assignments. The old tie-break "steps containing the complete code =
  mechanical" is deleted with Steps.
- Verify commands run under the harness shell, zsh on macOS: never use `status`,
  `path`, `argv` or `options` as variable names.
- Every library/API claim verified via Context7 or WebSearch first.
- Subjects ≤ 60 characters.

**Reply size.** Without code, a thirty-task spec is roughly 30 KB, an order of
magnitude under the output ceiling. The parts protocol, `TASKS-PER-PART`,
halving, `DRAFT: part`, `REMAINING`, `REVISION: sections`, `CHANGED-TASKS` and
the splicer are deleted. On revision the drafter returns the full spec. If a
spec reply ever overflows, that is a scope problem: the feature is too big for
one build and is decomposed into sub-projects, which the spec critic's scope
check already asks for. The harness facts (spilled output lands in a file and
returns a preview; the 64000-token ceiling returns nothing) stay in the drafter
and coordinator prose; only the remedies that mention sections or parts go.

### Brainstorm

Steps become: 0 preflight · 1 approach seam (unchanged) · 2 Fable drafts the spec,
now including the three trailing sections · 3 Astra critiques the spec, ≤ 2
rounds, Fable concludes · 4 the coordinator derives `<spec>.md.tasks.json` from
`## Tasks` and runs `node "$VIZ" "<spec path>"`, which writes `<spec>.md.html`
· 5 report, then stop or hand the spec path back under `--continue`.

The old Steps 4 (draft plan), 5 (critique plan) and the parts/splice protocol in
Step 0 are deleted. `--skip-critics` skips Step 3 only. The critique log's
`<seam>` set for brainstorm is `approach` and `spec`; `## plan ·` rows are never
written again. `"$WRAP" plan` appears in no skill.

`.tasks.json` derivation is unchanged in shape (`planPath`, `tasks[{id 0-based,
subject "Task N: …", description = the full task markdown including the fence,
blockedBy 0-based}]`, `lastUpdated`); `planPath` is kept as the key name to avoid
churn in the readers.

### Build

- Argument is a spec path. Step 0 classification stays artifact-driven: `<X>.md`
  with an `<X>.md.tasks.json` sibling → SPEC branch (was PLAN); anything else →
  BRIEF. An old plan file with its sibling still classifies and still runs; its
  Steps are reported as `has-steps` and ignored.
- Step 0.5 runs plan-viz on the spec; the stop/continue table is unchanged, with
  `has-steps` added to the report-and-continue row. "Has Astra ever read this
  spec?" greps the sibling critique log for `^## spec ` and, when absent, offers
  the same three options; "Critique it first" runs the `spec` seam at `ROUND=1`.
- Step B is unchanged except wording: brainstorm returns the spec path.
- E2 implementer prompt: the task's Goal / Files / Acceptance Criteria / Verify
  verbatim, plus `## Global Constraints` verbatim, plus `## Cross-Task Contracts`
  verbatim, plus the spec's Design subsection(s) that cover the task's files as
  scene-setting. Never Steps. Never "read the spec file".
- E5 task reviewer receives the brief, `## Global Constraints` and
  `## Cross-Task Contracts`.
- S3 code seam passes `SPEC_DOC: <spec path>` only; the code critic reviews
  against the spec's tasks and contracts. The critique log is always written
  beside the spec; the "bare plan, write beside the plan" branch is deleted.
- E3 BLOCKED row: "Spec is wrong → STOP and surface to the user".

### Implementers

Both implementer bodies (kept byte-identical): the assignment is Goal, Files,
Acceptance Criteria, Verify, Global Constraints, Cross-Task Contracts and
scene-setting. Names in Cross-Task Contracts are fixed: an implementer that
finds one cannot work reports `NEEDS_CONTEXT` rather than renaming. Tests are
written first for each acceptance criterion that can have one, then the code.
Task reviewer and code critic: "plan" → "spec"; the brief no longer lists steps.

### Spec critic

The spec critic absorbs the plan critic's checks that have no spec-side
equivalent, as a new group applied to the trailing sections:

7. **Coverage** — every requirement and success criterion maps to at least one
   task; uncovered = Critical.
8. **Contract pinning** — every name a task references from a sibling's files,
   and every name a verify command or criterion references outside the task's
   own Files and the existing repo, appears in `## Cross-Task Contracts` as a
   declaration; missing = Critical. A body in the contracts section = Important.
9. **Parallel readiness** — files disjoint within a wave; `blockedBy` only for
   real dependencies; barrier tasks for shared steps; test policy stated when a
   build unit is shared; **scaffold task present when a wave wider than one
   shares a build unit** (missing = Important).
10. **Task completeness** — exact paths, a runnable verify, checkable criteria,
    subjects ≤ 60, no placeholders ("TBD", "similar to Task N").
11. **Tier sanity** — tier reflects the judgment the task needs under the tier
    rule above; a blanket assignment = Important; mechanical on a task that
    needs judgment = Critical.

The clause "Do NOT demand an execution/parallelism section in the spec" is
deleted, as is "before writing-plans". `agents/foureyes-plan-critic.md` is
deleted.

### plan-viz

File name kept (`skills/foureyes-brainstorm/lib/plan-viz.mjs`); a rename touches
ten references for no behavior. Changes: header comment says it renders a spec's
task section; `spliceTasks` and `taskRanges` removed with their tests; the
`Steps` card block removed; title fallback becomes `Tasks`; the `Spec:` header
line is no longer expected (the header shows the document's own path); new
problem kind `has-steps` in `detectProblems`, detected on the task description
with `/^\*\*Steps:\*\*/m`, detail `task carries a **Steps:** field — the pipeline
never forwards it`. Every other export, check code and `FENCE_KEYS` unchanged.

### Stats, ledger, docs

`pipeline-stats.mjs` scans `foureyes/specs` and `superpowers/specs` in addition
to the two plans dirs, so old runs stay counted; `CODEX_ONLY` drops
`foureyes-plan-critic`. `astra-ledger.mjs` keeps `plan` in `SEAMS` so existing
logs still parse, with a comment saying it is read-only history. README, the
site (`docs/index.html` CMD arrays and roster), the ledger and review skills
describe the new shape. Existing artifacts under `docs/foureyes/plans/` are left
as history.

## Data flow

```
brief ─► approach seam ─► spec (design + contracts + constraints + tasks)
      ─► Astra spec seam ×≤2 ─► Fable concludes
      ─► coordinator derives <spec>.md.tasks.json ─► plan-viz ─► <spec>.md.html
      ─► STOP (or --continue → build)
build <spec>.md ─► plan-viz checks ─► waves from blockedBy + file-disjointness
      ─► implementer gets task + constraints + contracts + design excerpt
      ─► per-task review ─► per-task commit ─► Astra code seam against the spec
```

## Error handling

- Task carries Steps → `has-steps` reported; never forwarded; build continues.
- Verify names something unpinned → spec critic Critical before dispatch; if it
  slips through, the implementer's verify fails and it reports `NEEDS_CONTEXT`,
  the coordinator pins the name and re-dispatches.
- Implementer needs a file not in Files → forbidden to touch it; reports
  `NEEDS_CONTEXT`; coordinator adds it or serializes.
- Spec reply overflows → scope problem; decompose the feature; never a parts
  protocol.
- Old plan handed to build → runs as before; `has-steps` noise only.

## Explicit non-goals (YAGNI)

- No rename of `plan-viz.mjs` or the `planPath` JSON key.
- No automatic `.tasks.json` derivation script; the coordinator derives it as
  today.
- No change to the approach seam, the code seam, review, investigate, or the
  wave/commit mechanics in build.
- No migration of old plans; no deletion of `docs/foureyes/plans/`.
- No change to `tests/pressure/` scenarios (their "Steps:" is assignment prose
  inside a pressure prompt, not pipeline contract).
- No new dependencies. Node stdlib and bash only.

## Observable success criteria

1. `grep -rn '"\$WRAP" plan' skills/` returns nothing; `agents/foureyes-plan-critic.md` does not exist.
2. The drafter's Assignment A output format contains `## Cross-Task Contracts`, `## Global Constraints`, `## Tasks` and no `**Steps:**`; the drafter contains none of `TASKS-PER-PART`, `DRAFT: part`, `REVISION: sections`, `CHANGED-TASKS`.
3. `node plan-viz.mjs --json` on a tasks.json whose description has a `**Steps:**` line reports `has-steps`; `spliceTasks` and `taskRanges` are not exported.
4. Build's E2 prompt assembly names Cross-Task Contracts and not Steps; Step 0.5 greps `^## spec `.
5. `bash tests/run.sh` is green, with new prose contracts covering 1, 2 and 4.
6. Handing build the existing `docs/foureyes/plans/2026-08-05-test-entry-point.md` reaches Step 0.5 and reports `has-steps` for every task, nothing else new.

## Cross-Task Contracts

Strings the test task (Task 8) greps for; every sibling emits them exactly.

```
# spec section headings (drafter emits, critic checks, build lifts verbatim)
## Cross-Task Contracts
## Global Constraints
## Tasks
### Task N: <subject>

# task field markers — no Steps
**Goal:**  **Files:**  **Acceptance Criteria:**  **Verify:**
fence: json:metadata  keys: files modelTier verifyCommand acceptanceCriteria blockedBy model

# plan-viz (skills/foureyes-brainstorm/lib/plan-viz.mjs)
export { parseTasks, extractFence, normalizePath, computeWaves, FENCE_KEYS,
         detectProblems, detectPlanDrift, analyze, parsePlanMarkdown, renderHTML }
# removed: spliceTasks, taskRanges
problem kind: 'has-steps'   detail: 'task carries a **Steps:** field — the pipeline never forwards it'
CLI unchanged: node plan-viz.mjs <doc.md> [--json]; reads <doc.md>.tasks.json; writes <doc.md>.html

# tasks.json: <spec>.md.tasks.json, shape unchanged, key `planPath` kept

# seams: "$WRAP" spec | code | approach | review | refute   ("$WRAP" plan: never)
# critique log headers: ## spec · round <n> …   (## plan · rows: never written; still parsed)

# build phrases (tests/prose-contracts greps, via has())
"Has Astra ever read this spec"      grep for '^## spec '
E2 and E5 both name "Cross-Task Contracts" and "Global Constraints"; E2 never names Steps
Step 0 branch names: SPEC (was PLAN), BRIEF

# drafter phrases
Assignment A carries the three sections; contains "declarations only" and "scaffold"
absent: "**Steps:**", "Assignment B", "TASKS-PER-PART", "DRAFT: part", "REVISION: sections", "CHANGED-TASKS"

# spec-critic phrases
contains "Cross-Task Contracts", "scaffold", "coverage"
absent: "Do NOT demand an execution/parallelism section", "writing-plans"

# implementer phrases (both files, bodies byte-identical below frontmatter — tests/prose-contracts 27d `bodyof`)
contains "Cross-Task Contracts", "NEEDS_CONTEXT"; absent: "Steps"

# pipeline-stats: CODEX_ONLY = ['foureyes-spec-critic', 'foureyes-code-critic']
# astra-ledger:   SEAMS unchanged = ['approach','investigate','spec','plan','code']
```

**Test policy.** All nine tasks are wave 1 and file-disjoint; there is no shared
build unit, so no scaffold task. Each task's Verify checks only its own files.
`bash tests/run.sh` is expected red until the join and green at the join, when
Task 8's rewritten assertions meet the siblings' text. The pre-commit hook runs
the suite on the working tree, so the per-task commits at the join all pass;
individual wave-1 commits may be red in isolation, and that is accepted.

## Global Constraints

- No new dependencies; Node stdlib and bash only.
- Prose edits are surgical: change what the task names, keep the file's voice,
  do not reflow or "improve" adjacent sections. Every changed line traces to the
  task.
- `spec`, `code`, `approach`, `review`, `refute` critics reach Astra only through
  `scripts/codex-critic.sh`; never dispatched as Claude subagents.
- Implementers never commit and never touch a file outside their Files list;
  temp files go in `mktemp` dirs outside the repo.
- Never modify anything under `docs/foureyes/plans/` or `tests/pressure/`.
- The two implementer bodies stay byte-identical below the frontmatter.
- Verify commands are zsh-safe: no `status`, `path`, `argv`, `options` variables.

## Tasks

### Task 1: Drafter: spec owns tasks, no Steps, no plan assignment

**Goal:** Rewrite `agents/foureyes-drafter.md` so Assignment A produces the spec with its three trailing sections and Assignment B, Steps, and the parts/splice protocol are gone.

**Files:**
- Modify: `agents/foureyes-drafter.md`

**Acceptance Criteria:**
- Description no longer says "implementation plans"; says the drafter authors design specs that end with a task section.
- Assignment A's output list adds, after the existing coverage list: `## Cross-Task Contracts` (declarations only, never bodies, code blocks in the target language, test policy when a build unit is shared), `## Global Constraints` (one line each, written for implementers), `## Tasks` with the exact per-task format from the spec (Goal, Files, Acceptance Criteria, Verify, `json:metadata` fence with files/modelTier/verifyCommand/acceptanceCriteria/blockedBy). No `**Steps:**` anywhere in the file.
- Task rules carried into Assignment A: files disjoint per wave and barrier tasks; `"files": []` for verify-only tasks; the reference rule (verify/criteria may name only own Files, contracts, or existing repo names); the scaffold rule (wave width > 1 sharing a build unit → first task is a mechanical scaffold every wave task depends on); the tier rule (mechanical only when fully determined by contracts + criteria; standard when writing code from a goal; frontier for design judgment; no blanket assignments); zsh reserved names in Verify commands; library claims verified; subjects ≤ 60.
- Assignment B section deleted. "You receive ONE of three assignments" becomes two (A0, A).
- Deleted: "A big plan is fine — a big REPLY is not" section, `TASKS-PER-PART`, `DRAFT: part`, `REMAINING`, `TASKS-IN-THIS-PART`, `REVISION: sections`, `REVISION: full`, `CHANGED-TASKS`, the "complete code = mechanical" tie-break, "Show the real code".
- "On a REVISION" section now says: return the full spec; address every finding or state why the design is intentional. The `DRAFTER-STATS:` first-line rule stays, with its rationale reduced to "the coordinator reads it first and strips it".
- The overflow guidance keeps the harness facts (spill preview, 64000-token ceiling) and replaces the sections/halves remedy with: an overflowing spec is a scope problem; say so and return the design sections with a `## Unresolved` note recommending decomposition.
- The A0 line "a spec, a plan, two critic rounds" becomes "a spec, two critic rounds".

**Verify:** `f=agents/foureyes-drafter.md; ! grep -q '\*\*Steps:\*\*' $f && ! grep -q 'TASKS-PER-PART\|DRAFT: part\|REVISION: sections\|CHANGED-TASKS\|Assignment B' $f && grep -q '## Cross-Task Contracts' $f && grep -q '## Global Constraints' $f && grep -q '## Tasks' $f && grep -qi 'declarations only' $f && grep -qi 'scaffold' $f && grep -q 'DRAFTER-STATS' $f && echo OK`

```json:metadata
{"files": ["agents/foureyes-drafter.md"], "modelTier": "frontier", "verifyCommand": "f=agents/foureyes-drafter.md; ! grep -q '\\*\\*Steps:\\*\\*' $f && ! grep -q 'TASKS-PER-PART\\|DRAFT: part\\|REVISION: sections\\|CHANGED-TASKS\\|Assignment B' $f && grep -q '## Cross-Task Contracts' $f && grep -q '## Global Constraints' $f && grep -q '## Tasks' $f && grep -qi 'declarations only' $f && grep -qi 'scaffold' $f && grep -q 'DRAFTER-STATS' $f && echo OK", "acceptanceCriteria": ["Assignment A emits the three trailing sections with the per-task format and no Steps", "Assignment B and the parts/splice protocol are deleted", "scaffold, tier, and reference rules present", "DRAFTER-STATS first-line rule kept"]}
```

### Task 2: Spec critic absorbs task checks; delete plan critic

**Goal:** Extend `agents/foureyes-spec-critic.md` with the five task-section checks and delete `agents/foureyes-plan-critic.md`.

**Files:**
- Modify: `agents/foureyes-spec-critic.md`
- Delete: `agents/foureyes-plan-critic.md`

**Acceptance Criteria:**
- Checks 7–11 added exactly as the design lists them: Coverage (uncovered = Critical), Contract pinning (missing declaration = Critical; a body in the contracts section = Important), Parallel readiness including "scaffold task present when a wave wider than one shares a build unit" (missing = Important), Task completeness, Tier sanity (blanket = Important; mechanical needing judgment = Critical).
- The clause "Do NOT demand an execution/parallelism section in the spec — execution policy lives in the pipeline, not the spec" is deleted; check 6 says the spec's own `## Tasks` is what is judged for decomposability.
- Description and "SEAM 1" prose no longer say "before writing-plans" / "BEFORE any implementation plan is written"; they say the spec is the only document seam and is executed directly.
- The NOT A CLAUDE SUBAGENT guard and VERDICT/FINDINGS grammar are unchanged.
- `agents/foureyes-plan-critic.md` removed from the tree.

**Verify:** `f=agents/foureyes-spec-critic.md; test ! -e agents/foureyes-plan-critic.md && grep -q 'Cross-Task Contracts' $f && grep -qi 'scaffold' $f && grep -qi 'coverage' $f && ! grep -qi 'writing-plans' $f && ! grep -q 'Do NOT demand an execution' $f && grep -q 'NOT A CLAUDE SUBAGENT' $f && echo OK`

```json:metadata
{"files": ["agents/foureyes-spec-critic.md", "agents/foureyes-plan-critic.md"], "modelTier": "standard", "verifyCommand": "f=agents/foureyes-spec-critic.md; test ! -e agents/foureyes-plan-critic.md && grep -q 'Cross-Task Contracts' $f && grep -qi 'scaffold' $f && grep -qi 'coverage' $f && ! grep -qi 'writing-plans' $f && ! grep -q 'Do NOT demand an execution' $f && grep -q 'NOT A CLAUDE SUBAGENT' $f && echo OK", "acceptanceCriteria": ["checks 7-11 present with the stated severities", "parallelism clause and writing-plans wording removed", "plan-critic file deleted", "guard and verdict grammar unchanged"]}
```

### Task 3: Implementers, task reviewer, code critic: spec not plan

**Goal:** Update the four execution-side agent prompts so the assignment is defined without Steps and with Cross-Task Contracts, and "plan" reads "spec".

**Files:**
- Modify: `agents/foureyes-implementer.md`
- Modify: `agents/foureyes-implementer-frontier.md`
- Modify: `agents/foureyes-task-reviewer.md`
- Modify: `agents/foureyes-code-critic.md`

**Acceptance Criteria:**
- Both implementer files: description says "from a foureyes spec"; the assignment list is Goal, Files, Acceptance Criteria, Verify command, Global Constraints, Cross-Task Contracts, and scene-setting; "Do not go read the plan document" becomes "Do not go read the spec document"; the word "Steps" appears nowhere. New rule: names in Cross-Task Contracts are fixed; if one cannot work, report `NEEDS_CONTEXT`, never rename. "Write tests (following TDD when the Steps say to)" becomes "Write the test for each acceptance criterion that can have one first, then the code." "restructuring code the plan did not anticipate" → "the spec".
- Frontmatter of the two files: only the description wording changes; model and effort pins untouched. Bodies below the frontmatter are byte-identical.
- Task reviewer: the brief line drops "steps"; "copied verbatim from the plan" → "from the spec"; also receives Cross-Task Contracts; "plan's file structure" / "plan-mandated" → spec.
- Code critic: description and check 1 review against the spec's tasks and contracts; inputs are the spec path only; "rewrite = diverges from the plan" → spec.

**Verify:** `bodyof(){ awk 'f>1{print} /^---$/{f++}' "$1"; }; a=agents/foureyes-implementer.md; b=agents/foureyes-implementer-frontier.md; [ "$(bodyof $a)" = "$(bodyof $b)" ] && ! grep -q 'Steps' $a && grep -q 'Cross-Task Contracts' $a && grep -q 'NEEDS_CONTEXT' $a && grep -q 'Cross-Task Contracts' agents/foureyes-task-reviewer.md && ! grep -qi 'steps' agents/foureyes-task-reviewer.md && ! grep -q 'PLAN_DOC\|plan doc' agents/foureyes-code-critic.md && echo OK`

```json:metadata
{"files": ["agents/foureyes-implementer.md", "agents/foureyes-implementer-frontier.md", "agents/foureyes-task-reviewer.md", "agents/foureyes-code-critic.md"], "modelTier": "standard", "verifyCommand": "bodyof(){ awk 'f>1{print} /^---$/{f++}' \"$1\"; }; a=agents/foureyes-implementer.md; b=agents/foureyes-implementer-frontier.md; [ \"$(bodyof $a)\" = \"$(bodyof $b)\" ] && ! grep -q 'Steps' $a && grep -q 'Cross-Task Contracts' $a && grep -q 'NEEDS_CONTEXT' $a && grep -q 'Cross-Task Contracts' agents/foureyes-task-reviewer.md && ! grep -qi 'steps' agents/foureyes-task-reviewer.md && ! grep -q 'PLAN_DOC\\|plan doc' agents/foureyes-code-critic.md && echo OK", "acceptanceCriteria": ["implementer assignment has no Steps and includes contracts with the fixed-names rule", "implementer bodies byte-identical", "task reviewer and code critic reference the spec, not the plan"]}
```

### Task 4: Brainstorm skill: one document seam

**Goal:** Restructure `skills/foureyes-brainstorm/SKILL.md` to draft and critique a single spec that ends with tasks, derive tasks.json from it, and render it.

**Files:**
- Modify: `skills/foureyes-brainstorm/SKILL.md`

**Acceptance Criteria:**
- Frontmatter description: produces the spec (with its task section), its `.tasks.json`, and an HTML page; Astra critiques the spec at most twice; no mention of a plan.
- Step 0.4 `--skip-critics` skips Step 3 only. Step 0 sub-items 4c/4d: the spill/ceiling facts stay; "REVISION: sections", "tasks in halves", `spliceTasks`, `CHANGED-TASKS`, `MISSING` handling deleted; an overflowing spec is handled as scope (decompose). "Strip the leading `DRAFTER-STATS:`" stays.
- Step 2 dispatches Assignment A and says the returned spec ends with `## Cross-Task Contracts`, `## Global Constraints`, `## Tasks`; the coordinator writes it under `docs/foureyes/specs/`.
- Step 3 unchanged in mechanics (`"$WRAP" spec`, `CODEX_CRITIC_ROUND` 1 then 2, GATE table, critique log rows, Fable concludes).
- Old Steps 4 and 5 (plan draft, plan critique), the parts protocol, assembly rules, and "critiques the assembled plan" deleted. The loop section says "the DOC seam" (one), not "both DOC seams"; the critique-log seam set is `approach` and `spec`.
- New Step 4: derive `<spec>.md.tasks.json` from `## Tasks` (id 0-based, subject "Task N: …", description = full task markdown with fence, blockedBy 0-based, `planPath` key kept), then `node "$VIZ" "<spec path>"` writes `<spec>.md.html`; check table adds `has-steps` (Fable's to fix, like `no-verify`).
- New Step 5: report spec, tasks.json, HTML, critique log paths; standalone says the user runs `foureyes-build <spec>`; `--continue` returns the spec path.
- `"$WRAP" plan` appears nowhere; `docs/foureyes/plans` appears nowhere.

**Verify:** `f=skills/foureyes-brainstorm/SKILL.md; ! grep -q '"\$WRAP" plan' $f && ! grep -q 'foureyes/plans\|TASKS-PER-PART\|spliceTasks\|CHANGED-TASKS\|DRAFT: part' $f && grep -q 'has-steps' $f && grep -q '## Tasks' $f && grep -q 'tasks.json' $f && grep -q 'CODEX_CRITIC_ROUND' $f && grep -q 'Strip the leading' $f && echo OK`

```json:metadata
{"files": ["skills/foureyes-brainstorm/SKILL.md"], "modelTier": "frontier", "verifyCommand": "f=skills/foureyes-brainstorm/SKILL.md; ! grep -q '\"\\$WRAP\" plan' $f && ! grep -q 'foureyes/plans\\|TASKS-PER-PART\\|spliceTasks\\|CHANGED-TASKS\\|DRAFT: part' $f && grep -q 'has-steps' $f && grep -q '## Tasks' $f && grep -q 'tasks.json' $f && grep -q 'CODEX_CRITIC_ROUND' $f && grep -q 'Strip the leading' $f && echo OK", "acceptanceCriteria": ["one document seam: spec drafted, critiqued <=2, concluded", "tasks.json derived from the spec and plan-viz run on it", "plan steps, parts protocol and splicing deleted", "spec seam mechanics unchanged"]}
```

### Task 5: Build skill: execute the spec

**Goal:** Update `skills/foureyes-build/SKILL.md` so it takes a spec path, forwards contracts instead of Steps, and logs beside the spec.

**Files:**
- Modify: `skills/foureyes-build/SKILL.md`

**Acceptance Criteria:**
- Frontmatter, title, announce line and Inputs say spec, not plan; "the spec is the contract".
- Step 0: `<X>.md` with `<X>.md.tasks.json` sibling → SPEC (Step 0.5); else BRIEF. Note that an old plan file still classifies and runs, with `has-steps` reported.
- Step 0.5 title "Read the spec before executing it"; `has-steps` joins the report-and-continue row; "Has Astra ever read this spec?" greps `'^## spec '`; "Critique it first" runs the `spec` seam at `ROUND=1`.
- Step B wording: brainstorm returns the spec path.
- E2: the prompt is Goal / Files / Acceptance Criteria / Verify verbatim, plus `## Global Constraints` verbatim, plus `## Cross-Task Contracts` verbatim, plus the spec's Design subsection(s) covering the task's files; "Never tell an implementer to read the spec file"; Steps not mentioned.
- E3 BLOCKED row: "Spec is wrong → STOP".
- E5: reviewer receives the brief, `## Global Constraints`, `## Cross-Task Contracts`.
- S3: passes `SPEC_DOC: <spec path>`; no `PLAN_DOC`. Critique log always beside the spec; the bare-plan branch deleted.
- Every remaining "plan" refers to nothing; `docs/foureyes/plans` absent.

**Verify:** `f=skills/foureyes-build/SKILL.md; grep -q 'Has Astra ever read this spec' $f && grep -q "'^## spec '" $f && grep -q 'Cross-Task Contracts' $f && grep -q 'has-steps' $f && ! grep -q 'PLAN_DOC\|foureyes/plans\|Steps' $f && grep -q 'SPEC_DOC' $f && echo OK`

```json:metadata
{"files": ["skills/foureyes-build/SKILL.md"], "modelTier": "standard", "verifyCommand": "f=skills/foureyes-build/SKILL.md; grep -q 'Has Astra ever read this spec' $f && grep -q \"'^## spec '\" $f && grep -q 'Cross-Task Contracts' $f && grep -q 'has-steps' $f && ! grep -q 'PLAN_DOC\\|foureyes/plans\\|Steps' $f && grep -q 'SPEC_DOC' $f && echo OK", "acceptanceCriteria": ["argument and classifier are spec-based, old plans still run", "E2 and E5 forward contracts and constraints, never Steps", "S3 and the critique log use the spec only"]}
```

### Task 6: plan-viz: has-steps check, drop splicer and Steps card

**Goal:** Adjust `plan-viz.mjs` and its tests for a spec that owns its tasks.

**Files:**
- Modify: `skills/foureyes-brainstorm/lib/plan-viz.mjs`
- Modify: `skills/foureyes-brainstorm/lib/plan-viz.test.mjs`

**Acceptance Criteria:**
- Header comment describes rendering a spec's `## Tasks` section; usage `node plan-viz.mjs <spec.md> [--json]`.
- `spliceTasks` and `taskRanges` removed; their seven tests removed ("replaces only the named task…" through "taskRanges and parsePlanMarkdown agree…").
- `detectProblems` pushes `{kind: 'has-steps', task, detail: 'task carries a **Steps:** field — the pipeline never forwards it'}` when `/^\*\*Steps:\*\*/m` matches the task's description. One new test: a description with a Steps line flags `has-steps`; one without does not.
- `renderHTML`: the `Steps` card block removed; title fallback `'Tasks'`; the header shows the document path; the `Spec:` line handling stays tolerant (present or absent, no error). `splitFields` may keep recognising `steps` as a key; nothing renders it.
- All other exports, check codes, `FENCE_KEYS`, drift detection and the CLI contract unchanged; `node --test` on the test file passes.

**Verify:** `node --test skills/foureyes-brainstorm/lib/plan-viz.test.mjs && ! grep -q 'spliceTasks\|taskRanges' skills/foureyes-brainstorm/lib/plan-viz.mjs && grep -q "has-steps" skills/foureyes-brainstorm/lib/plan-viz.mjs && echo OK`

```json:metadata
{"files": ["skills/foureyes-brainstorm/lib/plan-viz.mjs", "skills/foureyes-brainstorm/lib/plan-viz.test.mjs"], "modelTier": "standard", "verifyCommand": "node --test skills/foureyes-brainstorm/lib/plan-viz.test.mjs && ! grep -q 'spliceTasks\\|taskRanges' skills/foureyes-brainstorm/lib/plan-viz.mjs && grep -q \"has-steps\" skills/foureyes-brainstorm/lib/plan-viz.mjs && echo OK", "acceptanceCriteria": ["has-steps detected on the description with a test", "spliceTasks/taskRanges and their tests removed", "Steps card gone, other exports and checks unchanged"]}
```

### Task 7: Stats, ledger, review and ledger skills

**Goal:** Keep the stats and ledger scripts reading old and new artifacts, drop the plan critic from the Codex-only list, and update the two skills that mention plans.

**Files:**
- Modify: `scripts/pipeline-stats.mjs`
- Modify: `scripts/pipeline-stats.test.mjs`
- Modify: `scripts/astra-ledger.mjs`
- Modify: `skills/foureyes-ledger/SKILL.md`
- Modify: `skills/foureyes-review/SKILL.md`

**Acceptance Criteria:**
- `pipeline-stats.mjs`: `PLAN_DIRS` becomes `['foureyes/specs', 'superpowers/specs', 'foureyes/plans', 'superpowers/plans']`; `CODEX_ONLY = ['foureyes-spec-critic', 'foureyes-code-critic']`; the "PLANS" report heading and the not-found message say "specs (and legacy plans)"; imports from plan-viz unchanged. `pipeline-stats.test.mjs`: the `CODEX_ONLY` assertion updated; `summarisePlans` tests still pass (they write to a plans dir, which is still scanned).
- `astra-ledger.mjs`: `SEAMS` unchanged; a one-line comment above it says `plan` is retained to parse logs written before 2026-09-23. `astra-ledger.test.mjs` untouched and passing.
- `skills/foureyes-ledger/SKILL.md`: "plans on disk" → "specs on disk (task sections)"; "plans are tagged frontier" → "tasks are tagged frontier"; the critic list drops `plan`.
- `skills/foureyes-review/SKILL.md` Step 2: context is the newest of `docs/foureyes/specs/*.md` only.

**Verify:** `node --test scripts/pipeline-stats.test.mjs scripts/astra-ledger.test.mjs && grep -q "foureyes/specs" scripts/pipeline-stats.mjs && ! grep -q 'plan-critic' scripts/pipeline-stats.mjs && ! grep -q 'foureyes/plans' skills/foureyes-review/SKILL.md && echo OK`

```json:metadata
{"files": ["scripts/pipeline-stats.mjs", "scripts/pipeline-stats.test.mjs", "scripts/astra-ledger.mjs", "skills/foureyes-ledger/SKILL.md", "skills/foureyes-review/SKILL.md"], "modelTier": "standard", "verifyCommand": "node --test scripts/pipeline-stats.test.mjs scripts/astra-ledger.test.mjs && grep -q \"foureyes/specs\" scripts/pipeline-stats.mjs && ! grep -q 'plan-critic' scripts/pipeline-stats.mjs && ! grep -q 'foureyes/plans' skills/foureyes-review/SKILL.md && echo OK", "acceptanceCriteria": ["stats scan specs and legacy plans, CODEX_ONLY drops plan-critic, tests pass", "ledger SEAMS kept with a comment", "ledger and review skills no longer describe plans"]}
```

### Task 8: Prose contracts and wrapper tests for the new shape

**Goal:** Rewrite the assertions in `tests/prose-contracts.test.sh` and `tests/codex-critic.test.sh` that encode the plan, and add the ones that pin the new contract.

**Files:**
- Modify: `tests/prose-contracts.test.sh`
- Modify: `tests/codex-critic.test.sh`

**Acceptance Criteria:**
- Removed or rewritten: test 3's loop drops `plan-critic`; test 4 loops over `spec` only; 6a/6b loop `spec code`; 14a–c grep "Has Astra ever read this spec" and `'^## spec '`; 21a, 21b, 21f, 22a–22j, 25a–25f deleted; 21c/21d/21e/21g kept (they are harness facts); 24a/b loop `spec code`; 27f loops `spec code approach investigate`; test 9's read-only agent list drops `plan-critic`.
- Added, using the existing `check`/`has` helpers: (a) no skill calls `"$WRAP" plan`; (b) the drafter's file contains no `**Steps:**` and does contain `## Cross-Task Contracts`, `## Global Constraints`, `## Tasks`, "declarations only", "scaffold"; (c) the drafter contains none of `TASKS-PER-PART`, `DRAFT: part`, `REVISION: sections`, `CHANGED-TASKS`; (d) the spec critic names "Cross-Task Contracts", "scaffold", "coverage"; (e) build E2 names "Cross-Task Contracts" and "Global Constraints" and the build file contains no `Steps`; (f) both implementers name "Cross-Task Contracts" and contain no `Steps`; (g) plan-viz exports no `spliceTasks`; (h) `agents/foureyes-plan-critic.md` does not exist.
- `tests/codex-critic.test.sh`: the round-budget loop becomes `for m in spec code`.
- Comments explaining deleted groups are removed with them; the file header is unchanged.
- At the join (all wave-1 tasks present), `bash tests/run.sh` exits 0.

**Verify:** `bash tests/run.sh`

```json:metadata
{"files": ["tests/prose-contracts.test.sh", "tests/codex-critic.test.sh"], "modelTier": "standard", "verifyCommand": "bash tests/run.sh", "acceptanceCriteria": ["plan-encoding assertions removed or rewritten as listed", "eight new contract assertions added", "codex-critic budget loop is spec code", "full suite green at the join"]}
```

### Task 9: README and site describe the new pipeline

**Goal:** Update `README.md` and `docs/index.html` so every description of the pipeline matches: one spec with tasks, critiqued twice, built directly.

**Files:**
- Modify: `README.md`
- Modify: `docs/index.html`

**Acceptance Criteria:**
- README: intro and table say Claude writes specs and code, Codex reads every spec and diff; the mermaid graph drops the "Claude writes the plan" and "Codex critiques it" nodes so the spec critique feeds the stop/build node; the brainstorm section says the spec ends with the task list and is critiqued twice; build examples use a spec path under `docs/foureyes/specs/`; Codex call cost becomes "up to three: one approach proposal, then up to two reviews of the spec; build adds up to two more"; the tree shows `specs/` carrying the `.tasks.json` and notes `plans/` as legacy; the ledger sample table drops the `plan` row; "all forty steps" count corrected to the real count after the edit.
- `docs/index.html`: hero copy "designs and writes", "every spec and diff"; brainstorm CMD steps: 4 becomes "The spec is rendered as a page" and 5 "Stop"; build CMD: arg `<spec or idea>`, step 0 "A spec file with its task list beside it", 0.5 "Check the spec, and offer a review", B "No spec? Brainstorm first", E1 "One task per spec entry", S3 "spec conformance"; review step "The most recent spec locally"; ledger step 2 "Read the specs and the dispatch history"; the roster row for `foureyes-plan-critic` removed.
- No other content changed.

**Verify:** `! grep -q 'plan-critic' docs/index.html && ! grep -q 'Claude writes the plan' README.md docs/index.html && grep -q 'foureyes/specs/' README.md && ! grep -q 'foureyes-build docs/foureyes/plans' README.md && echo OK`

```json:metadata
{"files": ["README.md", "docs/index.html"], "modelTier": "standard", "verifyCommand": "! grep -q 'plan-critic' docs/index.html && ! grep -q 'Claude writes the plan' README.md docs/index.html && grep -q 'foureyes/specs/' README.md && ! grep -q 'foureyes-build docs/foureyes/plans' README.md && echo OK", "acceptanceCriteria": ["README pipeline description, graph, examples, cost and tree updated", "site CMD arrays and roster updated", "nothing else changed"]}
```
