---
name: foureyes-ledger
description: >
  Report whether Sol is earning its keep. Reads the critique logs the seams write
  into consumer repos and shows, per seam, how often Sol was acted on versus
  factually wrong. Read-only, no model calls, no network. Takes repo paths:
  foureyes-ledger ~/dev/app-one ~/dev/app-two (default: the current repo).
---

# foureyes-ledger — is Sol worth the five minutes?

Every seam costs a `high`-effort Codex call, roughly five minutes. This is the
only thing that says whether any of them earned it.

## Announce
"Reading the Sol critique logs."

## Run it
```bash
S=$(ls -d ~/.claude/plugins/cache/*/foureyes/*/scripts 2>/dev/null | sort -V | tail -1)
node "$S/sol-ledger.mjs"     <repo paths, or nothing for the list>   # Sol: value and price
node "$S/pipeline-stats.mjs" <repo paths, or nothing for cwd>        # plans + dispatch history
```
Empty `S` is a broken install: STOP and say the plugin path did not resolve.

Run **both** unless asked for one. They answer different questions from different
sources, and only together do they cover the pipeline:

| | source | needs |
|---|---|---|
| `sol-ledger` | critique logs the seams write | runs since the ledger shipped |
| `pipeline-stats` | plans on disk + `~/.claude/projects` transcripts | nothing — it is all retroactive |

**With no arguments it reads `~/.claude/foureyes-repos`** — one path per line,
`#` comments and `~` both fine — and falls back to the current directory if that
file does not exist. The logs live in the repos you BUILD in, never in the plugin
repo, so a bare run without that file reports on whatever you happen to be
standing in. If the user asks about repos not in the list, add them there rather
than passing paths every time.

Each path may be a repo root, a specs directory, or an **umbrella holding several
repos**: every `docs/foureyes/specs` beneath it is included, because real
projects nest (a monorepo's sub-repos each carry their own, and so
does the umbrella). Returning only the top-level match would report on a fraction
of the specs and read as "few findings here" — which is the failure this whole
instrument exists to avoid.

## Read the result honestly

The number is `acted-on` = `(fixed + intentional) / raised`: findings that
changed the artifact or were consciously kept. `rejected` is its complement that
matters — Sol was factually wrong and the round was spent anyway.

- **A seam that stays low across several features is a seam to cut.** Say so
  plainly, and say which. That is the whole point of keeping the log.
- **Do not read significance into small n.** Twelve findings is an anecdote, not
  a measurement. It is enough to stop guessing, not enough to prove anything, and
  claiming otherwise makes the instrument worse than none.
- **`open` is not failure** — it is a seam that ended on `final` with findings
  the user shipped anyway. A high `open` count means the round budget binds, not
  that Sol was wrong.
- **Zero logs is not zero findings.** A repo that has not run a seam yet, or ran
  everything under `--skip-critics`, is empty for reasons that have nothing to do
  with Sol's quality. Check before concluding.

## Reading `pipeline-stats`

- **`hangs`** — dispatches that ran over 15 minutes AND returned under 3KB. A
  healthy slow call returns tens of kilobytes, so duration alone cannot tell
  working from stuck. Any non-zero count on `foureyes-drafter` is the failure
  where a user waits forty minutes and gets nothing; the drafter budgets itself
  because the Agent tool has no `timeout` and nothing external can stop it.
- **The `⚠ Codex-only critic` warning** — `spec`/`plan`/`code` critics must reach
  Sol through `codex-critic.sh`. Dispatched as Claude subagents they become
  Claude critiquing Claude, and the run only looked cross-model. `review-critic`
  and `refute-critic` are NOT misroutes: `foureyes-review` sends the identical
  prompt to both families on purpose.
- **`not in the routing table`** — a `modelTier` outside mechanical/standard/
  frontier maps to no row, so dispatch was improvised.
- **Wave width** — if most waves are width 1, the parallelism machinery is
  running one agent at a time and its cost is not being repaid.
- **Model mix per subagent** — compare against the routing table. Implementers
  landing on `opus` far more often than plans are tagged `frontier` means either
  E3 escalation or the tier being ignored; the data cannot tell you which.

## The one question the summary cannot answer

Whether to add a per-wave Sol review at build's E6 turns on something the table
does not carry: do S3 findings **span more than one task**, and do they cite code
from a wave that **is not the last one**? Only those would have been caught
earlier by a per-wave review.

To answer it, read the `## code` sections of the critique logs directly — at ten
or fifteen findings that is a two-minute read, which is why the fields are not
recorded structurally. Report the count both ways; an empty set is a real answer
and means E6 should not be built.
