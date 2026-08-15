---
name: foureyes-build
description: >
  Execute an implementation plan. Given a plan path, go straight to execution —
  the plan is the contract, no approval to verify. Without a plan, run
  foureyes-brainstorm inline (Fable drafts, Sol critiques) and continue into
  execution. Waves of concurrent subagents, per-task model routing via
  modelTier, then Sol reviews the diff. Flags: --skip-critics, --serial.
---

# foureyes-build — execute the plan you were handed

You are the COORDINATOR. If the user hands you a plan, that plan is done —
execute it. There is nothing to verify: no approval marker, no sidecar, no
hashes. Reviewing the plan was `foureyes-brainstorm`'s job and the user's;
your job starts after that.

## Announce
"Using foureyes-build to execute <plan> (Sol reviews the diff at the end)."

## Codex critic — how to run the code seam
```bash
WRAP=$(ls -d ~/.claude/plugins/cache/*/foureyes/*/scripts/codex-critic.sh 2>/dev/null | sort -V | tail -1)
VIZ=$(ls -d ~/.claude/plugins/cache/*/foureyes/*/skills/foureyes-brainstorm/lib/plan-viz.mjs 2>/dev/null | sort -V | tail -1)
LEDGER=$(ls -d ~/.claude/plugins/cache/*/foureyes/*/scripts/sol-ledger.mjs 2>/dev/null | sort -V | tail -1)
```
- Read-only: the wrapper runs `codex exec -s read-only`. All FIXING stays with
  the coordinator.
- Round budget: pass `CODEX_CRITIC_ROUND` as a literal positive integer (`1`,
  then `2`) — anything else exits 2 with `VERDICT: NEEDS-HUMAN`. Sol reviews at
  most `CODEX_CRITIC_MAX_ROUNDS` (default 2) times, then you fix what you can
  and finish. Read the trailing `GATE:` line; never reset the round to buy
  passes. Read stderr too: it warns when findings were in a format the wrapper
  could not count, meaning you must read the verdict body yourself.
- Every round runs at `high` effort. Do not set `CODEX_CRITIC_EFFORT` yourself. Sol also runs at the `fast` service tier by default (priority routing — same thinking, sooner, more per token); a user who wants to stop paying for that exports `CODEX_CRITIC_SPEED=normal`. Never set either yourself.
- **Pass the Bash tool's `timeout: 600000`** (10 min, the tool maximum) on every
  `"$WRAP"` call. The default is 120s and a `high`-effort review of a real diff
  routinely exceeds it — and a timeout arrives as a tool error with no `VERDICT`
  and no `GATE:` line, so without this the review looks like it merely failed.
  If a call really does hit 10 minutes, say so and offer `--skip-critics`.
  Run it with the Bash tool's own `run_in_background`, never by appending `&` inside
  a backgrounded call — the child dies with the outer shell, leaving an empty output
  file that looks like a critic which returned nothing.
- If either resolution above prints nothing, that is a broken install, not a
  failed critic: STOP and say the plugin path did not resolve. Note that shell
  state does not survive between Bash calls — these are paths you READ once and
  PASTE as literals; an empty `"$WRAP"` in a LATER call is your own bookkeeping
  slip, not a broken install, and reporting it as one sends the user to fix the
  wrong thing.
- Requires the `codex` CLI installed + authenticated (`codex login`).

## Inputs
- Optional plan path (any phrasing — detection is artifact-driven, below).
- `--skip-critics` — Sol never runs, at either stage. Say plainly what that
  costs when it is passed: the per-task reviewer at E5 is a Claude subagent, so
  with Sol switched off **nothing in the run crosses model families** — the whole
  premise of this plugin is off, and E5 is the only gate left standing.
- `--serial` — opt out of wave parallelism.

## Parallelism — one checkout, one run
Parallel builds in a single checkout are FORBIDDEN at the git level: sessions
share one working tree, so one session's `git checkout` lands the other's
commits on a foreign branch (observed live). A solo run may use a plain branch;
parallel runs MUST each live in their own git worktree.

## Step 0 — Classify the argument (artifact-driven, never phrasing)
Extract a file path from the argument if present.
```
<X>.md with an <X>.md.tasks.json sibling  →  PLAN   (Step 0.5) — brainstorm is NEVER called
anything else, or no path                 →  BRIEF  (Step B)
```
Announce which branch you took in one line, so a wrong classification is caught
immediately.

