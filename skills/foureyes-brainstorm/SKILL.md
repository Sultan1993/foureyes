---
name: foureyes-brainstorm
description: >
  Write a detailed, executable plan with Fable and Sol, then STOP. Fable and Sol
  propose approaches independently and you pick from the merged menu; then Fable
  (the foureyes-drafter subagent) authors the design spec and the implementation
  plan while Sol (Codex) critiques each one at most twice, and Fable concludes.
  Produces the spec, the plan, its .tasks.json, and an HTML review page. You read
  it and hand it to foureyes-build yourself. Flags: --continue (internal, used
  by foureyes-build: suppress the hard stop), --skip-critics (Fable drafts
  alone, Sol never runs).
---

# foureyes-brainstorm — two models propose, Fable drafts, Sol sharpens

You are the COORDINATOR. You do not author: Fable (the `foureyes-drafter`
subagent) writes every document, and Sol critiques through `codex-critic.sh`.

You DO arbitrate, in exactly one place — Step 1, where you pool two independent
approach sets into one auditable list and rank it into the menu the user picks
from. Arbitrating is deduping, ranking, and capping what the models returned.
Transcribing both sets into one file is squarely your job; deciding what belongs
in the list is not:

> **You may never put an approach in the menu that neither proposer named.**

If you think of a better approach, it goes back to a proposer or it does not
happen. Without that line, "arbitrate" becomes "design" within a week.

This command GATES NOTHING. Its output is a plan document. Handing that plan to
`foureyes-build` is the user's decision — there is no approval to verify, no
marker, no hash. If the user hands over a plan, it is done by definition.

## Announce
"Using foureyes-brainstorm: Fable and Sol propose approaches independently, you
pick once (or not at all), then Fable drafts and Sol critiques twice."

## The loop — identical at both DOC seams

Step 1 (approach) is NOT one of these loops: one dispatch each, concurrent, no
rounds, no budget, no gate. Neither model revises an approach set — the user
picks and the pipeline moves on.

```
Fable drafts → Sol → Fable revises → Sol → Fable revises → DONE
```

Two Sol passes per seam, then **Fable has the last word**. A critic that
re-reads a document always finds one more `[Important]`, so this never
converges on its own — the budget is the whole point. Pass
`CODEX_CRITIC_ROUND` on every seam call and act on the trailing `GATE:` line:

| `GATE:` | What you do |
|---|---|
| `pass` | Clean — the critic said `pass` AND no findings parsed. Move on. |
| `revise` | Show findings to the user, dispatch Fable to revise, re-run at `ROUND+1`. |
| `final` | Last critic pass. Fable revises once, addressing what it can. Then MOVE ON. |
| `conclude` | Budget already spent; no Codex call was made. Move on immediately. |
| `needs-human` | Surface stderr and STOP — a broken Codex is not a clean verdict. |

Never re-run a seam after `final` or `conclude`. Never reset `CODEX_CRITIC_ROUND`
to 1 to buy extra passes. If the user wants another round they will ask; that is
their call, not yours.

**Check each finding is FACTUALLY true before you pass it on.** A critic reading
cold gets things wrong: it cites a section that does not exist, claims an API is
missing when it is there, or describes the document as it was a round ago. Open
the artifact and confirm the claim before spending a revision on it. A finding
that fails this check is recorded as `rejected: <what you checked, what you
found>` and NOT sent to the drafter — a revision made against a false premise
makes the document worse, and the round is spent either way.

This is narrow, and it is not a licence to argue. You verify **facts**: does the
cited text exist, does it say what the critic says, does the named capability
behave that way (Context7 → WebSearch). You never reject a finding because you
disagree with it, dislike its severity, or think the design is fine —
**that** would be arguing on Fable's behalf, which remains forbidden. Judgment
about the design belongs to the drafter, who answers every surviving finding by
fixing it or stating why the design is intentional.

## The critique log — record what became of every finding

As each round closes, before moving on, append to
`docs/foureyes/specs/YYYY-MM-DD-<topic>-critique.md` — the SAME slug as the
approaches file and the spec, so one feature has one log:

