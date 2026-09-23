#!/usr/bin/env bash
# Contract tests for the SKILL/agent prose itself.
#
# The node + wrapper suites test code. Nearly all of this plugin is prose, and
# prose regresses silently: an edit that dispatches a Claude reviewer at a Codex
# seam, or drops CODEX_CRITIC_ROUND, or renames a verdict field the wrapper
# parses, breaks the design while every existing test stays green.
#
# These assertions are deliberately structural — they check invariants the design
# rests on, never wording. Deterministic, no model calls, milliseconds.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$HERE/.."
SK="$ROOT/skills"; AG="$ROOT/agents"

# Phrase assertions must survive line wrapping and inline markdown. grep is
# line-based, so a phrase split across two lines silently fails and the assertion
# looks broken when the prose is fine — this cost three false failures before I
# stopped reflowing prose to satisfy grep and fixed the matcher instead.
has() { tr '\n' ' ' < "$1" | tr -s ' ' | sed 's/\*\*//g' | grep -qi -- "$2"; }
B_MARK="<!-- SHARED-TEMPLATE-BEGIN -->"; E_MARK="<!-- SHARED-TEMPLATE-END -->"
tpl() { awk -v b="$B_MARK" -v e="$E_MARK" '$0==b{f=1;next} $0==e{f=0} f' "$1"; }
wf()  { awk -v b="$B_MARK" -v e="$E_MARK" '$0==b{nb++;ib=NR} $0==e{ne++;ie=NR} END{print (nb==1&&ne==1&&ib<ie)?"ok":"bad"}' "$1"; }
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ok  - $1"; }
bad()  { FAIL=$((FAIL+1)); echo "  FAIL - $1"; }
check(){ if eval "$2"; then ok "$1"; else bad "$1"; fi; }

BS="$SK/foureyes-brainstorm/SKILL.md"
BD="$SK/foureyes-build/SKILL.md"
RV="$SK/foureyes-review/SKILL.md"
IV="$SK/foureyes-investigate/SKILL.md"

echo "--- the plugin is self-contained ---"
# Skills must never invoke another plugin's skills. The discriminator is the
# NAMESPACE COLON: a dependency is always `superpowers-extended-cc:<skill>`, while
# a prose citation ("...is superpowers-extended-cc's convention") never is. Matching
# the bare name would forbid citing where a borrowed idea came from, which is
# provenance worth keeping.
check "1a no skill invokes superpowers-extended-cc" \
  '! grep -rq "superpowers-extended-cc:" "$SK"'
check "1b every Invoke Skill target is our own namespace" \
  '! grep -rhn "Invoke Skill" "$SK" | grep -qv "foureyes:"'

echo "--- every Codex mode a skill calls has a prompt file ---"
# codex-critic.sh resolves agents/foureyes-<mode>-critic.md by name, so a skill
# referencing a mode we never wrote fails only at runtime, mid-pipeline.
for m in $(grep -rho '"\$WRAP" [a-z]*' "$SK" | awk '{print $2}' | sort -u); do
  check "2 mode '$m' has agents/foureyes-$m-critic.md" \
    '[ -f "$AG/foureyes-'"$m"'-critic.md" ]'
done

echo "--- Codex owns every critique; Claude never reviews at a seam ---"
# The whole thesis: the author and the critic are different model families. If a
# seam ever dispatches one of the critic agents as a Claude subagent, that is
# gone — and nothing else in the suite would notice.
for a in spec-critic code-critic; do
  check "3 no skill dispatches foureyes-$a as a subagent" \
    '! grep -rq "subagent_type: foureyes-'"$a"'" "$SK"'
done

echo "--- doc seams stay round-budgeted ---"
# A seam that forgets CODEX_CRITIC_ROUND runs unbudgeted: the wrapper defaults to
# round 1 forever, and drafter<->critic never converges.
for m in spec; do
  check "4 brainstorm '$m' seam passes CODEX_CRITIC_ROUND" \
    'grep -B3 "\"\$WRAP\" '"$m"'" "$BS" | grep -q "CODEX_CRITIC_ROUND="'
done
check "4 build code seam passes CODEX_CRITIC_ROUND" \
  'grep -B3 "\"\$WRAP\" code" "$BD" | grep -q "CODEX_CRITIC_ROUND="'
