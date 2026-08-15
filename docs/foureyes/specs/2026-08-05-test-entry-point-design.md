# Spec: Single deterministic test entry point + CI wiring for foureyes

**Date:** 2026-08-05
**Approaches file:** `docs/superpowers/specs/2026-08-05-test-entry-point-approaches.md`
**Chosen approach:** Bash aggregator script + new test workflow (user-selected)

## Purpose

foureyes has four deterministic test suites — two bash
(`tests/codex-critic.test.sh`, `tests/prose-contracts.test.sh`)
and two `node:test` files (`skills/foureyes-brainstorm/lib/plan-viz.test.mjs`,
`skills/foureyes-review/lib/review-synth.test.mjs`) — and no single
command that runs them all. They get run by hand, inconsistently, and a regression in
one suite can ship because nobody happened to run it. This change adds exactly one
entry point, `tests/run.sh`, that runs all four and nothing else, and a
GitHub Actions workflow that runs it on every PR and every push to main. The pressure
suite (`tests/pressure/run.sh`) invokes the `claude` CLI and costs real
money per run; it is excluded structurally — by never appearing in the runner's
allowlist — not conditionally.

**Requirements provenance.** The keep-going behavior, the per-suite summary, and the
nonzero exit on any failure are user requirements, not design additions — the approach
the user selected reads: "Runs every suite even when an earlier one fails, prints a
per-suite summary, exits nonzero if any failed." The banner and line formats below are
design decisions matching the existing suites' style; they specify *how* the required
summary looks, not extra protocol. The only element beyond the selected requirements is
the `exit 2` node preflight, retained deliberately and justified where specified.

## Design

Two new files. Nothing else in the repo changes; `.github/workflows/release-please.yml`
remains byte-identical.

### Component 1 — `tests/run.sh` (the aggregator)

A bash script, committed with the executable bit set, in the same style as the existing
suites (`#!/usr/bin/env bash`, `set -u`, `BASH_SOURCE`-relative paths, `PASS`/`FAIL`
counters, final `[ "$FAIL" -eq 0 ]`). It executes exactly four suite invocations — one
per suite — in order, sequentially:

1. `bash "$HERE/codex-critic.test.sh"` — self-contained: line 10 of that suite prepends
   `tests/stubs` to `PATH` and line 9 restores the stub's exec bit, so the runner does
   no stub setup.
2. `bash "$HERE/prose-contracts.test.sh"` — resolves the repo via its own `HERE`/`ROOT`,
   cwd-independent.
3. `node --test "$HERE/../skills/foureyes-brainstorm/lib/plan-viz.test.mjs"`
4. `node --test "$HERE/../skills/foureyes-review/lib/review-synth.test.mjs"`

The two Node suites are invoked separately — one `node --test` per file — so the
runner's summary maps one line to one suite: four suites in, four result lines and a
`4 passed` count out, and a failure is attributable to a specific suite at the
aggregator level without reading Node's own reporter output. The cost is one extra Node
process startup, tens of milliseconds. Verified behavior (Node v20+): explicit file
paths are accepted and the process exits 1 if any test fails. ESM relative imports
resolve against the module file, not the cwd, so this works from any directory.

**The allowlist is the exclusion mechanism.** These four literal invocations are the
entire suite list — no `find`, no glob, no directory scan, no flag, no environment
toggle. `tests/pressure/` is not in the list, so it cannot run from this entry point
under any input. A header comment in the script states this invariant so a future
editor adding a suite understands why discovery is deliberately absent.

**Keep-going semantics** (user requirement — see provenance above). No `set -e`. Each invocation runs through a `run_suite`
helper that prints a `=== <name> ===` banner, streams the suite's own output unmodified
(so CI logs keep the per-check `ok  -` / `FAIL -` lines the suites already print),
records pass/fail from the exit code, and continues. All four invocations always
execute, regardless of earlier failures.

