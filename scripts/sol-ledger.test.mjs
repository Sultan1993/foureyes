import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync } from 'node:fs';
import { tmpdir, homedir } from 'node:os';
import { join } from 'node:path';
import { parseLog, tally, resolveTargets, readRepoList, median, dur, sortSeams, SEAMS, DISPOSITIONS } from './sol-ledger.mjs';

const LOG = `# Sol critique log — widget-sync

## spec · round 1 · 2026-08-09
- [Important] fixed — section 3 contradicts the offline assumption
- [Critical] rejected — cited API is absent; checked, \`foo.bar()\` is present
- [Important] intentional — migration deferred to a follow-up

## spec · round 2 · 2026-08-09
- [Important] open — no success criterion for the migration path

## plan · round 1 · 2026-08-09
- (none)
`;

test('parses seam, round, severity and disposition', () => {
  const rows = parseLog(LOG);
  assert.equal(rows.length, 4);
  assert.deepEqual(rows[0], {
    seam: 'spec', round: 1, severity: 'Important', disposition: 'fixed',
    text: 'section 3 contradicts the offline assumption',
  });
  assert.equal(rows[3].round, 2);
});

test('a clean round logs (none) and contributes no findings', () => {
  const rows = parseLog(LOG);
  assert.equal(rows.filter((r) => r.seam === 'plan').length, 0);
});

// The delimiter is the em-dash, and findings contain em-dashes of their own.
// Leading disposition is what makes that safe; trailing would not be.
test('an em-dash inside the finding text does not split it', () => {
  const rows = parseLog('## code · round 1 · 2026-08-09\n- [Critical] fixed — the wave — all of it — raced\n');
  assert.equal(rows[0].disposition, 'fixed');
  assert.equal(rows[0].text, 'the wave — all of it — raced');
});

test('findings before any header are ignored, not misattributed', () => {
  const rows = parseLog('- [Critical] fixed — orphan\n## spec · round 1 · 2026-08-09\n- [Minor] open — real\n');
  assert.equal(rows.length, 1);
  assert.equal(rows[0].text, 'real');
});

test('tally counts per seam and keeps rounds separate', () => {
  const t = tally(parseLog(LOG));
  assert.deepEqual(t.get('spec'), { raised: 4, fixed: 1, rejected: 1, intentional: 1, open: 1, other: 0 });
  assert.equal(t.has('plan'), false);
});

// A typo'd disposition that silently vanished would understate its seam's
// raised count, which is the one number the whole ledger exists to report.
test('an unknown disposition still counts as raised', () => {
  const t = tally(parseLog('## spec · round 1 · 2026-08-09\n- [Critical] deferred — later\n'));
  assert.equal(t.get('spec').raised, 1);
  assert.equal(t.get('spec').other, 1);
});

test('an unknown seam is kept, not dropped', () => {
  const t = tally(parseLog('## approcah · round 1 · 2026-08-09\n- [Minor] fixed — typo in the header\n'));
  assert.equal(t.get('approcah').raised, 1);
});

test('severity is recorded but never filters — a Criticals-only log is not a clean log', () => {
  const t = tally(parseLog('## code · round 1 · 2026-08-09\n- [Critical] open — a\n- [Minor] open — b\n'));
  assert.equal(t.get('code').raised, 2);
});

test('the vocabularies the seams write against are the ones parsed', () => {
  assert.deepEqual(SEAMS, ['approach', 'investigate', 'spec', 'plan', 'code']);
  assert.deepEqual(DISPOSITIONS, ['fixed', 'rejected', 'intentional', 'open']);
});

// The logs live in the repos you BUILD in. Passing a repo root has to work, or
// every read means typing the full docs/foureyes/specs path per repo — which
// is the friction that stops anyone from ever running this.
const mkroot = () => mkdtempSync(join(tmpdir(), 'ledger-'));
// The reader targets docs/foureyes, not .../specs: build writes a bare plan's
// log beside the PLAN, and a specs-only scan made exactly those logs invisible.
const sup = (root, ...seg) => join(root, ...seg, 'docs/foureyes');
const specs = (root, ...seg) => join(root, ...seg, 'docs/foureyes/specs');

test('a repo root resolves to its superpowers directory', () => {
  const root = mkroot();
  mkdirSync(specs(root), { recursive: true });
  assert.deepEqual(resolveTargets(root), [sup(root)]);
});

