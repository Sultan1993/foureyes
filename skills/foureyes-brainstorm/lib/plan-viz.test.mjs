import { test } from 'node:test';
import assert from 'node:assert/strict';
import { analyze, normalizePath, extractFence, parsePlanMarkdown, mdToHtml, parseTasks, computeWaves, detectProblems, spliceTasks, taskRanges } from './plan-viz.mjs';

// fixture helper: task with a valid fence unless overridden
const T = (id, over = {}, fence = {}) => ({
  id,
  subject: `Task ${id}`,
  description: `**Goal:** g${id}\n\n\`\`\`json:metadata\n${JSON.stringify({
    files: [`src/f${id}.js`], modelTier: 'mechanical',
    verifyCommand: 'true', acceptanceCriteria: ['a'], ...fence,
  })}\n\`\`\``,
  ...over,
});
const plan = tasks => ({ planPath: 'p.md', tasks });
const kinds = a => a.problems.map(p => p.kind);

test('wave layering follows blockedBy', () => {
  const a = analyze(plan([T(0), T(1), T(2, { blockedBy: [0, 1] }), T(3, { blockedBy: [2] })]));
  assert.deepEqual(a.waves, [[0, 1], [2], [3]]);
  assert.equal(a.stats.waves, 3);
  assert.deepEqual(kinds(a), []);
});

test('unknown blockedBy flagged, edge ignored', () => {
  const a = analyze(plan([T(0), T(1, { blockedBy: [99] })]));
  assert.ok(kinds(a).includes('unknown-dep'));
  assert.deepEqual(a.waves, [[0, 1]]); // edge ignored → same wave
});

test('cycle flagged and unschedulable', () => {
  const a = analyze(plan([T(0, { blockedBy: [1] }), T(1, { blockedBy: [0] }), T(2)]));
  assert.equal(kinds(a).filter(k => k === 'cycle').length, 2);
  assert.deepEqual(a.unschedulable.sort(), [0, 1]);
  assert.deepEqual(a.waves, [[2]]);
});

test('frontier-heavy: 31% flags, 30% does not', () => {
  // 13 tasks, 4 frontier = 30.8% → flag
  const heavy = analyze(plan(Array.from({ length: 13 }, (_, i) =>
    T(i, {}, { modelTier: i < 4 ? 'frontier' : 'mechanical' }))));
  assert.ok(kinds(heavy).includes('frontier-heavy'));
  // 10 tasks, 3 frontier = 30% exactly → no flag
  const ok = analyze(plan(Array.from({ length: 10 }, (_, i) =>
    T(i, {}, { modelTier: i < 3 ? 'frontier' : 'mechanical' }))));
  assert.ok(!kinds(ok).includes('frontier-heavy'));
});

test('same-wave file overlap flagged after normalization', () => {
  const a = analyze(plan([
    T(0, {}, { files: ['./src//x.js'] }),
    T(1, {}, { files: ['src/x.js'] }),
  ]));
  assert.ok(kinds(a).includes('file-overlap'));
  // different waves → no overlap problem
  const b = analyze(plan([
    T(0, {}, { files: ['src/x.js'] }),
    T(1, { blockedBy: [0] }, { files: ['src/x.js'] }),
  ]));
  assert.ok(!kinds(b).includes('file-overlap'));
});

test('missing verify / criteria / fence / tier flagged', () => {
  const a = analyze(plan([
    T(0, {}, { verifyCommand: '  ' }),
    T(1, {}, { acceptanceCriteria: [] }),
    T(2, { description: 'no fence here' }),
    T(3, {}, { modelTier: 'galactic' }),
  ]));
  const k = kinds(a);
  assert.ok(k.includes('no-verify'));
  assert.ok(k.includes('no-criteria'));
  assert.ok(k.includes('no-metadata'));
  assert.ok(k.includes('bad-tier'));
});

test('stats count tiers', () => {
  const a = analyze(plan([T(0), T(1, {}, { modelTier: 'standard' }), T(2, {}, { modelTier: 'frontier' })]));
  assert.deepEqual(a.stats, { tasks: 3, waves: 1, tiers: { mechanical: 1, standard: 1, frontier: 1, unknown: 0 } });
});

test('normalizePath', () => {
  assert.equal(normalizePath(' ./a//b\\c.js '), 'a/b/c.js');
});

