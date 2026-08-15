#!/usr/bin/env bash
# Stub-based tests for codex-critic.sh. No live Codex calls: a fake `codex` is
# PATH-prepended. The contract under test is small on purpose — run the critic,
# print its verdict, append a GATE: directive, and refuse to run past the round
# budget.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/../scripts/codex-critic.sh"
chmod +x "$HERE/stubs/codex" 2>/dev/null || true
export PATH="$HERE/stubs:$PATH"

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ok  - $1"; }
bad()  { FAIL=$((FAIL+1)); echo "  FAIL - $1"; }
check(){ if eval "$2"; then ok "$1"; else bad "$1"; fi; }

WS="$(mktemp -d)"
trap 'rm -rf "$WS"' EXIT
cd "$WS"

V() { printf '%s\n' "$@" > "$WS/verdict.txt"; export CODEX_STUB_VERDICT="$WS/verdict.txt"; }
CLEAN=("VERDICT: pass" "SUMMARY: s" "FINDINGS:" "- (none)")
IMPORTANT=("VERDICT: targeted-fixes" "SUMMARY: s" "FINDINGS:" "- [Important] x — y — z — w")
CRITICAL=("VERDICT: rewrite" "SUMMARY: s" "FINDINGS:" "- [Critical] x — y — z — w")

run() { # mode [env...] — stdin fed automatically
  local mode="$1"; shift
  rm -f "$WS/args.txt"
  echo "input" | env CODEX_STUB_ARGS="$WS/args.txt" "$@" bash "$SCRIPT" "$mode" \
    >"$WS/out.txt" 2>"$WS/err.txt"
  echo $? > "$WS/rc.txt"
}
gate() { grep -m1 '^GATE:' "$WS/out.txt" | sed 's/^GATE: //'; }

echo "--- GATE directive ---"
V "${CLEAN[@]}"
run spec
check "1a clean verdict -> GATE: pass"        '[ "$(gate)" = pass ]'
check "1b verdict block still printed intact" 'grep -q "^VERDICT: pass" out.txt'

V "${IMPORTANT[@]}"
run spec CODEX_CRITIC_ROUND=1 CODEX_CRITIC_MAX_ROUNDS=2
check "2a Important, budget left -> revise"   '[ "$(gate)" = revise ]'
check "2b revise names the next round"        'grep -q "round 2" err.txt'

V "${IMPORTANT[@]}"
run spec CODEX_CRITIC_ROUND=2 CODEX_CRITIC_MAX_ROUNDS=2
check "3a Important at last round -> final"   '[ "$(gate)" = final ]'
check "3b final says do not re-run"           'grep -q "do not re-run" err.txt'

V "${CRITICAL[@]}"
run spec CODEX_CRITIC_ROUND=2 CODEX_CRITIC_MAX_ROUNDS=2
check "4 Critical at last round -> final too" '[ "$(gate)" = final ]'

echo "--- round budget is a hard stop ---"
V "${CLEAN[@]}"
run spec CODEX_CRITIC_ROUND=3 CODEX_CRITIC_MAX_ROUNDS=2
check "5a past budget -> GATE: conclude"      '[ "$(gate)" = conclude ]'
check "5b past budget spends NO codex call"   '[ ! -f args.txt ]'
check "5c past budget still exits 0"          '[ "$(cat rc.txt)" = 0 ]'
check "5d past budget says FINAL"             'grep -q "FINAL" err.txt'

for m in plan code; do
  run "$m" CODEX_CRITIC_ROUND=9 CODEX_CRITIC_MAX_ROUNDS=2
  check "5e budget applies to seam '$m'"      '[ "$(gate)" = conclude ]'
done

# review/refute are not seams — they must never be budgeted away
run review CODEX_CRITIC_ROUND=9 CODEX_CRITIC_MAX_ROUNDS=2
check "5f review ignores the budget"          '[ -f args.txt ] && ! grep -q "^GATE:" out.txt'

# approach is a one-shot proposer: its prompt must resolve by name, and it must
# never be budgeted away or given a GATE line to follow.
run approach CODEX_CRITIC_ROUND=9 CODEX_CRITIC_MAX_ROUNDS=2
check "5g approach resolves + ignores budget" '[ -f args.txt ] && ! grep -q "^GATE:" out.txt'

