#!/usr/bin/env node
// sol-ledger.mjs — read the critique logs the seams write, and answer one
// question: is Sol earning its keep, per seam?
//
// The seams (brainstorm 3/5, build S3) append to
// docs/foureyes/specs/<slug>-critique.md as they go. This reads them back.
// No model calls, no network, no state — the files are committed, so this works
// across the whole repo history without anything being kept anywhere else.
//
// Line format the seams write, and the ONLY thing parsed here:
//
//   ## <seam> · round <n> · <YYYY-MM-DD>
//   - [<Severity>] <disposition> — <what the finding was>
//
// Disposition leads rather than trails so the em-dash inside a finding's own
// text can never be mistaken for the delimiter.
import { readFileSync, readdirSync, statSync, existsSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

// Written by this plugin now, and by its previous name before the rename.
export const DOC_DIRS = ['foureyes', 'superpowers'];
export const SEAMS = ['approach', 'investigate', 'spec', 'plan', 'code'];
export const DISPOSITIONS = ['fixed', 'rejected', 'intentional', 'open'];

const HEAD = /^##\s+(\S+)\s+·\s+round\s+(\d+)/;
// Duration is optional and matched separately from HEAD, so logs written before
// timing existed still parse. codex-critic.sh reports it; the seam appends it.
const SECS = /·\s*(\d+)s\s*$/;
// Severity is captured but not filtered on: a seam that logs only Criticals
// would look like a clean seam, and that is exactly the failure this guards.
const FIND = /^-\s+\[(\w+)\]\s+(\w+)\s+—\s+(.*)$/;

// One file → rows. Unknown seams and dispositions are RETURNED, not dropped:
// a typo that silently vanished would understate the seam it belongs to.
export function parseLog(text) {
  const rows = [], rounds = [];
  let seam = null, round = null;
  for (const line of String(text).split('\n')) {
    const h = HEAD.exec(line);
    if (h) {
      seam = h[1]; round = Number(h[2]);
      const s = SECS.exec(line);
      // A round is counted once, whether or not it produced findings — a clean
      // round still cost its five minutes, and dropping it would flatter the seam.
      rounds.push({ seam, round, secs: s ? Number(s[1]) : null });
      continue;
    }
    const f = FIND.exec(line.trim());
    if (!f || !seam) continue;
    rows.push({ seam, round, severity: f[1], disposition: f[2].toLowerCase(), text: f[3] });
  }
  rows.rounds = rounds;
  return rows;
}

export function tally(rows) {
  const by = new Map();
  for (const r of rows) {
    if (!by.has(r.seam)) by.set(r.seam, { raised: 0, fixed: 0, rejected: 0, intentional: 0, open: 0, other: 0 });
    const t = by.get(r.seam);
    t.raised++;
    if (r.disposition in t) t[r.disposition]++; else t.other++;
  }
  return by;
}

// acted-on = the share of findings that changed the artifact or were consciously
// kept. `rejected` is the complement worth watching: Sol was factually wrong and
// the round was spent anyway.
const actedOn = (t) => (t.raised ? Math.round(((t.fixed + t.intentional) / t.raised) * 100) : 0);

function collect(dir) {
  let files = [];
  for (const e of readdirSync(dir, { withFileTypes: true })) {
    const p = join(dir, e.name);
    if (e.isDirectory()) files = files.concat(collect(p));
    else if (e.name.endsWith('-critique.md')) files.push(p);
  }
  return files;
}

// Pipeline order, then anything unrecognized, so a typo'd seam name sits at the
// bottom instead of hiding among the real ones.
export function sortSeams(names) {
  return [...names].sort((a, b) => {
    const ia = SEAMS.indexOf(a), ib = SEAMS.indexOf(b);
    return (ia < 0 ? 99 : ia) - (ib < 0 ? 99 : ib) || a.localeCompare(b);
  });
}

export function median(a) {
  if (!a.length) return null;
  const s = [...a].sort((x, y) => x - y);
  return s.length % 2 ? s[(s.length - 1) / 2] : Math.round((s[s.length / 2 - 1] + s[s.length / 2]) / 2);
}
export function dur(s) {
  if (s === null || s === undefined) return '—';
  return s < 60 ? `${s}s` : `${Math.floor(s / 60)}m${String(s % 60).padStart(2, '0')}s`;
}

function pad(s, n) { s = String(s); return s + ' '.repeat(Math.max(0, n - s.length)); }
function lpad(s, n) { s = String(s); return ' '.repeat(Math.max(0, n - s.length)) + s; }

// Directories that never contain specs and cost a fortune to walk.
const PRUNE = new Set(['node_modules', 'build', 'dist', 'out', 'target', 'vendor',
  'Pods', 'DerivedData', '__pycache__', 'Carthage']);

// An argument may be a specs dir, a repo root, OR an umbrella holding several
// repos — real projects nest (an umbrella whose sub-repos each carry
// their own docs/foureyes/specs, AND so does the umbrella). Returning only
// the top-level match would silently report on a fraction of the specs and read
// as "few findings here", so every match under the path is returned.
export function resolveTargets(arg, maxDepth = 4) {
  const hits = [];
  const walk = (dir, depth) => {
    let entries;
    try { entries = readdirSync(dir, { withFileTypes: true }); } catch { return; }
    for (const e of entries) {
      if (!e.isDirectory() || e.name.startsWith('.') || PRUNE.has(e.name)) continue;
      if (e.name === 'docs') {
        // The whole docs/<convention> dir, NOT .../specs: build writes a bare
        // plan's log beside the PLAN, and scanning only specs/ made exactly those
        // logs invisible. Anything named *-critique.md is found wherever it sits.
        //
        // BOTH conventions, always. New runs write docs/foureyes; everything
        // recorded before the rename lives under docs/superpowers, and dropping
        // it would silently under-report every seam on years of real history
        // rather than fail loudly.
        for (const conv of DOC_DIRS) {
          const s = join(dir, 'docs', conv);
          try { if (statSync(s).isDirectory()) hits.push(s); } catch { /* not this one */ }
        }
        continue; // never descend into docs/ looking for more
      }
      if (depth < maxDepth) walk(join(dir, e.name), depth + 1);
    }
  };
  try { if (!statSync(arg).isDirectory()) return []; } catch { return []; }
  walk(arg, 0);
  // No docs/foureyes/specs anywhere under it: the arg may BE a specs dir.
  return hits.length ? hits : [arg];
}

// With no arguments, read the user's own repo list before falling back to the
// current directory — the logs live in the repos you BUILD in, which is never
// the plugin repo you are usually standing in.
export const REPO_LIST = join(homedir(), '.claude', 'foureyes-repos');
export function readRepoList(file = REPO_LIST) {
  let text;
  try { text = readFileSync(file, 'utf8'); } catch { return []; }
  return text.split('\n')
    .map((l) => l.replace(/#.*$/, '').trim())
    .filter(Boolean)
    .map((l) => (l.startsWith('~/') ? join(homedir(), l.slice(2)) : l));
}

function main(args) {
  // ponytail: rescans every file each run. Fine at this size; if it ever matters,
  // cache by (path, mtime) — not worth it against a directory of small markdown.
  const roots = args.length ? args : (readRepoList().length ? readRepoList() : ['.']);
  const found = [], missing = [];
  for (const r of roots) {
    const t = resolveTargets(r);
    if (t.length && (t[0] !== r || existsSync(r))) found.push(...t); else missing.push(r);
  }
  // One bad path must not kill a multi-repo sweep, but it must never pass
  // silently either — a dropped repo reads as "that repo has no findings".
  for (const d of missing) console.error(`sol-ledger: skipping, no such directory: ${d}`);
  if (!found.length) process.exit(2);

  const files = found.flatMap(collect);
  const dir = found.length === 1 ? found[0] : `${found.length} superpowers dirs`;

  if (!files.length) {
    console.log(`\nNo critique logs yet — searched ${found.length} superpowers director${found.length === 1 ? 'y' : 'ies'}:`);
    for (const d of found) console.log(`  ${d}`);
    console.log('\nSeams append a log as they run. A repo that has not run one since the ledger');
    console.log('shipped is empty for that reason, not because Sol found nothing.\n');
    return;
  }

  const parsed = files.map((f) => parseLog(readFileSync(f, 'utf8')));
  const rows = parsed.flat();
  const roundRecs = parsed.flatMap((p) => p.rounds);
  if (!rows.length) {
    console.log(`${files.length} critique log(s) under ${dir}, no findings recorded.`);
    console.log('A seam that ran clean logs `- (none)`, which is a real result: Sol found nothing.');
    return;
  }

  const by = tally(rows);
  // Rounds come from headers, not findings: a clean round still cost its five
  // minutes, and counting only rounds that found something flatters the seam.
  console.log(`\nSol ledger — ${dir} (${files.length} feature(s), ${roundRecs.length} round(s), ${rows.length} finding(s))\n`);
  console.log(`${pad('seam', 10)}${lpad('raised', 7)}${lpad('fixed', 7)}${lpad('rejected', 10)}${lpad('intentional', 13)}${lpad('open', 6)}${lpad('acted-on', 10)}`);

  const order = sortSeams([...by.keys()]);
  for (const seam of order) {
    const t = by.get(seam);
    const mark = SEAMS.includes(seam) ? '' : '  ← unknown seam';
    console.log(`${pad(seam, 10)}${lpad(t.raised, 7)}${lpad(t.fixed, 7)}${lpad(t.rejected, 10)}${lpad(t.intentional, 13)}${lpad(t.open, 6)}${lpad(actedOn(t) + '%', 10)}${mark}`);
  }

  // ---- cost ----------------------------------------------------------------
  // A hit rate is not a decision on its own. 72% acted-on is worth having at 90
  // seconds a round and probably is not at nine minutes, so the ledger prints
  // the denominator next to the numerator.
  const timed = roundRecs.filter((r) => r.secs !== null);
  if (timed.length) {
    console.log('\n— cost —');
    console.log(`${pad('seam', 10)}${lpad('rounds', 7)}${lpad('timed', 7)}${lpad('median', 9)}${lpad('total', 9)}${lpad('per acted-on', 15)}`);
    // Seams come from the ROUNDS, not the findings tally. A seam that always
    // runs clean raises nothing, so ordering by findings would hide its cost
    // entirely — and a seam that costs five minutes to say "no issues" every
    // time is the single strongest candidate for cutting.
    for (const seam of sortSeams([...new Set(roundRecs.map((r) => r.seam))])) {
      const rs = roundRecs.filter((r) => r.seam === seam);
      const ts = rs.filter((r) => r.secs !== null).map((r) => r.secs);
      const t = by.get(seam) || { fixed: 0, intentional: 0 };
      const useful = t.fixed + t.intentional;
      const total = ts.reduce((a, b) => a + b, 0);
      // Scale total by the untimed share, or the price reads low purely because
      // some rounds predate timing.
      const per = useful && ts.length ? dur(Math.round((total / ts.length) * rs.length / useful)) : '—';
      console.log(`${pad(seam, 10)}${lpad(rs.length, 7)}${lpad(ts.length, 7)}${lpad(dur(median(ts)), 9)}${lpad(dur(total), 9)}${lpad(per, 15)}`);
    }
    if (timed.length < roundRecs.length) {
      console.log(`\n${roundRecs.length - timed.length} round(s) carry no duration — logged before timing shipped.`);
      console.log('`per acted-on` extrapolates from the timed rounds; `total` counts only them.');
    }
  } else if (roundRecs.length) {
    console.log('\nNo round durations recorded yet, so there is no price beside the hit rate.');
    console.log('codex-critic.sh reports one per seam call; the seams append it to the log header.');
  }

  const odd = rows.filter((r) => !DISPOSITIONS.includes(r.disposition));
  if (odd.length) {
    console.log(`\n${odd.length} finding(s) carry a disposition outside ${DISPOSITIONS.join('/')}:`);
    for (const r of odd.slice(0, 5)) console.log(`  ${r.seam} r${r.round}: "${r.disposition}" — ${r.text.slice(0, 60)}`);
  }

  console.log('\nacted-on = (fixed + intentional) / raised — findings that changed the artifact');
  console.log('or were consciously kept. `rejected` is Sol being factually wrong, and the round');
  console.log('was spent either way. A seam that stays low is a seam worth cutting.');
  if (found.length > 1) console.log(`\nread from:\n${found.map((d) => `  ${d}`).join('\n')}`);
  console.log();
}

if (import.meta.url === `file://${process.argv[1]}`) main(process.argv.slice(2));