```
## <seam> · round <n> · <YYYY-MM-DD> · <n>s
- [<Severity>] <disposition> — <the finding, one line>
```

The trailing `<n>s` is the round's wall clock, copied from the wrapper's own
stderr line (`codex-critic: spec r1 took 287s`) — it times itself, so you never
measure anything by hand. **A hit rate is not a decision without it**: 72%
acted-on is worth having at ninety seconds a round and probably is not at nine.
If the line is absent, omit the field rather than guessing; the reader treats
duration as optional.

`<seam>` is `spec` or `plan`. `<disposition>` is exactly one of:

| | means |
|---|---|
| `fixed` | the drafter changed the artifact |
| `rejected` | you fact-checked it and it was false — say what you checked |
| `intentional` | the drafter kept the design and said why |
| `open` | the seam ended on `final`/`conclude` with this unaddressed |

The disposition LEADS the em-dash because findings contain em-dashes of their
own; a trailing one cannot be parsed back. A round Sol ran clean still gets its
header and a single `- (none)` line — "Sol found nothing" is a result, and a
missing header is indistinguishable from a seam that never ran.

`node "$LEDGER" docs/foureyes/specs` reads these back and reports, per seam,
how often Sol was acted on versus factually wrong. Without the log that number
does not exist anywhere: every seam costs ~5 minutes at `high` effort, and
nothing today records whether any of them ever earned it. This is the only
instrument that can retire a seam.

`CODEX_CRITIC_ROUND` must be a literal positive integer — `1`, then `2`. The
wrapper exits 2 with `VERDICT: NEEDS-HUMAN` on anything else (including the
`<1,2>` placeholder below, copied verbatim). Also read stderr on every call: it
may warn that the critic's findings were in a format the wrapper cannot count,
which means you must read the verdict body yourself rather than trust the gate.

## Step 0 — Preflight
1. `[ -z "${CLAUDE_CODE_SUBAGENT_MODEL:-}" ] || [ "$CLAUDE_CODE_SUBAGENT_MODEL" = "fable" ]`
   — if set to anything else, STOP and tell the user: that env var outranks
   per-dispatch models, so the Fable-authorship guarantee cannot hold. Do not
   silently draft on the wrong model.
   Note which state you are in, because it decides whether item 5 can work: that
   env var outranks the Agent tool's `model` parameter too. So if it is set to
   `fable` and Fable then turns out to be unavailable, the Opus fallback CANNOT
   take effect — STOP and tell the user to unset `CLAUDE_CODE_SUBAGENT_MODEL`
   before retrying. Only promise the fallback when the variable is unset.
2. Resolve the wrapper and the viz:
   ```bash
   WRAP=$(ls -d ~/.claude/plugins/cache/*/foureyes/*/scripts/codex-critic.sh 2>/dev/null | sort -V | tail -1)
   VIZ=$(ls -d ~/.claude/plugins/cache/*/foureyes/*/skills/foureyes-brainstorm/lib/plan-viz.mjs 2>/dev/null | sort -V | tail -1)
   LEDGER=$(ls -d ~/.claude/plugins/cache/*/foureyes/*/scripts/sol-ledger.mjs 2>/dev/null | sort -V | tail -1)
   ```
   If ANY prints nothing, that is a broken install, not a failed critic: STOP
   and say the plugin path did not resolve. Never let it fall through to the
   degrade-and-continue rule at Step 1 — that rule is for a Codex that ran and
   failed, not for a wrapper that was never found.
   **Shell state does not survive between Bash calls.** These two are paths you
   READ once and PASTE as literals into every later command; `"$WRAP"` in a later
   call expands to nothing. The emptiness check above is on THIS command's output,
   not on a later expansion — an empty expansion downstream is your own bookkeeping
   slip, and reporting it as a broken install sends the user to fix the wrong thing.
