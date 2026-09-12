#!/usr/bin/env node
// Run the Godot unit tests headless.  node tools/godot/test.mjs [--filter substr] [--no-import]
// Always (re)imports first so `class_name` globals resolve in headless mode.
import { spawnSync } from 'node:child_process';
import { GODOT_DIR, requireGodot, parseArgs } from '../paths.mjs';

const args = parseArgs(process.argv.slice(2));
const godot = requireGodot();
const run = (a, timeout) => spawnSync(godot, a, { cwd: GODOT_DIR, encoding: 'utf8', timeout, stdio: ['ignore', 'pipe', 'pipe'] });

if (!args['no-import']) {
  const imp = run(['--headless', '--path', '.', '--import'], 180_000);
  if (imp.error) { console.error('import failed:', imp.error.message); process.exit(3); }
}
const extra = args.filter ? ['--', `--filter=${args.filter}`] : [];
const r = run(['--headless', '--path', '.', '--script', 'res://tests/run.gd', ...extra], 300_000);
const out = (r.stdout || '') + (r.stderr || '');
process.stdout.write(out.split('\n').filter((l) => !l.startsWith('Godot Engine v')).join('\n'));
if (r.error) { console.error('\nrunner error:', r.error.message); process.exit(3); }
process.exit(r.status ?? 1);