# approach is a one-shot proposer, NOT a seam — a round would budget it away.
check "4 approach seam passes NO round" \
  '! grep -B3 "\"\$WRAP\" approach" "$BS" | grep -q "CODEX_CRITIC_ROUND="'

echo "--- every wrapper call site carries the timeout ---"
# Measured: real Codex calls run ~5 min. The Bash default is 120s, and a timeout
# arrives with no VERDICT and no GATE line — indistinguishable from a failed critic.
for f in "$BS" "$BD" "$RV" "$IV"; do
  check "5 $(basename "$(dirname "$f")") states timeout: 600000" \
    'grep -q "600000" "$f"'
done

echo "--- critic prompts emit the grammar the wrapper parses ---"
# codex-critic.sh keys on ^VERDICT: and counts ^- [Critical] / ^- [Important].
# Rewording a critic's output format silently zeroes those counts, and the gate
# then reports clean.
for a in spec code; do
  check "6a $a-critic specifies a VERDICT line" \
    'grep -q "^VERDICT:" "$AG/foureyes-'"$a"'-critic.md"'
  check "6b $a-critic specifies [Critical] findings" \
    'grep -q "\[Critical\]" "$AG/foureyes-'"$a"'-critic.md"'
done

echo "--- Fable authors, and only Fable ---"
check "7a drafter pins model: fable" \
  'grep -q "^model: fable" "$AG/foureyes-drafter.md"'
check "7b brainstorm dispatches the drafter for spec and plan" \
  '[ "$(grep -c "foureyes-drafter" "$BS")" -ge 2 ]'
check "7c the drafter has no write tools" \
  '! grep "^tools:" "$AG/foureyes-drafter.md" | grep -qE "\bWrite\b|\bEdit\b"'

echo "--- implementers cannot commit, and cannot roam ---"
# Wave parallelism is sound only because implementers stay inside their files
# list and never touch the index.
check "8a implementer forbids committing" \
  'grep -qi "never commit" "$AG/foureyes-implementer.md"'
check "8b implementer forbids writing outside its files list" \
  'grep -qi "outside your assignment.s Files list" "$AG/foureyes-implementer.md"'
check "8c build says the coordinator commits at the join" \
  'grep -qi "implementers never commit" "$BD"'

echo "--- verification gates produce no commit ---"
# A task with files:[] verifies rather than builds. Without an explicit exemption,
# E4's nonempty-commit rule forces every plan to invent an artifact for its gates,
# and that invented file then contradicts the spec's file list. Found by running
# the pipeline, not by reading it.
check "11a build exempts empty-files tasks from the commit rule" \
  'grep -q "files\` is \`\[\]\` is a verification gate" "$BD"'
check "11b build still requires a commit for nonempty files" \
  'grep -q "NONEMPTY \`files\` list" "$BD"'
check "11c the drafter knows to emit files: \[\] for gates" \
  'grep -q "only VERIFIES declares" "$AG/foureyes-drafter.md"'

echo "--- the brief itself can be questioned ---"
# The coordinator takes the brief as given and so does every stage after it. The
# proposers are the ONLY place a bad premise is cheap to catch. Today this cost
# two built tasks and a revert before a human noticed.
check "12a drafter may return 'Do not build this'" \
  'grep -q "Do not build this" "$AG/foureyes-drafter.md"'
check "12b approach proposer may too" \
  'grep -q "Do not build this" "$AG/foureyes-approach-critic.md"'
check "12c brainstorm handles it surviving alone" \
  'grep -q "ONLY survivor\|ONLY entry" "$BS"'

echo "--- every doc/code seam records what became of its findings ---"
# The ledger is the only instrument that can retire a seam. A seam that stops
# logging goes silent, and its column in astra-ledger.mjs quietly reads as clean
# rather than as absent — nothing else in the suite would notice.
check "13a brainstorm defines the critique-log grammar" \
  'grep -q "critique.md" "$BS" && grep -q "round <n>" "$BS"'
check "13b build's code seam logs to the same file" \
  'grep -q "critique.md" "$BD" && grep -q "## code · round" "$BD"'
for d in fixed rejected intentional open; do
  check "13c disposition '$d' is defined in brainstorm" \
    'grep -q "\`'"$d"'\`" "$BS"'