**Summary** (user requirement; format is a style-matching design decision). After all suites, the runner prints a `--- summary ---` section (matching
the suites' `--- section ---` banner style) with one `  ok  - <name>` / `  FAIL - <name>`
line per suite (matching the suites' per-check line style), then a trailing line in the
exact shape the suites already emit — `<name>: N passed, M failed` — counting suites:

```
--- summary ---
  ok  - codex-critic.test.sh
  ok  - prose-contracts.test.sh
  ok  - plan-viz.test.mjs
  ok  - review-synth.test.mjs
run.sh: 4 passed, 0 failed
```

**Exit codes:** `0` all suites passed; `1` at least one suite failed (via the same
`[ "$FAIL" -eq 0 ]` idiom the suites use as their final command); `2` preflight failure
— `node` not on `PATH` — reported to stderr before any suite runs.

The `exit 2` preflight is the one piece *not* part of the user's selected requirements;
it is kept deliberately. Without it, a machine missing `node` reports two green bash
suites and two failing node suites with `command not found` noise, exit 1 —
indistinguishable at a glance from real test regressions. One line buys an unambiguous
environment-versus-tests distinction, and it mirrors the existing
`command -v claude || exit 2` idiom in `tests/pressure/run.sh`, so the repo already
treats exit 2 as "environment not ready".

Reference implementation (the plan's implementer produces exactly this behavior;
cosmetic drift in comments is acceptable, behavior and output shape are not):

```bash
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

echo "--- summary ---"
printf '%s\n' "${RESULTS[@]}"
echo "run.sh: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
```

(Bash-3.2-safe: arrays and `+=` are already used by `codex-critic.test.sh`, and
`RESULTS` is always non-empty by the time it is expanded, so `set -u` never sees an
empty-array expansion.)

### Component 2 — `.github/workflows/test.yml` (CI)

Matches `release-please.yml`'s style exactly: minimal, two-space indent, explicit
`permissions`, `ubuntu-latest`, no comments:

```yaml
name: test
on:
  push:
    branches: [main]
  pull_request:
permissions:
  contents: read
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: actions/setup-node@v7
        with:
          node-version: 'lts/*'
      - run: bash tests/run.sh
```

Decisions baked in:

- **Action versions** (verified against the GitHub releases API, cross-checked with the
  actions' docs via Context7): `actions/checkout@v7` — latest release v7.0.1, published
  2026-07-20; `actions/setup-node@v7` — latest release v7.0.0, published 2026-07-14. An
  earlier draft cited `checkout@v5` and `setup-node@v6` as current; both were stale and
  are corrected here. Nothing in this workflow depends on a previous major's behavior.
- **`node-version: 'lts/*'` is confirmed valid on setup-node v7.** v7's `action.yml`
  leaves the `node-version` input unchanged from v6 (v7 adds only two cache-related
  outputs, `cache-primary-key` and `cache-matched-key`), and the v7 resolver documents
  `lts/*` as resolving to the latest LTS release.
- **"Pinned to LTS" means the LTS line, not a frozen major.** `lts/*` auto-advances with
  the LTS designation; the suites depend only on `node:test`/`node:assert/strict` (stable
  since v20), so a floating LTS is the lower-maintenance reading and never needs a manual bump.
- **No `cache:` input on setup-node.** The repo has no `package.json` or lockfile anywhere
  (verified); `cache: npm` without a lockfile fails the step, and there is nothing to
  cache. setup-node v6+/v7 automatic npm caching activates only when a `package.json`
  declares npm; with no `package.json` it is inert, so the default needs no override.
- **`bash tests/run.sh`**, not `./…/run.sh` — the run does not depend on the
  exec bit surviving checkout. The suites use bash arrays, so invoking via `bash` (not
  `sh`) is required and explicit.
- **No login of any kind.** Nothing in the four suites reaches Codex or Claude:
  `codex-critic.test.sh` stubs `codex` via its own PATH prepend, and only
  `tests/pressure/run.sh` invokes `claude` — which is outside the allowlist. The workflow
  sets no secrets and `permissions: contents: read` is the least privilege that lets
  checkout work.
- **Triggers:** `pull_request` (all PRs) plus `push` to `branches: [main]` — per the brief.
  The two never double-fire for the same event: pushes to PR branches only trigger the
  `pull_request` run.

## Data flow

```
developer / GitHub event
        │
        ▼
tests/run.sh
        │  preflight: node on PATH?  ──no──▶ stderr + exit 2
        ▼
  suite 1: bash codex-critic.test.sh ──▶ exit code recorded, output streamed
  suite 2: bash prose-contracts.test.sh ─▶ exit code recorded, output streamed
  suite 3: node --test plan-viz.test.mjs ────▶ exit code recorded, output streamed
  suite 4: node --test review-synth.test.mjs ▶ exit code recorded, output streamed
        │            (all four always run; failures do not short-circuit)
        ▼
  per-suite summary + "run.sh: N passed, M failed"
        │
        ▼
  exit 0 (all green) / 1 (any red)  ──▶  GitHub check: green / red on the PR or main
```

Note on suites 3-4's output: `node --test` picks its reporter by TTY (human-readable `spec`
locally, TAP-style in CI logs). Only the exit code is load-bearing; the runner does not
parse suite output.

## Error handling

- **A suite's checks fail** → that suite exits 1 (both bash suites end in
  `[ "$FAIL" -eq 0 ]`, verified trustworthy; `node --test` exits 1 on any failing test),
  the runner records `FAIL`, runs the remaining suites, prints the failure in the
  summary, exits 1.
- **A suite file is moved/renamed** → `bash <missing>` exits 127, `node --test <missing>`
  exits nonzero; either is recorded as a failed suite and the runner exits 1. Loud failure
  on rename is the desired behavior; no separate existence preflight.
- **`node` missing locally** → stderr message, exit 2, before any suite runs. (In CI
  setup-node guarantees node.)
- **Runner crashes mid-run** (e.g. SIGINT) → nonzero exit; no cleanup needed because the
  runner owns no temp state — `codex-critic.test.sh` creates and traps its own `mktemp`
  workspace.
- **CI-side failures** (checkout/setup-node step errors) → the workflow step fails and the
  check is red; no custom handling.

## Explicit non-goals (YAGNI)

- **No pressure integration of any kind** — no `--with-pressure` flag, no env toggle, no
  conditional. Pressure stays runnable only directly via `tests/pressure/run.sh`.
- **No suite discovery** (`find`/glob) — the allowlist is the safety mechanism; discovery
  would re-open the accidental-invocation hole.
- **No `package.json` / `npm test`** — the repo has none and needs none; adding one to
  alias a script is pure overhead.
- **No CLI options on run.sh** (no `--only` filter, no verbosity flags) — each suite is
  already individually invocable.
- **No machine-readable output** (TAP/JUnit aggregation, coverage) — exit code + human
  summary is the contract.
- **No CI matrix** (Node versions, OSes), **no caching**, **no concurrency/cancel-in-progress
  groups**, **no shellcheck/lint job** — one job, one runner, one LTS.
- **No parallel suite execution inside run.sh** — the suites complete in milliseconds
  (the second Node startup adds tens of milliseconds); sequential keeps output ordered.
- **No grouped Node invocation** — one `node --test` naming both `.mjs` files would save
  a process startup but report four suites as three summary lines, breaking the
  one-line-per-suite mapping; per-suite invocation is the deliberate choice.
- **No changes to `release-please.yml`**, no README/docs updates — the runner's header
  comment is its documentation.

## Observable success criteria

All commands below are repo-relative or derive the repo path dynamically; none embeds a
machine-specific absolute path.

1. `bash tests/run.sh` from the repo root runs all four suite invocations,
   prints each suite's own output followed by the `--- summary ---` block with four
   per-suite lines and a trailing `run.sh: 4 passed, 0 failed`, exit 0.
2. cwd-independence: `REPO="$(git rev-parse --show-toplevel)" && cd / && bash "$REPO/tests/run.sh"`
   produces the same result as criterion 1.
3. Keep-going: with a deliberately broken assertion temporarily injected into
   `codex-critic.test.sh`, the runner still executes all three remaining suites, the
   summary shows `FAIL - codex-critic.test.sh` and `run.sh: 3 passed, 1 failed`, and the
   exit code is 1 (revert the injection afterward).
4. Exclusion: `grep -c pressure tests/run.sh` matches only the header comment;
   the runner makes zero invocations of `claude` or real `codex`, and passes on a machine
   with no `claude` CLI installed and no Codex/Claude login.
5. Missing node: with `node` shadowed off `PATH`, the runner prints
   `ERROR: node not found on PATH` to stderr and exits 2 without running any suite.
6. CI: the `test` workflow appears as a check on a PR and on pushes to main; a green run
   completes on ubuntu-latest with no secrets configured; a seeded failing test turns the
   check red at the `run: bash tests/run.sh` step.
7. Change isolation, checked with an explicit base: before committing,
   `git status --porcelain` lists exactly two paths — `.github/workflows/test.yml` and
   `tests/run.sh` — and `git diff HEAD -- .github/workflows/release-please.yml`
   is empty; after committing on a branch, `git diff --name-only main...HEAD` lists exactly
   those two paths.
8. Local wall time for a full `run.sh` pass stays in the low seconds (suites are
   milliseconds; node startup dominates).

---

## Amendment 2026-08-05: CI dropped, replaced by a local pre-commit hook

**Component 2 (`.github/workflows/test.yml`) was built, then reverted.** The user
does not use CI. The requirement came from the brief, and the brief was written by
the coordinator for this run — nobody asked for GitHub Actions. Rung one of the
ladder, *does this need to exist at all*, was never applied to it.

Costs of keeping it: version upkeep on `checkout`/`setup-node`, Actions minutes on
every push, and a red check nobody reads — which is worse than no check, because it
trains you to ignore red.

**Replaced by `.githooks/pre-commit`**, which runs `tests/run.sh` and
blocks a red commit. That is what CI was actually for — running the tests without
relying on remembering to — delivered natively, in ~2s, with no service. Enabled
once per checkout with `git config core.hooksPath .githooks`; `--no-verify` remains
the escape hatch, so a red commit stays possible but becomes a decision.

**Consequently void:** criterion 6 (CI check on a PR, seeded red, post-merge run)
and Task 4 in its entirety. Criterion 7's post-commit half is already proven by
Task 3 at the commit level, which is stronger than the original path-filtered form.

**Knowingly given up: Linux coverage.** Everything here has only ever run on
Darwin/bash 3.2.57, and `plan-viz.mjs`, `review-synth.mjs` and `codex-critic.sh`
ship to other people. This is worth paying for when a Linux user hits a break, not
before — `test.yml` is 16 lines to write again.