3. Every Codex call runs at `high` effort — each is a fresh cold read, and at the Sol also runs at the `fast` service tier by default (priority routing — same thinking, sooner, more per token); a user who wants to stop paying for that exports `CODEX_CRITIC_SPEED=normal`. Never set either yourself.
   doc seams the last round is the final word before Fable concludes. Do not set
   `CODEX_CRITIC_EFFORT` yourself; a user who exports it overrides it.
3b. **Every** `"$WRAP"` call passes the Bash tool's `timeout: 600000` (10 min, the
   tool maximum). The default is 120s and a `high`-effort call with `--search`
   routinely exceeds it — and a timeout arrives as a tool error, with no
   `VERDICT` and no `GATE:` line, so without this it silently looks like a critic
   that failed. If a call really does hit 10 minutes, say so and offer
   `--skip-critics`; do not retry it silently.
   Run it with the Bash tool's own `run_in_background`, never by appending `&`
   inside a backgrounded call — the child dies with the outer shell and you get a
   completed task with an empty output file, which looks exactly like a critic that
   returned nothing. (Cost two wasted Codex calls in a live run.)
4. `--skip-critics`: announce that Sol will not run, then do Steps 1, 2, 4, 6, 7
   and skip Steps 3 and 5. Fable still authors everything. At Step 1, Fable
   proposes alone and you rank its set — the seam survives with one proposer, and
   the approaches file records that only one ran.
4b. **Say what a normal drafter call looks like, before the first one.** A draft
   is the slowest step in this pipeline — minutes, not seconds — and the Agent
   tool has no `timeout` parameter, so neither you nor the user can interrupt it.
   The one thing you can supply is the expectation, because a user who knows what
   normal looks like stops at the right moment instead of sitting through forty
   minutes wondering.
   **Do not quote a number from this file.** What is normal depends on the repo,
   the model and the machine. If the user wants one, get it from their own
   history: `node <plugin>/scripts/pipeline-stats.mjs` prints the median and max
   for `foureyes-drafter` across every dispatch they have ever run. Say "this
   usually takes several minutes" until that tool has something to say.
   If a call does run long and returns a partial with `## Unresolved`, that is the
   drafter working correctly — take the partial, answer the gaps, and re-dispatch
   with those answers. Never discard a partial to start over.
   **Strip the leading `DRAFTER-STATS:` line** from returned content before
   writing any file or splicing any section, and report it in your Step 7 summary
   — it is the only view anyone has inside that dispatch. It is the FIRST line of
   every reply, in every mode, precisely so that a `REVISION: sections` reply
   cannot bury it inside the last task section and have it spliced into the plan.
4c. **Two things a large drafter return does that will silently corrupt a file.**
   Check for both before writing anything:
   - **`<persisted-output>` / `Output too large (NNN KB). Full output saved to:
     <path>`** — the harness spilled the return to disk and handed you a ~2KB
     preview. **Read that path** and use its contents. Writing the preview gives
     you a plan truncated mid-task that still looks plausible. Measured: this has
     already happened on returns around 97KB.
   - **`Agent terminated early due to an API error: … exceeded the 64000 output
     token maximum`** — nothing was produced and nothing is recoverable.
     Do NOT re-dispatch the same assignment; it will fail the same way. Split it: ask for
     a `REVISION: sections` pass, or for the tasks in halves. (A user who hits
     this often can raise `CLAUDE_CODE_MAX_OUTPUT_TOKENS`, but splitting is the
     fix — fifty minutes to hit a ceiling is fifty minutes lost either way.)
