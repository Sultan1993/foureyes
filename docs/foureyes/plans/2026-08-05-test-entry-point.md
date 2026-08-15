Spec: docs/superpowers/specs/2026-08-05-test-entry-point-design.md

## Cross-Task Contracts

- **Runner path (Task 1 -> Task 2):** `tests/run.sh` — Task 1 creates it at exactly this repo-relative path; Task 2's workflow invokes it verbatim as `run: bash tests/run.sh`. Any rename breaks both tasks.
- **Invocation form:** CI calls `bash tests/run.sh`, never `./…/run.sh` — the run must not depend on the exec bit surviving checkout. Task 1 still sets `chmod +x`.
- **Exit-code contract (Task 1 -> Task 2/CI):** `0` = all four suites passed; `1` = at least one suite failed; `2` = preflight failure (`node` not on `PATH`, stderr, before any suite runs). The GitHub check goes red/green on this exit code alone; no output parsing anywhere.
- **Node floor:** the Node suites rely on `node --test <file>` accepting explicit file paths and exiting 1 on any failing test — Node v20+ behavior (spec-verified). CI satisfies this via `node-version: 'lts/*'` on `actions/setup-node@v7`.
- **Test policy (shared verification, no shared build unit):** the deliverables are a standalone bash script and a standalone YAML file — no compilation unit. Each wave-1 task verifies only its own file. The combined acceptance battery (keep-going injection, change isolation) runs solely in barrier Task 3. Only Task 3 may touch `tests/codex-critic.test.sh`, temporarily, and must restore it with `git checkout --` before finishing. No task ever modifies `.github/workflows/release-please.yml`.
- **Verification idiom (every task, every block):** an assertion block must exit nonzero when its assertion fails. The pattern `<asserts> && echo 'X: PASS' || echo 'X: FAIL'` is FORBIDDEN — `echo` exits 0 in both branches, so a failed assertion still reports success to the shell. Use `if <asserts>; then echo 'X: PASS'; else echo 'X: FAIL' >&2; <evidence>; exit 1; fi`.
- **Acceptance records (executor commit contract):** the executor commits one commit per task, path-scoped to that task's `files`, and treats an empty task diff as a defect. Task 3 restores its temporary injection byte-identically by design, so its committable artifact is a durable acceptance record: `docs/superpowers/acceptance/2026-08-05-test-entry-point-barrier.txt` (written only by Task 3). Task 4's is `docs/superpowers/acceptance/2026-08-05-test-entry-point-ci.txt`. Nothing else writes under `docs/superpowers/acceptance/`. The records double as preserved evidence of the destructive checks, which previously vanished with the shell session.
- **Library-claim provenance:** `actions/checkout@v7` (v7.0.1, 2026-07-20) and `actions/setup-node@v7` (v7.0.0, 2026-07-14, `node-version` unchanged from v6, `lts/*` resolves to latest LTS) were verified against the GitHub releases API and cross-checked via Context7 during spec drafting, and survived two critic rounds; this plan copies them verbatim and introduces no new library claims.
- **Waves:** Wave 1 = Tasks 1 and 2 (file-disjoint, concurrent). Wave 2 = Task 3 (barrier, in-worktree). Post-join = Task 4 — coordinator-owned, executed AFTER the per-task commits exist and are pushed. Task 4 is NEVER dispatched to an implementer: implementers never commit or push, and every one of its observations requires real commits, a real push, and GitHub actually running the workflow.
- **Spec criterion 6 is Task 4, not an aside.** It cannot be observed from a worktree. It is carried as a real task with exact commands so it cannot be silently dropped; Task 2's byte-equality to the verified YAML is the local proxy, not the coverage.

## Global Constraints