// Regression: a log written beside the PLAN (build does this for a bare plan) was
// unreachable while the reader scanned specs/ only.
test('a critique log under plans/ is reachable, not just under specs/', () => {
  const root = mkroot();
  mkdirSync(join(sup(root), 'plans'), { recursive: true });
  writeFileSync(join(sup(root), 'plans', 'x-critique.md'), '## code · round 1 · 2026-08-11 · 60s\n- [Minor] fixed — y\n');
  const [target] = resolveTargets(root);
  assert.equal(target, sup(root));
});

// Real layout: an umbrella dir whose sub-repos each carry their own specs, AND
// which carries some of its own. Returning only the top-level match would report
// on a fraction and read as "few findings here".
test('an umbrella returns its own dir AND every sub-repo\'s', () => {
  const root = mkroot();
  for (const p of [specs(root), specs(root, 'Android'), specs(root, 'Backend')]) mkdirSync(p, { recursive: true });
  assert.deepEqual(resolveTargets(root).sort(), [sup(root), sup(root, 'Android'), sup(root, 'Backend')].sort());
});

test('a specs directory passed directly is left alone', () => {
  const dir = mkroot();
  assert.deepEqual(resolveTargets(dir), [dir]);
});

test('a nonexistent path resolves to nothing, so main can report it as missing', () => {
  assert.deepEqual(resolveTargets('/nonexistent-xyz'), []);
});

test('node_modules is never walked', () => {
  const root = mkroot();
  mkdirSync(specs(root, 'node_modules', 'pkg'), { recursive: true });
  assert.deepEqual(resolveTargets(root), [root]);
});

test('docs/ is never descended into looking for more', () => {
  const root = mkroot();
  mkdirSync(join(specs(root), 'sub/docs/foureyes/specs'), { recursive: true });
  assert.deepEqual(resolveTargets(root), [sup(root)]);
});

test('the repo list skips comments and blanks, and expands ~', () => {
  const root = mkroot();
  const f = join(root, 'list');
  writeFileSync(f, '# a comment\n\n~/dev/one\n/abs/two   # trailing\n');
  const got = readRepoList(f);
  assert.equal(got.length, 2);
  assert.equal(got[0], join(homedir(), 'dev/one'));
  assert.equal(got[1], '/abs/two');
});

test('a missing repo list is empty, not an error', () => {
  assert.deepEqual(readRepoList('/nonexistent-xyz/list'), []);
});

// Duration is what turns a hit rate into a decision, but logs written before
// timing existed must keep parsing — hence optional, matched separately.
test('a round header carries its duration when present', () => {
  const r = parseLog('## spec · round 1 · 2026-08-09 · 287s\n- [Minor] fixed — a\n');
  assert.deepEqual(r.rounds, [{ seam: 'spec', round: 1, secs: 287 }]);
});

test('a header without a duration parses with secs null', () => {
  const r = parseLog('## spec · round 1 · 2026-08-09\n- [Minor] fixed — a\n');
  assert.equal(r.rounds[0].secs, null);
  assert.equal(r.length, 1);
});

// A clean round still cost its five minutes. Counting rounds from findings
// would drop it and flatter the seam.
test('a clean round is still counted, with no findings', () => {
  const r = parseLog('## plan · round 1 · 2026-08-09 · 90s\n- (none)\n');
  assert.equal(r.length, 0);
  assert.deepEqual(r.rounds, [{ seam: 'plan', round: 1, secs: 90 }]);
});

test('a date that ends in a digit is not mistaken for a duration', () => {
  assert.equal(parseLog('## spec · round 1 · 2026-08-09\n').rounds[0].secs, null);
});

test('median takes the mean of the middle pair on even counts', () => {
  assert.equal(median([1, 2, 3]), 2);
  assert.equal(median([10, 20, 30, 40]), 25);
  assert.equal(median([]), null);
});

test('durations render as m/s above a minute', () => {
  assert.equal(dur(45), '45s');
  assert.equal(dur(290), '4m50s');
  assert.equal(dur(3605), '60m05s');
  assert.equal(dur(null), '—');
});

// A seam that always runs clean raises nothing, so ordering the cost table by
// the findings tally would hide its price entirely — and a seam costing five
// minutes to say "no issues" every time is the strongest candidate for cutting.
test('a findings-free seam still appears among the seams to cost', () => {
  const r = parseLog('## plan · round 1 · 2026-08-09 · 88s\n- (none)\n');
  assert.equal(tally(r).has('plan'), false);
  assert.deepEqual(sortSeams([...new Set(r.rounds.map((x) => x.seam))]), ['plan']);
});

test('seams sort in pipeline order, unknown ones last', () => {
  assert.deepEqual(sortSeams(['code', 'zzz', 'spec', 'approach']), ['approach', 'spec', 'code', 'zzz']);
});