4d. **Applying a `REVISION: sections` reply.** Strip the leading `DRAFTER-STATS:`
   line first, then splice with the library rather than by hand:
   ```bash
   node -e 'import("<VIZ>").then(async m=>{const fs=await import("node:fs");
     const r=m.spliceTasks(fs.readFileSync("<plan>","utf8"), JSON.parse(fs.readFileSync("<sections.json>","utf8")));
     if(r.missing.length){console.error("MISSING "+r.missing.join(","));process.exit(1)}
     fs.writeFileSync("<plan>", r.markdown); console.error("spliced "+r.applied.join(","));})'
   ```
   `<sections.json>` maps each changed task NUMBER to its complete replacement text,
   built from the reply: `CHANGED-TASKS:` lists the numbers, and each `### Task N`
   block below it is that number's replacement. Cross-check the two — a number in
   `CHANGED-TASKS` with no matching block, or a block not listed, means the reply is
   malformed; re-dispatch rather than splicing half of it.
   `spliceTasks` is fence-aware and shares its boundary scan with the renderer, so a
   `### Task` line inside a code block is never mistaken for a section start.
   Untouched tasks, the intro and any trailing content come through byte-identical.
   **A non-empty `missing` exits 1 and writes nothing.** That means the drafter asked
   to replace a task the plan does not have, which means it meant a structural change
   and sent the wrong mode — re-dispatch asking for `REVISION: full`. Never hand-edit
   around it, and never guess where a new task belongs.
   Then re-derive `.tasks.json` from the spliced markdown as usual.
5. **Fable unavailable → fall back to Opus, LOUDLY.** The realistic failure is a
   spent quota or a model-unavailable error, and that is not a reason to stop:
   `model: fable` is a preference, not a correctness requirement, and Opus authors
   everything Fable can. Pass the Agent tool's `model` parameter (it outranks the
   agent's frontmatter pin, though NOT the env var — see item 1), say in one line
   that you fell back and why, and record the authoring model in the artifact
   itself. This is the ONE permitted override of that pin — what item 1 forbids is
   drafting on another model SILENTLY, and an announced fallback is the opposite of
   that. Malformed output is NOT unavailability: re-dispatch once on Fable, and
   only treat a second failure as unavailable.
   **The fallback is one level deep.** If the drafter is still unusable after it —
   Opus also unavailable, timed out, or malformed on its retry — STOP. There is no
   third model to try, and no amount of proposals substitutes for an author.

## Step 1 — Approach seam (two proposers, one arbiter)
Purpose: settle DIRECTION before a spec commits to one, using two models that
never see each other's answer. No rounds, no gate. The most expensive mistake in
this pipeline is a well-executed wrong approach, and this is the only cheap place
to catch it. One dispatch each and they run CONCURRENTLY, so the latency floor is
one dispatch — that is why this seam needs no cost classifier in front of it, and
a classifier would be the coordinator's judgment wearing a costume anyway.

**Do NOT interview the user first.** No requirements questionnaire, no "does
this look right?" confirmation. The brief is whatever they gave you:
- Detailed brief → asking them to confirm it back is pure friction.
- Thin brief → filling the gaps is the models' job. They read the repo; the
  approaches they return ARE the clarifying question, in concrete form.

State in ONE line what you understood the brief to be — a statement, never a
question. A misread is visible immediately and they will correct you; nothing
blocks waiting for a yes.

**Never narrow the brief yourself.** Not by subsystem, not by phase, not "the
first one for now". Deciding what is in scope is designing, and both proposers
receive the brief VERBATIM — so a narrowing you announce but do not pass through
produces approaches for one scope and a spec for another, with nothing
reconciling them. If the brief spans independent subsystems, pass all of it; an
approach is free to propose staged delivery, and then it is the proposers'
recommendation and the user's pick, not your edit.

**This seam always runs**, even when the brief names the approach and the files.
The proposers are not only a source of options, they are the check that the named
approach can be built here at all — and a brief that specifies confidently is not
a brief that specifies correctly. A named approach collapses the MENU (see 3); it
never skips the check.

**1. Both proposers, in ONE message (concurrent — they must not see each other):**
Say in one line that Sol is proposing and may take a few minutes at `high`
effort; a silent terminal reads as a hang.

**Set the Bash tool's `timeout: 600000` on this call** (Step 0.3b). That is a
tool parameter — a `timeout` comment inside the script does nothing.
```bash
# Sol proposes. NOT a seam mode: pass no CODEX_CRITIC_ROUND, expect no GATE line.
printf '%s\n' "BRIEF (verbatim):" "<brief>" "" "REPO: <repo root>" \
  | "$WRAP" approach
```
…and in the same message, dispatch `foureyes-drafter` with **Assignment A0**
(brief + repo context). Neither input mentions the other model.

