import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { summarisePlans, summariseHistory, median, classify, CODEX_ONLY } from './pipeline-stats.mjs';

const fence = (o) => '```json:metadata\n' + JSON.stringify(o) + '\n```';
const planFile = (tasks) => {
  const d = mkdtempSync(join(tmpdir(), 'ps-'));
  const p = join(d, 'docs/foureyes/plans'); mkdirSync(p, { recursive: true });
  const f = join(p, 'x.md.tasks.json');
  writeFileSync(f, JSON.stringify({ tasks }));
  return f;
};

test('tier mix and file counts come out per tier', () => {
  const f = planFile([
    { id: 0, subject: 'a', blockedBy: [], status: 'completed', description: fence({ files: ['a', 'b'], modelTier: 'mechanical', verifyCommand: 'x', acceptanceCriteria: ['c'] }) },
    { id: 1, subject: 'b', blockedBy: [], status: 'pending', description: fence({ files: ['c'], modelTier: 'standard', verifyCommand: 'x', acceptanceCriteria: ['c'] }) },
  ]);
  const s = summarisePlans([f]);
  assert.equal(s.tasks, 2);
  assert.equal(s.tiers.mechanical, 1);
  assert.deepEqual(s.filesBy.mechanical, [2]);
  assert.equal(s.completed, 1);
  assert.equal(s.known, 2);
});

// Two independent tasks are one wave of width 2; a dependency makes two of width
// 1. Getting this backwards would report parallelism that never happens.
test('wave width follows the dependency graph', () => {
  const indep = summarisePlans([planFile([
    { id: 0, subject: 'a', blockedBy: [], description: fence({ files: ['a'], modelTier: 'standard', verifyCommand: 'x', acceptanceCriteria: ['c'] }) },
    { id: 1, subject: 'b', blockedBy: [], description: fence({ files: ['b'], modelTier: 'standard', verifyCommand: 'x', acceptanceCriteria: ['c'] }) },
  ])]);
  assert.deepEqual(indep.widths, [2]);

  const chained = summarisePlans([planFile([
    { id: 0, subject: 'a', blockedBy: [], description: fence({ files: ['a'], modelTier: 'standard', verifyCommand: 'x', acceptanceCriteria: ['c'] }) },
    { id: 1, subject: 'b', blockedBy: [0], description: fence({ files: ['b'], modelTier: 'standard', verifyCommand: 'x', acceptanceCriteria: ['c'] }) },
  ])]);
  assert.deepEqual(chained.widths, [1, 1]);
});

test('an off-contract tier is counted, never silently normalised', () => {
  const s = summarisePlans([planFile([
    { id: 0, subject: 'a', blockedBy: [], description: fence({ files: ['a'], modelTier: 'complex', verifyCommand: 'x', acceptanceCriteria: ['c'] }) },
  ])]);
  assert.equal(s.tiers.complex, 1);
  assert.equal(s.problems['bad-tier'], 1);
});

test('inert fence keys surface as unknown-key', () => {
  const s = summarisePlans([planFile([
    { id: 0, subject: 'a', blockedBy: [], description: fence({ files: ['a'], modelTier: 'standard', verifyCommand: 'x', acceptanceCriteria: ['c'], wave: 2 }) },
  ])]);
  assert.equal(s.problems['unknown-key'], 1);
});

// ---- history ----
const txDir = (records) => {
  const root = mkdtempSync(join(tmpdir(), 'tx-'));
  const proj = join(root, 'proj'); mkdirSync(proj, { recursive: true });
  writeFileSync(join(proj, 's.jsonl'), records.map((r) => JSON.stringify(r)).join('\n'));
  return root;
};
const dispatch = (id, type, ts, model) => ({ timestamp: ts, message: { content: [{ type: 'tool_use', id, name: 'Agent', input: { subagent_type: type, ...(model ? { model } : {}) } }] } });
const result = (id, ts, body) => ({ timestamp: ts, message: { content: [{ type: 'tool_result', tool_use_id: id, content: body }] } });

test('dispatch duration comes from the timestamp delta', async () => {
  const r = txDir([
    dispatch('a', 'foureyes:foureyes-drafter', '2026-08-09T10:00:00Z', undefined),
    result('a', '2026-08-09T10:09:00Z', 'x'.repeat(40000)),
  ]);
  const h = await summariseHistory(r);
  assert.equal(h.dispatches, 1);
  assert.deepEqual(h.byType['foureyes-drafter'].secs, [540]);
  assert.equal(h.byType['foureyes-drafter'].models['(omitted)'], 1);
});