done
# Parsed as `- [Sev] <disposition> — <text>`, so the disposition MUST lead.
# A trailing one is unparseable the moment a finding contains an em-dash.
check "13d the log grammar puts the disposition before the em-dash" \
  'grep -q "disposition> — <the finding" "$BS"'
check "13e both skills resolve the ledger reader" \
  'grep -q "astra-ledger.mjs" "$BS" && grep -q "astra-ledger.mjs" "$BD"'
check "13f the reader is on the deterministic suite list" \
  'grep -q "astra-ledger.test.mjs" "$HERE/run.sh"'

echo "--- an uncritiqued spec asks, and never auto-runs brainstorm ---"
# Step 0.5 offering to critique must stay an offer. Invoking brainstorm here
# would make `foureyes-build <spec>` silently slower than the user asked for.
check "14a build detects a spec with no spec-seam entry" \
  'grep -q "Has Astra ever read this spec" "$BD" && grep -q "'"'"'^## spec '"'"'" "$BD"'
check "14b it asks rather than deciding" \
  'grep -A12 "Has Astra ever read this spec" "$BD" | grep -q "AskUserQuestion"'
check "14c it never invokes brainstorm from that branch" \
  'grep -A12 "Has Astra ever read this spec" "$BD" | grep -q "never invoke brainstorm"'

echo "--- inline brainstorm hands back instead of stopping ---"
# build invokes brainstorm with --continue and goes straight to execution. Step 5
# used to be titled "Hard stop" with the --continue exception as its LAST bullet,
# so the model read a whole section framed as stopping before reaching the one
# line saying not to, and paused for HTML approval mid-build anyway. The mode has
# to be decided BEFORE the report. 14e is the assertion that actually bites: it
# fails the moment the branch drifts back below the report body.
s5()  { sed -n '/^## Step 5/,$p' "$BS"; }
s5n() { s5 | grep -n -i -e "$1" | head -1 | cut -d: -f1; }
check "14d build invokes brainstorm with --continue" \
  'grep -A2 "Invoke Skill .foureyes:foureyes-brainstorm" "$BD" | grep -q -e "--continue"'
check "14e brainstorm picks the mode before writing the report" \
  'a=$(s5n "--continue"); b=$(s5n "print the paths"); [ -n "$a" ] && [ -n "$b" ] && [ "$a" -lt "$b" ]'
check "14f the --continue branch forbids asking" \
  'has "$BS" "ask NOTHING"'
check "14g standalone still stops" \
  's5 | grep -qi "standalone.*STOP"'

echo "--- transient failures retry, then degrade — never wait on the user ---"
# The pipeline is left unattended. A timed-out Astra call used to be handed back as
# "offer --skip-critics" — a question nobody was there to answer, so the run did
# nothing. 16a is the rule; 16b is the assertion that bites: it fails the moment
# a skill drifts back to offering the flag instead of retrying and continuing.
for f in "$BS" "$BD" "$RV" "$IV"; do
  n=$(basename "$(dirname "$f")")
  check "16a $n carries the three-attempt retry rule" \
    'has "$f" "3 attempts in total"'
  check "16b $n never offers --skip-critics as a timeout response" \
    '! has "$f" "offer .--skip-critics"'
done
check "16c build retries a silent implementer before calling it blocked" \
  'grep -q "^| _no status_.*3 attempts in total" "$BD"'

echo "--- run dirs never land in the worktree ---"
# Both tools write run artifacts inside the git dir: this plugin ships no
# .gitignore into consumer repos, so a worktree path leaves a stray directory in
# every repo it touches — and for review, inside the diff being reviewed.
check "15a review's run dir is under the git dir" \
  'grep -q "git rev-parse --git-dir)/foureyes-review" "$RV"'
check "15b review no longer writes a bare worktree path" \
  '! grep -q "RUN=\"\.foureyes-review" "$RV"'
check "15c build's run dir is under the git dir" \
  'grep -q "<gitdir>/foureyes-build/" "$BD"'

echo "--- --skip-critics states what it costs ---"
# With Astra off, E5 is a Claude subagent reviewing Claude's work: nothing in the
# run crosses model families, which is the entire premise of the plugin.
check "16 build says skip-critics leaves no cross-model check" \
  'grep -q "nothing in the run crosses model families" "$BD"'