- Exactly two new files: `tests/run.sh` and `.github/workflows/test.yml`. "Nothing else in the repo changes; `.github/workflows/release-please.yml` remains byte-identical."
- Pressure exclusion is structural: excluded "by never appearing in the runner's allowlist — not conditionally"; "no `--with-pressure` flag, no env toggle, no conditional."
- "No suite discovery (`find`/glob)" — "no `find`, no glob, no directory scan, no flag, no environment toggle."
- Runner style: `#!/usr/bin/env bash`, `set -u` (no `set -e`), `BASH_SOURCE`-relative paths, `PASS`/`FAIL` counters, final `[ "$FAIL" -eq 0 ]`; Bash-3.2-safe.
- Exit codes: `0` all passed; `1` any suite failed; `2` preflight — `node` not on `PATH` — stderr, before any suite runs.
- "No grouped Node invocation" — one `node --test` per `.mjs`; sequential, four invocations, four summary lines.
- Summary format: `--- summary ---` banner, one `  ok  - <name>` / `  FAIL - <name>` line per suite, trailing `run.sh: N passed, M failed`.
- Workflow style matches `release-please.yml`: minimal, two-space indent, explicit `permissions`, `ubuntu-latest`, no comments; `permissions: contents: read`; no login, no secrets.
- Action versions: `actions/checkout@v7`, `actions/setup-node@v7`, `node-version: 'lts/*'`; no `cache:` input.
- Triggers: `pull_request` (all PRs) plus `push` to `branches: [main]`.
- No `package.json`/`npm test`; no CLI options on run.sh; no machine-readable output; no CI matrix, caching, concurrency groups, or lint job.
- No changes to `release-please.yml`, no README/docs updates.
- Implementer discipline: never commit; never write any repo file outside the task's `files` list (temp files go in `mktemp` dirs outside the repo).

### Task 1: Create tests/run.sh (suite aggregator)

**Goal:** Add the single deterministic entry point that runs all four suites keep-going, prints the per-suite summary, and exits 0/1/2 per the contract.

**Files:**
- Create: `tests/run.sh`

**Steps:**

1. Red: confirm the entry point does not exist yet — `bash tests/run.sh` must fail (127). Confirm the four suite files exist.
2. Create `tests/run.sh` with exactly this content (behavior and output shape are the contract; do not restructure):

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

3. `chmod +x tests/run.sh` (the coordinator commits — you do not).
4. Green — happy path (criterion 1), ONE invocation from the repo root:

```bash
out="$(bash tests/run.sh 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] \
  && printf '%s\n' "$out" | grep -qF -- '--- summary ---' \
  && printf '%s\n' "$out" | grep -qF '  ok  - codex-critic.test.sh' \
  && printf '%s\n' "$out" | grep -qF '  ok  - prose-contracts.test.sh' \
  && printf '%s\n' "$out" | grep -qF '  ok  - plan-viz.test.mjs' \
  && printf '%s\n' "$out" | grep -qF '  ok  - review-synth.test.mjs' \
  && printf '%s\n' "$out" | grep -qF 'run.sh: 4 passed, 0 failed'; then
  echo 'HAPPY-PATH: PASS'
else
  echo 'HAPPY-PATH: FAIL' >&2; printf '%s\n' "$out"; exit 1
fi
```

5. cwd-independence (criterion 2), ONE invocation:

```bash
REPO="$(git rev-parse --show-toplevel)"
if (cd / && bash "$REPO/tests/run.sh" > /dev/null 2>&1); then
  echo 'CWD-INDEPENDENCE: PASS'
else echo 'CWD-INDEPENDENCE: FAIL' >&2; exit 1; fi
```

6. Structural exclusion (criterion 4), ONE invocation:

```bash
if [ "$(grep -c pressure tests/run.sh)" -eq 1 ] \
  && [ "$(grep -c '^run_suite ' tests/run.sh)" -eq 4 ] \
  && test -z "$(grep '^run_suite ' tests/run.sh | grep -vE 'bash "|node --test ')"; then
  echo 'EXCLUSION: PASS'
else echo 'EXCLUSION: FAIL' >&2; exit 1; fi
```

7. Missing-node preflight (criterion 5), ONE invocation:

```bash
SHADOW="$(mktemp -d)"
ln -s "$(command -v dirname)" "$SHADOW/dirname"
out="$(PATH="$SHADOW" /bin/bash tests/run.sh 2>"$SHADOW/stderr.txt")"
rc=$?
if [ "$rc" -eq 2 ] && [ -z "$out" ] \
  && grep -qF 'ERROR: node not found on PATH' "$SHADOW/stderr.txt"; then
  echo 'PREFLIGHT: PASS'; rm -rf "$SHADOW"
else echo 'PREFLIGHT: FAIL' >&2; cat "$SHADOW/stderr.txt" >&2; rm -rf "$SHADOW"; exit 1; fi
```