## Step 0.5 — Read the plan before executing it (PLAN branch only)
```bash
node "$VIZ" "<plan path>"    # writes the HTML page, prints structural problems on stderr
```
A plan handed straight to build may never have been through brainstorm, so
nothing has ever checked it. This is not a gate — it is looking before you act:
- `cycle` / unschedulable → STOP. Those tasks cannot be ordered, so execution
  would stall or run them in a wrong order. Show the user and stop.
- `plan-tasks-order-mismatch` / `-count-mismatch` / `-fence-drift` → STOP. The
  markdown and the `.tasks.json` disagree, and you are about to execute the
  JSON. Show the user both versions and let them say which is right.
- `unknown-key` → the fence sets a field you never read (`wave`, `noCommit`,
  `serial`…). Report it and IGNORE the field — never honour one, or the plan and
  the executor disagree about which contract is in force. In particular `wave` is
  advisory: you compute waves yourself from `blockedBy` plus file-disjointness.
- `no-verify` / `no-criteria` / `bad-tier` / `file-overlap` → report them and
  continue; the user decides. `file-overlap` in particular means those tasks
  must not share a wave — serialize them at Step E.
If the file cannot be parsed at all, stop and say so; do not guess at a repair.

**Has Sol ever read this plan?** A plan that came from brainstorm has a sibling
critique log with a `plan` seam entry; one written by hand, by another tool, or
by an older version has none:
```bash
ls docs/foureyes/specs/*-critique.md 2>/dev/null | xargs grep -l '^## plan ' 2>/dev/null
```
If nothing matches this plan's topic slug, say so in one line and **ask** with a
single `AskUserQuestion` — never decide it yourself, and never invoke brainstorm:

| option | what happens |
|---|---|
| **Critique it first** (recommended) | run the `plan` seam once at `ROUND=1`, show findings, then continue |
| Execute as-is | straight to E0 |
| Stop | they will run brainstorm themselves |

Recommended because it is one ~5-minute call against a plan about to spend real
commits, and because every other Sol pass in this skill happens *after* the code
exists. But it is their call: an uncritiqued plan is a normal thing to hand over
deliberately, and forcing a critic on it would make `foureyes-build <plan>`
slower than the user asked for. If they pick it, log the round exactly as Step S3
does below.

## Step B — No plan: brainstorm inline, then execute
Invoke Skill `foureyes:foureyes-brainstorm` with `--continue` and the
brief (adding `--skip-critics` if it was passed to you). It does NOT interview
the user: Fable and Sol propose approaches concurrently, the user picks once from
the merged menu (or not at all, when one option survives), then Fable drafts the
spec and plan while Sol critiques each. It generates the HTML and returns the plan
path without stopping. Then go to Step E.

## Step E — Execute (waves, then a per-task review)
You own the loop: task state, dispatch, review, and every commit. Nothing here
is delegated to another skill.

**E0 — Establish the workspace before anything writes.** Nothing else here is
safe until this holds:
```bash
git rev-parse --abbrev-ref HEAD    # → <parent-branch>: RECORD it, Step F needs it
git status --porcelain             # MUST be empty
git rev-parse --git-dir            # → <gitdir>
```
- **A dirty tree stops the run.** Path-scoped commits cannot tell your
  uncommitted edit from an implementer's work, so a pre-existing change in any
  task's `files` gets committed under that task's message. Show `git status` and
  stop; let the user stash or commit.
- **Never implement on the default branch.** If `<parent-branch>` is `main`,
  `master`, or the repo's default, create a feature branch and say so. Step F's
  merge option is meaningless when parent and working branch are the same.
- Run artifacts go under `<gitdir>/foureyes-build/<short-sha>/` — inside the git
  directory, so they are untracked by construction in ANY consumer repo. Never
  write them into the worktree: this plugin ships no `.gitignore` rule, so a
  worktree path would show up as a stray file in E4's contract check and could be
  swept into a commit.
```bash
git merge-base <parent-branch> HEAD                 # → BASE_SHA, before execution
mkdir -p "<gitdir>/foureyes-build/$(git rev-parse --short HEAD)"   # → RUN
```
**Shell state does not survive between Bash calls.** Every value above and below —
`<parent-branch>`, `BASE_SHA`, `RUN`, each task's base and head — is something you
READ from output and PASTE into later commands as a literal. Writing `FOO=$(…)` in
one call and `"$FOO"` in the next gets you an empty string, which here means a
command that silently operates on the wrong range. The `<placeholder>` style used
throughout this skill is the convention; follow it.

**E1 — Create the task list, once.** Read `<plan>.md.tasks.json` and `TaskCreate`
one native task per entry, carrying its description verbatim, then wire
`addBlockedBy` from the JSON's `blockedBy`. This is the ONLY place tasks are
created; a second creator only makes duplicates.

