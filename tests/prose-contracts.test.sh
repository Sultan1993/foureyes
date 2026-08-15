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
for a in spec-critic plan-critic code-critic; do
  check "3 no skill dispatches foureyes-$a as a subagent" \
    '! grep -rq "subagent_type: foureyes-'"$a"'" "$SK"'
done

echo "--- doc seams stay round-budgeted ---"
# A seam that forgets CODEX_CRITIC_ROUND runs unbudgeted: the wrapper defaults to
# round 1 forever, and drafter<->critic never converges.
for m in spec plan; do
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
for a in spec plan code; do
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
# logging goes silent, and its column in sol-ledger.mjs quietly reads as clean
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
  'grep -q "sol-ledger.mjs" "$BS" && grep -q "sol-ledger.mjs" "$BD"'
check "13f the reader is on the deterministic suite list" \
  'grep -q "sol-ledger.test.mjs" "$HERE/run.sh"'

echo "--- an uncritiqued plan asks, and never auto-runs brainstorm ---"
# Step 0.5 offering to critique must stay an offer. Invoking brainstorm here
# would make `foureyes-build <plan>` silently slower than the user asked for.
check "14a build detects a plan with no plan-seam entry" \
  'grep -q "Has Sol ever read this plan" "$BD"'
check "14b it asks rather than deciding" \
  'grep -A12 "Has Sol ever read this plan" "$BD" | grep -q "AskUserQuestion"'
check "14c it never invokes brainstorm from that branch" \
  'grep -A12 "Has Sol ever read this plan" "$BD" | grep -q "never invoke brainstorm"'

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
# With Sol off, E5 is a Claude subagent reviewing Claude's work: nothing in the
# run crosses model families, which is the entire premise of the plugin.
check "16 build says skip-critics leaves no cross-model check" \
  'grep -q "nothing in the run crosses model families" "$BD"'

echo "--- the ledger is reachable from the repos it reports on ---"
# The logs are written into CONSUMER repos; the reader ships here. Without an
# entry point, reading them means typing a cache glob, which means never.
check "17a a ledger skill exists" \
  '[ -f "$SK/foureyes-ledger/SKILL.md" ]'
check "17b it resolves the reader script" \
  'grep -q "sol-ledger.mjs" "$SK/foureyes-ledger/SKILL.md"'
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

echo "--- a revision never re-emits the whole document ---"
# Measured over 90 drafter dispatches: 20 returns were too large and got spilled
# to disk behind a 2KB preview, and one died on the 64k output-token ceiling
# after 51 minutes. The drafter is the only subagent with this problem, and
# re-emitting a whole plan to fix three findings is the cause.
check "21a drafter has a section-scoped revision mode" \
  'grep -q "REVISION: sections" "$DR" && grep -q "CHANGED-TASKS:" "$DR"'
check "21b full re-emit is reserved for structural change" \
  'grep -q "REVISION: full" "$DR"'
check "21c the rule is send-only-what-changed, not a borrowed byte count" \
  'grep -qi "never send more than the change requires" "$DR"'
check "21d brainstorm reads a spilled return instead of writing the preview" \
  'grep -q "persisted-output" "$BS" && grep -qi "Read that path" "$BS"'
check "21e brainstorm never re-dispatches an over-limit assignment unchanged" \
  'grep -q "64000 output" "$BS" && grep -qi "do NOT.*re-dispatch" "$BS"'
check "21f brainstorm knows how to splice a sections reply" \
  'grep -q "CHANGED-TASKS" "$BS"'
check "21g the reader classifies spill and over-limit distinctly" \
  'grep -q "over-limit" "$PS" && grep -q "spilled" "$PS"'

echo "--- a big plan is allowed; a big reply is not ---"
# Plan size is deliberately uncapped. The reply has a ceiling, so a large plan
# arrives in parts — and the part protocol is only safe if numbering stays global
# and the coordinator derives .tasks.json once, after assembly.
check "22a drafter can emit a plan in parts" \
  'grep -q "DRAFT: part" "$DR" && grep -q "REMAINING:" "$DR"'
check "22b numbering is global, never restarted per part" \
  'grep -qi "globally and contiguously" "$DR"'
check "22c continuations get a manifest, not the earlier text" \
  'grep -qi "manifest of the tasks already emitted\|manifest of tasks already emitted" "$DR"'