echo "--- the ledger is reachable from the repos it reports on ---"
# The logs are written into CONSUMER repos; the reader ships here. Without an
# entry point, reading them means typing a cache glob, which means never.
check "17a a ledger skill exists" \
  '[ -f "$SK/foureyes-ledger/SKILL.md" ]'
check "17b it resolves the reader script" \
  'grep -q "astra-ledger.mjs" "$SK/foureyes-ledger/SKILL.md"'
check "17c it says the logs live in other repos" \
  'grep -qi "repos you BUILD in\|consumer repo" "$SK/foureyes-ledger/SKILL.md"'
check "17e it documents the no-argument repo list" \
  'grep -q "foureyes-repos" "$SK/foureyes-ledger/SKILL.md"'
# Real projects nest. A resolver that stopped at the top-level match would report
# on a fraction of the specs and read as a quiet repo, which is the exact
# misreading this instrument exists to prevent.
check "17f it says umbrellas expand to every nested specs dir" \
  'grep -qi "umbrella" "$SK/foureyes-ledger/SKILL.md"'
# Skills are addressed by directory name; a frontmatter mismatch makes one
# unroutable while every other test stays green.
for d in "$SK"/*/; do
  n=$(basename "$d")
  check "17d skill '$n' frontmatter name matches its directory" \
    '[ "$(awk "/^name:/{print \$2; exit}" "'"$d"'SKILL.md")" = "'"$n"'" ]'
done

echo "--- the drafter bounds itself, because nothing else can ---"
# The Agent tool has no timeout parameter, so the coordinator CANNOT interrupt a
# subagent. Measured over 68 real dispatches: 9 ran past 15 minutes and returned
# under 3KB — up to 51 minutes for nothing, recoverable only by killing the
# session. Every guard here is self-imposed; there is no external one to add.
DR="$AG/foureyes-drafter.md"
PS="$ROOT/scripts/pipeline-stats.mjs"
check "18a drafter is told to orient, not audit" \
  'grep -qi "Orient, do not audit" "$DR"'
check "18b drafter never retries a slow network call" \
  'grep -qi "Never retry a network call that was slow" "$DR"'
check "18c drafter must return a partial rather than nothing" \
  'grep -q "RETURN SOMETHING" "$DR" && grep -q "## Unresolved" "$DR"'
check "18d drafter self-reports its tool counts" \
  'grep -q "DRAFTER-STATS:" "$DR"'
check "18e brainstorm strips the stats line before writing" \
  'grep -q "DRAFTER-STATS" "$BS"'
# A plugin others install must not ship one deployment's numbers as if they were
# universal. Where a norm is needed, point at the tool that computes theirs.
check "18f brainstorm sources timing from the user's own history" \
  'grep -q "pipeline-stats.mjs" "$BS" && grep -qi "Do not quote a number from this file" "$BS"'
check "18g no invented per-run constants survive in the drafter" \
  '! grep -qE "capped at [0-9]+ tool calls|[0-9]+ network calls total|under ~?[0-9]+KB" "$DR"'

echo "--- a large drafter return is read from disk, never re-dispatched blind ---"
# Measured over 90 drafter dispatches: 20 returns were too large and got spilled
# to disk behind a 2KB preview, and one died on the 64k output-token ceiling
# after 51 minutes. The drafter is the only subagent with this problem.
check "21d brainstorm reads a spilled return instead of writing the preview" \
  'grep -q "persisted-output" "$BS" && grep -qi "Read that path" "$BS"'
check "21e brainstorm never re-dispatches an over-limit assignment unchanged" \
  'grep -q "64000 output" "$BS" && grep -qi "do NOT.*re-dispatch" "$BS"'
check "21g the reader classifies spill and over-limit distinctly" \
  'grep -q "over-limit" "$PS" && grep -q "spilled" "$PS"'
check "22j the token ceiling is read from the environment, not hardcoded" \
  'grep -q "CLAUDE_CODE_MAX_OUTPUT_TOKENS" "$DR"'

echo "--- inert plan metadata is reported, never honoured ---"
check "19a plan-viz declares the keys build actually reads" \
  'grep -q "export const FENCE_KEYS" "$SK/foureyes-brainstorm/lib/plan-viz.mjs"'
check "19b it flags keys nothing reads" \
  'grep -q "unknown-key" "$SK/foureyes-brainstorm/lib/plan-viz.mjs"'
check "19c build ignores such a field rather than acting on it" \
  'grep -A3 "unknown-key" "$BD" | grep -qi "IGNORE the field"'

echo "--- the history reader guards what no prose test can ---"
# A prose test greps skill text. It cannot see the coordinator dispatching a
# Codex-only critic as a Claude subagent, which happened 143 times.
check "20a pipeline-stats exists" '[ -f "$PS" ]'
check "20b it names the three Codex-only critics" \
  'grep -q "foureyes-spec-critic" "$PS" && grep -q "foureyes-code-critic" "$PS"'
check "20c review/refute critics are NOT treated as misroutes" \
  '! grep -q "CODEX_ONLY.*review-critic" "$PS"'
check "20d the ledger skill runs it too" \
  'grep -q "pipeline-stats.mjs" "$SK/foureyes-ledger/SKILL.md"'
check "20e it is on the deterministic suite list" \
  'grep -q "pipeline-stats.test.mjs" "$HERE/run.sh"'

echo "--- speed is orthogonal to effort, and never half-applied ---"
WR="$ROOT/scripts/codex-critic.sh"
check "23a the wrapper honours a speed knob" \
  'grep -q "CODEX_CRITIC_SPEED" "$WR"'
# codex discards the tier when fast_mode is off, so one without the other is a
# silent no-op. They must be emitted by the same branch.
check "23b fast_mode and service_tier ship together" \
  'grep -q "enable fast_mode -c service_tier" "$WR"'
check "23c asking for fast never lowers effort" \
  '! grep -qE "SPEED.*EFFORT=|fast.*EFFORT=(low|medium|minimal)" "$WR"'
# macOS baseline is bash 3.2, where "${ARR[@]}" on an EMPTY array under set -u is
# fatal. An array here kills the DEFAULT path while fast keeps working.
check "23d no empty-array expansion in the wrapper" \
  '! grep -q "SPEED_ARGS\[@\]" "$WR"'
check "23e the knob is documented for users" \
  'grep -q "CODEX_CRITIC_SPEED" "$ROOT/README.md"'
# Fast is 2.5x the usage on gpt-6-astra for the same output, and a critic runs
# unattended — nobody is waiting on the minutes it saves. It is opt-in.
check "23f normal is the default; fast is opt-in" \
  'grep -q "CODEX_CRITIC_SPEED:-normal" "$WR"'
# SEARCH=0 was recommended for latency on no evidence it was ever dead weight.
# The drafter has web access; a critic without it reviews from weaker information
# than the document it is reviewing.
check "23g search is documented on, and never recommended off" \
  'has "$ROOT/README.md" "CODEX_CRITIC_SEARCH" && ! has "$ROOT/README.md" "SEARCH=0"'
check "23h both skills say how to opt in to the tier" \
  'grep -q "CODEX_CRITIC_SPEED=fast" "$BS" && grep -q "CODEX_CRITIC_SPEED=fast" "$BD"'

echo "--- the misroute is now PREVENTED, not only detected ---"
# 143 real dispatches sent these to Claude subagents. Assertion 3 was green the
# whole time: it greps skill prose and cannot see what a coordinator did. The
# frontmatter description is what Claude reads when choosing an agent, and
# codex-critic.sh strips frontmatter, so it is the one place a warning reaches
# Claude and never reaches Codex.
for a in spec code; do
  check "24a $a-critic's description forbids subagent dispatch" \
    'awk "/^---/{n++} n==1" "$AG/foureyes-'"$a"'-critic.md" | grep -qi "NOT A CLAUDE SUBAGENT"'
  check "24b $a-critic's body tells a Claude subagent to stop" \
    'grep -qi "you were dispatched wrongly" "$AG/foureyes-'"$a"'-critic.md"'
done
# review/refute go to BOTH families on purpose and must NOT carry the guard.
for a in review refute; do
  check "24c $a-critic is not falsely guarded" \
    '! grep -qi "NOT A CLAUDE SUBAGENT" "$AG/foureyes-'"$a"'-critic.md"'
done

echo "--- unobserved is not failure ---"
# Subagents run in the background by default and their completion carries no link
# back to the dispatch, so half of them have no recorded outcome. Reporting that
# gap as failure overstates the failures.
check "26a the history table separates unseen from failed" \
  'grep -q "unseen" "$PS"'
check "26b it says unseen is not a failure" \
  'grep -qi "outcome NOT RECORDED — not a failure" "$PS"'

echo "--- effort is actually applied, not merely tabulated ---"
# The Agent tool has NO effort parameter, so an effort column in a routing table
# applies to nothing. Measured over 114 transcripts before this: xhigh on 99.7%
# of turns, inherited from the session — including Sonnet implementers, where
# high effort buys Opus-class cost at lower fidelity. Frontmatter is the only
# mechanism that works (Anthropic's own claude-security plugin pins it too).
for a in drafter implementer implementer-frontier task-reviewer review-critic refute-critic; do
  check "27a $a pins effort in frontmatter" \
    'awk "/^---/{n++} n==1 && /^effort:/{print}" "$AG/foureyes-'"$a"'.md" | grep -q .'
done
check "27b mechanical and standard both run medium" \
  'awk "/^---/{n++} n==1 && /^effort:/{print \$2}" "$AG/foureyes-implementer.md" | grep -qx medium'
check "27c frontier runs high" \
  'awk "/^---/{n++} n==1 && /^effort:/{print \$2}" "$AG/foureyes-implementer-frontier.md" | grep -qx high'
# Two implementer files exist ONLY because effort cannot vary per dispatch. If
# their bodies drift, the wave-safety rules differ by tier and nothing else notices.
bodyof() { python3 -c "import sys;s=open(sys.argv[1]).read();print(s[s.index(chr(10)+chr(45)*3+chr(10),3)+5:],end='')" "$1"; }
# Rule 2 bounds which FILES may be touched; nothing bounded how much of a file.
# An implementer allowed to edit auth.ts could reformat the whole thing, burying
# the change its reviewer was asked to check — and forcing a sibling's reviewer
# to read the same file twice, since they share the tree.
check "27i implementers are bounded inside a file, not just across files" \
  'grep -qi "Surgical changes" "$AG/foureyes-implementer.md" && has "$AG/foureyes-implementer.md" "every changed line traces directly to the task"'
check "27d the two implementer bodies are byte-identical" \
  '[ "$(bodyof "$AG/foureyes-implementer.md")" = "$(bodyof "$AG/foureyes-implementer-frontier.md")" ]'
# A JSON routing file cannot override frontmatter-pinned effort, so honouring one
# could change the model but not the effort — a combination nobody chose. The
# mechanism is gone; this stops it coming back, and stops such a file shipping.
check "27g no external routing file is honoured" \
  '! grep -q "model-routing.json" "$BD"'
check "27h and none ships in the repo" \
  '! ls "$ROOT"/docs/*/model-routing.json >/dev/null 2>&1'