test('extractFence tolerates garbage', () => {
  assert.equal(extractFence('no fence'), null);
  assert.equal(extractFence('```json:metadata\n{broken\n```'), null);
});

// --- plan markdown <-> tasks.json equivalence -----------------------------------
// build executes tasks.json while the reader reads the markdown; if they drift
// the page shows one task's metadata under another's heading, silently.

const MD = `Spec: s.md

# demo

### Task 0: alpha
**Goal:** first.

\`\`\`json:metadata
{"files":["src/f0.js"],"modelTier":"mechanical","verifyCommand":"true","acceptanceCriteria":["a"]}
\`\`\`

### Task 1: beta
**Goal:** second.

\`\`\`json:metadata
{"files":["src/f1.js"],"modelTier":"mechanical","verifyCommand":"true","acceptanceCriteria":["a"]}
\`\`\`
`;

test('parsePlanMarkdown splits sections, fields and fences', () => {
  const p = parsePlanMarkdown(MD);
  assert.equal(p.tasks.length, 2);
  assert.equal(p.tasks[0].heading, 'Task 0: alpha');
  assert.equal(p.tasks[0].fields.goal, 'first.');
  assert.match(p.tasks[0].fence, /src\/f0\.js/);
  assert.match(p.intro, /# demo/);
});

test('a fenced ### Task example does not mint a task section', () => {
  const p = parsePlanMarkdown('# t\n\n```\n### Task 9: not real\n```\n\n### Task 0: real\n**Goal:** g\n');
  assert.deepEqual(p.tasks.map(t => t.heading), ['Task 0: real']);
});

test('matching plan and tasks.json report no drift', () => {
  const p = parsePlanMarkdown(MD);
  const a = analyze(plan([T(0, { subject: 'Task 0: alpha' }), T(1, { subject: 'Task 1: beta' })]), p.tasks);
  assert.deepEqual(kinds(a).filter(k => k.startsWith('plan-tasks')), []);
});

test('reordered tasks.json flagged as order mismatch', () => {
  const p = parsePlanMarkdown(MD);
  const a = analyze(plan([T(0, { subject: 'Task 1: beta' }), T(1, { subject: 'Task 0: alpha' })]), p.tasks);
  assert.deepEqual(kinds(a).filter(k => k.startsWith('plan-tasks')),
    ['plan-tasks-order-mismatch', 'plan-tasks-order-mismatch']);
});

test('task count divergence flagged', () => {
  const p = parsePlanMarkdown(MD);
  const a = analyze(plan([T(0, { subject: 'Task 0: alpha' })]), p.tasks);
  assert.ok(kinds(a).includes('plan-tasks-count-mismatch'));
});

test('same subject but edited metadata flagged as fence drift', () => {
  const p = parsePlanMarkdown(MD);
  const a = analyze(plan([
    T(0, { subject: 'Task 0: alpha' }, { verifyCommand: 'rm -rf /' }),
    T(1, { subject: 'Task 1: beta' }),
  ]), p.tasks);
  assert.deepEqual(kinds(a).filter(k => k.startsWith('plan-tasks')), ['plan-tasks-fence-drift']);
});

test('no markdown available: drift checks stay silent', () => {
  const a = analyze(plan([T(0), T(1)]), null);
  assert.deepEqual(kinds(a).filter(k => k.startsWith('plan-tasks')), []);
});

test('unsafe link schemes are not rendered as hrefs', () => {
  assert.match(mdToHtml('see [x](javascript:alert(1))'), /x \(javascript:/);
  assert.doesNotMatch(mdToHtml('see [x](javascript:alert(1))'), /href/);
  assert.match(mdToHtml('see [x](https://example.com)'), /href="https:\/\/example\.com"/);
});

// A fence key the executor never reads is a contract the drafter believes it set
// and did not. Found by auditing 3,334 real tasks: the vocabulary had drifted to
// 47 distinct keys, all of them inert.
test('unknown-key flags metadata nothing reads', () => {
  const tasks = parseTasks({ tasks: [{ id: 1, subject: 's', description:
    '```json:metadata\n{"files":["a.ts"],"verifyCommand":"x","modelTier":"standard","acceptanceCriteria":["c"],"wave":2,"noCommit":true}\n```' }] });
  const { waves } = computeWaves(tasks);
  const p = detectProblems(tasks, waves).filter(x => x.kind === 'unknown-key');
  assert.equal(p.length, 1);
  assert.match(p[0].detail, /wave/);
  assert.match(p[0].detail, /noCommit/);
});

test('a fence using only known keys raises no unknown-key', () => {
  const tasks = parseTasks({ tasks: [{ id: 1, subject: 's', description:
    '```json:metadata\n{"files":[],"verifyCommand":"x","modelTier":"mechanical","acceptanceCriteria":["c"],"blockedBy":[],"model":"opus"}\n```' }] });
  const { waves } = computeWaves(tasks);
  assert.equal(detectProblems(tasks, waves).filter(x => x.kind === 'unknown-key').length, 0);
});

// ---- spliceTasks: a bad splice corrupts a plan that then gets executed ----
const PLAN = `Spec: docs/x-design.md

## Global Constraints
- never commit

### Task 1: first
Goal: a
\`\`\`json:metadata
{"files":["a"]}
\`\`\`

### Task 2: second
Goal: b

### Task 3: third
Goal: c

## Notes
trailing prose
`;

test('replaces only the named task, byte-identical elsewhere', () => {
  const r = spliceTasks(PLAN, { 2: '### Task 2: second (revised)\nGoal: B2' });
  assert.deepEqual(r.applied, [2]);
  assert.deepEqual(r.missing, []);
  assert.match(r.markdown, /### Task 2: second \(revised\)\nGoal: B2/);
  assert.match(r.markdown, /### Task 1: first/);
  assert.match(r.markdown, /### Task 3: third/);
  assert.match(r.markdown, /## Global Constraints\n- never commit/);
  assert.match(r.markdown, /## Notes\ntrailing prose/);
  assert.equal(r.markdown.match(/### Task 2/g).length, 1);
});

test('replaces several tasks at once without index drift', () => {
  const r = spliceTasks(PLAN, { 1: '### Task 1: X\nG', 3: '### Task 3: Z\nG' });
  assert.deepEqual(r.applied, [1, 3]);
  assert.match(r.markdown, /### Task 1: X/);
  assert.match(r.markdown, /### Task 2: second/);
  assert.match(r.markdown, /### Task 3: Z/);
});

// The drafter asked to replace a task that is not there: it meant a structural
// change and sent the wrong mode. Appending or guessing would wreck the plan.
test('an unknown task number is reported, never appended', () => {
  const r = spliceTasks(PLAN, { 9: '### Task 9: new\nG' });
  assert.deepEqual(r.applied, []);
  assert.deepEqual(r.missing, [9]);
  assert.equal(r.markdown, PLAN);   // untouched, trailing newline included
});

test('the last task splices without eating trailing content', () => {
  const noTrailer = PLAN.replace('\n## Notes\ntrailing prose\n', '');
  const r = spliceTasks(noTrailer, { 3: '### Task 3: last\nG' });
  assert.deepEqual(r.applied, [3]);
  assert.match(r.markdown, /### Task 3: last\nG$/);
});

// A `### Task` line inside a fenced block is not a task boundary: it belongs to
// whichever task's block encloses it. A splice that disagreed would cut a task in
// half, and `### Task 99` would be addressable as a task that does not exist.
test('### Task inside a code fence is not a boundary', () => {
  const src = '### Task 1: real\nGoal: a\n```md\n### Task 99: fake\n```\n\n### Task 2: other\nGoal: b\n';
  assert.equal(taskRanges(src.split('\n')).length, 2);           // not 3
  assert.deepEqual(spliceTasks(src, { 99: 'x' }).missing, [99]);  // not addressable
  // Replacing task 1 replaces its WHOLE block, fence included — that is correct;
  // the fence was task 1's content, not a section of its own.
  const r = spliceTasks(src, { 1: '### Task 1: replaced\nGoal: A' });
  assert.deepEqual(r.applied, [1]);
  assert.doesNotMatch(r.markdown, /Task 99/);
  assert.match(r.markdown, /### Task 2: other\nGoal: b/);
});

test('splicing nothing returns the document unchanged', () => {
  assert.equal(spliceTasks(PLAN, {}).markdown, PLAN);
});

test('taskRanges and parsePlanMarkdown agree on task count', () => {
  const n = taskRanges(PLAN.split('\n')).length;
  assert.equal(n, parsePlanMarkdown(PLAN).tasks.length);
  assert.equal(n, 3);
});
