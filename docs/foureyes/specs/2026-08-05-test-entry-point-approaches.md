# Approaches — single test entry point

Brief: one entry point that runs every deterministic suite in `foureyes`, wired
into GitHub Actions. The pressure suite is excluded (needs the `claude` CLI, costs
real money). CI must not require a Codex or Claude login.

## Proposed

Raw pool, both proposers, nothing merged or dropped. Ordered alphabetically by
title — deterministic, content-derived, and uncorrelated with who wrote it.

### 1 — Bash aggregator script + new test workflow
WHAT: `tests/run.sh` runs the four deterministic suites and nothing
else: the two bash suites, plus one `node --test` invocation with the two explicit
`.mjs` paths. Runs every suite even when an earlier one fails, prints a per-suite
summary, exits nonzero if any failed. Pressure is excluded by simple omission — never
listed, so no login, no cost, no conditional logic. New `.github/workflows/test.yml`
(checkout, setup-node pinned to LTS) on `pull_request` and `push` to main;
`release-please.yml` untouched.
COST: Two new files. No deps, manifests, or migrations. Harder later: a fifth node
suite is not auto-discovered and needs a line added (a `*.test.mjs` glob confined to
`skills/` would fix that, at the price of auto-scooping future files).
GIVES UP: `npm test` muscle memory for outside contributors; manifest metadata such
as an engines field pinning a Node floor.
CHECKED: `node --test` accepts explicit paths and exits 1 when any test fails, stable
since Node v20 (Context7, /nodejs/node test.md + cli.md). Both bash suites end in
`[ "$FAIL" -eq 0 ]`, so exit codes are trustworthy; `codex-critic.test.sh` prepends
`tests/stubs` to PATH itself, so the runner needs no stub setup.
`actions/checkout@v4`/`setup-node@v4` are long-stable first-party actions — not re-verified.

### 2 — Explicit Bash runner
WHAT: `tests/run.sh` resolves the repo path and sequentially runs the
four named suites; `.github/workflows/test.yml` calls it on push and pull request.
The runner uses an explicit allowlist, so `tests/pressure/run.sh` cannot be
discovered or invoked accidentally.
COST: No dependencies or migrations; two new files, no changes to existing tests.
Future deterministic suites require one explicit runner edit.
GIVES UP: No automatic discovery, no parallel jobs, no per-suite CI status.
CHECKED: Repo inspection confirmed both node suites use built-in `node:test`, both
bash suites are self-contained, `codex-critic.test.sh` substitutes a fake Codex
executable, and only the excluded pressure suite invokes `claude`. Context7's GitHub
Actions docs (/websites/github_en_actions) confirmed `ubuntu-latest`,
`actions/checkout`, `actions/setup-node`, and push/pull-request triggers work with no
Codex or Claude login.

### 3 — Makefile with a `test` target + new test workflow
WHAT: Root `Makefile` with `test:` (the four suites) and room for a later
`pressure:` target; CI runs `make test`.
COST: A third convention layered onto a bash-script repo, expressing what is
underneath exactly the same script, with tab-sensitive syntax and `.PHONY`
boilerplate. macOS ships BSD make and CI uses GNU make — trivial here, but a
portability contract someone now keeps.
GIVES UP: Nothing entry 1 doesn't also give up — it is that entry wearing a Makefile
costume.
CHECKED: n/a, no external capability (make is preinstalled on macOS and
ubuntu-latest; node/bash facts as above).

### 4 — Root `package.json` with `npm test` + new test workflow
WHAT: Minimal root `package.json` (`"private": true`, no deps) whose `"test"` script
chains the two bash suites and `node --test` over the two `.mjs` files; CI runs
`npm test`. Root, not inside `foureyes/`, where it could ride along with plugin
packaging.
COST: Introduces a Node manifest into a plugin marketplace repo with zero npm
dependencies. release-please is configured for a non-node repo, and a root
`package.json` invites its node strategy assumptions, `npm install` reflexes, and
lockfile questions that all must be actively suppressed. The test logic still ends up
as a shell one-liner inside a JSON string.
GIVES UP: Single-convention purity; manifest maintenance bought only an `npm test` alias.
CHECKED: Same `node --test` verification as entry 1 (Context7, /nodejs/node). npm
`scripts.test` is npm core and not version-sensitive here — not separately verified.

## Decisions

Written after ranking, never before — this is the audit trail, not an input to the
judgment.

**Provenance**
| entry | proposed by | outcome |
|---|---|---|
| 1 — Bash aggregator / Explicit Bash runner | **both** (Fable, Sol) | merged, recommended |
| 3 — Makefile `test` target | Fable | kept, ranked below 1 |
| 4 — Root `package.json` | Fable | kept, ranked below 1 |

Both proposers' own picks: Fable `VERDICT: A`, Sol `VERDICT: A` — independently the
same design. Neither proposer raised any `UNKNOWNS`, so the approach question is the
only thing to ask.

**Merged.** Entries 1 and 2 are one design under two descriptions: a bash runner over
an explicit allowlist plus a `test.yml` workflow. Merged into entry 1, keeping entry
2's framing that an allowlist means the pressure suite *cannot* be invoked
accidentally, rather than merely being left out.

**Re-verified** — only the load-bearing claims the runner rests on, since both
`CHECKED` lines were substantive rather than thin:
- both bash suites end in `[ "$FAIL" -eq 0 ]` → exit codes are trustworthy ✓
- `codex-critic.test.sh:10` exports `PATH="$HERE/stubs:$PATH"` itself → the runner
  needs no stub setup ✓
- both node suites import `node:test` + `node:assert/strict` → no dependencies ✓
- only `tests/pressure/run.sh` invokes `claude` ✓ — `review-synth.mjs` matches a grep
  for "claude" but those are a parameter name and a `raisedBy` label, not an
  invocation. Checked because a stray `claude` call would break the "CI needs no
  login" requirement.

**Not re-verified**, deliberately: `node --test` exit semantics and the GitHub
Actions basics. Both proposers verified these independently via Context7 and agree;
a third pass buys nothing.

**Dropped:** none. Entries 3 and 4 are workable, just worse — ranking is not disproof.

**CHOSEN: 1 — user** (bash runner + test.yml)