**Skip any entry already marked `"status": "completed"`** — that is a resumed run,
and E5 wrote that status so the work is not repeated. Say in one line which tasks
you skipped. Two things this breaks unless you handle them:
- `blockedBy` holds **0-based indices into the full JSON list**, not native task
  ids. Keep an explicit index→id map as you create tasks, and translate. A
  dependency on a skipped (completed) task is already satisfied — drop it rather
  than pointing it at nothing.
- **Resume granularity is one whole task.** Only `completed` is persisted; a task
  interrupted mid-dispatch or mid-review comes back as pending and would be
  re-run on top of its own committed work. Before re-dispatching any incomplete
  task, check whether its `files` already carry committed changes
  (`git log --oneline -- <task's files>`); if they do, show the user and ask
  whether to re-run or mark it done. Never silently re-implement over a partial.

**E2 — Dispatch a wave** (one task at a time under `--serial`).
Record `git rev-parse HEAD` as `<wave-head>` immediately BEFORE dispatching — E4
needs it to detect an implementer that committed. Mark every task of the wave
`in_progress`, then send ALL of them in ONE message as parallel `Agent` calls:
- `subagent_type` per the table below, and **always pass `model` explicitly** —
  never rely on frontmatter resolution, which would silently inherit the session's
  most expensive model. Resolve it from the task's `modelTier`:

  | `modelTier` | `subagent_type` | `model` you pass | effort (pinned in that agent) |
  |---|---|---|---|
  | `mechanical` | `foureyes-implementer` | `sonnet` | medium |
  | `standard` | `foureyes-implementer` | `sonnet` | medium |
  | `frontier` | `foureyes-implementer-frontier` | `opus` | high |

  **Effort is not a dispatch parameter — the Agent tool has none.** It is pinned in
  the agent's frontmatter, which is why frontier gets its own subagent type rather
  than the same one with a different model. The two files' bodies are byte-identical
  and a test enforces it; edit both or neither.

  This table previously listed an effort column that nothing applied: every Claude
  subagent inherited the session instead. Measured across 114 transcripts, that was
  `xhigh` on 99.7% of turns — including Sonnet implementers, where high effort buys
  Opus-class cost at lower fidelity.

  A task's `"model"` pin overrides its tier. Nothing else does: this table and the
  agents' pinned effort are the whole contract. There is deliberately no external
  routing file, because effort lives in agent frontmatter where a JSON file cannot
  reach it — such a file could change the model but not the effort, silently
  producing combinations nobody chose.
- The `prompt` is the assignment: the task's Goal / Files / Acceptance Criteria /
  Verify / Steps verbatim, plus the plan's `## Global Constraints` and enough
  scene-setting to place the task. **Never tell an implementer to read the plan
  file** — you already hold the text, and reading it burns their context on
  everything that is not their task.
- A wave contains only tasks whose `files` lists are disjoint and which are not in
  each other's `blockedBy` chain. `file-overlap` from Step 0.5 means those tasks
  must not share a wave. Uncertain overlap → serialize.

**E3 — Handle each status** (never force an unchanged retry — if the implementer
says it is stuck, something has to change):

| status | what you do |
|---|---|
| `DONE` | go to E4 |
| `DONE_WITH_CONCERNS` | read the concerns. Correctness or scope → resolve before review. Observation ("this file is getting large") → note it and review |
| `NEEDS_CONTEXT` | supply what was missing, re-dispatch the same task |
| `BLOCKED` | context problem → re-dispatch with more context. Needs more reasoning → re-dispatch one tier up. Too large → split the task. Plan is wrong → STOP and surface to the user |

Statuses are handled per task, but you handle them at the JOIN — let the whole
wave return first. Stopping the moment one task reports `BLOCKED` abandons
siblings still writing into the same tree, which leaves the checkout in a state
nobody chose.

**E4 — Commit at the join, one commit per task.** Implementers never commit; they
share one index. Because the wave is file-disjoint you can separate their work by
path — commit each task's own `files` and nothing else. Capture the base BEFORE
committing, or the range is wrong:
```bash
git rev-parse HEAD                                  # → <base> for this task
git add <task's files> && git commit -m "<task subject>"
git rev-parse HEAD                                  # → <head> for this task
{ git log --oneline <base>..<head>
  git diff --stat <base>..<head> -- <task's files>
  git diff -U15   <base>..<head> -- <task's files>; } > <RUN>/task-<N>.diff
```
**Scope every task diff by its paths, not by the range alone.** A bare range
stops being that task's change the moment anything else commits inside it — and
at E5 something does: task 1's fix commit lands *after* task 2's commit, so
`<task-1 base>..<new head>` would hand the reviewer task 2's work as well.
Path-scoping is exactly the disjointness that made the wave legal, reused.