echo "--- proposer templates must stay byte-identical ---"
# The coordinator pools both proposers into ONE list. If the templates drift, a
# missing field reveals who wrote which entry. Extraction is marker-delimited, not
# content-delimited: a content range ends at the last field it knows about, so
# anything appended AFTER it in one file only would pass unnoticed.
AG="$HERE/../agents"
D="$AG/foureyes-drafter.md"; A="$AG/foureyes-approach-critic.md"
B='<!-- SHARED-TEMPLATE-BEGIN -->'; E='<!-- SHARED-TEMPLATE-END -->'
# Markers must match the WHOLE line: counting substrings would accept 2 BEGINs and
# 0 ENDs, and prose sharing a marker's line would be skipped instead of compared.
tpl() { awk -v b="$B" -v e="$E" '$0==b{f=1;next} $0==e{f=0} f' "$1"; }
# exactly one BEGIN, exactly one END, BEGIN first — ordering matters because an
# END-before-BEGIN file extracts to EOF and can still compare equal.
wf() { awk -v b="$B" -v e="$E" '
  $0==b{nb++; ib=NR} $0==e{ne++; ie=NR}
  END{print (nb==1 && ne==1 && ib<ie) ? "ok" : "bad"}' "$1"; }
check "12a drafter markers well-formed"     '[ "$(wf "$D")" = ok ]'
check "12b approach markers well-formed"    '[ "$(wf "$A")" = ok ]'
check "12c extracted template is non-empty" '[ -n "$(tpl "$D")" ]'
check "12d both templates byte-identical"   '[ "$(tpl "$D")" = "$(tpl "$A")" ]'

echo "--- a non-clean token is never a pass, however findings are formatted ---"
# Regression: a count-only gate reported this as clean.
V "VERDICT: rewrite" "SUMMARY: fundamentally broken" "FINDINGS:" "* [Critical] wrong model — corrupts on write"
run spec CODEX_CRITIC_ROUND=1 CODEX_CRITIC_MAX_ROUNDS=2
check "10a unparsed findings + bad token -> revise" '[ "$(gate)" = revise ]'
check "10b warns the body must be read"             'grep -q "READ THE VERDICT BODY" err.txt'
V "VERDICT: targeted-fixes" "FINDINGS:" "- (none)"
run spec CODEX_CRITIC_ROUND=2 CODEX_CRITIC_MAX_ROUNDS=2
check "10c non-pass token at last round -> final"   '[ "$(gate)" = final ]'
V "VERDICT: PASS" "FINDINGS:" "- (none)"
run spec
check "10d token match is case-insensitive"         '[ "$(gate)" = pass ]'

echo "--- a malformed round must stop, never silently unbound the loop ---"
V "${IMPORTANT[@]}"
for bad in two junk 0 -1 1.5 ""; do
  run spec CODEX_CRITIC_ROUND="$bad"
  if [ "$bad" = "" ]; then
    check "11 empty ROUND defaults to 1"            '[ "$(gate)" = revise ]'
  else
    check "11 ROUND='$bad' -> exit 2, no GATE"      '[ "$(cat rc.txt)" = 2 ] && ! grep -q "^GATE:" out.txt'
  fi
done
run spec CODEX_CRITIC_MAX_ROUNDS=nope
check "11 MAX_ROUNDS non-numeric -> exit 2"         '[ "$(cat rc.txt)" = 2 ]'
check "11 malformed round spends no codex call"     '[ ! -f args.txt ]'

echo "--- broken codex is never a pass ---"
V "VERDICT: NEEDS-HUMAN" "SUMMARY: s"
run spec
check "6a NEEDS-HUMAN -> GATE: needs-human"   '[ "$(gate)" = needs-human ]'
V "garbled output, no verdict line"
run spec
check "6b no VERDICT line -> needs-human"     '[ "$(gate)" = needs-human ]'
run spec PATH="/usr/bin:/bin"
check "6c missing codex CLI -> exit 2"        '[ "$(cat rc.txt)" = 2 ] && grep -q "NEEDS-HUMAN" out.txt'
run bogus-mode
check "6d unknown mode -> exit 2"             '[ "$(cat rc.txt)" = 2 ]'

echo "--- passthrough fidelity (foureyes-review depends on it) ---"
printf 'VERDICT: pass\nline with  spaces\n\ntrailing blank above\n' > "$WS/verdict.txt"
export CODEX_STUB_VERDICT="$WS/verdict.txt"
echo "input" | bash "$SCRIPT" review > "$WS/rv.txt" 2>/dev/null
check "7 review output is byte-identical"     'cmp -s rv.txt verdict.txt'

echo "--- codex invocation flags ---"
V "${CLEAN[@]}"
run spec
check "8a read-only sandbox"                  'grep -qx -- "-s" args.txt && grep -qx "read-only" args.txt'
check "8b search on by default"               'grep -qx -- "--search" args.txt'
run spec CODEX_CRITIC_SEARCH=0
check "8c search disabled"                    '! grep -qx -- "--search" args.txt'
run spec CODEX_CRITIC_MODEL=other-model
check "8d CODEX_CRITIC_MODEL honored"         'grep -qx "other-model" args.txt'
run spec CODEX_CRITIC_MODEL=
check "8e empty model omits -m"               '! grep -qx -- "-m" args.txt'

echo "--- effort: high on every round ---"
run spec CODEX_CRITIC_ROUND=1
check "9a round 1 -> high"                    'grep -qx "model_reasoning_effort=high" args.txt'
run spec CODEX_CRITIC_ROUND=2 CODEX_CRITIC_MAX_ROUNDS=2
check "9b last round stays high"              'grep -qx "model_reasoning_effort=high" args.txt'
run spec CODEX_CRITIC_ROUND=2 CODEX_CRITIC_MAX_ROUNDS=3 CODEX_CRITIC_EFFORT=low
check "9c explicit effort wins"               'grep -qx "model_reasoning_effort=low" args.txt'
run review
check "9d non-seam is high too"               'grep -qx "model_reasoning_effort=high" args.txt'

echo "--- service tier: fast needs BOTH halves or neither ---"
# codex discards the tier when fast_mode is off (get_service_tier returns None),
# so emitting one without the other is a silent no-op: you believe you are on
# priority routing, you are not, and nothing anywhere says so.
V "${CLEAN[@]}"
run spec
check "13a fast is the DEFAULT: both halves present"  'grep -qx "fast_mode" args.txt && grep -qx "service_tier=priority" args.txt'
run spec CODEX_CRITIC_SPEED=fast
check "13b fast passes the feature gate"             'grep -qx -- "--enable" args.txt && grep -qx "fast_mode" args.txt'
check "13c fast passes the tier itself"              'grep -qx "service_tier=priority" args.txt'
run spec CODEX_CRITIC_SPEED=priority
check "13d 'priority' is accepted as a synonym"      'grep -qx "fast_mode" args.txt && grep -qx "service_tier=priority" args.txt'
run spec CODEX_CRITIC_SPEED=normal
check "13e explicit normal sends neither half"       '[ -f args.txt ] && ! grep -qx "fast_mode" args.txt && ! grep -q "service_tier" args.txt'
# A typo must not read as "fast" and must not pass silently as "normal" either.
run spec CODEX_CRITIC_SPEED=quick
check "13f a typo runs normal, loudly"               '[ -f args.txt ] && ! grep -qx "fast_mode" args.txt && grep -q "not .fast. or .normal." err.txt'
check "13g a typo still produces a verdict"          '[ "$(gate)" = pass ]'
# Speed is orthogonal to effort: asking for fast must never quietly lower thinking.
run spec CODEX_CRITIC_SPEED=fast
check "13h fast keeps effort at high"                'grep -qx "model_reasoning_effort=high" args.txt'
# review/refute exec-replace this shell; the tier has to reach them too.
run review CODEX_CRITIC_SPEED=fast
check "13i non-seam modes get the tier as well"      'grep -qx "fast_mode" args.txt && grep -qx "service_tier=priority" args.txt'

echo
echo "codex-critic.test.sh: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
