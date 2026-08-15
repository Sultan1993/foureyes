#!/usr/bin/env bash
# RED-GREEN-PRESSURE runner for skill prose. See README.md.
#
# GREEN/PRESSURE inject the skill text; RED withholds it, to prove the scenario
# actually applies pressure. A scenario that passes RED is a broken scenario.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN="$HERE/../.."
OUT="$HERE/out"; mkdir -p "$OUT"

command -v claude >/dev/null || { echo "ERROR: claude CLI not found on PATH" >&2; exit 2; }

ONLY="${1:-}"; PHASE="${2:-green}"
PASS=0; FAIL=0; BROKEN=0

hdr() { sed -n "1,/^$/p" "$1" | grep -i "^$2:" | sed "s/^$2: *//I"; }

for s in "$HERE"/scenarios/*.txt; do
  name=$(basename "$s" .txt)
  [ -n "$ONLY" ] && [ "$ONLY" != "$name" ] && continue

  rule=$(hdr "$s" RULE); skill=$(hdr "$s" SKILL); model=$(hdr "$s" MODEL)
  body=$(sed -n '/^$/,$p' "$s")
  [ -f "$PLUGIN/$skill" ] || { echo "  BROKEN - $name: no such SKILL: $skill"; BROKEN=$((BROKEN+1)); continue; }

  # Every scenario ends with an enumerated verdict, and the assertions read ONLY
  # that line. Two reasons this is not optional:
  #   1. Matching prose conflates "I ran git commit" with "I did not run git
  #      commit" — a well-behaved refusal grades as a violation, because the
  #      explanation names the same command as the act.
  #   2. Free-text answers drift in wording across runs, so the regex silently
  #      stops matching and every scenario turns green.
  # The tokens in ANSWER must not be substrings of one another.
  answer=$(hdr "$s" ANSWER)
  [ -n "$answer" ] || { echo "  BROKEN - $name: no ANSWER header"; BROKEN=$((BROKEN+1)); continue; }
  body="$body

Finish your response with exactly one line, last — no markdown, nothing after it:

DECISION: <exactly one of: $answer>"

  case "$PHASE" in
    red)      prompt="$body" ;;
    pressure|green)
      prompt="You are operating under the following skill. Follow it exactly.

--- BEGIN SKILL ---
$(cat "$PLUGIN/$skill")
--- END SKILL ---

$body" ;;
    *) echo "unknown phase: $PHASE" >&2; exit 2 ;;
  esac

  echo "=== $name [$PHASE]${model:+ (model: $model)} — $rule"
  log="$OUT/$name.$PHASE.txt"
  printf '%s\n' "$prompt" | claude -p --output-format text ${model:+--model "$model"} > "$log" 2>&1 || true

  # Assertions read the DECISION line only.
  verdict=$(grep -i '^DECISION:' "$log" | tail -1)
  if [ -z "$verdict" ]; then
    echo "  BROKEN - $name: no DECISION line; cannot grade (see transcript)"
    BROKEN=$((BROKEN+1)); echo "    transcript: $log"; continue
  fi
  echo "    $verdict"

  violated=0
  while IFS= read -r re; do
    [ -z "$re" ] && continue
    if printf '%s' "$verdict" | grep -qiE "$re"; then echo "    violated FORBID: $re"; violated=1; fi
  done < <(hdr "$s" FORBID)
  while IFS= read -r re; do
    [ -z "$re" ] && continue
    if ! printf '%s' "$verdict" | grep -qiE "$re"; then echo "    missing REQUIRE: $re"; violated=1; fi
  done < <(hdr "$s" REQUIRE)

  if [ "$PHASE" = red ]; then
    # RED wants the violation. Compliance here means the scenario has no teeth.
    if [ "$violated" = 1 ]; then echo "  ok  - RED violated as expected (scenario has teeth)"; PASS=$((PASS+1))
    else echo "  BROKEN - RED complied without the skill; this scenario proves nothing"; BROKEN=$((BROKEN+1)); fi
  else
    if [ "$violated" = 0 ]; then echo "  ok  - complied"; PASS=$((PASS+1))
    else echo "  FAIL - rule broken under $PHASE"; FAIL=$((FAIL+1)); fi
  fi
  echo "    transcript: $log"
done

echo
echo "pressure [$PHASE]: $PASS passed, $FAIL failed, $BROKEN broken"
echo "Greps are a first filter, not proof. Read the transcripts."
[ "$FAIL" -eq 0 ] && [ "$BROKEN" -eq 0 ]
