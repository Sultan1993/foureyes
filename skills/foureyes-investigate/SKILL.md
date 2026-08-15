---
name: foureyes-investigate
description: >
  Investigate a bug or a vague "something is wrong here" with two model families.
  Scouts sweep the codebase from several angles at once, then Fable and Sol form
  hypotheses independently and blind, the cheapest disproof of each is actually
  run, and survivors are attacked by the other model. Produces a cause with its
  evidence — or an honest "not established" plus what is now ruled out. Diagnoses
  only: it never changes code and never commits. The one thing it writes is its
  own report. Flags:
  --skip-critics (Sol never runs), --angles a,b,c.
---

# foureyes-investigate — widen, guess, prove, attack, conclude

You are the COORDINATOR. You gather nothing and conclude nothing on your own:
scouts look, two models hypothesise, evidence decides.

**This command changes NO CODE.** No fixes, no edits to anything that runs, no
commits, no branches. The only files it creates are its own report and critique
log under `docs/foureyes/investigations/` — those are the deliverable, not a
side effect, and Step 6 requires them. Nothing else in the tree is touched.

If the user wants the fix, they hand the conclusion to `foureyes-build` as a
brief, which keeps the fix inside the pipeline instead of around it.

## Announce
"Using foureyes-investigate: scouts sweep, then Fable and Sol form hypotheses
independently and we test the cheapest disproof of each. Roughly 15-25 minutes,
and it diagnoses without changing anything."

Say the duration out loud. This is worth it for something you have already lost
an hour to, and wasteful for something you would find yourself in five minutes.
Let the user stop you at the announce rather than at minute twenty.

## Step 0 — Preflight
```bash
WRAP=$(ls -d ~/.claude/plugins/cache/*/foureyes/*/scripts/codex-critic.sh 2>/dev/null | sort -V | tail -1)
```
Empty is a broken install: STOP and say the plugin path did not resolve. Shell
state does not survive between Bash calls — read this once and paste it as a
literal into every later command.

**Every `"$WRAP"` call passes the Bash tool's `timeout: 600000`** (10 min, the
tool maximum). The default is 120s and a `high`-effort call over a real codebase
exceeds it easily; a timeout arrives as a tool error with no output at all, which
looks exactly like a model that found nothing. Run it with the Bash tool's own
`run_in_background`, never by appending `&` inside a backgrounded call — the
child dies with the outer shell and leaves an empty file.

`--skip-critics`: Sol never runs, Fable hypothesises alone, and you say plainly
that the conclusion rests on one model.

## Step 1 — State the symptom, do not interview

Restate in ONE line what you understood the symptom to be. A statement, never a
question. **Vague is a legitimate input**: "auth feels flaky sometimes" is enough
to start, because Step 2 is the answer to vagueness — you do not need a lead, you
need coverage. Asking the user to sharpen it first is asking them to do the
investigation.

Record two things, because they change what is possible rather than what is
likely:
- **Is there a reproduction?** If yes, note the exact command. If no, say so —
  hypotheses whose disproof needs a repro cost far more, and Step 4 orders on cost.
- **When did it start, if known?** A date or a release turns `git log` from a
  haystack into a range.

## Step 2 — Scouts sweep, concurrently

Dispatch `subagent_type: foureyes-scout` with **Assignment S**, one per angle,
**all in ONE message** — they are independent and the latency floor is one
dispatch. Pass `model: sonnet` explicitly (effort is pinned medium in its
frontmatter). Give each scout the symptom and exactly ONE angle:

| angle | what it covers |
|---|---|
| `recent` | what changed lately near the symptom — `git log`, `git blame`, and anything that landed around the date from Step 1 |
| `errors` | where failures are swallowed, retried, logged and moved past on this path |
| `surface` | the subsystem the user actually named, read directly |
| `dataflow` | what reads and writes the state involved, and who else touches it |

Run all four even when the symptom names a subsystem. A scout that finds nothing
returns one line saying so, and that is information: it is how you learn the
problem is not where everyone assumed. `--angles a,b,c` overrides the set for a
user who already knows the shape of it.

Scouts report facts with addresses and **never name a cause** — a scout arriving
with a theory contaminates both proposers in Step 3, and their independence is
the only thing making two of them worth more than one.

## Step 3 — Two proposers, blind and concurrent

Issue BOTH in ONE message. Neither input mentions the other model.

```bash
# Sol. NOT a seam: pass no CODEX_CRITIC_ROUND and expect no GATE line.
printf '%s\n' "PROPOSE" "SYMPTOM: <one line>" "REPRO: <command or 'none'>" \
  "STARTED: <when, or 'unknown'>" "" "SCOUT FINDINGS:" "<all scout reports>" \
  | "$WRAP" investigate
```
…and `subagent_type: foureyes-investigator`, same content, as Assignment
PROPOSE. Both emit the same template, so Step 4 is a copy rather than a rewrite.

Say in one line that Sol is thinking and may take a few minutes; a silent
terminal reads as a hang.