// Each of these was a real observed return. Misreading any one of them makes the
// whole table lie — the first version counted spills and dispatch receipts as
// hangs and reported nine failures that were mostly fine.
test('classify separates receipts, spills and real failures', () => {
  assert.equal(classify('Async agent launched successfully. agentId: abc', 0), 'async');
  assert.equal(classify("Agent terminated early due to an API error: API Error: Claude's response exceeded the 64000 output token maximum.", 3050), 'over-limit');
  assert.equal(classify("The user doesn't want to proceed with this tool use.", 2374), 'cancelled');
  assert.equal(classify('<persisted-output>\nOutput too large (97KB). Full output saved to: /x.json', 1558), 'spilled');
  assert.equal(classify('x'.repeat(40000), 1200), 'ok');
  assert.equal(classify('tiny', 1200), 'hang');
  assert.equal(classify('tiny', 30), 'ok');
});

// A spill is a SUCCESS the harness moved to disk. Counting it as a hang sends you
// hunting a bug that is not there; the real bug is a coordinator writing the
// 2KB preview into the plan file.
test('a spill is not a hang, and is not timed as a completed call', async () => {
  const h = await summariseHistory(txDir([
    dispatch('a', 'foureyes-drafter', '2026-08-09T10:00:00Z'),
    result('a', '2026-08-09T10:26:00Z', '<persisted-output> Output too large (97KB). Full output saved to: /x.json'),
    dispatch('b', 'foureyes-drafter', '2026-08-09T11:00:00Z'),
    result('b', '2026-08-09T11:20:00Z', 'x'.repeat(40000)),
  ]));
  const d = h.byType['foureyes-drafter'];
  assert.equal(d.spilled, 1);
  assert.equal(d.hang, undefined);
  assert.deepEqual(d.secs, [1200]);
});

test('an async receipt never times the dispatch as if it were the work', async () => {
  const h = await summariseHistory(txDir([
    dispatch('a', 'foureyes-drafter', '2026-08-09T10:00:00Z'),
    result('a', '2026-08-09T10:00:01Z', 'Async agent launched successfully. agentId: zz'),
  ]));
  assert.equal(h.byType['foureyes-drafter'].async, 1);
  assert.deepEqual(h.byType['foureyes-drafter'].secs, []);
});

test('a long empty return with no explanation is still a hang', async () => {
  const h = await summariseHistory(txDir([
    dispatch('a', 'foureyes-drafter', '2026-08-09T10:00:00Z'),
    result('a', '2026-08-09T10:40:00Z', 'tiny'),
  ]));
  assert.equal(h.byType['foureyes-drafter'].hang, 1);
});

test('a gap over two hours is excluded rather than dominating the median', async () => {
  const h = await summariseHistory(txDir([
    dispatch('a', 'foureyes-drafter', '2026-08-09T10:00:00Z'),
    result('a', '2026-08-09T20:00:00Z', 'x'),
  ]));
  assert.deepEqual(h.byType['foureyes-drafter'].secs, []);
});

test('a Codex-only critic sent to a Claude subagent is flagged', async () => {
  const h = await summariseHistory(txDir([
    dispatch('a', 'foureyes:foureyes-spec-critic', '2026-08-09T10:00:00Z'),
    result('a', '2026-08-09T10:05:00Z', 'v'),
  ]));
  assert.equal(h.misroute['foureyes-spec-critic'], 1);
});

test('review-critic and refute-critic are NOT misroutes — both families run them', () => {
  assert.deepEqual(CODEX_ONLY, ['foureyes-spec-critic', 'foureyes-plan-critic', 'foureyes-code-critic']);
  assert.ok(!CODEX_ONLY.includes('foureyes-review-critic'));
  assert.ok(!CODEX_ONLY.includes('foureyes-refute-critic'));
});

test('a doubled namespace prefix still resolves to one bucket', async () => {
  const h = await summariseHistory(txDir([
    dispatch('a', 'foureyes:foureyes:foureyes-implementer', '2026-08-09T10:00:00Z'),
    result('a', '2026-08-09T10:01:00Z', 'x'),
  ]));
  assert.equal(h.byType['foureyes-implementer'].n, 1);
});

test('median returns null on empty and the middle otherwise', () => {
  assert.equal(median([]), null);
  assert.equal(median([5, 1, 3]), 3);
});
