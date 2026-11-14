# foureyes efficiency: measure first, then route — design spec

Date: 2026-11-14. Revision 3, final (after Sol's spec critique round 2; Sol does not review again). Approach: 3 (user's pick). Approaches file: `docs/foureyes/specs/2026-11-14-foureyes-efficiency-approaches.md`. User's answer on the binding limit: none in particular, favour quality.

## Purpose

The brief asks for model and effort choices per role that hold finding quality at lower subscription usage and wall-clock. The evidence so far cannot justify any change:

- The model cohorts are unpaired and come from different weeks.
- 1,682 Codex runs sit against 280 ledger rounds, with the difference unexplained.
- Nothing measures what a cheaper setting would have missed.

This run changes no default. It builds three instruments, runs them on the user's real history, and commits a results document that the later defaults run consumes.

1. **Attribution.** Every `codex-critic.sh` call is attributed by mode, round, model, effort, seconds and credits. This is retroactive, joining Claude transcripts to Codex session files on identity evidence, never on time and repo alone.
2. **Per-round yield.** The ledger reports yield per seam and round number, reproducibly, with a `--since` filter.
3. **Paired replay.** Saved seam inputs are re-run against candidate settings and scored on recall of findings the ledger recorded as `fixed`. Candidates are `gpt-6.1-sol:medium` and `gpt-6.1-terra:high`, with `gpt-6.1-sol:high` as control.

Because the user favours quality, every rule below resolves doubt against the candidate: a match without identity evidence is neither priced nor replayed, a failed candidate call counts as a miss, every retry is paid for in the efficiency comparison, and a weak baseline yields `inconclusive`, never `holds`.

## Verified facts this design rests on

**Repo** (read this session and the last)
- `scripts/pipeline-stats.mjs` `summariseHistory(root)` streams `~/.claude/projects/*/*.jsonl` and pairs `tool_use` to `tool_result` by id, with timestamps (lines 89-135). It only looks at `Agent` tool calls today. Its glob does not reach subagent transcripts, which sit one level deeper.
- `scripts/codex-critic.sh` accepts `CODEX_CRITIC_MODEL`, `CODEX_CRITIC_EFFORT`, `CODEX_CRITIC_ROUND` and `CODEX_CRITIC_MAX_ROUNDS` (lines 34-49). It runs under `set -euo pipefail` (line 23).
- The wrapper has four exits before any Codex call, each with a fixed message: `no Codex call made` (budget spent, lines 64-68), `no prompt file at` (line 72), `codex CLI not found` (line 73), and `must be a positive integer` (lines 58-59).
- Seam modes (`spec`, `plan`, `code`) print `codex-critic: <mode> r<N> took <S>s` on stderr (line 119) and a `GATE:` line on stdout. Non-seam modes `exec` straight into Codex and are not timed.
- The wrapper's prompt is the agent file body, then the line `## Your assignment (inputs from the coordinator)`, then the piped inputs, then a trailer starting `Read whatever files, paths, or git ranges are referenced above` and ending `no preamble, no text after it.` (lines 80-87).
- Modes in use: `approach`, `spec`, `plan` (retired), `code`, `review`, `refute`, `investigate`. `investigate` inputs start with `PROPOSE` or `REFUTE`.
- `skills/foureyes-review/SKILL.md` calls the wrapper as `"$WRAP" review`, so a command can carry `$WRAP` instead of the literal path.
- `skills/foureyes-brainstorm/SKILL.md` has no `git commit` between spec rounds. The pre-revision spec is therefore not in git; it is recovered from the transcript's `Write` call.
- `scripts/sol-ledger.mjs` `parseLog` returns rows `{seam, round, severity, disposition, text}` and `rows.rounds` `{seam, round, secs}`. The header date is written by the seams but not parsed.
- `tests/run.sh` is an explicit allowlist of suites. New suites are added by hand.

**Codex session files** (two wrapper sessions inspected: one from 2026-11-13, one from 2026-10-02; same envelope in both)
- `session_meta` payload carries `id`, `timestamp`, `cwd`, `originator` (`codex_exec` for wrapper runs) and `source`.
- `turn_context` carries `model` and `effort`.
- The wrapper's prompt is stored as a `response_item` whose payload has `type: "message"`, `role: "user"` and a `content` part of `type: "input_text"`. It is repeated in an `event_msg` of type `item_completed` with `item.type: "UserMessage"`. Tool output sits in other record types.
- An `event_msg` of type `task_complete` carries `last_agent_message`, the final answer `codex exec` prints to stdout (seen in the November file; not checked in the October one).
- `event_msg` payloads of type `token_count` carry `info.total_token_usage` with `input_tokens`, `cached_input_tokens`, `output_tokens`, `reasoning_output_tokens`.
- The same payload carries `rate_limits`: `primary.used_percent` (seen as `48.0`), `primary.window_minutes` (10080), `primary.resets_at` (epoch seconds; two events in one session differed by one second), and `plan_type` (`prolite`) as a sibling of `primary`. This is the weekly subscription meter.