**A task whose `files` is `[]` is a verification gate: it produces no commit, and
that is correct.** Its deliverable is evidence, not code. Skip the commit and the
diff for it entirely and assert the opposite — `git status` must show NOTHING from
that task, because a gate that wrote a file did something nobody asked for.

Without this exemption every gate has to invent an artifact just to satisfy the
commit rule, and the invented file then breaks whatever the spec said about which
files the change touches. (`"files": []` is
`superpowers-extended-cc`'s convention for exactly this case — see its user-gate
tasks in `skills/shared/task-format-reference.md`.)

For every task with a NONEMPTY `files` list: if `git commit` reports nothing to
commit, that task produced no changes. Do not shrug it through with an empty diff —
surface it: either the implementer did nothing or its `files` list is wrong, and
both are defects.
Two contract checks belong here, because only you can see them. Run BOTH before
staging anything:
```bash
git rev-parse HEAD        # MUST still equal <wave-head> from E2
git status --porcelain    # paths MUST fall inside the union of the wave's files
```
- **HEAD moved** → an implementer committed. That is the index race this design
  exists to prevent, and checking after your own first commit would be too late to
  see it. Stop and show the user; do not build further on top of it.
- **A path outside the union** → an implementer wrote where it was not allowed.
  Surface it before committing — never sweep a stray path into someone's commit.

**E5 — Review each task.** Dispatch `subagent_type: foureyes-task-reviewer`,
passing `model: sonnet` explicitly (its effort is pinned medium in frontmatter), plus the task brief, the
plan's `## Global Constraints`, the implementer's report, and
`DIFF_FILE=<RUN>/task-<N>.diff` with that task's `<base>`/`<head>`. The diff reaches the
reviewer as a file so it never enters your context. Reviews of different tasks are
independent — dispatch them in one message.
**A `files: []` gate has no diff, so it gets no reviewer.** `foureyes-task-reviewer`'s
entire contract is "read this diff", and reviewing a checker with a checker is
recursion for its own sake. YOU check its evidence instead: every entry in
`acceptanceCriteria` must have a matching `AC: <criterion> — PROVEN BY <command or
output excerpt>` line, and the evidence must be a command, an output excerpt, or a
`file:line` — never a restatement. A criterion with no line, or a line that merely
asserts the criterion back at you, fails the gate. Then mark it completed and sync
`.tasks.json` as usual.

For every other task, the reviewer returns **two** verdicts and both must clear. A task passes only on
`Spec Compliance: ✅` **and** `Task quality: Approved`. Anything else — spec issues
with clean code, a missing verdict, or a `⚠️ cannot verify` you have not resolved
yourself — is `Needs fixes`. Treating quality-approved as done is how a task ships
with a requirement missing, and under `--skip-critics` this is the last gate there
is.
- Both clear → `TaskUpdate` the task to completed, then sync `.tasks.json`: set
  that task's `"status": "completed"` and refresh `"lastUpdated"`. Without the
  sync a later session resumes and re-runs finished work.
- `Needs fixes` → re-dispatch the SAME task to an implementer with the findings
  verbatim. **You commit the fix too** — the implementer still must not — then
  extend the range and rebuild the diff before re-reviewing:
  ```bash
  git add <task's files> && git commit -m "<task subject>: review fixes"
  git rev-parse HEAD                       # → new <head>; <base> stays put
  ```
  Rebuild `<RUN>/task-<N>.diff` with the same path-scoped commands and re-review
  against it. **MAX 2 fix rounds**, then record what is open and move on; a
  reviewer that re-reads always finds one more thing. The same rule covers barrier
  repairs at E6: the coordinator commits every fix, and any range the reviewer or
  Sol will see is rebuilt afterwards.

**E6 — Barrier after each wave**: codegen/regen, build, full test run. Failures
go back to the owning task's implementer; MAX 2 repair rounds, then surface.
Inherently serial tasks stay OUTSIDE waves.

Codegen and formatters write files that belong to no task, so nothing above
commits them. Commit that output yourself — otherwise the tree is dirty when Step
S3 captures its range, Sol reviews a diff missing the generated files, and Step F
reports uncommitted work nobody can explain:
```bash
git status --porcelain            # read it; stage the generated paths BY NAME
git add <the generated paths> && git commit -m "wave <n>: codegen"
```
Never `git add -A` here. It stages whatever else happens to be lying around —
including this run's own artifacts if they ever land in the worktree — and you
have no way to explain the result afterwards.

