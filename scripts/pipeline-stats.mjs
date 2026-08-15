#!/usr/bin/env node
// pipeline-stats.mjs — read what the pipeline already writes. No instrumentation,
// no model calls, no network, read-only.
//
// Two sources, both retroactive:
//   plans    — every <plan>.md.tasks.json on disk: tier mix, wave width, sizing
//   history  — ~/.claude/projects/**.jsonl: every subagent dispatch, its model
//              parameter, and its wall clock from timestamp deltas
//
// The history source exists because a subagent's own transcript is NOT recorded
// (isSidechain is absent everywhere), so dispatch parameters and elapsed time are
// the only view there is into what actually ran. It is also the only thing that
// can catch the coordinator improvising past a skill's prose — no prose test
// reaches that.
import { readFileSync, readdirSync, statSync, createReadStream } from 'node:fs';
import { createInterface } from 'node:readline';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { parseTasks, computeWaves, detectProblems } from '../skills/foureyes-brainstorm/lib/plan-viz.mjs';

const PLAN_DIRS = ['foureyes/plans', 'superpowers/plans'];
const TIERS = ['mechanical', 'standard', 'frontier'];
// Seam critics must reach Codex through codex-critic.sh. Dispatched as Claude
// subagents they become Claude reviewing Claude, which is the one thing this
// plugin exists to prevent — and it happened 143 times before anyone looked.
export const CODEX_ONLY = ['foureyes-spec-critic', 'foureyes-plan-critic', 'foureyes-code-critic'];