check "27e build routes frontier to the frontier agent" \
  'grep -q "foureyes-implementer-frontier" "$BD"'
# Codex-only critics are never dispatched as Claude subagents and the wrapper
# strips frontmatter — an effort pin there would imply they are dispatchable.
for a in spec code approach investigate; do
  check "27f $a-critic carries no effort pin" \
    '! awk "/^---/{n++} n==1 && /^effort:/{print}" "$AG/foureyes-'"$a"'-critic.md" | grep -q .'
done

echo "--- investigation proves, it does not merely opine ---"
# A bug has a ground truth, so two models agreeing on a wrong cause is WORSE than
# one: agreement reads as confirmation and sends someone to fix working code.
check "28a agreement is explicitly not a verdict" \
  'has "$IV" "Agreement is a prior, never a verdict"'
check "28b hypotheses are tested cheapest-disproof first" \
  'has "$IV" "cheapest-disproof-first"'
check "28c an untested hypothesis never counts as surviving" \
  'has "$IV" "INCONCLUSIVE" && has "$IV" "Never promote it to .SURVIVES"'
check "28d not-established is a real outcome" \
  'has "$IV" "NOT ESTABLISHED" && has "$IV" "This is a successful run"'
# The whole command is advisory. A fix here would skip the pipeline entirely.
check "28e-2 the report it must write is not forbidden by its own rule" \
  '! has "$IV" "no new files in the worktree"'