8. If any block prints FAIL: report which block and paste its captured output; touch no file other than `tests/run.sh`.

**Acceptance Criteria:**
- `tests/run.sh` exists, matches the reference implementation's behavior and output shape, exec bit set.
- Full run: four suites, `--- summary ---` with four `  ok  -` lines, `run.sh: 4 passed, 0 failed`, exit 0; low-seconds wall time.
- Same result invoked from `/` via absolute path.
- `grep -c pressure` = 1; exactly four `run_suite` invocations, all `bash` or `node --test`; no discovery.
- `node` shadowed off PATH: `ERROR: node not found on PATH` on stderr, exit 2, no suite output.
- No `set -e`; keep-going structure records failures without short-circuiting.

**Verify:** `test -x tests/run.sh && bash tests/run.sh && [ "$(grep -c pressure tests/run.sh)" -eq 1 ]`

```json:metadata
{"files": ["tests/run.sh"], "modelTier": "mechanical", "verifyCommand": "test -x tests/run.sh && bash tests/run.sh && [ \"$(grep -c pressure tests/run.sh)\" -eq 1 ]", "acceptanceCriteria": ["run.sh exists with exec bit, matches spec reference implementation behavior and output shape", "Full run: four suites, four ok summary lines, 'run.sh: 4 passed, 0 failed', exit 0", "Identical result invoked from / via absolute path", "grep -c pressure = 1; four run_suite lines, all bash or node --test; no discovery", "node shadowed off PATH: 'ERROR: node not found on PATH' on stderr, exit 2, no suite runs", "No set -e; keep-going run_suite structure records failures without short-circuiting"]}
```

### Task 2: Create .github/workflows/test.yml (CI wiring)

**Goal:** Add the GitHub Actions workflow that runs the aggregator on every PR and every push to main, byte-identical to the spec's verified YAML.

**Files:**
- Create: `.github/workflows/test.yml`

**Steps:**

1. Red: confirm `test ! -e .github/workflows/test.yml`.
2. Create `.github/workflows/test.yml` with exactly this content (two-space indent, no comments, no trailing whitespace, single trailing newline):

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

3. Green — byte-compare against the contract content:

```bash
if diff .github/workflows/test.yml - <<'EOF'
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
EOF
then echo 'CONTENT: PASS'; else echo 'CONTENT: FAIL' >&2; exit 1; fi
```

4. Confirm the sibling workflow is untouched, honest exit:

```bash
if git diff --quiet HEAD -- .github/workflows/release-please.yml; then
  echo 'RELEASE-PLEASE: UNTOUCHED'
else echo 'RELEASE-PLEASE: MODIFIED' >&2; exit 1; fi
```
5. Do NOT add `cache:` to setup-node, no secrets, no extra steps, no comments. Touch no file other than `.github/workflows/test.yml`.

**Acceptance Criteria:**
- `.github/workflows/test.yml` byte-identical to the YAML above.
- No `cache:` input, no secrets, no login, no comments, no extra jobs/steps/matrix/concurrency groups.
- `.github/workflows/release-please.yml` byte-identical to HEAD.

**Verify:** `grep -qF 'run: bash tests/run.sh' .github/workflows/test.yml && grep -qF 'actions/checkout@v7' .github/workflows/test.yml && grep -qF 'actions/setup-node@v7' .github/workflows/test.yml && git diff --quiet HEAD -- .github/workflows/release-please.yml`

```json:metadata
{"files": [".github/workflows/test.yml"], "modelTier": "mechanical", "verifyCommand": "grep -qF 'run: bash tests/run.sh' .github/workflows/test.yml && grep -qF 'actions/checkout@v7' .github/workflows/test.yml && grep -qF 'actions/setup-node@v7' .github/workflows/test.yml && git diff --quiet HEAD -- .github/workflows/release-please.yml", "acceptanceCriteria": ["test.yml byte-identical to the spec YAML: push-to-main + pull_request triggers, contents: read, ubuntu-latest, checkout@v7, setup-node@v7 with node-version 'lts/*', run: bash tests/run.sh", "No cache: input, no secrets, no comments, no extra jobs or steps", "release-please.yml byte-identical to HEAD"]}
```

### Task 3: Barrier: keep-going + change-isolation verification gate