Failure handling is NOT symmetric between the two, because they are not
interchangeable — Fable also authors every later artifact:
- **Sol fails** (exit 2, `NEEDS-HUMAN`, unparseable, or a well-formed answer with
  no entries at all): continue with Fable's set alone exactly as `--skip-critics`
  does, and tell the user Sol did not run. The `GATE:` table above governs the DOC
  seams and does not apply here — a seam with no gate cannot be stopped by one.
- **Sol times out**: name it AS a timeout, offer `--skip-critics`, and let the
  user decide whether to spend the wait. Never file a timeout under "the critic
  failed" — that hides a systematic loss of the second model behind a one-line
  notice.
- **Fable fails** — unavailable, timed out, or malformed twice: fall back to Opus
  per Step 0.5, announced. Never proceed Sol-only on the assumption Fable comes
  back; it is the author of Steps 2 and 4.
- **The drafter is unusable even after the Opus fallback**: STOP, **regardless of
  what Sol returned**. A rich set of approaches with nobody able to write the spec
  is not partial progress, it is a dead end — say so plainly rather than ranking a
  menu you cannot act on.
- **Neither proposer returns a usable entry**: STOP. There is nothing to rank and
  inventing an approach is forbidden.

**2. Pool both sets into ONE auditable file, then rank from the file:**
Derive the run's `<topic>` slug ONCE, from the brief, and reuse that exact slug
for every artifact of this run — approaches, spec, plan. Different slugs leave the
artifacts unlinked.

Write `docs/foureyes/specs/YYYY-MM-DD-<topic>-approaches.md`. `## Proposed` is
the RAW pool: every entry from both sets, nothing merged, nothing dropped,
relabeled `1..N` and ordered **alphabetically by title**. Alphabetical because it
is deterministic, derived from content, and uncorrelated with who wrote it —
whereas alternating Fable/Sol/Fable makes index parity an exact authorship label,
and grouping by source is the same leak in blocks. Both proposers emit the same
template, so this is a copy, not a rewrite. Write it BEFORE deciding anything: a
pre-cleaned file cannot show that Sol proposed entry 4 and it got folded into
entry 1, which is the whole reason the file exists.

`VERDICT:` and `SUMMARY:` are NOT entries — they are each proposer's own pick, so
they are authorship information. Keep them out of `## Proposed`; they go to
`## Decisions` with their letters rewritten to pool numbers. (Both proposers letter
from A, so relabelling to `1..N` is also what makes the pool referenceable at all.)

**Call this auditable, not blinded.** You read both labeled results before writing
the file and you cannot unsee them. What the file buys is that a systematic
preference becomes *visible after the fact* — it is an instrument, not a blindfold.

Decide in your head through 1-3, then write `## Decisions` at 4:
1. **Merge** structural duplicates — two spellings of one design is one entry.
2. **Re-verify** a capability only where the claim is load-bearing AND the
   proposer's `CHECKED` line is thin or missing. Both were told to verify before
   listing; do not pay for a third pass by default. An approach resting on an API
   that does not exist is dropped, with the evidence.
3. **Rank** on merit and cap at 3. **No source quota** — if one proposer's whole
   set is weaker, all of it drops, and that is the correct outcome. Forcing one of
   each into the menu would let a weak entry displace a strong one on authorship.
   Mark the recommendation and put it first, so "just go" is one keypress.
4. **Write** `## Decisions`: who proposed each entry, both proposers' own picks,
   every merge, every drop with its reason, your recommendation, the authoring
   model if it was not Fable, and **the model YOU are running on** (`arbiter:
   <model>`). Nothing goes in before ranking is done — provenance is the audit
   trail, never an input to the judgment.

   The arbiter line matters because Step 0 guards `CLAUDE_CODE_SUBAGENT_MODEL`
   for Fable's dispatch and there is no equivalent guard for the coordinator —
   ranking quality tracks whatever the session happens to be, silently. Recording
   it does not fix that, but it makes a thin menu explainable after the fact
   instead of mysterious.