check "28e it never fixes code" \
  'has "$IV" "This command changes NO CODE" && has "$IV" "Do not fix anything"'
check "28f scouts gather but never name a cause" \
  'has "$AG/foureyes-scout.md" "You do not diagnose"'
# Two blind proposers are only worth two while they stay blind.
check "28g both proposers emit the same template" \
  '[ "$(tpl "$AG/foureyes-investigate-critic.md")" = "$(tpl "$AG/foureyes-investigator.md")" ]'
check "28h both templates are well-formed" \
  '[ "$(wf "$AG/foureyes-investigate-critic.md")" = ok ] && [ "$(wf "$AG/foureyes-investigator.md")" = ok ]'
check "28i the pooled list may not gain a coordinator theory" \
  'has "$IV" "may not test a hypothesis neither proposer named"'
check "28j the evidence loop is round-budgeted" \
  'has "$IV" "at most 2 rounds"'
check "28k Astra rounds are priced by the ledger like every other seam" \
  'grep -q "## investigate · round" "$IV"'

echo "--- read-only agents stay read-only ---"
for a in approach-critic investigate-critic spec-critic code-critic task-reviewer review-critic refute-critic scout investigator; do
  check "9 $a has no Write/Edit tool" \
    '! grep "^tools:" "$AG/foureyes-'"$a"'.md" | grep -qE "\bWrite\b|\bEdit\b"'
