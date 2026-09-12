#!/usr/bin/env node
// Capture a 1920x1080 PNG of any scene, WINDOWED (headless cannot render), with a hard watchdog.
//   node tools/godot/shot.mjs --scene res://scenes/Night.tscn --out shots/night.png [--preset customer_at_counter] [--frames 12] [--timeout 45]
// Exit 0 + prints "SHOT ..." on success. The PNG is what tools/codex/judge.mjs compares to the concept art.
import { spawn } from 'node:child_process';
import path from 'node:path';
import fs from 'node:fs';
import { GODOT_DIR, REPO, requireGodot, parseArgs, pngInfo, acquireGodotLock } from '../paths.mjs';

const args = parseArgs(process.argv.slice(2));
if (!args.scene || !args.out) { console.error('usage: --scene res://... --out file.png [--preset name] [--frames n] [--timeout s]'); process.exit(2); }
const godot = requireGodot();
const out = path.resolve(REPO, String(args.out));
fs.mkdirSync(path.dirname(out), { recursive: true });
if (fs.existsSync(out)) fs.unlinkSync(out);
const timeoutS = Number(args.timeout || 45);
const frames = Number(args.frames || 12);
const godotOut = out.replaceAll(String.fromCharCode(92), '/');
const releaseLock = acquireGodotLock();

if (!fs.existsSync(path.join(GODOT_DIR, '.godot'))) {
  const { spawnSync } = await import('node:child_process');
  spawnSync(godot, ['--headless', '--path', '.', '--import'], { cwd: GODOT_DIR, stdio: 'ignore', timeout: 180_000 });
}

const gargs = ['--path', '.', '--resolution', '320x180', '--position', '0,0', 'res://tools/Shot.tscn', '--',
  `--scene=${args.scene}`, `--out=${godotOut}`, `--frames=${frames}`, `--timeout=${Math.max(5, timeoutS - 5)}`];
if (args.preset) gargs.push(`--preset=${args.preset}`);

const child = spawn(godot, gargs, { cwd: GODOT_DIR, stdio: ['ignore', 'pipe', 'pipe'] });
let log = '';
child.stdout.on('data', (d) => (log += d));
child.stderr.on('data', (d) => (log += d));
const killer = setTimeout(() => {
  console.error(`shot: watchdog ${timeoutS}s — killing Godot`);
  spawn('taskkill', ['/PID', String(child.pid), '/T', '/F'], { stdio: 'ignore' });
}, timeoutS * 1000);
child.on('exit', (code) => {
  clearTimeout(killer);
  releaseLock();
  const line = log.split('\n').find((l) => l.startsWith('SHOT ')) || '';
  const errs = log.split('\n').filter((l) => /ERROR|SCRIPT ERROR|Shot:/.test(l)).slice(0, 12).join('\n');
  if (code === 0 && fs.existsSync(out)) {
    const info = pngInfo(out);
    console.log(`${line.trim()}\nOK ${out} ${info.width}x${info.height}`);
    if (errs) console.log('(engine messages)\n' + errs);
    process.exit(0);
  }
  console.error(`shot FAILED (exit ${code}) ${out}\n${errs || log.slice(-1500)}`);
  process.exit(code || 1);
});
