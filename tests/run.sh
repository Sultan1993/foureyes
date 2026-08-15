#!/usr/bin/env bash
# Runs every DETERMINISTIC suite in foureyes: two bash suites plus two
# node --test suites. The list below is an explicit allowlist — the
# pressure suite (tests/pressure/run.sh) is deliberately absent: it calls the
# claude CLI and costs real money, so it must be impossible to trigger from
# here. Do not add discovery (find/glob); add new suites to this list by hand.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

command -v node >/dev/null || { echo "ERROR: node not found on PATH" >&2; exit 2; }

PASS=0; FAIL=0; RESULTS=()
run_suite() { # name cmd...
  local name="$1"; shift
  echo "=== $name ==="
  if "$@"; then PASS=$((PASS+1)); RESULTS+=("  ok  - $name")
  else            FAIL=$((FAIL+1)); RESULTS+=("  FAIL - $name")
  fi
  echo
}

run_suite "codex-critic.test.sh"    bash "$HERE/codex-critic.test.sh"
run_suite "prose-contracts.test.sh" bash "$HERE/prose-contracts.test.sh"
run_suite "plan-viz.test.mjs"       node --test "$HERE/../skills/foureyes-brainstorm/lib/plan-viz.test.mjs"
run_suite "review-synth.test.mjs"   node --test "$HERE/../skills/foureyes-review/lib/review-synth.test.mjs"
run_suite "sol-ledger.test.mjs"     node --test "$HERE/../scripts/sol-ledger.test.mjs"
run_suite "pipeline-stats.test.mjs" node --test "$HERE/../scripts/pipeline-stats.test.mjs"

echo "--- summary ---"
printf '%s\n' "${RESULTS[@]}"
echo "run.sh: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