done

echo "--- every agent file is well-formed ---"
for f in "$AG"/*.md; do
  n=$(basename "$f" .md)
  check "10 $n frontmatter name matches filename" \
    '[ "$(awk "/^name:/{print \$2; exit}" "$f")" = "'"$n"'" ]'
done

echo "--- the spec owns the tasks; there is no separate plan ---"
# The implementation plan, its Steps field, and the parts/splice protocol are
# gone. A skill that still calls "$WRAP" plan, or an implementer that still
# expects a Steps field, is running the deleted design.
check "29a no skill calls \"\$WRAP\" plan" \
  '! grep -rq "\"\$WRAP\" plan" "$SK"'
check "29b the drafter has no Steps field, and emits spec structure" \
  '! has "$AG/foureyes-drafter.md" "Steps:" && grep -q "## Cross-Task Contracts" "$AG/foureyes-drafter.md" && grep -q "## Global Constraints" "$AG/foureyes-drafter.md" && grep -q "## Tasks" "$AG/foureyes-drafter.md" && has "$AG/foureyes-drafter.md" "declarations only" && has "$AG/foureyes-drafter.md" "scaffold"'
check "29c the drafter carries no part/splice protocol" \
  '! grep -q "TASKS-PER-PART" "$AG/foureyes-drafter.md" && ! grep -q "DRAFT: part" "$AG/foureyes-drafter.md" && ! grep -q "REVISION: sections" "$AG/foureyes-drafter.md" && ! grep -q "CHANGED-TASKS" "$AG/foureyes-drafter.md"'
check "29d the spec critic reviews contracts, scaffolding and coverage" \
  'has "$AG/foureyes-spec-critic.md" "Cross-Task Contracts" && has "$AG/foureyes-spec-critic.md" "scaffold" && has "$AG/foureyes-spec-critic.md" "coverage"'
# Scoped to the sections that own the rule, so the check fails when E2 stops
# forwarding a section or Step 0.5 downgrades has-steps to report-and-continue —
# a whole-file grep passed on both mutations.
e2()  { sed -n '/^\*\*E2 /,/^\*\*E3 /p' "$BD" | tr '\n' ' '; }
s05() { sed -n '/^## Step 0.5/,/^## Step B/p' "$BD"; }
check "29e build's E2 forwards contracts and constraints, not Steps" \
  'e2 | grep -q "Cross-Task Contracts" && e2 | grep -q "Global Constraints" && ! e2 | grep -q "Verify / Steps"'
check "29e2 build's Step 0.5 stops on has-steps" \
  's05 | grep -q "has-steps.* STOP"'
for a in implementer implementer-frontier; do
  check "29f $a knows the Cross-Task Contracts and expects no Steps" \
    'has "$AG/foureyes-$a.md" "Cross-Task Contracts" && ! grep -q "Steps" "$AG/foureyes-$a.md"'
done
check "29g plan-viz exports no spliceTasks" \
  '! grep -q "spliceTasks" "$SK/foureyes-brainstorm/lib/plan-viz.mjs"'
check "29h foureyes-plan-critic.md no longer exists" \
  '[ ! -f "$AG/foureyes-plan-critic.md" ]'

echo
echo "prose-contracts.test.sh: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