You may NOT add an approach neither proposer named. See the rule at the top. That
also means you never turn an `UNKNOWNS` line into an approach: an axis like "must
this work offline?" names no architecture, so converting it would require you to
design one. Axes the proposers did not turn into entries stay questions (see 3).

**ZERO survivors** (everything disproven): do not invent one. Show the user what
was disproven and the evidence, and ask them to redirect. This is the one place
the seam stops.

**`Do not build this` is an approach like any other.** Rank it on its evidence;
never drop it for being inconvenient. Surviving alongside others → it goes in the
menu as an option. Surviving as the ONLY entry → STOP, because there is nothing to
spec: show the user the evidence and let them redirect or overrule. This seam is
the pipeline's one chance to question the brief itself — you take the brief as
given and so does every stage after you, so a premise nobody challenges here gets
a spec, a plan, two critic rounds and real commits built on top of it before
anyone notices.

<!-- ponytail: auditable pool, not real blinding — the coordinator reads both
     labeled results first. Upgrade path if the audit trail ever shows one
     proposer's entries being dropped systematically: a fresh arbiter subagent
     that receives ONLY the source-stripped pool and returns a ranking, with
     provenance appended after it answers. Costs a third dispatch and a serial
     step, so it is not worth building against a bias nobody has observed yet. -->

<!-- ponytail: menu quality tracks the SESSION model, since the arbiter is
     whoever is coordinating. Step 0 guards CLAUDE_CODE_SUBAGENT_MODEL for
     Fable's dispatch; there is no equivalent guard for the coordinator and
     there cannot be one. Known ceiling. The `arbiter:` line in ## Decisions is a
     record, not a guard — it makes a thin menu explainable instead of
     mysterious. Upgrade path if the records ever show menu quality tracking the
     session: a fresh arbiter subagent with a pinned model, costing one dispatch
     and a serial step. Not worth building before the records exist. -->

**3. ONE interaction — the only one before the plan exists.**
It is a single `AskUserQuestion` carrying up to 4 questions. Make the call when
there are **2+ survivors OR at least one retained unknown**; skip it only when
there is exactly one survivor and nothing left to ask.

- **Approach question** — only when 2-3 survived (the cap is 3, so four is not a
  reachable state). Recommendation first and labeled. Price each option in what
  the user feels — deps, files, what gets harder later — not in architecture
  nouns. Dropped entries live in the approaches file, not in the question.
- **1 survivor** → no approach question; announce it and why it was the only one.
  That skips ONE question, not the call — retained unknowns still go in it.
- **Retained unknowns** — one question each. Budget: 3 alongside an approach
  question, 4 without one. These are the `UNKNOWNS` lines both proposers raised,
  deduped, that clear the bar "guessing wrong would waste the run". Everything
  below the bar becomes an explicit `## Assumptions` entry in the spec, where Sol
  argues with it at Step 3 instead of costing a turn now. Never a follow-up turn:
  this call is the whole budget.
- **Never ask a question the approach pick already answers.** Every question in
  this call is answered at the same moment, so two that interact can come back
  contradicting each other — and there is no permitted turn in which to reconcile
  them. Both proposers were told to express an approach-changing axis as entries;
  when one leaves it as an unknown anyway, decide by whether the SURVIVORS differ
  on it:
  - **Survivors differ** (one offline-first, one online-only) → the pick settles
    the axis. Drop the question, and note in `## Decisions` that the axis arrived
    as an unknown and which entries answer it. Asking both is how the user ends up
    selecting the online approach and requesting offline support in one breath.
  - **Survivors agree on it, or there is one survivor** → the pick settles
    nothing, so the question is genuinely independent. Ask it.
  This is a reading of the entries, not a judgment about the design.