**Claude subagent transcripts** (coordinator's check this session; not re-read by the drafter)
- `~/.claude/projects/<project>/<session-id>/subagents/agent-<id>.jsonl` exists for the current session. Its records carry `message.model` (seen: `claude-fable-5-2`) and `usage` with `input_tokens`, `cache_creation_input_tokens`, `cache_read_input_tokens`, `output_tokens` and `output_tokens_details.thinking_tokens`.
- Only one such session directory was found for this project so far. Historical coverage is thin and has not been counted.

**Pricing** (official table at https://learn.chatgpt.com/docs/pricing, verified by the coordinator this session)
- Credits per 1M tokens, input / cached input / output:

| Model | Input | Cached | Output |
|---|---|---|---|
| GPT-6.1 Sol | 50 | 2.5 | 250 |
| GPT-6 Sol | 50 | 5 | 250 |
| GPT-5.6 Sol | 100 | 10 | 500 |
| GPT-6 Astra | 250 | 25 | 1250 |
| GPT-6.1 Terra | 25 | 1.25 | 125 |
| GPT-6 Luna | 2.5 | 0.25 | 12.5 |
| GPT-5.6 Terra | 50 | 5 | 300 |
| GPT-5.6 Luna | 5 | 0.5 | 30 |

- The same page states that credit prices alone do not determine included subscription usage. Credits are therefore a proxy for this Pro Lite user, and the design treats them as one (§2 allowance block, §5).
- Included usage is one meter shared by all models (Sol's round-2 check of the same page, confirmed by the coordinator). The page does not say how to attribute a meter movement to a model; §1 does that only from clean observations.
- Reasoning effort does not change the per-token credit rate (search summary from the first draft; page not opened).

## Assumptions

Each was decided for the user. Each line says what breaks if it is wrong.

- **The paid replay runs inside this build without a further prompt.** The approach's COST line stated about 400 credits and the user picked it. If that was not consent to spend, Task 8 must stop after `collect` and the dry-run plan.
- **`input_tokens` includes `cached_input_tokens`, and `output_tokens` includes reasoning tokens.** If wrong, every credit figure is off. Task 7 checks it by reproducing the coordinator's 6.9 median credits per Sol-high run within 10%.
- **Model ids in session files are the pricing table's names lower-cased and hyphenated** (`gpt-6-sol`, `gpt-5.6-sol`, `gpt-6-astra`, and so on). Only `gpt-6.1-sol` was seen in a file. If a historical id is spelled differently, its runs are unpriced under their literal id, and Task 7 lists every unpriced id with its run count. Nothing is mispriced.
- **`task_complete.last_agent_message` equals the text the wrapper printed.** If it does not, `output` evidence never fires. Calls then need `inputs` evidence or become proximity matches, which are neither priced nor replayed. Task 7 prints the verified share, and `collect` counts the loss as `unverified-join`.
- **Bash tool results in Claude transcripts contain both stdout and stderr.** The `took` line and the pre-launch messages are read from them. If stderr is absent, seconds fall back to timestamps and a failed launch becomes an orphan call. Neither is priced.
- **Claude transcript entries carry a top-level `cwd` field.** If absent, joins fail the repo check and replay cases are skipped as `no-repo`.
- **The coordinator writes each spec revision with a whole-file `Write`.** If revisions were applied with `Edit`, those cases are skipped as `edited-after-write`.
- **The critique log is the spec's sibling.** Its name is the spec path with a trailing `-design.md` (or `.md`) replaced by `-critique.md`. Otherwise the case is skipped as `no-ledger-round`.
- **Effort does not change how a model's tokens draw on the included allowance.** The allowance conversion is per model, not per model and effort. If wrong, the Sol-medium allowance figure is biased; the results document states the assumption beside the figure.
- **A run draws on the meter only up to its last `token_count`.** The allowance observations of §1 rest on it. If a run moves the meter after that event, an observation can miss part of the earlier run's draw; the figure is labelled approximate for this and for other-device usage.
- **Losing a Minor `fixed` finding makes a case `worse`, and re-raising a `rejected` finding does not.** This is the paired outcome of §5. If the user wants Minor losses ignored, the quality rule is stricter than intended and a candidate can fail on them; the per-case counts in `score.json` allow a recount without a re-run.
- **Real-data runs happen on the laptop with plain `node`.** `~/.claude/projects` and `~/.codex/sessions` live there. Unit tests go through `builder run`. If the laptop hook blocks plain `node`, Tasks 7 and 8 cannot run and must report that.
- **A Claude session judges finding equivalence, blind.** If the user wants human judging, the sheet format already supports it.
- **Replay fidelity is approximate and identical across arms.** Uncommitted working-tree state from the time is lost and submodules are not checked out. All arms see the same reconstruction. The control-recall floor in §5 detects a reconstruction too lossy to compare on.
- **`gpt-6.1-terra` is callable from the user's Pro Lite Codex and accepts `high`.** If not, `run` aborts after the first case with exit 3. A silent fallback to another model is caught by the session check in §4 and recorded as `model-mismatch`.
- **The README is not touched.** The ledger skill is the documentation surface for these scripts.

## Design

### 1. Codex usage reader: `scripts/codex-usage.mjs` (new)

This is the single home for credit rates and for reading Codex session files. `pipeline-stats.mjs` and `sol-replay.mjs` both import it.

**Rates** are keyed by exact model id, lower-cased: the eight rows of the table above, as `gpt-6.1-sol`, `gpt-6-sol`, `gpt-5.6-sol`, `gpt-6-astra`, `gpt-6.1-terra`, `gpt-6-luna`, `gpt-5.6-terra`, `gpt-5.6-luna`. There is no substring or family matching. Any other id has no rate, its credits are `null`, and it is reported as unpriced under its literal id. It is never estimated.

**Credits** = `((input − cached) × rate.input + cached × rate.cached + output × rate.output) / 1e6`. Every printed credit figure is labelled a proxy (see §2).

**`readCodexRuns`** walks the given roots recursively for `*.jsonl`. The defaults are `~/.codex/sessions` and `~/.codex/archived_sessions`. Each file is streamed and yields one run:

- id, start, cwd and originator from `session_meta`; `start` falls back to the first line's timestamp when there is no `session_meta`;
- end from the last line's timestamp;
- model and effort from the last `turn_context`;
- tokens from the last `token_count`;
- from that same event's `rate_limits`: `usedPercent`, `windowMinutes`, `resetsAt` (converted to ms), `planType`, and `limitAt`, the timestamp of that event;
- `lastMessage` from the last `task_complete` event, or `null`.

With `opts.since`, a run is kept when its `end` is at or after it. Filtering on the end, not the start, keeps every run that could overlap a later allowance observation.

**Wrapper recognition.** A run is a wrapper run only when all of these hold:

1. `originator` is `codex_exec`.
2. A `response_item` with `payload.type` `message` and `payload.role` `user` has an `input_text` part in which the marker begins a line.
3. That text, trimmed, ends with the trailer's closing words `no preamble, no text after it.`

`inputs` is the text between the first line-initial marker and the last occurrence of the trailer's opening line. The marker in tool output, in an assistant message, in a developer message or in an interactive session never qualifies. A prompt that quotes the wrapper's source fails rule 3, because the source continues after the trailer. The envelope is pinned to the one shape seen in both inspected files; a file in another shape is counted as `other exec`, so a future envelope change shows up as a coverage drop in Task 7 and not as wrong data.

**Allowance conversion** (`allowanceByModel`). The meter is one number shared by every model and every run. Completion order alone says nothing about who moved it: a run of another model can span two readings and report its own reading later. A conversion is therefore attributed to a model only from clean observations, where exactly one run's whole draw lies between two readings.

- A *reading* is a run's last `token_count`: `usedPercent` at `limitAt`. A run's *interval* is `[start, end]`.
- Order the runs that have a reading by `limitAt`. Each consecutive pair (A, B) with the same priced model is a *pair*. A pair is a *clean observation* when all four hold:
  1. A and B have the same `planType`, the same `windowMinutes`, and `resetsAt` within 120 s of each other;
  2. B's reading is not below A's;
  3. B started at or after A's reading (`B.start ≥ A.limitAt`), so all of B's tokens fall inside the observation;
  4. no run other than A and B has an interval that intersects `[A.limitAt, B.limitAt]`. This counts every run: any model, priced or not, wrapper or interactive, with or without a reading of its own.
- A clean observation contributes `percent = B's reading − A's reading` and `credits = B's credits`, the one run wholly inside it.
- Per model, `creditsPerPercent = Σ credits ÷ Σ percent` over its clean observations. It is `null` when there is no clean observation or `Σ percent` is below 5 points; the report prints `insufficient`.

A file with no timestamp at all holds no record of the session envelope and takes no part. A long interactive session voids every observation it spans; that costs coverage, never correctness (intentional). Usage from other devices moves the same meter and the reading may be coarse, so the figure is approximate and labelled so.

### 2. Sol-call attribution in `scripts/pipeline-stats.mjs`

`summariseHistory` keeps its single pass and gains a `solCalls` array in its return value. No second read of the transcripts.

- **What counts as a call.** A `Bash` `tool_use` whose command matches `(?:codex-critic\.sh|\$\{?WRAP\}?)["']?\s+(approach|spec|plan|code|review|refute|investigate)\b`. The preflight `ls … codex-critic.sh 2>/dev/null` has no mode word after it and never matches. Intentional limit: a command that merely mentions the wrapper followed by a mode word (a `grep` for it, say) also matches. Such a call finds no run with identity evidence and carries no cost.
- **Fields from the command.** Mode; round from `CODEX_CRITIC_ROUND=<n>` (default 1 for seam modes, null otherwise); inline `CODEX_CRITIC_MODEL=` and `CODEX_CRITIC_EFFORT=` overrides; `sub` (`propose` or `refute`) for investigate when the command contains the quoted literal.
- **Fields from the result.** `resultText` is the result's text. Seconds, in order of preference: the wrapper's own `took <S>s` line, then the timestamp delta for a synchronous call. A call with `run_in_background: true` has no end time; it takes its seconds from its verified joined run, and has none otherwise. `gate` is the `GATE:` token when the result carries one.
- **Launch.** `launched` is false when the result carries one of the wrapper's four pre-launch messages. Such a call made no Codex session and takes no part in the join.
- **Repeats.** A call whose command text is identical to an earlier `tool_use` in the same transcript is a repeat. That is rule 3c's "re-run the SAME call".

**Join** (`joinRuns`). Time and repo only nominate candidates. A pair is *joined* only on identity evidence. A match without it is a *proximity match*: counted, shown, never priced into a cost cell and never replayed.

*Eligibility.* A launched call and a wrapper run are eligible for each other when both hold:
- the run starts in `[t0 − 5 s, (t1 or t0 + 600 s) + 5 s]`;
- the run's `cwd` equals the call's `cwd`, or appears literally in the call's command (a command that changes into a worktree first).

*Evidence*, tried in this order. Text is compared with whitespace collapsed.
1. `output` — the first 400 characters of the run's `lastMessage` (at least 40 characters long) occur in the call's `resultText`. Joined when this holds for exactly one eligible call of the run and exactly one eligible run of the call.
2. `inputs` — the run's `inputs` (at least 40 characters long) occur in the call's command. Same exactly-one rule.
3. Over what remains, take connected components of the eligibility relation:
   - one call and one run: a proximity match, kind `unique`;
   - n calls and n runs, n above 1, where every call has the same mode, round, `sub`, model override, effort override and `cwd`: proximity matches in start order, kind `group`;
   - anything else: every call in it is `ambiguous` and its runs stay unmatched.

Why `unique` and `group` are not joins: a lone call and a lone run in the same repo and window can still be strangers. A parent call whose own session file is missing can sit beside a wrapper run launched by a subagent, whose transcript `summariseHistory` does not read. The same can happen to one member of a group. Neither kind proves which call produced which run, so neither moves a credit into a report row.

What a proximity match is used for: it is counted in the row's `proximity` cell, and its run's credits are summed in the row's `proximity-credits` cell, labelled unverified. That keeps the volume of parallel refutes, whose output is redirected to files, visible without presenting it as attributed cost. Nothing else reads it.

**Report.** A new section, printed after HISTORY and filtered by `--since YYYY-MM-DD` when given. Row formats are pinned in Cross-Task Contracts.

- `═══ SOL CALLS` — per mode and round: calls, not launched, joined, proximity, ambiguous, orphan, repeats, median seconds, median credits, total credits, share of all joined wrapper credits, proximity credits, and the `model/effort=n` mix. Median credits, total credits and share come from verified joins only. One `note:` line below the table gives joins by evidence (`output`, `inputs`) and proximity matches by kind (`unique`, `group`), and says proximity credits are unverified and in no cost cell.
- `— by model/effort (all Codex sessions) —` — n, median and mean credits per run, median input, cached and output tokens. Unpriced ids appear under their literal id with `—`.
- `reconciled:` — total Codex sessions as the sum of joined wrapper, unjoined wrapper, other exec and interactive. `joined` counts runs in verified joins; `unjoined` is every other wrapper run. This explains the 1,682-versus-280 gap. A `note:` line says how many unjoined runs are proximity matches, and that the rest come from transcripts not on this machine, from subagents, or from ambiguous components.
- `— allowance —` — the latest reading: `used_percent`, window minutes, plan, the time it was observed and the reset time. Then one row per model from `allowanceByModel`, showing pairs and clean observations. Then a fixed `note:` that credits are a proxy, that OpenAI states credit prices alone do not determine included subscription usage, and that other devices move the same meter.

Existing output above the new section is unchanged.

### 3. Per-round yield in `scripts/sol-ledger.mjs`

- `parseLog` also captures the header date. Rounds and rows gain `date` (string or null).
- `--since YYYY-MM-DD` filters rounds and rows. Undated rounds are excluded under `--since` and counted in one note line.
- A new `— per round —` table prints last. Per seam and round number it shows: rounds, raised, Critical, Important, other, fixed, acted-on %, findings per round, median seconds.
- The existing tables are unchanged.

### 4. Replay: `scripts/sol-replay.mjs` (new)

Four subcommands share one `--out` directory. The default is `~/.claude/foureyes-replay`, outside every repo, because it holds consumer-project text.

**`collect`** — no model calls. It builds `cases.json` from history.

1. Run `summariseHistory`, `readCodexRuns` and `joinRuns`. Keep `spec` and `code` calls that have a verified join, evidence `output` or `inputs`. A proximity match of either kind and an ambiguous call are skipped as `unverified-join`; an orphan as `no-codex-session`. The replayed inputs must be proven to belong to the call whose ledger round is the ground truth.
2. Parse `SPEC_DOC`, `WORKTREE`, `BASE_SHA` and `HEAD_SHA` from the joined run's `inputs`, as `^KEY: value$` lines. The Bash command is never shell-parsed.
3. Resolve the repo. For code, use the git common dir of `WORKTREE` if it still exists, else the toplevel of the transcript `cwd`. For spec, use the toplevel containing `SPEC_DOC`. `specRel` is `SPEC_DOC` relative to the worktree root or the repo toplevel, whichever contains it; neither means `spec-outside-repo`.
4. Spec cases: recover the spec text from the last `Write` to that path before the call in the same transcript. Record the repo commit as `git rev-list -1 --before=<call time> HEAD`.
5. Code cases: require `git cat-file -e` to succeed for both SHAs. Then the spec must be reachable in the reconstruction, because a clone carries no uncommitted file:
   - if `git cat-file -e <HEAD_SHA>:<specRel>` succeeds, the checkout already contains it;
   - else, if `recoverSpecText` finds a `Write` of it in the same transcript, the case stores that text as `specText`;
   - else the case is skipped as `spec-missing-at-sha`.
   Whether `SPEC_DOC` exists on disk today is not consulted.
6. Ground truth: the sibling critique log, parsed with `parseLog`, restricted to this seam and round. `fixed` rows are expected findings and `rejected` rows are traps.
7. Select newest first, alternating seams, at most half of `--limit` (default 20) per seam. A seam with fewer than `--min-per-seam` (default 6) eligible cases contributes none, and its cases are counted as `thin-seam`: fewer cases cannot reach a verdict under §5, so they are not paid for.

The case id is the first 12 hex digits of `sha256(seam, round, original Codex session id)`. Every case excluded for cause is counted under exactly one skip reason: `not-control`, `no-codex-session`, `unverified-join`, `no-repo`, `no-spec-write`, `edited-after-write`, `spec-outside-repo`, `spec-missing-at-sha`, `sha-missing`, `no-ledger-round`, `ambiguous-round`, `no-fixed`, `thin-seam`.

**`run`** — the only step that spends.

- Without `--yes` it prints the plan and exits 0: cases × candidates and an estimated credit total, each case's original credits scaled by the candidate's input rate relative to the control's.
- With `--yes`, cases run sequentially and the candidates of one case run concurrently. Intentional: candidates are not isolated from each other, so the replay does not itself measure a candidate's allowance draw; §5 says what that costs.
- **Identity.** A pair is a case and a candidate. Its artifacts are named by the candidate's slug (`gpt-6.1-sol@high`), never by position. Its fingerprint is `sha256` over the case (id, seam, round, sha, inputs, spec text), the candidate, and the bytes of `scripts/codex-critic.sh` and of the seam's agent prompt file. A pair is skipped on resume only when its meta has status `ok`, the same candidate and the same fingerprint. A meta with the same candidate and fingerprint that is not `ok` is run again and gains an attempt. A meta with a different candidate or fingerprint belongs to another experiment: it is replaced and its attempts start again at 1.
- **Each attempt:**
  1. Clone with `git clone --shared --no-checkout <repo>` into `<os.tmpdir()>/foureyes-replay/<caseId>/<8 random hex>`, then `git checkout --detach <sha>`. The directory name is random because critics quote paths in findings, and a candidate name there would unblind the judge. The source repo is never modified.
  2. When the case carries `specText`, write it to `specRel` in the clone.
  3. Rewrite the inputs so repo and worktree prefixes point at the clone. If the rewritten `SPEC_DOC` does not exist in the clone, the attempt is `failed` with reason `spec-missing` and nothing is spawned. An attempt that spawned nothing records `sessionMatch` `none` and credits `0`.
  4. Run this repo's `scripts/codex-critic.sh <seam>` with `cwd` = the clone, stdin = the rewritten inputs, `CODEX_CRITIC_MODEL`, `CODEX_CRITIC_EFFORT`, the original `CODEX_CRITIC_ROUND`, and `CODEX_CRITIC_MAX_ROUNDS` = max(2, round). Timeout 900 s; on timeout the process group is killed.
  5. Find the attempt's Codex session: wrapper runs whose `cwd` is the clone path or its real path and whose start lies in `[startedAt − 5 s, endedAt + 5 s]`. Exactly one is `one`, and its id and credits are recorded. None or several is `none` or `ambiguous`, with credits `null`. A single match whose model or effort differs from the candidate makes the attempt `failed` with reason `model-mismatch`. This match is identity, not proximity: the clone directory is random, exists only for this attempt and is deleted after it, so no other run can have its `cwd`.
  6. Write stdout to `<slug>.out`, stderr to `<slug>.err`, and update `<slug>.meta.json` with the attempt: number, `startedAt`, `endedAt`, seconds, status, clone path, session id, session match and credits. Delete the clone.

**`sheet`** — writes a blinded `sheet.json` and a separate `key.json`.

- It first validates every `ok` meta against `cases.json` and the candidate list: candidate and recomputed fingerprint must match, else exit 2 naming the stale artifact.
- A case whose control pair is not `ok` is left out and listed in `key.json` as `control-failed`.
- Per remaining case, the sheet lists truth findings as `T1…` (severity and text; disposition hidden; `fixed` and `rejected` rows alike) and the parsed findings of each candidate with an `ok` pair, under a label `A`/`B`/`C`. A candidate that is not `ok` gets no label.
- Label order per case is fixed by sorting candidates on `sha256(caseId + candidate)`.
- `matches` is left empty for the judge. For each truth id and each label, the judge enters the id of the candidate finding that states the same defect, or `null`.
- `key.json` maps each label to its candidate and fingerprint.

**`score`** — validates that the sheet is complete and that every artifact still matches `key.json` and its recomputed fingerprint (exit 2 otherwise), then unblinds. Seconds and credits used by the verdict are cumulative per pair, as §5 defines. Per seam and candidate it prints:

- the cohort size, and cases dropped as `control-failed`;
- completed and failed or timed-out cases;
- recall of `fixed` findings on the cohort, all severities and Critical + Important only, beside control's on the same cohort;
- `rejected` findings re-raised, reported only: they enter neither the paired outcome nor the verdict;
- the paired outcome counts against control (worse / equal / better), by the rule of §5;
- median findings per run;
- median cumulative seconds over the cohort, beside control's, and the saving;
- the priced subset's size and its share of the cohort; median cumulative credits (proxy) on that subset for both arms, and the saving;
- supplementary, never used by the verdict: median final-attempt seconds and credits over cases both arms completed;
- total credits spent over every attempt, and the number of pairs with an attempt whose session was not matched;
- the verdict and its basis under §5.

It also writes `score.json`, which carries the per-case hit counts, re-raise counts, outcome and cumulative figures behind every printed number.

### 5. Pre-registered reading

The rule is fixed now, before any number exists, and `score` applies it mechanically (`scoreSheet`, then `verdictFor`), so the result cannot be read to taste.

**Cohort.** Per seam, the cohort is every replayed case whose control call completed. It is the same set of cases, and so the same denominator, for control and for every candidate.

**Match.** An arm matched a truth finding when the judge's entry for that truth id under the arm's label is not `null`. Recall is pooled: matched expected findings ÷ expected findings, summed over the cohort.

**Failures count against quality.** On a cohort case where the candidate's call failed or timed out after the retry pass, the candidate matched none of that case's expected findings and the case is `worse`, whatever control matched.

**Paired outcome.** For every other cohort case, each arm has two counts over the case's expected (`fixed`) findings: `ci`, the matched ones of severity Critical or Important, and `all`, the matched ones of any severity. The candidate is compared with control on `ci` first and on `all` second:

- `worse` — lower `ci`, or equal `ci` and lower `all`;
- `better` — higher `ci`, or equal `ci` and higher `all`;
- `equal` — both counts equal.

So a candidate that keeps every Critical and Important finding but loses a Minor one is `worse` on that case. Re-raised `rejected` findings do not enter the outcome (intentional): the truth set is drawn from Sol-high's own earlier output, so control is the arm most likely to repeat a rejected finding, and counting re-raises could only reward a candidate for saying less. They are reported beside the outcome.

**Preconditions.** If any fails, the verdict is `inconclusive`, with the reason:
- the cohort has at least 6 cases;
- the cohort's expected findings include at least 12 Critical + Important;
- control's pooled Critical + Important recall on the cohort is at least 50%. Below that, the reconstruction or the judging is too lossy for any comparison, and two arms near zero would otherwise look equivalent.

**Quality.** A candidate holds quality when all three are true:
- it completed at least 80% of the cohort's cases;
- its pooled Critical + Important recall on the cohort is no more than 5 percentage points below control's;
- it is `worse` than control on at most a quarter of the cohort's cases.

**Efficiency.** Every figure is cumulative per case and arm: the sum over all attempts in the pair's meta, for control and candidate alike. A timeout that a later retry repaired is paid for in the comparison. Cumulative credits are `null` when any attempt's credits are `null`.

- *Seconds*: over the whole cohort, including cases the candidate never completed, the candidate's median cumulative seconds is at least 20% below control's.
- *Priced subset*: the cohort cases on which both arms' cumulative credits are known. Both arms' credit medians are taken over this same subset, and its size is reported. Credit coverage is adequate when the subset is at least 80% of the cohort.
- *Allowance*: coverage is adequate, both arms' models have a `creditsPerPercent` from `allowanceByModel`, and the candidate's median cumulative credits divided by its model's figure is at least 20% below control's.
- *Credits proxy*: coverage is adequate and the candidate's median cumulative credits is at least 20% below control's, without the allowance evidence above.

**Verdict**, decided in this order.
1. `inconclusive` — a precondition failed.
2. `does not hold` — quality fails.
3. `holds` — the seconds or the allowance saving is met. The basis names which.
4. `inconclusive` — credit coverage is inadequate. The reason is `credit coverage`, with the subset size: a credit saving can be neither shown nor ruled out.
5. `holds on credits proxy only` — only the credits-proxy saving is met. This is not a subscription saving. The later run must not change a default on subscription grounds from this verdict; it first needs allowance evidence for the candidate's model.
6. `does not hold` — no saving is met.

What this run can and cannot establish: `gpt-6.1-sol` has weeks of history, so Sol at medium can reach an allowance basis, but only if that history holds enough clean observations; parallel critic calls and long interactive sessions void them, and Sol's own row may read `insufficient`. `gpt-6.1-terra` has only this replay, run concurrently with Sol, which yields no clean observation at all, so terra will read `insufficient` and can hold on seconds or on the credits proxy only. The results document states that, and names the evidence the later run needs: clean observations of the model, run alone, that together move the meter at least 5 points.

With about 10 cases per seam this is evidence to stop guessing, not proof. The results document must say so in those words and must not claim significance.

### 6. Results document

`docs/foureyes/specs/2026-11-14-foureyes-efficiency-results.md`, committed to this repo, with these sections:

- `## Attribution`
- `## Per-round yield`
- `## Replay`
- `## Role table`
- `## Limits of this measurement`

The role table has one row per role in the brief: drafter, both approach proposers, spec critic, code critic, review and refute critics on both families, investigators, scouts, implementers by tier, and task reviewer. Each row gives the current setting, measured volume, time and cost where an instrument covers it, the evidence status (`replayed`, `attributed only` or `not measured`), the candidate change the later run should consider, and the basis for it (`seconds`, `allowance`, `credits proxy only`, or `none`). A row with status `not measured` names where its evidence lives, when the spec knows it.

The document carries aggregates and case ids only. It contains no finding text, no consumer repo names and no absolute paths.

## Data flow

```
~/.claude/projects/*/*.jsonl ── summariseHistory ──► solCalls ─┐
~/.codex/{sessions,archived_sessions}/**.jsonl ── readCodexRuns ─► runs ─┤
                                    allowanceByModel ◄── runs            │
                                                                joinRuns ├─► SOL CALLS report
consumer repos' *-critique.md ── parseLog ──► per-round table            │   (verified joins priced,
                                              └─ truth rows ─────────────┤    proximity matches counted)
                                                 collect (verified only) ▼
                 cases.json ─► run ─► runs/<caseId>/<slug>.{out,err,meta.json}
                                      └─► sheet ─► (judge) ─► score ─► score.json (verdicts)
                                                                      └─► results doc
```

## Error handling

- **Malformed input.** Unparseable JSONL lines are skipped, as today. A session file with no `session_meta` or no `token_count` yields a run with null fields. It is counted, never dropped.
- **Unlisted model id.** Credits are `null`. The run is listed under its literal id with `—`, and totals state how many runs they exclude.
- **`--since` with a malformed date.** Exit 2 with a one-line message, in all three scripts.
- **`collect` finds no eligible case.** It writes `cases.json` with an empty selection and the skip table, and exits 0. The skip table is the result.
- **`run` guards**, checked before any call: exit 4 if cases × candidates exceeds 60; exit 4 if the latest recorded `used_percent` is above 80. Both messages name the number.
- **`run` early abort.** If any candidate's status is not `ok` after the first case, exit 3 naming the candidate and its reason and printing the tail of its `.err`. Written results are kept.
- **Failed or timed-out call.** Recorded as an attempt with status `failed` or `timeout` and a reason. There is no in-run retry; a second `run --yes` retries exactly the pairs that are not `ok`. Every attempt's seconds and credits stay in the pair's cumulative figures.
- **Stale artifact.** A meta whose candidate or fingerprint does not match is replaced by `run` and rejected with exit 2 by `sheet` and `score`.
- **Session not matched.** The pair keeps its findings and is scored for recall and for seconds. Its cumulative credits are `null`, its case leaves the priced subset for both arms, and the count is printed. Too many such cases make credit coverage inadequate under §5.
- **Clone cleanup.** The clone is removed in a `finally` path. `run` removes any leftover `<os.tmpdir()>/foureyes-replay/<caseId>` before starting that case.
- **`score` with an incomplete sheet.** Exit 2, listing each missing truth-id and label pair.

## Non-goals

- **Changing any default, prompt, round budget or routing table.** That is the later run.
- **Replaying `approach`, `review`, `refute` or `investigate`.** They have no ledger ground truth of the `fixed` kind. They are covered by attribution only.
- **Measuring a candidate's allowance draw inside the replay.** It would need every call isolated from all other Codex use for hours and more terra volume than 20 cases give. §5 states the consequence.
- **Measuring Claude-side token usage per subagent.** Not measured in this run; it is measurable. The evidence is the subagent transcripts under each session's `subagents/` directory, whose records carry `message.model` and `usage` (see Verified facts). Historical coverage is thin and uncounted, so the later role analysis must first count how many sessions have such a directory before it reads anything from them. No instrument for it is built here.
- **Astra and `xhigh` candidates.** The brief's own numbers rule them out, and Astra 6.1 is not released. The candidate list is a CLI flag.
- **Judging whether a candidate's novel findings are valid.** Only recall of `fixed`, re-raising of `rejected`, and counts are scored.
- **Statistical tests.** n is about 20.
- **A model-API judge.** Judging is done by the session, on a blinded sheet.
- **New instrumentation in the wrapper or the seams.**
- **Fast-tier multipliers, and `CODEX_CRITIC_SPEED`.** The user excluded both.
- **JSON output from `pipeline-stats` or `sol-ledger`, and README edits.** The gate in Task 7 parses pinned row formats instead.

## Success criteria

- `bash tests/run.sh` passes with two more suites than before.
- On the user's history, `pipeline-stats --since 2026-09-30` prints a `reconciled:` line whose right side sums to its left. Its `gpt-6.1-sol/high` median credits per run falls in 6.2–7.6. At least 70% of launched `spec` and `code` calls are matched, by a verified join or a proximity match, and the verified share is printed beside it.
- `sol-ledger --since 2026-09-30` prints a `— per round —` table with at least 64 spec round-1 rounds and at least 61 code round-1 rounds.
- The results document exists with its five sections. It states, per seam and candidate, one of the four verdicts of §5 with its basis, copied from `score`. If replay was infeasible, it carries the skip-reason table that shows why.
- No default in `scripts/codex-critic.sh`, any `agents/*.md` or any routing table changed.

## Cross-Task Contracts

No scaffold task. Wave 1 (Tasks 1 and 2) touches independent files with no shared new name. Every later wave has width one.

`scripts/codex-usage.mjs`

```js
export const RATES;            // { '<exact lower-case model id>': {input, cached, output} } — the eight ids of Design §1, credits per 1M tokens
export const WRAPPER_MARKER;   // '## Your assignment (inputs from the coordinator)'
export const WRAPPER_TRAILER;  // 'Read whatever files, paths, or git ranges are referenced above'
export function rateFor(model);            // exact id → {input, cached, output} | null
export function credits(model, tokens);    // tokens: {input, cached, output} → number | null
export async function readCodexRuns(roots, opts);  // opts: {since?: number(ms)} — keeps runs whose end >= since → CodexRun[]
// CodexRun: { file, id, start, end, secs, cwd, originator, model, effort,
//             tokens: {input, cached, output, reasoning} | null, credits: number | null,
//             wrapper: boolean, inputs: string | null, lastMessage: string | null,
//             usedPercent: number | null, windowMinutes: number | null, resetsAt: number | null,
//             planType: string | null, limitAt: number | null }   // times in ms since epoch
export function allowanceByModel(runs);    // runs: every run, not only wrapper runs
// → [{model, pairs, observations, credits, percent, creditsPerPercent: number | null}]
//   pairs: consecutive same-model reading pairs; observations: the clean ones (Design §1, rules 1–4)
export const DEFAULT_CODEX_ROOTS;  // [~/.codex/sessions, ~/.codex/archived_sessions]
```

`scripts/pipeline-stats.mjs` — existing exports unchanged; additions:

```js
export const WRAPPER_MODES;    // ['approach','spec','plan','code','review','refute','investigate']
export function parseWrapperCalls(command);  // → [{mode, round, sub, modelEnv, effortEnv}]
export function joinRuns(calls, runs);
// → { joined:    [{call, run, evidence: 'output' | 'inputs'}],   // verified: identity evidence
//     proximity: [{call, run, kind: 'unique' | 'group'}],        // unverified: never priced, never replayed
//     ambiguousCalls: SolCall[], orphanCalls: SolCall[],
//     orphanRuns: CodexRun[] }                                   // wrapper runs in neither joined nor proximity
// summariseHistory(root) return value gains: solCalls: SolCall[]
// SolCall: { transcript, toolUseId, t0, t1: number | null, cwd: string | null, command,
//            mode, round: number | null, sub: 'propose' | 'refute' | null,
//            modelEnv: string | null, effortEnv: string | null, background: boolean,
//            launched: boolean, resultText: string | null,
//            secs: number | null, secsSource: 'wrapper' | 'delta' | null,
//            gate: string | null, repeat: boolean }
```

- CLI: `node scripts/pipeline-stats.mjs [--since YYYY-MM-DD] [roots…]`.
- Section headers other tasks grep: `═══ SOL CALLS`, `— by model/effort (all Codex sessions) —`, `reconciled:`, `— allowance —`.
- Row formats, parsed by Task 7. Cells are separated by whitespace and contain none; numbers have no thousands separator; a missing value is `—`; any footnote line starts with `note:`.
  - SOL CALLS row: `<mode> <r<N>|-> <calls> <not-launched> <joined> <proximity> <ambiguous> <orphan> <repeats> <median-secs> <median-credits> <total-credits> <share%> <proximity-credits> <mix>`
  - by model/effort row: `<model>/<effort> <n> <median-credits> <mean-credits> <median-input> <median-cached> <median-output>`
  - `reconciled: <T> sessions = <a> joined + <b> unjoined + <c> other-exec + <d> interactive`
  - allowance model row: `<model> <pairs> <observations> <credits> <percent> <credits-per-percent|insufficient>`

`scripts/sol-ledger.mjs` — existing exports unchanged; additions:

```js
// parseLog: rows and rows.rounds entries gain `date: string | null`
export function byRound(rows, rounds);  // → Map<`${seam} r${round}`, {seam, round, rounds, raised, critical, important, other, fixed, rejected, intentional, open, secs: number[]}>
```

- CLI: `node scripts/sol-ledger.mjs [--since YYYY-MM-DD] [roots…]`.
- Header: `— per round —`. It is the last table printed.
- Row format, same cell rules: `<seam> r<round> <rounds> <raised> <critical> <important> <other> <fixed> <acted-on%> <findings-per-round> <median-secs>`

`scripts/sol-replay.mjs`

```js
export const CANDIDATES;       // ['gpt-6.1-sol:high', 'gpt-6.1-sol:medium', 'gpt-6.1-terra:high'] — first is control
export const SKIP_REASONS;     // the thirteen reasons listed in Design §4
export function parseInputs(inputs);                    // → {SPEC_DOC?, WORKTREE?, BASE_SHA?, HEAD_SHA?}
export function critiquePathFor(specDoc);               // → string
export function recoverSpecText(transcriptPath, specDoc, toolUseId);  // async → {text} | {skip: reason}
export function selectCases(eligible, limit, minPerSeam);  // → {selected: Case[], thin: Case[]}
export function candidateSlug(candidate);               // 'gpt-6.1-sol:high' → 'gpt-6.1-sol@high'
export function pairFingerprint(kase, candidate, promptBytes);  // → hex sha256
export function parseFindings(verdictText);             // → [{severity, text}]
export function labelOrder(caseId, candidates);         // → candidates in blinded order
export function scoreSheet(sheet, key, cases, metas);   // → Score (per seam and candidate statistics)
export function verdictFor(stats, conversions);         // → {verdict, basis, reasons: string[]}
export async function runReplay(opts, deps);            // deps: {spawn, findSession} — injected for tests
// Case: { id, seam, round, repo, sha, baseSha?, specRel, specText?, inputs, origCredits,
//         truth: [{id, severity, disposition, text}] }
// Meta: { caseId, candidate, fingerprint, status: 'ok' | 'failed' | 'timeout', reason: string | null,
//         attempts: [{n, startedAt, endedAt, secs, status, reason, clone,
//                     sessionId: string | null, sessionMatch: 'one' | 'none' | 'ambiguous',
//                     credits: number | null}] }   // top-level status and reason are the last attempt's;
//                                                  // an attempt that spawned nothing has credits 0
// Score, per seam and candidate, carries per cohort case:
//   { caseId, ci, all, controlCi, controlAll, reraised, outcome: 'worse' | 'equal' | 'better',
//     cumSecs, controlCumSecs, cumCredits: number | null, controlCumCredits: number | null }
//   cumSecs    = sum of attempts[].secs
//   cumCredits = sum of attempts[].credits, null when any is null
//   priced subset = cohort cases where cumCredits and controlCumCredits are both non-null
// verdict: 'holds' | 'holds on credits proxy only' | 'does not hold' | 'inconclusive'
// basis:   'seconds' | 'allowance' | 'seconds+allowance' | 'credits proxy only' | null
```

- CLI: `node scripts/sol-replay.mjs <collect|run|sheet|score> [--out DIR] [--since YYYY-MM-DD] [--limit N] [--min-per-seam N] [--candidates a,b,c] [--yes]`.
- Files under `--out`: `cases.json`, `runs/<caseId>/<slug>.out`, `runs/<caseId>/<slug>.err`, `runs/<caseId>/<slug>.meta.json`, `sheet.json`, `key.json`, `score.json`.
- Exit codes: 0 ok; 2 usage, bad date, incomplete sheet, or stale artifact; 3 candidate failed on first case; 4 spend guard (over 60 calls, or `used_percent` above 80).

Exact test names

- `scripts/codex-usage.test.mjs`:
  - `credits charge cached input at the cached rate`
  - `rates are keyed by exact model id and differ across Sol versions`
  - `an unlisted model id is unpriced, never estimated`
  - `a wrapper run is recognised only from the exec user prompt`
  - `a marker in tool output or quoted source is not a wrapper run`
  - `usage and allowance come from the last token_count, not the sum`
  - `allowance conversion uses clean observations only`
  - `a run overlapping an observation voids it`
- `scripts/pipeline-stats.test.mjs`:
  - `a wrapper call is parsed for mode, round and inline overrides`
  - `the preflight ls is not a wrapper call`
  - `a $WRAP invocation counts as a call`
  - `seconds prefer the wrapper's own took line`
  - `joinRuns requires the same repo and reports orphans on both sides`
  - `overlapping calls of different modes are never swapped`
  - `a failed launch takes no run`
  - `a lone call and run without identity evidence is a proximity match, not a join`
  - `a same-bucket group is a proximity match, a mixed one stays ambiguous`
  - `an identical command in one transcript is a repeat`
- `scripts/sol-ledger.test.mjs`:
  - `the header date is parsed and optional`
  - `byRound splits yield by seam and round number`
  - `--since drops earlier and undated rounds`
- `scripts/sol-replay.test.mjs`, Task 4:
  - `inputs are parsed by KEY: value lines`
  - `spec text comes from the last Write before the call`
  - `an Edit after the Write skips the case`
  - `a code case needs its spec at the head SHA or recovered text`
  - `only output or inputs joins become cases`
  - `selection alternates seams newest first and drops a thin seam`
- `scripts/sol-replay.test.mjs`, Task 5:
  - `label order is deterministic and hides the candidate`
  - `run without --yes spawns nothing`
  - `run skips a pair only when candidate and fingerprint match`
  - `run refuses more than 60 calls`
  - `each attempt records its window and matched session`
  - `a clone missing its spec fails without spawning`
  - `score rejects an incomplete sheet or a stale artifact`
  - `recall counts fixed truth only and reports re-raised rejected`
  - `a failed candidate call scores zero recall and worse`
  - `the paired outcome ranks Critical and Important hits, then all hits, and ignores rejected`
  - `efficiency uses cumulative seconds and credits over all attempts`
  - `credits compare on the common priced subset and need 80% coverage`
  - `verdict needs usable control recall and allowance evidence`

Test policy

- Tasks 1–5 each run only their own suite.
- Tasks 2 and 3 must keep every pre-existing test in their suite green.
- Task 6 runs the full `tests/run.sh`. It is the first point the shared suite is expected green with the new suites listed.

## Global Constraints

- Node built-ins only. No `package.json`, no dependencies, ESM `.mjs`, tests with `node:test` and `node:assert`.
- Unit tests run as `builder run node --test <file>`. Never run a test suite locally.
- Real-data commands in Tasks 7 and 8 run on the laptop as plain `node scripts/…`, because `~/.claude/projects` and `~/.codex/sessions` exist only there. Never use `builder run` for them, and never copy those directories to a builder.
- Change no default: `scripts/codex-critic.sh`, every `agents/*.md`, and every routing table in `skills/*/SKILL.md` stay byte-identical, except the `skills/foureyes-ledger/SKILL.md` additions in Task 6.
- The critic persona is "Sol" in all prose and output, permanently. Never introduce `CODEX_CRITIC_SPEED` or any fast-tier option.
- Credit rates exist only in `scripts/codex-usage.mjs`, keyed by exact model id. No other file contains a rate number, and no code matches a model by substring or family.
- Every printed or written credit figure is labelled a proxy for subscription usage. Never describe a credit saving as a subscription saving.
- Never join a call to a run on time and repo alone. Only `output` or `inputs` evidence makes a join. `unique` and `group` are proximity matches: counted, never priced into a cost cell, never replayed. An ambiguous match stays unmatched.
- Never attribute a meter movement to a model from completion order. Only the clean observations of Design §1 count; anything else is `insufficient`.
- Efficiency comparisons use cumulative seconds and credits over every attempt of a pair. Final-attempt figures are supplementary only.
- All scripts are read-only towards `~/.claude`, `~/.codex` and consumer repos. The only writes are under `--out` and under `os.tmpdir()`. Consumer repos are checked out only through `git clone --shared` into `os.tmpdir()`. Never run `git worktree add`, `checkout` or `stash` in a consumer repo.
- Nothing from a consumer repo is committed to this repo: no finding text, repo name, spec text or absolute path. Test fixtures are synthetic.
- Tests never call the real `codex` or `claude` CLI. Subprocess and session-lookup behaviour is tested through the injected `deps`. A test may run `git` against a temporary repository it creates under `os.tmpdir()`.
- Match the existing style of `scripts/*.mjs`: small exported pure functions, a guarded `main`, comments only for the why.
- Existing printed output of `pipeline-stats.mjs` and `sol-ledger.mjs` stays unchanged. New sections are appended, in the row formats of Cross-Task Contracts.
- Shell snippets must run under zsh. Never use `status`, `path`, `argv` or `options` as variable names; use `rc=$?`.
- Task subjects are used as commit messages. Keep them in conventional-commit form as written.
- Task 8's judge fills `sheet.json` before reading `key.json`, `score.json` or any `runs/*/*.meta.json`.

## Tasks

### Task 1: feat(stats): add codex-usage session reader and rates

**Goal:** One module reads Codex session files into runs, is the only home of credit rates, and derives a per-model allowance conversion from clean observations only.

**Files:**
- Create: `scripts/codex-usage.mjs`
- Create: `scripts/codex-usage.test.mjs`

**Acceptance Criteria:**
- Exports `RATES`, `WRAPPER_MARKER`, `WRAPPER_TRAILER`, `rateFor`, `credits`, `readCodexRuns`, `allowanceByModel` and `DEFAULT_CODEX_ROOTS` with the signatures in Cross-Task Contracts.
- `RATES` has exactly the eight model ids of Design §1 with the table's numbers.
- With tokens `{input: 1000000, cached: 900000, output: 4000}`, `credits` returns 8.25 for `gpt-6.1-sol`, 10.5 for `gpt-6-sol` and 21 for `gpt-5.6-sol`.
- `rateFor` matches the exact id only. `rateFor('gpt-7-sol')` and `rateFor('sol')` return `null`, and `credits` then returns `null`.
- `readCodexRuns` walks roots recursively, tolerates a missing root, and takes tokens, `usedPercent`, `windowMinutes`, `resetsAt`, `planType` and `limitAt` from the last `token_count` event of each file. `resetsAt` is in ms. `start` falls back to the first line's timestamp when there is no `session_meta`. With `since`, a run is kept when its `end` is at or after it.
- `wrapper` is true only under the three rules of Design §1 "Wrapper recognition". A file whose only marker is in a tool-output record, or in a user prompt that does not end with the trailer, or whose originator is not `codex_exec`, yields `wrapper: false` and `inputs: null`.
- `inputs` is the text between the first line-initial marker and the last trailer opening. `lastMessage` is the last `task_complete` event's `last_agent_message`, or `null`.
- `allowanceByModel` applies the four clean-observation rules of Design §1. Two sequential runs of one priced model with nothing else between their readings give one observation, with `percent` equal to the reading delta and `credits` equal to the later run's credits.
- The same two runs give zero observations in each of these cases: a run of another model whose interval spans both readings and whose own reading comes later; the later run starting before the earlier run's reading; an unpriced or reading-less third run inside the interval; differing `planType` or `windowMinutes`; `resetsAt` more than 120 s apart.
- `creditsPerPercent` is `null` when a model has no clean observation or its summed `percent` is below 5 points.
- The eight test names listed for this suite exist and pass.

**Verify:** `builder run node --test scripts/codex-usage.test.mjs`

```json:metadata
{"files": ["scripts/codex-usage.mjs", "scripts/codex-usage.test.mjs"], "modelTier": "standard", "verifyCommand": "builder run node --test scripts/codex-usage.test.mjs", "acceptanceCriteria": ["Exports RATES, WRAPPER_MARKER, WRAPPER_TRAILER, rateFor, credits, readCodexRuns, allowanceByModel, DEFAULT_CODEX_ROOTS per Cross-Task Contracts", "RATES has exactly the eight model ids of Design §1 with the table's numbers", "With tokens {input:1000000, cached:900000, output:4000} credits returns 8.25 for gpt-6.1-sol, 10.5 for gpt-6-sol and 21 for gpt-5.6-sol", "rateFor matches the exact id only; rateFor('gpt-7-sol') and rateFor('sol') return null and credits then returns null", "readCodexRuns walks roots recursively, tolerates a missing root, reads tokens, usedPercent, windowMinutes, resetsAt (ms), planType and limitAt from the last token_count event, falls back to the first line's timestamp for start, and with since keeps runs whose end is at or after it", "wrapper is true only under the three recognition rules of Design §1; a marker in tool output, in a prompt not ending with the trailer, or in a non-codex_exec session yields wrapper false and inputs null", "inputs is the text between the first line-initial marker and the last trailer opening; lastMessage is the last task_complete last_agent_message or null", "allowanceByModel applies the four clean-observation rules of Design §1; two sequential same-model runs with nothing else between their readings give one observation with percent = reading delta and credits = the later run's credits", "The same two runs give zero observations when: another model's run spans both readings and reports later; the later run started before the earlier reading; an unpriced or reading-less third run lies inside the interval; planType or windowMinutes differ; resetsAt differ by more than 120 s", "creditsPerPercent is null when a model has no clean observation or its summed percent is below 5 points", "The eight named tests for codex-usage.test.mjs exist and pass"], "blockedBy": []}
```

### Task 2: feat(ledger): report yield per round, add --since

**Goal:** The ledger prints yield per seam and round number and can be limited to rounds on or after a date.

**Files:**
- Modify: `scripts/sol-ledger.mjs`
- Modify: `scripts/sol-ledger.test.mjs`

**Acceptance Criteria:**
- `parseLog` rows and `rows.rounds` entries carry `date` (string, or null when the header has none). Logs without a date or duration still parse.
- `byRound` is exported with the contract signature and counts Critical, Important and other severities separately.
- `main` prints a `— per round —` table as its last table, with rows in the format pinned in Cross-Task Contracts.
- `--since YYYY-MM-DD` filters rounds and rows, prints one line counting excluded undated rounds, and exits 2 on a malformed date.
- Output without `--since` is unchanged above the new table.
- Pre-existing tests pass. Any assertion edited changes only by the added `date` field.
- The three named tests for this suite exist and pass.

**Verify:** `builder run node --test scripts/sol-ledger.test.mjs`

```json:metadata
{"files": ["scripts/sol-ledger.mjs", "scripts/sol-ledger.test.mjs"], "modelTier": "standard", "verifyCommand": "builder run node --test scripts/sol-ledger.test.mjs", "acceptanceCriteria": ["parseLog rows and rounds carry date (string or null); undated and untimed headers still parse", "byRound exported per contract, counting Critical, Important and other separately", "main prints a '— per round —' table as its last table, rows in the format pinned in Cross-Task Contracts", "--since filters rounds and rows, notes excluded undated rounds, exits 2 on a malformed date", "Output without --since is unchanged above the new table", "Pre-existing tests pass; edited assertions differ only by the added date field", "The three named tests for sol-ledger.test.mjs exist and pass"], "blockedBy": []}
```

### Task 3: feat(stats): attribute Sol calls by mode, model, cost

**Goal:** `pipeline-stats` attributes every `codex-critic.sh` call from transcripts, joins it to its Codex run only on identity evidence, records weaker matches as proximity matches, and prints the SOL CALLS section.

**Files:**
- Modify: `scripts/pipeline-stats.mjs`
- Modify: `scripts/pipeline-stats.test.mjs`

**Acceptance Criteria:**
- `WRAPPER_MODES`, `parseWrapperCalls` and `joinRuns` are exported per contract. `summariseHistory` returns `solCalls` from the same single pass.
- `parseWrapperCalls` matches both the literal `codex-critic.sh` path and a `$WRAP` or `${WRAP}` invocation followed by a known mode. It returns an empty array for the preflight `ls` command.
- Round defaults to 1 for `spec`, `plan` and `code`, and to null for other modes. Inline `CODEX_CRITIC_MODEL=` and `CODEX_CRITIC_EFFORT=` are captured.
- `secs` comes from the `took <S>s` line when the result carries one, else from the timestamp delta for a synchronous call, else is null. `background` reflects `run_in_background`. A background call's seconds in the report come from its verified joined run only.
- `launched` is false when the result carries one of the wrapper's four pre-launch messages. Such a call is never joined or matched and is in neither `orphanCalls` nor `ambiguousCalls`.
- `joinRuns` applies the eligibility rule and the evidence order of Design §2. `joined` holds only pairs with `output` or `inputs` evidence. A run whose `cwd` neither equals the call's nor appears in its command is never joined or matched to it.
- One eligible call and one eligible run with no `output` or `inputs` evidence are returned in `proximity` with kind `unique`, and not in `joined`. A same-bucket n-by-n component is returned in `proximity` with kind `group`. Proximity-matched runs are not in `orphanRuns`.
- Two overlapping calls of different modes with no `output` or `inputs` evidence are both returned in `ambiguousCalls`, with their runs in `orphanRuns`. The same two calls with `output` evidence are joined to their own runs.
- With `--since YYYY-MM-DD`, `main` filters the new section only. It exits 2 on a malformed date and does not treat the flag or its value as a root.
- `main` prints the four sections of Design §2 in the row formats pinned in Cross-Task Contracts. Median credits, total credits and share in a SOL CALLS row come from verified joins only; a proximity match's credits appear only in `proximity-credits`. The `note:` line under the table gives joins by evidence and proximity matches by kind.
- The four parts of `reconciled:` sum to its total, with `joined` counting runs in verified joins only. The allowance block prints the latest `used_percent`, window minutes, plan, observation time and reset time, one row per model from `allowanceByModel` called with every run, and the proxy `note:`.
- All credit arithmetic goes through `scripts/codex-usage.mjs`. No rate number appears in this file.
- Pre-existing tests pass unmodified. The ten named tests for this suite exist and pass.

**Verify:** `builder run node --test scripts/pipeline-stats.test.mjs`

```json:metadata
{"files": ["scripts/pipeline-stats.mjs", "scripts/pipeline-stats.test.mjs"], "modelTier": "standard", "verifyCommand": "builder run node --test scripts/pipeline-stats.test.mjs", "acceptanceCriteria": ["WRAPPER_MODES, parseWrapperCalls, joinRuns exported per contract; summariseHistory returns solCalls from the same single pass", "parseWrapperCalls matches literal path and $WRAP/${WRAP} invocations followed by a known mode; returns [] for the preflight ls", "Round defaults to 1 for spec/plan/code and null otherwise; inline model and effort overrides captured", "secs prefers the wrapper took line, then synchronous timestamp delta, else null; background reflects run_in_background; a background call's reported seconds come from its verified joined run only", "launched is false when the result carries one of the wrapper's four pre-launch messages; such a call is never joined or matched and is in neither orphanCalls nor ambiguousCalls", "joinRuns applies the eligibility rule and evidence order of Design §2; joined holds only output or inputs evidence; a run whose cwd neither equals the call's nor appears in its command is never joined or matched to it", "One eligible call and one eligible run without output or inputs evidence are in proximity with kind unique and not in joined; a same-bucket n-by-n component is in proximity with kind group; proximity-matched runs are not in orphanRuns", "Two overlapping calls of different modes without output or inputs evidence are both in ambiguousCalls with their runs in orphanRuns; with output evidence each joins its own run", "--since filters only the new section, exits 2 on a malformed date, and is not treated as a root", "main prints the four sections of Design §2 in the pinned row formats; median credits, total credits and share come from verified joins only; proximity credits appear only in the proximity-credits cell; the note line gives joins by evidence and proximity matches by kind", "reconciled: parts sum to the total with joined counting verified joins only; the allowance block prints used_percent, window minutes, plan, observation time, reset time, per-model rows from allowanceByModel called with every run, and the proxy note", "No rate number in this file; credits come from scripts/codex-usage.mjs", "Pre-existing tests pass unmodified; the ten named tests exist and pass"], "blockedBy": [1]}
```

### Task 4: feat(replay): collect replayable seam cases

**Goal:** `sol-replay.mjs collect` turns history into `cases.json` with ground truth and a skip-reason count for every case it could not use.

**Files:**
- Create: `scripts/sol-replay.mjs`
- Create: `scripts/sol-replay.test.mjs`

**Acceptance Criteria:**
- Exports `CANDIDATES`, `SKIP_REASONS`, `parseInputs`, `critiquePathFor`, `recoverSpecText` and `selectCases` per contract.
- `collect` uses `summariseHistory`, `readCodexRuns`, `joinRuns` and `parseLog` from the existing modules. It does not reimplement transcript, session or ledger parsing.
- Only entries of `joinRuns`'s `joined`, evidence `output` or `inputs`, become cases. A call in `proximity`, of kind `unique` or `group`, or in `ambiguousCalls` is counted as `unverified-join` and never becomes a case.
- `parseInputs` reads `SPEC_DOC`, `WORKTREE`, `BASE_SHA` and `HEAD_SHA` only from `^KEY: value$` lines of the joined run's inputs.
- `recoverSpecText` returns the content of the last `Write` to the spec path before the call. It returns `{skip: 'edited-after-write'}` when an edit tool call on that path sits between, and `{skip: 'no-spec-write'}` when there is none.
- A code case is accepted only when `git cat-file -e <HEAD_SHA>:<specRel>` succeeds, or when `recoverSpecText` supplies the text, which is then stored as `specText`. Otherwise it is counted as `spec-missing-at-sha`. The spec's presence on disk today is not consulted.
- Each excluded case is counted under exactly one of the thirteen `SKIP_REASONS`. `collect` prints the count per reason and the number selected.
- `selectCases` orders newest first, alternates `spec` and `code`, takes at most half the limit (default 20) per seam, and returns a seam with fewer than `minPerSeam` (default 6) eligible cases as `thin`.
- Case ids are the first 12 hex digits of `sha256(seam, round, original Codex session id)`.
- `cases.json` is written under `--out` (default `~/.claude/foureyes-replay`). `collect` makes no model call and writes nothing else. An empty selection exits 0 with the skip table printed.
- The six Task 4 test names for this suite exist and pass.

**Verify:** `builder run node --test scripts/sol-replay.test.mjs`

```json:metadata
{"files": ["scripts/sol-replay.mjs", "scripts/sol-replay.test.mjs"], "modelTier": "standard", "verifyCommand": "builder run node --test scripts/sol-replay.test.mjs", "acceptanceCriteria": ["Exports CANDIDATES, SKIP_REASONS, parseInputs, critiquePathFor, recoverSpecText, selectCases per contract", "collect reuses summariseHistory, readCodexRuns, joinRuns and parseLog rather than reimplementing parsing", "Only entries of joinRuns's joined (evidence output or inputs) become cases; a call in proximity (kind unique or group) or in ambiguousCalls is counted as unverified-join and never becomes a case", "parseInputs reads the four keys only from KEY: value lines of the joined run's inputs", "recoverSpecText returns the last Write before the call, or skip edited-after-write / no-spec-write", "A code case is accepted only when git cat-file -e HEAD_SHA:specRel succeeds or recoverSpecText supplies specText; otherwise spec-missing-at-sha; presence on disk today is not consulted", "Every excluded case is counted under exactly one of the thirteen SKIP_REASONS; counts and selected total are printed", "selectCases orders newest first, alternates spec and code, takes at most half the limit per seam, and returns a seam below minPerSeam (default 6) as thin", "Case ids are the first 12 hex digits of sha256(seam, round, original Codex session id)", "cases.json is written under --out; collect makes no model call and writes nothing else; an empty selection exits 0 with the skip table printed", "The six Task 4 test names for sol-replay.test.mjs exist and pass"], "blockedBy": [1, 3]}
```

### Task 5: feat(replay): run candidates, blind sheet, score recall

**Goal:** `sol-replay.mjs` gains `run`, `sheet` and `score`, so cases can be replayed against candidates, judged blind, and given a mechanical verdict that pays for every retry.

**Files:**
- Modify: `scripts/sol-replay.mjs`
- Modify: `scripts/sol-replay.test.mjs`

**Acceptance Criteria:**
- Exports `candidateSlug`, `pairFingerprint`, `parseFindings`, `labelOrder`, `scoreSheet`, `verdictFor` and `runReplay` per contract.
- `run` without `--yes` prints the call count and estimated credits, spawns nothing, and exits 0.
- `run --yes` exits 4 before any spawn when cases × candidates exceeds 60, or when the latest recorded `usedPercent` is above 80.
- Artifacts are named `runs/<caseId>/<slug>.{out,err,meta.json}`. A pair is skipped only when its meta has status `ok` and the same candidate and fingerprint. A not-`ok` meta with the same candidate and fingerprint gains an attempt; a meta with a different candidate or fingerprint is replaced and its attempts restart at 1. Reordering or changing `--candidates` never makes one candidate's artifact count for another.
- Each attempt clones with `git clone --shared --no-checkout` into `<os.tmpdir()>/foureyes-replay/<caseId>/<8 random hex>`, checks out the case SHA detached, writes `specText` to `specRel` when the case carries it, and rewrites repo and worktree prefixes in the inputs to the clone. The clone is removed afterwards, including on failure.
- If the rewritten `SPEC_DOC` is absent from the clone, the attempt is `failed` with reason `spec-missing`, nothing is spawned, and the attempt records `sessionMatch` `none` and credits `0`.
- Each candidate runs `scripts/codex-critic.sh <seam>` from this repo with `cwd` set to its clone and with `CODEX_CRITIC_MODEL`, `CODEX_CRITIC_EFFORT`, `CODEX_CRITIC_ROUND` and `CODEX_CRITIC_MAX_ROUNDS` set. Candidates of one case run concurrently; cases run sequentially. The per-call timeout is 900 s.
- Each attempt is appended to the meta with `n`, `startedAt`, `endedAt`, `secs`, `status`, `reason`, `clone`, `sessionId`, `sessionMatch` and `credits`, per the `Meta` contract. A matched session whose model or effort differs from the candidate makes the attempt `failed` with reason `model-mismatch`.
- If any candidate is not `ok` after the first case, `run` exits 3 naming the candidate and its reason.
- `sheet` exits 2 on a meta whose candidate or fingerprint does not match. Otherwise it writes `sheet.json` without candidate names or dispositions, omits cases whose control pair is not `ok`, gives no label to a candidate that is not `ok`, and writes `key.json` separately.
- `score` exits 2 listing every missing truth-id and label pair when the sheet is incomplete, and exits 2 on a stale artifact.
- `scoreSheet` uses the cohort of Design §5: one denominator for all arms, and a failed or timed-out candidate case counted as zero recall and `worse`, also when control matched nothing on that case.
- `scoreSheet` computes the paired outcome of Design §5. Tests assert: equal Critical + Important hits with one Minor expected finding matched by control only is `worse`; equal `ci` and `all` where only the candidate re-raises a `rejected` finding is `equal`; higher `ci` with lower `all` is `better`.
- Seconds and credits in `scoreSheet` are cumulative over a meta's attempts, with cumulative credits `null` when any attempt's credits are `null`. Median seconds are taken over the whole cohort. Credit medians for both arms are taken over the priced subset of Design §5, and its size is in the result. Final-attempt medians are present as supplementary fields and are not read by `verdictFor`.
- `verdictFor` applies the six ordered steps of Design §5. Tests assert: with a six-case cohort where control has one 300 s attempt per case and the candidate has a 900 s timeout followed by a 60 s success on five cases, the seconds saving is not met and the verdict is not `holds`; with quality holding, no seconds saving and a priced subset below 80% of the cohort, the verdict is `inconclusive` with a reason naming credit coverage; a credits saving without `creditsPerPercent` for both models never returns `holds`; a failed precondition returns `inconclusive`.
- `score` prints the per-seam, per-candidate figures of Design §4 with the verdict and writes `score.json` with the per-case fields of the `Score` contract.
- The thirteen Task 5 test names for this suite exist and pass. No test invokes the real `codex` CLI.

**Verify:** `builder run node --test scripts/sol-replay.test.mjs`

```json:metadata
{"files": ["scripts/sol-replay.mjs", "scripts/sol-replay.test.mjs"], "modelTier": "standard", "verifyCommand": "builder run node --test scripts/sol-replay.test.mjs", "acceptanceCriteria": ["Exports candidateSlug, pairFingerprint, parseFindings, labelOrder, scoreSheet, verdictFor, runReplay per contract", "run without --yes prints call count and estimated credits, spawns nothing, exits 0", "run --yes exits 4 before any spawn when calls exceed 60 or latest usedPercent is above 80", "Artifacts are named runs/<caseId>/<slug>.{out,err,meta.json}; a pair is skipped only when its meta is ok with the same candidate and fingerprint; a not-ok meta with the same candidate and fingerprint gains an attempt; a meta with a different candidate or fingerprint is replaced and attempts restart at 1; changing --candidates never lets one candidate's artifact count for another", "Each attempt clones with git clone --shared --no-checkout into os.tmpdir()/foureyes-replay/<caseId>/<8 random hex>, detached checkout of the case SHA, specText written to specRel when present, inputs rewritten to the clone, clone removed even on failure", "A rewritten SPEC_DOC absent from the clone makes the attempt failed with reason spec-missing, nothing is spawned, and the attempt records sessionMatch none and credits 0", "Each candidate runs this repo's codex-critic.sh with cwd at its clone and the four CODEX_CRITIC_* variables; candidates concurrent, cases sequential, 900 s timeout", "Each attempt is appended to the meta with n, startedAt, endedAt, secs, status, reason, clone, sessionId, sessionMatch, credits; a matched session with a different model or effort makes the attempt failed with reason model-mismatch", "A candidate not ok after the first case makes run exit 3 naming it and its reason", "sheet exits 2 on a mismatching meta; otherwise sheet.json carries no candidate names or dispositions, omits control-failed cases, gives no label to a non-ok candidate, and key.json is separate", "score exits 2 listing missing truth-id and label pairs on an incomplete sheet, and exits 2 on a stale artifact", "scoreSheet uses the Design §5 cohort: one denominator for all arms; a failed or timed-out candidate case counts as zero recall and worse, also when control matched nothing on it", "scoreSheet computes the Design §5 paired outcome; tests assert: equal Critical+Important hits with one Minor expected finding matched by control only is worse; equal ci and all where only the candidate re-raises a rejected finding is equal; higher ci with lower all is better", "Seconds and credits in scoreSheet are cumulative over a meta's attempts, cumulative credits null when any attempt's credits are null; median seconds over the whole cohort; credit medians for both arms over the priced subset, whose size is in the result; final-attempt medians are supplementary and not read by verdictFor", "verdictFor applies the six ordered steps of Design §5; tests assert: six-case cohort, control one 300 s attempt per case, candidate a 900 s timeout then a 60 s success on five cases gives no seconds saving and a verdict other than holds; quality holding, no seconds saving and a priced subset below 80% of the cohort gives inconclusive with a reason naming credit coverage; a credits saving without creditsPerPercent for both models never returns holds; a failed precondition returns inconclusive", "score prints the Design §4 figures per seam and candidate with the verdict and writes score.json with the per-case fields of the Score contract", "The thirteen Task 5 test names exist and pass; no test invokes the real codex CLI"], "blockedBy": [4]}
```

### Task 6: test(stats): wire new suites and ledger skill docs

**Goal:** The new suites run from `tests/run.sh` and the ledger skill explains how to run and read the new output.

**Files:**
- Modify: `tests/run.sh`
- Modify: `tests/prose-contracts.test.sh`
- Modify: `skills/foureyes-ledger/SKILL.md`

**Acceptance Criteria:**
- `tests/run.sh` lists `codex-usage.test.mjs` and `sol-replay.test.mjs` as explicit `run_suite` lines. It uses no discovery, and its header comment's suite count is corrected.
- `tests/prose-contracts.test.sh` gains checks, in the style of its existing `run.sh` checks, that both new suite names appear in `tests/run.sh` and that `sol-replay.mjs` is named in `skills/foureyes-ledger/SKILL.md`.
- `skills/foureyes-ledger/SKILL.md` documents:
  - `--since` for both existing scripts;
  - how to read the `SOL CALLS` section, including the difference between a verified join and a proximity match and that proximity credits are unverified, the `reconciled:` line, the allowance block with its clean observations, and the `— per round —` table;
  - that credits are a proxy for subscription usage;
  - the four `sol-replay.mjs` subcommands, the four verdicts, that efficiency is judged on cumulative attempts, that `run --yes` spends Codex allowance, and that the sheet is judged before the key is read.
- The skill's frontmatter and its existing sections are otherwise unchanged. It still calls the critic "Sol".
- `bash tests/run.sh` reports 8 passed, 0 failed.

**Verify:** `builder run bash tests/run.sh`

```json:metadata
{"files": ["tests/run.sh", "tests/prose-contracts.test.sh", "skills/foureyes-ledger/SKILL.md"], "modelTier": "standard", "verifyCommand": "builder run bash tests/run.sh", "acceptanceCriteria": ["tests/run.sh lists codex-usage.test.mjs and sol-replay.test.mjs as explicit run_suite lines, no discovery, header count corrected", "prose-contracts.test.sh checks both new suite names in tests/run.sh and sol-replay.mjs in the ledger skill", "The ledger skill documents --since, the SOL CALLS section with verified joins versus proximity matches and unverified proximity credits, the reconciled: line, the allowance block with clean observations, the per round table, that credits are a proxy, and the four sol-replay subcommands with the four verdicts, cumulative-attempt efficiency, and the spend and blind-judging warnings", "Skill frontmatter and existing sections otherwise unchanged; the critic is still called Sol", "bash tests/run.sh reports 8 passed, 0 failed"], "blockedBy": [2, 3, 5]}
```

### Task 7: Gate: instruments reproduce the known baseline

**Goal:** Confirm on the user's real history that attribution and the per-round ledger reproduce the numbers already measured this session, before any credits are spent on replay.

**Files:** none (verification only; runs on the laptop).

**Acceptance Criteria:**
- Observable: exit codes of `node scripts/pipeline-stats.mjs --since 2026-09-30 .` and `node scripts/sol-ledger.mjs --since 2026-09-30` (no path arguments, so it reads `~/.claude/foureyes-repos`), each redirected to a file. Pass: both 0. The Verify command chains them with `&&`, so either failure stops it before `PASS`.
- Observable: the `reconciled:` line. Pass: its total equals the sum of its four parts; the Verify command prints `reconciled_ok=1`.
- Observable: the median-credits cell of the `gpt-6.1-sol/high` row of the by model/effort table. Pass: between 6.2 and 7.6 inclusive. On fail, stop and report the row: the token-accounting assumption is wrong and Task 8 must not start.
- Observable: `spec` and `code` rows of SOL CALLS, summed over rounds. Pass: (joined + proximity) ÷ (calls − not launched) is at least 0.70 for each. The Verify command prints each as `<joined>+<proximity>/<launched>`, so the verified share is visible. On fail, report the ambiguous and orphan counts and the `note:` line under the table, and do not start Task 8.
- Observable: the `spec r1` and `code r1` rows of the `— per round —` table. Pass: at least 64 and at least 61 rounds; the Verify command prints both.
- Observable: rows of the by model/effort table whose median-credits cell is `—`. Pass: none of them has the id `gpt-6.1-sol`. Every such row's id and n is listed in the task report.
- Observable: the last line of the Verify command's output. Pass: exactly `PASS`.
- Evidence reported: the full SOL CALLS section, the allowance block and the per-round table, pasted into the task report. Nothing is written to the repo.

**Verify:** `t=$(mktemp -d) && node scripts/pipeline-stats.mjs --since 2026-09-30 . > "$t/ps.txt" && node scripts/sol-ledger.mjs --since 2026-09-30 > "$t/sl.txt" && awk '/SOL CALLS/{s=1} /by model.effort/{s=2} s==1&&$1=="spec"{sc+=$3-$4;sj+=$5;sp+=$6} s==1&&$1=="code"{cc+=$3-$4;cj+=$5;cp+=$6} s==2&&$1=="gpt-6.1-sol/high"{m=$3} /^reconciled:/{r=($2==$5+$8+$11+$14)} END{print "reconciled_ok=" (r+0), "sol_high_median=" m, "spec=" (sj+0) "+" (sp+0) "/" (sc+0), "code=" (cj+0) "+" (cp+0) "/" (cc+0); exit !(r && m+0>=6.2 && m+0<=7.6 && sc>0 && cc>0 && (sj+sp)/sc>=0.7 && (cj+cp)/cc>=0.7)}' "$t/ps.txt" && awk '/per round/{s=1} s==1&&$1=="spec"&&$2=="r1"{a=$3} s==1&&$1=="code"&&$2=="r1"{b=$3} END{print "spec_r1=" (a+0), "code_r1=" (b+0); exit !(a>=64 && b>=61)}' "$t/sl.txt" && echo PASS`

```json:metadata
{"files": [], "modelTier": "standard", "verifyCommand": "t=$(mktemp -d) && node scripts/pipeline-stats.mjs --since 2026-09-30 . > \"$t/ps.txt\" && node scripts/sol-ledger.mjs --since 2026-09-30 > \"$t/sl.txt\" && awk '/SOL CALLS/{s=1} /by model.effort/{s=2} s==1&&$1==\"spec\"{sc+=$3-$4;sj+=$5;sp+=$6} s==1&&$1==\"code\"{cc+=$3-$4;cj+=$5;cp+=$6} s==2&&$1==\"gpt-6.1-sol/high\"{m=$3} /^reconciled:/{r=($2==$5+$8+$11+$14)} END{print \"reconciled_ok=\" (r+0), \"sol_high_median=\" m, \"spec=\" (sj+0) \"+\" (sp+0) \"/\" (sc+0), \"code=\" (cj+0) \"+\" (cp+0) \"/\" (cc+0); exit !(r && m+0>=6.2 && m+0<=7.6 && sc>0 && cc>0 && (sj+sp)/sc>=0.7 && (cj+cp)/cc>=0.7)}' \"$t/ps.txt\" && awk '/per round/{s=1} s==1&&$1==\"spec\"&&$2==\"r1\"{a=$3} s==1&&$1==\"code\"&&$2==\"r1\"{b=$3} END{print \"spec_r1=\" (a+0), \"code_r1=\" (b+0); exit !(a>=64 && b>=61)}' \"$t/sl.txt\" && echo PASS", "acceptanceCriteria": ["Both node commands exit 0 with output redirected to files; the && chain stops before PASS on either failure", "The reconciled: total equals the sum of its four parts; the Verify command prints reconciled_ok=1", "The median-credits cell of the gpt-6.1-sol/high row is between 6.2 and 7.6 inclusive; otherwise stop and report the row, Task 8 must not start", "For spec and for code, summed over rounds, (joined + proximity) / (calls - not launched) is at least 0.70, printed as <joined>+<proximity>/<launched>; otherwise report ambiguous and orphan counts and the note: line under the table, Task 8 must not start", "The per round table shows at least 64 rounds in the spec r1 row and at least 61 in the code r1 row", "No by model/effort row with a median-credits cell of — has the id gpt-6.1-sol; every unpriced row's id and n is listed in the task report", "The last line of the Verify command's output is exactly PASS", "The SOL CALLS section, the allowance block and the per round table are pasted into the task report; nothing is written to the repo"], "blockedBy": [6]}
```

### Task 8: docs(efficiency): run the replay, write the results

**Goal:** Execute the paired replay across the three candidates, judge it blind, and commit the results document the later defaults run will consume.

**Files:**
- Create: `docs/foureyes/specs/2026-11-14-foureyes-efficiency-results.md`

**Acceptance Criteria:**
- `node scripts/sol-replay.mjs collect` was run and its selected count and skip-reason counts are in the document's `## Replay` section.
- If `collect` selected at least one case:
  - `run --yes` was executed with the default `CANDIDATES`, re-run until no pair remains retryable or two passes have been made;
  - `sheet.json` was filled before `key.json` was read;
  - `score` exited 0.
- Otherwise no paid call was made, and `## Replay` states that replay was infeasible and why, from the skip table.
- `## Replay` reports, per seam and candidate, the figures `score` printed: cohort size and `control-failed` cases, completed and failed cases, recall of `fixed` (all severities, and Critical + Important) beside control's, re-raised `rejected` count, the paired worse/equal/better counts, median findings, median cumulative seconds, the priced subset's size and share, median cumulative credits labelled as a proxy, the supplementary final-attempt medians labelled as such, and total credits spent. It quotes the rule of Design §5, including the paired-outcome rule, and gives the verdict and basis exactly as `score` printed them. A seam that was not replayed is reported `inconclusive: too few cases`.
- For every verdict `holds on credits proxy only`, and for every model whose allowance row reads `insufficient`, the document states that no subscription saving is established and names the evidence the later run needs: clean observations of that model, run alone, summing to at least 5 points of the meter.
- `## Attribution` carries the SOL CALLS table with its `note:` line, the `reconciled:` line and the allowance block from Task 7's run. One paragraph states what the 1,682-versus-280 gap consists of, and one sentence states that proximity matches are unverified and in no cost cell.
- `## Per-round yield` carries the per-round table and the coordinator's recorded round-2 split from the approaches file, cited as already measured.
- `## Role table` has one row for every role named in the brief. Each row gives the current setting, measured volume, time and cost where available, an evidence status (`replayed`, `attributed only` or `not measured`), the candidate change for the later run or `none`, and its basis (`seconds`, `allowance`, `credits proxy only` or `none`). No row proposes a change for a seam and candidate whose verdict is `does not hold` or `inconclusive`. Every Claude-side role has status `not measured`.
- `## Limits of this measurement` states: the sample size; that fidelity is reconstructed; that the judge was a model on a blinded sheet; that credits are a proxy for subscription usage; and that no significance is claimed. It states that Claude-side tokens were not measured in this run, that the evidence for the later role analysis is the subagent transcripts under each session's `subagents/` directory with `message.model` and `usage` per record, and that their historical coverage is thin and has not been counted.
- The document contains no absolute path, no consumer repo name, no finding text, and nowhere the phrase `not measurable`.
- No file other than the results document is changed in the repo.

**Verify:** `f=docs/foureyes/specs/2026-11-14-foureyes-efficiency-results.md; test -s "$f" && ! grep -q '/Users/' "$f" && ! grep -q 'not measurable' "$f" && grep -q 'proxy' "$f" && test "$(grep -c -E '^## (Attribution|Per-round yield|Replay|Role table|Limits of this measurement)$' "$f")" -eq 5 && git diff --quiet HEAD -- scripts agents skills && echo PASS`

```json:metadata
{"files": ["docs/foureyes/specs/2026-11-14-foureyes-efficiency-results.md"], "modelTier": "frontier", "verifyCommand": "f=docs/foureyes/specs/2026-11-14-foureyes-efficiency-results.md; test -s \"$f\" && ! grep -q '/Users/' \"$f\" && ! grep -q 'not measurable' \"$f\" && grep -q 'proxy' \"$f\" && test \"$(grep -c -E '^## (Attribution|Per-round yield|Replay|Role table|Limits of this measurement)$' \"$f\")\" -eq 5 && git diff --quiet HEAD -- scripts agents skills && echo PASS", "acceptanceCriteria": ["collect was run; selected count and skip-reason counts are in the Replay section", "With at least one selected case: run --yes executed with default CANDIDATES (at most two passes), sheet.json filled before key.json was read, score exited 0", "Otherwise no paid call was made and the Replay section states replay was infeasible and why", "Replay section reports per seam and candidate the figures score printed (including median cumulative seconds, the priced subset's size and share, median cumulative credits as a proxy, and final-attempt medians labelled supplementary), quotes the Design §5 rule with the paired-outcome rule, and gives verdict and basis exactly as score printed them; an unreplayed seam is reported inconclusive: too few cases", "For every 'holds on credits proxy only' verdict and every model with an insufficient allowance row, the document states no subscription saving is established and names the evidence the later run needs: clean observations of that model, run alone, summing to at least 5 points", "Attribution section carries the SOL CALLS table with its note: line, the reconciled: line, the allowance block, one paragraph explaining the 1,682 vs 280 gap, and one sentence that proximity matches are unverified and in no cost cell", "Per-round yield section carries the per round table and cites the coordinator's recorded round-2 split", "Role table has a row for every role in the brief with current setting, measurements, evidence status (replayed, attributed only or not measured), candidate change or none, and basis; no row proposes a change where the verdict is does not hold or inconclusive; every Claude-side role has status not measured", "Limits section states sample size, reconstructed fidelity, model judge on a blinded sheet, credits as a proxy, no significance claimed; and that Claude-side tokens were not measured in this run, that the evidence for the later role analysis is the subagent transcripts under each session's subagents/ directory with message.model and usage per record, and that their historical coverage is thin and uncounted", "The document contains no absolute path, no consumer repo name, no finding text, and nowhere the phrase 'not measurable'", "No file other than the results document is changed in the repo"], "blockedBy": [7]}
```