**A barrier repair reopens its task.** Tasks were reviewed and marked completed at
E5, so a repair committed now has been through no quality lens at all — and
`foureyes-code-critic` deliberately defers general quality to the per-task
reviewer, so nothing downstream catches it either. After any repair: reopen the
owning task, rebuild its path-scoped diff through the repair commit, re-run
`foureyes-task-reviewer`, and only then mark it completed again. The 2-round fix
budget applies here too.

When every task is complete, `git rev-parse HEAD` → `HEAD_SHA` for Step S3.

## Step S3 — Sol reviews the diff (≤2 rounds, then finish)
Skip entirely under `--skip-critics`.
```bash
printf '%s\n' "WORKTREE: <path>" "BASE_SHA: <sha>" "HEAD_SHA: <sha>" \
  "PLAN_DOC: <plan path>" "SPEC_DOC: <spec path>" "" "<re-review: what changed>" \
  | CODEX_CRITIC_ROUND=<1,2> "$WRAP" code
```
| `GATE:` | What you do |
|---|---|
| `pass` | Step F. |
| `revise` | Address Critical/Important (coordinator or a fix subagent), commit, update `HEAD_SHA`, re-run at `ROUND+1`. |
| `final` | Last review. Fix what you can, commit, then go to Step F and LIST what is still open. |
| `conclude` | Budget spent, no call made. Go to Step F. |
| `needs-human` | Surface stderr and STOP. |

**Verify each finding is factually true before fixing it.** Open the cited code and
confirm the claim; a critic reading cold can cite a line that does not exist or
describe the diff as it was a round ago. Record a false one as `rejected: <what
you checked>` and do not spend a fix on it. Facts only — never reject a finding
because you disagree with its severity or think the code is fine.

**Log every finding and its disposition**, as each round closes, appending to the
plan's sibling `docs/foureyes/specs/YYYY-MM-DD-<topic>-critique.md` — the same
file brainstorm's seams write, so one feature keeps one log from approach through
merge. Same grammar, with `code` as the seam:
```
## code · round <n> · <YYYY-MM-DD> · <n>s
- [<Severity>] <fixed|rejected|intentional|open> — <the finding, one line>
```
The trailing `<n>s` is the round's wall clock, copied from the wrapper's own
stderr line (`codex-critic: code r1 took 412s`). It times itself; never measure
by hand, and omit the field rather than guess if the line is missing.
A clean round still gets its header and a single `- (none)` line. If this plan
has no spec path — handed over bare — write the log beside the plan instead; a
run whose findings went nowhere is the one case the ledger cannot report on.
`node "$LEDGER" docs/foureyes/specs` reads them all back.

**Any fix here invalidates the barrier.** E6's build and test run happened before
these edits existed, so going straight to Step F would report a green suite for
code that has since changed. After the last `revise`/`final` fix, re-run the FULL
barrier — build plus the complete test suite — and carry its real result forward.
If it now fails, that is a finding, not a formality: fix and re-run rather than
reporting a stale pass.

## Step F — Finish
Report what landed — branch, commits, and the verification evidence: the exact
command you ran, its exit status, and the failure count, from the run that
included the LAST change. Carry each task's acceptance criteria through as
`AC: <criterion> — PROVEN BY <evidence>`, taken from the implementer reports the
reviewer accepted. Any criterion that reached the end unproven gets listed as
such; shipping it silently is how "done" stops meaning anything. "Tests pass" without the command that proves it is the
claim, not the evidence. Report this run's Sol tally in one line — `Sol: <n>
raised, <n> fixed, <n> rejected, <n> intentional, <n> open` — counted from the
lines you just wrote, and name the critique log's path. Then ask what to do with it via `AskUserQuestion`:
**open a PR**, **merge to the parent branch**, or **leave the branch as is**. Do exactly what they pick and nothing more. Never
merge or push without being asked; the work is theirs to place.
If Step S3 ended on `final`, repeat Sol's residual findings to the user first —
they are shipping with those open and should hear it from you, not discover it.

## VERDICT parser
- VERDICT token = the word after `^VERDICT:`. Counts are authoritative:
  `^- \[Critical\]` and `^- \[Important\]` lines.
- The wrapper's trailing `GATE:` line already applies this rule — read it and
  act. You parse the findings themselves only to relay and fix them.
- `NEEDS-HUMAN` is never a pass: surface stderr, stop the seam, fix Codex.