// What a subagent's tool_result actually is. Getting this wrong makes the whole
// history table lie: an async envelope is a DISPATCH receipt, not a result, and
// a spilled return is a SUCCESS the harness moved to disk — counting either as a
// failure (or timing either as a call) is how the first version of this reported
// nine "hangs" that were mostly fine.
export function classify(txt, secs) {
  if (/Async agent launched successfully/.test(txt)) return 'async';
  if (/exceeded the \d+ output token maximum/.test(txt)) return 'over-limit';
  if (/user doesn't want to proceed|tool use was rejected/i.test(txt)) return 'cancelled';
  if (/<persisted-output>|Output too large \(/.test(txt)) return 'spilled';
  if (/^Agent terminated early|API Error/i.test(txt)) return 'aborted';
  // Long and genuinely empty, with none of the explanations above: the real hang.
  if (secs > 900 && txt.length < 3000) return 'hang';
  return 'ok';
}

export const median = (a) => (a.length ? [...a].sort((x, y) => x - y)[Math.floor(a.length / 2)] : null);
const pct = (a, b) => (b ? `${Math.round((a / b) * 100)}%` : '—');
const dur = (s) => (s == null ? '—' : s < 60 ? `${s}s` : `${Math.floor(s / 60)}m${String(s % 60).padStart(2, '0')}s`);
const pad = (s, n) => String(s) + ' '.repeat(Math.max(0, n - String(s).length));
const lpad = (s, n) => ' '.repeat(Math.max(0, n - String(s).length)) + String(s);

// ---------------------------------------------------------------- plans ------
function findPlans(dir, depth = 0, out = []) {
  if (depth > 6) return out;
  let ents; try { ents = readdirSync(dir, { withFileTypes: true }); } catch { return out; }
  for (const e of ents) {
    if (e.name.startsWith('.') || e.name === 'node_modules') continue;
    if (e.isDirectory()) findPlans(join(dir, e.name), depth + 1, out);
    // Both conventions: plans written before the rename live under
    // docs/superpowers/plans and are still perfectly valid history.
    else if (e.name.endsWith('.md.tasks.json') && PLAN_DIRS.some((d) => dir.includes(d))) out.push(join(dir, e.name));
  }
  return out;
}

export function summarisePlans(files) {
  const tiers = {}, widths = [], tasksPer = [], filesBy = {}, problems = {};
  let tasks = 0, completed = 0, known = 0;
  for (const f of files) {
    let j; try { j = JSON.parse(readFileSync(f, 'utf8')); } catch { continue; }
    const ts = parseTasks(j);
    if (!ts.length) continue;
    const { waves } = computeWaves(ts);
    for (const w of waves) widths.push(w.length);
    tasksPer.push(ts.length);
    for (const p of detectProblems(ts, waves)) problems[p.kind] = (problems[p.kind] || 0) + 1;
    for (const t of ts) {
      tasks++;
      const tier = t.fence?.modelTier || '(none)';
      tiers[tier] = (tiers[tier] || 0) + 1;
      const n = Array.isArray(t.fence?.files) ? t.fence.files.length : null;
      if (n != null) (filesBy[tier] = filesBy[tier] || []).push(n);
    }
    for (const t of j.tasks || []) if (t.status) { known++; if (t.status === 'completed') completed++; }
  }
  return { plans: tasksPer.length, tasks, tiers, widths, tasksPer, filesBy, problems, completed, known };
}

// -------------------------------------------------------------- history ------
export async function summariseHistory(root) {
  const pend = new Map(), byType = {}, misroute = {};
  let dispatches = 0, sessions = 0;
  let dirs; try { dirs = readdirSync(root); } catch { return null; }
  for (const p of dirs) {
    let ents; try { ents = readdirSync(join(root, p)); } catch { continue; }
    for (const f of ents) {
      if (!f.endsWith('.jsonl')) continue;
      sessions++;
      const rl = createInterface({ input: createReadStream(join(root, p, f)), crlfDelay: Infinity });
      for await (const line of rl) {
        if (!line) continue;
        let o; try { o = JSON.parse(line); } catch { continue; }
        const c = o.message?.content;
        if (!Array.isArray(c)) continue;
        for (const b of c) {
          if (b.type === 'tool_use' && b.name === 'Agent') {
            const st = String(b.input?.subagent_type || '(none)').replace(/^(foureyes:)+/, '');
            dispatches++;
            const e = (byType[st] = byType[st] || { n: 0, models: {}, secs: [] });
            e.n++;
            const m = b.input?.model || '(omitted)';
            e.models[m] = (e.models[m] || 0) + 1;
            if (CODEX_ONLY.includes(st)) misroute[st] = (misroute[st] || 0) + 1;
            if (o.timestamp) pend.set(b.id, { st, t: Date.parse(o.timestamp) });
          }
          if (b.type === 'tool_result' && pend.has(b.tool_use_id) && o.timestamp) {
            const { st, t } = pend.get(b.tool_use_id); pend.delete(b.tool_use_id);
            const s = Math.round((Date.parse(o.timestamp) - t) / 1000);
            // >2h is a session resumed across a gap, not a call. Excluded, and
            // silently — it would dominate every median it touched.
            if (s < 0 || s > 7200) continue;
            const e = byType[st]; if (!e) continue;
            const txt = typeof b.content === 'string' ? b.content : JSON.stringify(b.content ?? '');
            const k = classify(txt, s);
            e[k] = (e[k] || 0) + 1;
            // Only a completed synchronous return times a real call. An async
            // envelope times the DISPATCH (~0s) and would drag every median to
            // zero; a spill or an abort times work that produced no usable result.
            if (k === 'ok') e.secs.push(s);
          }
        }
      }
    }
  }
  return { dispatches, byType, misroute, sessions };
}

// ----------------------------------------------------------------- main ------
function reportPlans(s) {
  console.log(`\n═══ PLANS — ${s.plans} plans, ${s.tasks} tasks ═══\n`);
  console.log('— modelTier mix (the routing contract knows three) —');
  for (const [k, v] of Object.entries(s.tiers).sort((a, b) => b[1] - a[1])) {
    const bad = TIERS.includes(k) || k === '(none)' ? '' : '  ← not in the routing table';
    console.log(`  ${pad(k, 14)}${lpad(v, 6)} ${lpad(pct(v, s.tasks), 6)}   median files/task ${median(s.filesBy[k] || []) ?? '—'}${bad}`);
  }
  const w1 = s.widths.filter((w) => w === 1).length;
  console.log('\n— wave width (is the parallelism real?) —');
  console.log(`  waves ${s.widths.length}   width-1 ${w1} (${pct(w1, s.widths.length)})   median ${median(s.widths)}   widest ${Math.max(...s.widths, 0)}`);
  console.log(`  median tasks/plan ${median(s.tasksPer)}`);
  console.log(`  completed ${s.completed}/${s.known} (${pct(s.completed, s.known)})`);
  if (Object.keys(s.problems).length) {
    console.log('\n— detected problems —');
    for (const [k, v] of Object.entries(s.problems).sort((a, b) => b[1] - a[1])) console.log(`  ${pad(k, 18)}${lpad(v, 6)}`);
  }
}

function reportHistory(h) {
  console.log(`\n═══ HISTORY — ${h.dispatches} subagent dispatches across ${h.sessions} sessions ═══\n`);
  console.log(`${pad('subagent', 28)}${lpad('n', 4)}${lpad('ok', 4)}${lpad('median', 8)}${lpad('max', 7)}${lpad('spill', 6)}${lpad('limit', 6)}${lpad('hang', 5)}${lpad('unseen', 7)}  models`);
  for (const [k, v] of Object.entries(h.byType).sort((a, b) => b[1].n - a[1].n).slice(0, 14)) {
    const ms = Object.entries(v.models).map(([m, n]) => `${m}=${n}`).join(' ');
    const unseen = v.n - (v.ok || 0) - (v.spilled || 0) - (v['over-limit'] || 0) - (v.cancelled || 0) - (v.hang || 0) - (v.aborted || 0);
    console.log(`${pad(k, 28)}${lpad(v.n, 4)}${lpad(v.ok || '', 4)}${lpad(dur(median(v.secs)), 8)}${lpad(dur(v.secs.length ? Math.max(...v.secs) : null), 7)}${lpad(v.spilled || '', 6)}${lpad(v['over-limit'] || '', 6)}${lpad(v.hang || '', 5)}${lpad(unseen > 0 ? unseen : '', 7)}  ${ms}`);
  }
  console.log('\nn counts dispatches; ok counts synchronous returns, and only those are timed —');
  console.log('an async dispatch receipt would time the launch (~0s), not the work.');
  console.log('spill = output too large, harness wrote it to a file and returned a ~2KB preview.');
  console.log('        The run SUCCEEDED; a coordinator that writes the preview truncates the plan.');
  console.log('limit = hit the output-token ceiling and returned nothing. Split the assignment;');
  console.log('        re-dispatching it whole fails the same way.');
  console.log('hang  = over 15 min, under 3KB, and none of the above explains it.');
  console.log('unseen = dispatched, outcome NOT RECORDED — not a failure. Subagents run in the');
  console.log('        background by default and their result arrives as a notification that');
  console.log('        carries no link back to the dispatch (no join key exists; sourceToolUseID');
  console.log('        does not resolve to Agent tool_use ids). Every other column is a share of');
  console.log('        n - unseen, never of n. Treating unseen as failure overstates the failures.');
  const bad = Object.entries(h.misroute);
  if (bad.length) {
    const total = bad.reduce((a, [, n]) => a + n, 0);
    console.log(`\n⚠  ${total} dispatch(es) sent a Codex-only critic to a Claude subagent:`);
    for (const [k, n] of bad) console.log(`     ${pad(k, 30)} ${n}`);
    console.log('   Those ran Claude-critiques-Claude. Only codex-critic.sh reaches Sol, and no');
    console.log('   prose test can catch this — it greps skill text, not what the coordinator did.');
  }
}

async function main(args) {
  const roots = args.length ? args : ['.'];
  const files = roots.flatMap((r) => findPlans(r));
  if (files.length) reportPlans(summarisePlans(files));
  else console.log(`\nNo plans found under ${roots.join(', ')} (looked for *.md.tasks.json under superpowers/plans).`);

  const h = await summariseHistory(join(homedir(), '.claude/projects'));
  if (h && h.dispatches) reportHistory(h);
  else console.log('\nNo transcript history at ~/.claude/projects — nothing to report on dispatches.');
  console.log();
}

if (import.meta.url === `file://${process.argv[1]}`) {
  try { statSync(join(homedir(), '.claude')); } catch { /* fine, history just reports empty */ }
  main(process.argv.slice(2));
}