- A brief that already names its approach is **1 survivor by definition**. A
  proposer's evidence-backed dissent ("that cannot work here, because…") earns a
  second option; bare preference does not. Never re-open a decision the user
  already made just because alternatives exist.
- Both proposers may honestly return one approach; that is a valid outcome, not
  a failure to explore. Never pad a menu to look thorough.
- **Afterwards append `CHOSEN: <n> — user` to the approaches file** (or
  `CHOSEN: <n> — only survivor` when there was no approach question). Until that
  line exists the file records a recommendation, not a decision — never log a pick
  the user has not made.

## Step 2 — Fable drafts the spec
Dispatch the drafter (Agent tool, `subagent_type: foureyes-drafter` — its
frontmatter pins `model: fable`; do not override): Assignment A with the
complete brief, **the chosen approach verbatim**, the approaches-file path, any
unknowns the user answered, and any that fell below the bar and must become
`## Assumptions`. It RETURNS spec content; YOU write it to
`docs/foureyes/specs/YYYY-MM-DD-<topic>-design.md` — the SAME `<topic>` slug as the approaches file. If the content is
malformed (no success criteria, placeholders, missing an `## Assumptions` section
when you passed unanswered unknowns), reject and re-dispatch — do not patch it
yourself.

## Step 3 — Sol critiques the spec (≤2 rounds)
```bash
# Bash tool: set timeout: 600000 (Step 0.3b) — a tool parameter, not a script line.
printf '%s\n' "SPEC_DOC: <spec path>" "" "ORIGINAL BRIEF (verbatim):" "<brief>" "" "<re-review: what changed>" \
  | CODEX_CRITIC_ROUND=<1,2> "$WRAP" spec
```
Follow the GATE table. Spec findings are intent decisions: show them to the
user, and dispatch Fable to revise with the findings verbatim. On `final`,
Fable's revision closes the spec — go to Step 4 regardless of what is left.

## Step 4 — Fable drafts the plan
Dispatch the drafter: Assignment B with the spec path. It returns the plan
markdown (starting `Spec: <path>`, tasks with the four headers +
`json:metadata` fences, subjects ≤ 60 chars, real `blockedBy` only, tiers by
spec-completeness). YOU write `<plan>.md` under `docs/foureyes/plans/` and
derive `<plan>.md.tasks.json` from it (id/subject/description per task,
0-based `blockedBy`). Create NO native tasks — the execution stage owns
TaskCreate; a second creator only makes duplicates.

**A plan too large for one reply arrives in parts.** Plan size is deliberately
uncapped; the reply is what has a ceiling. Pass `TASKS-PER-PART: <n>` in the
assignment — **start at 8 and halve it (8 → 4 → 2 → 1) every time a reply
overflows**, then re-dispatch that part. Fable emits `DRAFT: part N of M` with
`TASKS-IN-THIS-PART:` and a `REMAINING:` list, and you assemble.

8 is a starting guess, not a measurement: how many tasks fit depends on how
verbose this repo's tasks are and on `CLAUDE_CODE_MAX_OUTPUT_TOKENS`, and neither
is knowable in advance. Halving is what makes it correct anywhere — it converges
on this environment's real limit within two retries and needs no configuration.
An overflow is either signal from Step 4c: a `<persisted-output>` spill, or an
`exceeded … output token maximum` error. Never re-dispatch an overflowed part at
the same size; that is the loop that costs fifty minutes.

<!-- ponytail: the working value lives in this conversation, so a session resumed
     mid-plan restarts at 8. Self-healing by construction — it overflows once and
     halves again, converging in at most three steps — so the cost of not
     persisting it is a few wasted dispatches in a case that needs both a very
     large plan and a restart inside it. Persisting it would mean writing
     coordinator state into the plan file, which is worse. Known ceiling. -->

1. Keep part 1 whole — it alone carries the `Spec:` header and
   `## Global Constraints`. Append later parts' task sections verbatim, in order.
   Never renumber: `blockedBy` refers to the global task numbers Fable assigned.