check "22d nothing in the drafter caps how large a PLAN may be" \
  'grep -qi "Plans are not capped" "$DR"'
# The split size must come from the caller and self-correct, not from a constant
# baked in from whoever happened to be measured.
check "22h part size is supplied by the coordinator, not chosen by the drafter" \
  'grep -q "TASKS-PER-PART:" "$DR" && grep -q "TASKS-PER-PART:" "$BS"'
check "22i the coordinator halves it on overflow instead of guessing once" \
  'grep -qi "halve it (8" "$BS" || grep -qi "halving" "$BS"'
check "22j the token ceiling is read from the environment, not hardcoded" \
  'grep -q "CLAUDE_CODE_MAX_OUTPUT_TOKENS" "$DR"'
check "22e brainstorm assembles parts before deriving tasks.json" \
  'grep -q "DRAFT: part" "$BS" && grep -qi "Derive \`.tasks.json\` ONCE\|derive .tasks.json ONCE" "$BS"'
check "22f brainstorm verifies no task number is missing" \
  'grep -qi "ids contiguous from 1" "$BS"'
check "22g Sol critiques the assembled plan, not a part" \
  'grep -qi "critiques the assembled plan" "$BS"'

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
check "23f fast is the default, not opt-in" \
  'grep -q "CODEX_CRITIC_SPEED:-fast" "$WR"'
# SEARCH=0 was recommended for latency on no evidence it was ever dead weight.
# The drafter has web access; a critic without it reviews from weaker information
# than the document it is reviewing.
check "23g search is documented on, and never recommended off" \
  'has "$ROOT/README.md" "CODEX_CRITIC_SEARCH" && ! has "$ROOT/README.md" "SEARCH=0"'
check "23h both skills say how to opt out of paying for the tier" \
  'grep -q "CODEX_CRITIC_SPEED=normal" "$BS" && grep -q "CODEX_CRITIC_SPEED=normal" "$BD"'

echo "--- the misroute is now PREVENTED, not only detected ---"
# 143 real dispatches sent these to Claude subagents. Assertion 3 was green the
# whole time: it greps skill prose and cannot see what a coordinator did. The
# frontmatter description is what Claude reads when choosing an agent, and
# codex-critic.sh strips frontmatter, so it is the one place a warning reaches
# Claude and never reaches Codex.
for a in spec plan code; do
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

echo "--- a section revision is spliced by the library, never by hand ---"
# A hand splice can silently corrupt a plan that then executes into commits. This
# was prose-only while classify(), which only affects a report, had 14 tests.
PV="$SK/foureyes-brainstorm/lib/plan-viz.mjs"
check "25a plan-viz exports spliceTasks" \
  'grep -q "export function spliceTasks" "$PV"'
check "25b splice shares its boundary scan with the renderer" \
  'grep -q "export function taskRanges" "$PV" && grep -q "taskRanges(lines)" "$PV"'
check "25c a missing task number is reported, not appended" \
  'grep -q "missing" "$PV"'
check "25d brainstorm calls spliceTasks instead of editing by hand" \
  'grep -q "spliceTasks" "$BS"'
check "25e a non-empty missing aborts the write" \
  'grep -q "MISSING" "$BS"'
check "25f the stats line is FIRST so no splice can bury it" \
  'grep -qi "START every response with this line, FIRST" "$DR" && grep -qi "Strip the leading" "$BS"'

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
for a in spec plan code approach investigate; do
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
check "28k Sol rounds are priced by the ledger like every other seam" \
  'grep -q "## investigate · round" "$IV"'

echo "--- read-only agents stay read-only ---"
for a in approach-critic investigate-critic spec-critic plan-critic code-critic task-reviewer review-critic refute-critic scout investigator; do
  check "9 $a has no Write/Edit tool" \
    '! grep "^tools:" "$AG/foureyes-'"$a"'.md" | grep -qE "\bWrite\b|\bEdit\b"'
done

echo "--- every agent file is well-formed ---"
for f in "$AG"/*.md; do
  n=$(basename "$f" .md)
  check "10 $n frontmatter name matches filename" \
    '[ "$(awk "/^name:/{print \$2; exit}" "$f")" = "'"$n"'" ]'
done

echo
echo "prose-contracts.test.sh: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