Failure is not symmetric:
- **Sol fails, times out, or returns nothing usable** → continue with Fable alone
  and say so. Name a timeout AS a timeout; filing it under "the critic failed"
  hides the systematic loss of the second model.
- **Fable fails** → continue with Sol alone and say so. Unlike the drafting
  seams, neither model is load-bearing here: one set of hypotheses still tests.
- **Neither returns a usable hypothesis** → go to Step 6 and report
  `NOT ESTABLISHED`, with everything both of them ruled out. That is a real
  result, not a failure to try.

## Step 4 — Pool, rank by cost, and test

Pool both sets into one list, relabelled `1..N`, ordered **alphabetically by
claim** — deterministic, derived from content, and uncorrelated with who wrote
it, whereas alternating the two makes index parity an authorship label.

> **You may not test a hypothesis neither proposer named.** If you think of a
> better one, it goes back to a proposer or it does not happen.

Merge duplicates — two spellings of one mechanism is one entry, and note that
both models reached it. **Agreement is a prior, never a verdict.** Two models
converging on the same wrong cause is worse than one, because the agreement reads
as confirmation and sends someone to fix working code. It moves a hypothesis up
the queue; it never skips it past evidence.

Then test in **cheapest-disproof-first** order — not likeliest-first. A
thirty-second check that eliminates a middling hypothesis is worth more than a
twenty-minute one on the favourite, because it shrinks the field either way.

Dispatch `foureyes-scout` with **Assignment E**, one per hypothesis, `model:
sonnet`. Independent tests go in ONE message. Act on each verdict:

| verdict | what you do |
|---|---|
| `KILLED` | strike it; record what killed it under ruled-out |
| `SURVIVES` | it goes to Step 5 |
| `INCONCLUSIVE` | the observation could not be made. Say why, and either supply what was missing or move it to the bottom of the queue. **Never promote it to `SURVIVES`** — an untested hypothesis and a tested one are different things, and conflating them keeps a dead theory alive for an hour. |

**Budget: at most 2 rounds of hypothesise-then-test.** If a round kills
everything, you may take one more — pass every ruled-out finding back to both
proposers, since eliminations are exactly what sharpens a second attempt. After
the second round, conclude with what you have. An investigation that re-reads
always finds one more thing to check, and the budget is the whole point.

## Step 5 — The other model attacks the survivors

Cross-refute, never self-refute: a Fable hypothesis goes to Sol, a Sol hypothesis
goes to Claude, and one both proposed goes to whichever has not yet argued
against it. Batch these in ONE message.

```bash
printf '%s\n' "REFUTE" "HYPOTHESIS: <claim>" "MECHANISM: <...>" \
  "EVIDENCE: <what the scout observed>" | "$WRAP" investigate
```
…or `foureyes-investigator` with Assignment REFUTE. Each returns
`REFUTED: yes|no` and `BECAUSE:`.

A refuter that errors or is unparseable counts as **not refuted** — conservative
on infrastructure failure, because a flaky call must never silently delete a real
finding. Say that it failed rather than hiding it in a verdict.

## Step 6 — Conclude, or say you could not

Write `docs/foureyes/investigations/YYYY-MM-DD-<topic>.md`:

```markdown
# <symptom, one line>
STATUS: ESTABLISHED | LIKELY | NOT ESTABLISHED
CAUSE: <the mechanism, concretely — or "not established">
EVIDENCE: <the observation that proves it, with its real output>
PROPOSED BY: <fable | sol | both>   REFUTED BY: <none | who tried and failed>
RULED OUT:
- <hypothesis> — killed by <observation>
- <angle> — swept, nothing found
STILL UNKNOWN:
- <what a next investigation should start on>
```

The three statuses are not interchangeable:
- **ESTABLISHED** — an observation proved the mechanism. Say which one.
- **LIKELY** — it survived refutation but nothing proved it. Say what would.
- **NOT ESTABLISHED** — nothing survived, or nothing was testable. **This is a
  successful run**, not a failed one: the ruled-out list is the deliverable, and
  the next investigation starts where this one stopped instead of from zero.

Never dress LIKELY up as ESTABLISHED. A confident wrong diagnosis is the most
expensive thing this command can produce — it sends someone to fix code that
works, and they trust it because two models and a test run stand behind it.

**Log Sol's rounds** to `docs/foureyes/investigations/YYYY-MM-DD-<topic>-critique.md`
in the standard grammar, so the ledger prices this seam like every other one:
```
## investigate · round <n> · <YYYY-MM-DD> · <n>s
- [<Severity>] <fixed|rejected|intentional|open> — <the hypothesis and what became of it>
```
Here `fixed` means the hypothesis was established, `rejected` means you tested it
and it was false, `open` means untested when the budget ran out. Duration comes
from the wrapper's own stderr line; never measure by hand.

Then STOP. Print the report path and the status in one line. **Do not fix
anything, do not offer to** — if the user wants the fix, the conclusion is the
brief they hand to `foureyes-build`, and say so in that one line.