**Goal:** Prove the destructive and cross-file criteria — keep-going under an injected suite failure (criterion 3), integrated happy path + wall time (criteria 1, 8), and change isolation (criterion 7) — as a pure verification gate: no file created, no commit produced, the tree left byte-identical to how the wave left it.

**Files:** none — this is a `files: []` verification gate. Per the executor contract it produces NO commit and that is correct; the executor asserts `git status` shows nothing from this task, and the coordinator checks the `AC:` evidence lines instead of dispatching a task reviewer. The previous revision's acceptance-record file is deleted from the plan entirely: it existed only to satisfy the old nonempty-commit rule and violated the spec's "exactly two new files" contract.

**Criterion 7, restored unscoped — with one honest translation.** The spec's literal post-commit form ("`git diff --name-only main...HEAD` lists exactly those two paths") assumed a branch dedicated to this plan. The actual branch predates the plan and legitimately carries the approach-seam work plus plan/spec docs. The unscoped *spirit* — nothing this plan delivered beyond the two files, verified with no path filter that could hide an artifact — is asserted at the commit level instead: each delivery commit's full `diff-tree` must list exactly its one file, no commit anywhere in `main..HEAD` may touch `docs/superpowers/acceptance`, `release-please.yml` must be byte-identical to main, and the gate must leave a zero footprint. Nothing is scoped away; the sweep runs over the whole branch history.

**Steps:**

1. Baseline snapshot, clean-target precondition (refuse to inject into a dirty target — staged AND unstaged), integrated happy path + wall time (criteria 1, 8), ONE invocation:

```bash
set -u
SNAP="${TMPDIR:-/tmp}/foureyes-gate3-status-$(git rev-parse --short HEAD).txt"
git status --porcelain > "$SNAP"
T=tests/codex-critic.test.sh
if git diff --quiet -- "$T" && git diff --cached --quiet -- "$T"; then
  echo 'PRECONDITION: PASS (target clean, staged and unstaged)'
else
  echo 'PRECONDITION: FAIL — target has local changes; refusing to inject' >&2
  git status --porcelain -- "$T" >&2; exit 1
fi
start=$(date +%s); out="$(bash tests/run.sh 2>&1)"; rc=$?
secs=$(( $(date +%s) - start ))
if [ "$rc" -eq 0 ] \
  && printf '%s\n' "$out" | grep -qF '  ok  - codex-critic.test.sh' \
  && printf '%s\n' "$out" | grep -qF '  ok  - prose-contracts.test.sh' \
  && printf '%s\n' "$out" | grep -qF '  ok  - plan-viz.test.mjs' \
  && printf '%s\n' "$out" | grep -qF '  ok  - review-synth.test.mjs' \
  && printf '%s\n' "$out" | grep -qF 'run.sh: 4 passed, 0 failed' \
  && [ "$secs" -le 60 ]; then
  echo "AC: integrated run green — PROVEN BY bash tests/run.sh -> exit 0, 'run.sh: 4 passed, 0 failed', four ok lines, ${secs}s wall"
else
  echo 'HAPPY-PATH: FAIL' >&2; printf '%s\n' "$out" >&2; exit 1
fi
```

2. Keep-going under failure (criterion 3), non-destructive by construction — original bytes saved to `mktemp` outside the repo BEFORE the append, restoration by content (never `git checkout --`, which in a shared worktree could discard unrelated changes), restoration proven by `git hash-object` equality, `trap` restores even on interrupt. ONE invocation:

```bash
set -u
T=tests/codex-critic.test.sh
SAVE="$(mktemp -d)"
cp "$T" "$SAVE/orig"
H0="$(git hash-object "$SAVE/orig")"
restore() { cat "$SAVE/orig" > "$T"; }
trap 'restore' EXIT
echo 'exit 1' >> "$T"
out="$(bash tests/run.sh 2>&1)"; rc=$?
restore
trap - EXIT
if [ "$(git hash-object "$T")" = "$H0" ] && git diff --quiet HEAD -- "$T"; then
  echo "AC: non-destructive restoration — PROVEN BY git hash-object equal before/after ($H0) and empty git diff HEAD -- $T"
else
  echo 'RESTORE: retrying from saved bytes' >&2
  restore
  if [ "$(git hash-object "$T")" = "$H0" ]; then
    echo "AC: non-destructive restoration — PROVEN BY git hash-object equal after re-restore ($H0)"
  else
    echo 'RESTORE: FAIL — hash mismatch persists; saved bytes kept at' "$SAVE/orig" >&2; exit 1
  fi
fi
rm -rf "$SAVE"
if [ "$rc" -eq 1 ] \
  && printf '%s\n' "$out" | grep -qF '  FAIL - codex-critic.test.sh' \
  && printf '%s\n' "$out" | grep -qF 'run.sh: 3 passed, 1 failed' \
  && printf '%s\n' "$out" | grep -qF '=== prose-contracts.test.sh ===' \
  && printf '%s\n' "$out" | grep -qF '=== plan-viz.test.mjs ===' \
  && printf '%s\n' "$out" | grep -qF '=== review-synth.test.mjs ==='; then
  echo "AC: keep-going under injected failure — PROVEN BY exit 1, 'run.sh: 3 passed, 1 failed', 'FAIL - codex-critic.test.sh', all three remaining banners in captured output"
else
  echo 'KEEP-GOING: FAIL' >&2; printf '%s\n' "$out" >&2; exit 1
fi
```

3. Change isolation at the commit level (criterion 7, unscoped), ONE invocation:

```bash
set -u
c_run="$(git rev-list -n 1 HEAD -- tests/run.sh)"
c_yml="$(git rev-list -n 1 HEAD -- .github/workflows/test.yml)"
t_run="$(git diff-tree --no-commit-id --name-only -r "$c_run")"
t_yml="$(git diff-tree --no-commit-id --name-only -r "$c_yml")"
if [ "$t_run" = "tests/run.sh" ] && [ "$t_yml" = ".github/workflows/test.yml" ]; then
  echo "AC: delivery commits touch exactly their own file — PROVEN BY git diff-tree -r $c_run -> '$t_run'; git diff-tree -r $c_yml -> '$t_yml'"
else
  echo 'ISOLATION: FAIL — a delivery commit carries extra paths' >&2
  printf '%s\n' "$t_run" "$t_yml" >&2; exit 1
fi
if git diff --quiet main...HEAD -- .github/workflows/release-please.yml \
  && [ ! -e docs/superpowers/acceptance ] \
  && [ -z "$(git log --format= --name-only main..HEAD -- docs/superpowers/acceptance)" ]; then
  echo 'AC: release-please untouched and no acceptance artifacts — PROVEN BY empty git diff main...HEAD -- .github/workflows/release-please.yml; test ! -e docs/superpowers/acceptance; empty git log --name-only main..HEAD -- docs/superpowers/acceptance'
else
  echo 'ARTIFACT-CHECK: FAIL' >&2
  git log --oneline --name-only main..HEAD -- docs/superpowers/acceptance >&2; exit 1
fi
```