2. Re-dispatch for each continuation with the spec, the `## Global Constraints`
   **as written**, a manifest of tasks already emitted (id, subject, files) and the
   `REMAINING` list. **Do not resend the earlier parts' full text** — output is the
   constraint here, not input, and the manifest is what keeps files disjoint and
   `blockedBy` pointing at tasks that exist.
3. Before deriving `.tasks.json`, check the assembly: ids contiguous from 1 with no
   gaps or repeats, every subject promised in a `REMAINING` list actually present,
   and `## Global Constraints` appearing exactly once. A gap means a part was lost;
   stop and re-dispatch for the missing numbers rather than shipping a plan whose
   `blockedBy` points into a hole.
4. Derive `.tasks.json` ONCE, from the assembled markdown. A per-part derivation
   would renumber and silently break every cross-part dependency.

Sol critiques the assembled plan, not the parts — a part on its own has dangling
`blockedBy` references and would draw findings that are artefacts of the split.

## Step 5 — Sol critiques the plan (≤2 rounds)
```bash
# Bash tool: set timeout: 600000 (Step 0.3b) — a tool parameter, not a script line.
printf '%s\n' "PLAN_DOC: <plan path>" "SPEC_DOC: <spec path>" "" "<re-review: what changed>" \
  | CODEX_CRITIC_ROUND=<1,2> "$WRAP" plan
```
Follow the GATE table. When Fable revises the plan markdown, re-derive
`.tasks.json` from it — the markdown is the source, the JSON is its mirror.
A user-directed spec change mid-loop = back to Step 3 with `ROUND=1`. A
user-directed APPROACH change = back to Step 2 with the new approach; the spec is
rewritten, not patched, and Step 3 restarts at `ROUND=1`.

## Step 6 — HTML plan page
```bash
node "$VIZ" "<plan path>"    # writes <plan>.md.html, prints the path
```
This renders THE PLAN — the brief, then every task in execution order with its
goal, steps, files, acceptance criteria and verify command, grouped into the
waves they run in. It is what the user reads instead of the markdown; the
structural checks are a collapsed footnote, not the subject. The local
self-contained file is the deliverable. (You MAY additionally publish it via
the Artifact tool if available — never required.)

If it prints structural problems on stderr, they go in your Step 7 summary
verbatim. `plan-tasks-order-mismatch` / `-count-mismatch` / `-fence-drift` mean
YOUR `.tasks.json` derivation disagrees with Fable's markdown — build executes
the JSON while the user reads the page, so fix the derivation and re-run the
viz before stopping. `unknown-key` means the fence carries a field build never
reads — a contract Fable believed it set and did not, which is worse than a
missing one because it looks handled. It / `no-verify` / `no-criteria` / `bad-tier` are Fable's to
fix. Nothing blocks here, but shipping an unreported problem is not an option.

## Step 7 — Report, then stop or hand back

**Decide the mode before you write the report.** The report is identical either
way; only the ending differs.

- **`--continue`** — you are inside `foureyes-build`. Report, return the plan path
  to the caller, and go straight on to execution. Ask NOTHING. Do not wait for
  the user to read the HTML: build's Step E is next, and pausing here is the one
  thing `--continue` exists to prevent.
- **standalone** — report, then STOP. Never ask a question here; the user reads
  the HTML and runs `foureyes-build <plan>` when they are ready.

The report, in both modes: print the paths: spec, plan, tasks.json, HTML, the critique log, and the
approaches file if the seam ran. Report this run's tally in one line —
`Sol: <n> raised, <n> fixed, <n> rejected, <n> intentional, <n> open` — counted
from the lines you just wrote. It costs nothing and it is the only feedback that
arrives while you still remember the run. Name the chosen approach in one line — the plan only makes sense
against the direction it was built for. List any `## Assumptions` the spec is
carrying, since those were decided FOR the user, not by them. If any seam ended
on `final` or `conclude`, say so plainly and list what Sol still had open — the
user is deciding whether to build, and they need to know what went unaddressed.
If Sol never ran at this seam (a failed `approach` call), say that too: the menu
came from one model.