4. Zero gate footprint (the executor's `files: []` assertion, proven from inside), ONE invocation:

```bash
set -u
SNAP="${TMPDIR:-/tmp}/foureyes-gate3-status-$(git rev-parse --short HEAD).txt"
now="$(git status --porcelain)"
if [ "$now" = "$(cat "$SNAP")" ] \
  && ! printf '%s\n' "$now" | grep -qE 'tests/|\.github/workflows/'; then
  echo 'AC: zero gate footprint — PROVEN BY git status --porcelain identical to the step-1 snapshot and free of tests/ and .github/workflows/ paths'
else
  echo 'FOOTPRINT: FAIL' >&2; diff "$SNAP" <(printf '%s\n' "$now") >&2; rm -f "$SNAP"; exit 1
fi
rm -f "$SNAP"
```

5. Failure protocol: every block exits nonzero on failure by construction, and step 2's trap plus content-restore guarantee the target is clean even on failure paths. Report which block failed with its captured output. Do NOT edit `run.sh` or `test.yml` — out of scope; a suite failure attributes to Task 1 or Task 2. Emit no `AC:` line for anything unproven.

**Acceptance Criteria:**
- Integrated run green: exit 0, `run.sh: 4 passed, 0 failed`, four `  ok  -` lines; wall time recorded and <= 60s.
- Keep-going under injected failure: exit 1, `  FAIL - codex-critic.test.sh`, `run.sh: 3 passed, 1 failed`, all three remaining `===` banners present.
- Non-destructive restoration: clean-target precondition; original bytes saved outside the repo; restored by content with `git hash-object` equality; target byte-identical to HEAD.
- Delivery commits touch exactly their own file: full `diff-tree` of each delivery commit lists exactly one path.
- release-please untouched and no acceptance artifacts anywhere in `main..HEAD`.
- Zero gate footprint: `git status --porcelain` identical before and after, free of delivery paths.

**Verify:** re-executes the defining behavior with honest exit status and no reliance on any record or self-authored label — clean-target precondition, happy-path re-run, content-saved re-injection with hash-checked restore asserting exit 1 + `3 passed, 1 failed`, then the commit-level isolation battery. Independent of push/PR state.

```json:metadata
{"files": [], "modelTier": "mechanical", "verifyCommand": "bash -c 'set -u; T=tests/codex-critic.test.sh; git diff --quiet -- \"$T\" || exit 1; git diff --cached --quiet -- \"$T\" || exit 1; bash tests/run.sh >/dev/null 2>&1 || exit 1; S=$(mktemp -d); cp \"$T\" \"$S/orig\"; H0=$(git hash-object \"$S/orig\"); trap \"cat \\\"$S/orig\\\" > \\\"$T\\\"; rm -rf \\\"$S\\\"\" EXIT; echo \"exit 1\" >> \"$T\"; out=$(bash tests/run.sh 2>&1); s=$?; cat \"$S/orig\" > \"$T\"; [ \"$(git hash-object \"$T\")\" = \"$H0\" ] || exit 1; [ \"$s\" -eq 1 ] || exit 1; printf \"%s\\n\" \"$out\" | grep -qF \"run.sh: 3 passed, 1 failed\" || exit 1; git diff --quiet HEAD -- \"$T\" || exit 1; c1=$(git rev-list -n 1 HEAD -- tests/run.sh); c2=$(git rev-list -n 1 HEAD -- .github/workflows/test.yml); [ \"$(git diff-tree --no-commit-id --name-only -r \"$c1\")\" = tests/run.sh ] || exit 1; [ \"$(git diff-tree --no-commit-id --name-only -r \"$c2\")\" = .github/workflows/test.yml ] || exit 1; git diff --quiet main...HEAD -- .github/workflows/release-please.yml || exit 1; test ! -e docs/superpowers/acceptance || exit 1; [ -z \"$(git log --format= --name-only main..HEAD -- docs/superpowers/acceptance)\" ]'", "acceptanceCriteria": ["integrated run green: exit 0, 'run.sh: 4 passed, 0 failed', four ok lines, wall time <= 60s", "keep-going under injected failure: exit 1, 'FAIL - codex-critic.test.sh', 'run.sh: 3 passed, 1 failed', remaining three suite banners present", "non-destructive restoration: clean-target precondition, bytes saved outside the repo, restored by content with git hash-object equality, target byte-identical to HEAD", "delivery commits touch exactly their own file: diff-tree of each delivery commit lists exactly one path", "release-please untouched and no acceptance artifacts in the tree or anywhere in main..HEAD", "zero gate footprint: git status --porcelain identical before and after, free of delivery paths"], "blockedBy": [1, 2]}
```

_modelTier: mechanical — every step is a complete copy-paste block with derived values, bounded behavior, and honest exits; no judgment remains._

### Task 4: Post-join CI gate (COORDINATOR-OWNED)

**Goal:** Prove spec criterion 6 against GitHub itself: the `test` check appears on a real PR and is green with no secrets; a seeded failing test turns a check red at the `run: bash tests/run.sh` step; after merge, the workflow runs green on main's merge commit.

**Ownership:** executed by the coordinator or the human driving it, NEVER dispatched to an implementer — implementers never push, and every observation requires a real push and GitHub actually running the workflow. Prerequisite: `gh` authenticated.

**Design decisions (replacing the previous revision's record + on-branch seed):**
- **`files: []` — yes.** The old "CI record" was the same invented artifact the critic flagged. Durable evidence already exists in GitHub's own run and PR history, which outlives any shell session and cannot be self-authored. With the executor's verification-gate exemption this task legally produces no commit.
- **The seeded-red probe leaves the shared branch.** Committing deliberate breakage to the feature branch created the transient-commit ownership contradiction. Instead the seed goes on a throwaway branch built in a temporary `git worktree`, observed via a draft PR, then closed unmerged and deleted. The `test` workflow triggers on all `pull_request` events, so the probe PR is a real PR and the red observation is genuine; the feature branch's history never contains the breakage, so there is nothing to revert and no ownership exception to model.
- **Criterion 7 lives wholly in Task 3** (commit-level, unscoped). This task carries criterion 6 only.

**Steps:** (full copy-pasteable blocks — preconditions + push + PR; bounded-poll green check with `statusCheckRollup` assertion and a no-`secrets.` grep; throwaway-worktree seeded-red probe with a cleanup `trap` that closes the PR and deletes the branch on every exit path; self-arming post-merge clause; zero-footprint assertion. Every value derived by a command in the block that uses it; polling bounded at 40x15s for run discovery and 60x10s for completion.)

**The post-merge criterion is self-arming.** The merge is a human decision that happens after this gate completes, so no command run at gate time can observe main's merge commit. The honest contract: before the merge the block reports the check PENDING and armed; the `verifyCommand`'s conditional enforces the main-run assertion automatically the moment `gh pr view` reports MERGED. That is a stated weaker contract, not a concealment.

**Acceptance Criteria:**
- test check green on the real PR head: `test.yml` run conclusion `success` for the PR head sha; `statusCheckRollup` lists `test=SUCCESS`.
- no secrets: zero `secrets.` references in `test.yml` and the green run needed none.
- seeded red at the run.sh step: probe run conclusion `failure` with `run.sh: 3 passed, 1 failed` in `--log-failed`; probe PR closed unmerged, probe branch deleted, feature branch history untouched.
- post-merge main run green: enforced live by the self-arming verify clause once the PR reports MERGED.
- gate leaves no commit and no footprint: empty `git status --porcelain`, HEAD equal to the pushed branch tip, no probe worktree remaining.

**Verify:** queries live GitHub state only, no self-authored labels — a `success` run for the pushed branch tip, a `failure` run on the probe branch (run records persist after branch deletion), and, if the PR reports MERGED, a `success` run for `mergeCommit.oid` on main.

```json:metadata
{"files": [], "modelTier": "mechanical", "verifyCommand": "bash -c 'set -u; BR=feat/approach-seam-and-self-contained; PROBE=ci-red-probe-2026-08-05-test-entry-point; git fetch origin >/dev/null 2>&1 || exit 1; sha=$(git rev-parse \"origin/$BR\" 2>/dev/null || git rev-parse HEAD); ok=$(gh run list --workflow=test.yml --branch \"$BR\" --limit 20 --json headSha,conclusion --jq \"[.[] | select(.headSha == \\\"$sha\\\" and .conclusion == \\\"success\\\")] | length\"); [ \"${ok:-0}\" -ge 1 ] || exit 1; red=$(gh run list --workflow=test.yml --branch \"$PROBE\" --limit 10 --json conclusion --jq \"[.[] | select(.conclusion == \\\"failure\\\")] | length\"); [ \"${red:-0}\" -ge 1 ] || exit 1; state=$(gh pr view \"$BR\" --json state --jq .state 2>/dev/null); if [ \"$state\" = \"MERGED\" ]; then m=$(gh pr view \"$BR\" --json mergeCommit --jq .mergeCommit.oid); g=$(gh run list --workflow=test.yml --branch main --limit 30 --json headSha,conclusion --jq \"[.[] | select(.headSha == \\\"$m\\\" and .conclusion == \\\"success\\\")] | length\"); [ \"${g:-0}\" -ge 1 ] || exit 1; fi'", "acceptanceCriteria": ["test check green on the real PR head: run conclusion success for the PR head sha; statusCheckRollup lists test=SUCCESS", "no secrets: zero secrets. references in test.yml and the green run needed none", "seeded red at the run.sh step: probe run conclusion failure with 'run.sh: 3 passed, 1 failed' in --log-failed; probe PR closed unmerged, probe branch deleted, feature branch untouched", "post-merge main run green: self-arming verify clause enforces a success run for mergeCommit.oid once the PR reports MERGED", "gate leaves no commit and no footprint: empty git status --porcelain, HEAD == pushed branch tip, no probe worktree"], "blockedBy": [3]}
```

_modelTier: mechanical (nominal — never routed, coordinator-owned): every block is complete with derived values, bounded polling, and honest exits; the one judgment point (merge timing) is encoded as the self-arming clause._
