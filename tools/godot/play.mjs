#!/usr/bin/env node
// Play the real game end to end, WINDOWED (headless cannot render), with the same lock + watchdog
// shot.mjs uses.  It drives res://scenes/Main.tscn through the screens' own handlers — New game →
// Manage → Open up → serve → a story beat → wave off → 06:00 → Summary → night 2 — and writes
// shots/play-NN-<step>.png plus shots/play-log.json.
//
//   node tools/godot/play.mjs [--out shots] [--timeout 240] [--keep]
//
// Exit 0 and a "PLAY ok steps=N" line means the loop is playable. Any ERROR / SCRIPT ERROR from the
// engine fails the run even if the playthrough itself reported ok — a night that only works while
// the log is full of errors is not a working night.
import { spawn, spawnSync } from 'node:child_process';
import path from 'node:path';
import fs from 'node:fs';
import { GODOT_DIR, REPO, requireGodot, parseArgs, acquireGodotLock, killTree, fwd } from '../paths.mjs';

const args = parseArgs(process.argv.slice(2));
const godot = requireGodot();
const outDir = path.resolve(REPO, String(args.out || 'shots'));
fs.mkdirSync(outDir, { recursive: true });
// Old frames would happily pass for new ones — a run always starts from an empty set.
if (!args.keep) for (const f of fs.readdirSync(outDir)) if (/^play-/.test(f)) fs.unlinkSync(path.join(outDir, f));

const timeoutS = Number(args.timeout || 240);
const releaseLock = acquireGodotLock();

if (!fs.existsSync(path.join(GODOT_DIR, '.godot'))) {
  spawnSync(godot, ['--headless', '--path', '.', '--import'], { cwd: GODOT_DIR, stdio: 'ignore', timeout: 180_000 });
}

// Small window: the game renders into its own 480x270 SubViewport, so the window is only a host.
const gargs = ['--path', '.', '--resolution', '320x180', '--position', '0,0', 'res://tools/Playthrough.tscn', '--',
  `--out=${fwd(outDir)}`, `--timeout=${Math.max(20, timeoutS - 15)}`];

const child = spawn(godot, gargs, { cwd: GODOT_DIR, stdio: ['ignore', 'pipe', 'pipe'] });
let log = '';
const onData = (d) => { log += d; process.stdout.write(d); };
child.stdout.on('data', onData);
child.stderr.on('data', onData);
const killer = setTimeout(() => {
  console.error(`play: watchdog ${timeoutS}s — killing Godot`);
  killTree(child.pid);
}, timeoutS * 1000);

child.on('exit', (code) => {
  clearTimeout(killer);
  releaseLock();
  const okLine = log.split('\n').find((l) => l.startsWith('PLAY ok')) || '';
  const failLine = log.split('\n').find((l) => l.startsWith('PLAY FAILED')) || '';
  const engineErrors = log.split('\n').filter((l) => /SCRIPT ERROR|ERROR:|Parse Error|leaked/.test(l));
  const shots = fs.readdirSync(outDir).filter((f) => /^play-\d+-.*\.png$/.test(f)).sort();
  const logFile = path.join(outDir, 'play-log.json');
  console.log(`\n--- ${shots.length} captures in ${outDir}${fs.existsSync(logFile) ? `, log ${logFile}` : ', NO play-log.json'}`);
  if (engineErrors.length) {
    console.error(`play FAILED: ${engineErrors.length} engine error line(s)\n` + engineErrors.slice(0, 12).join('\n'));
    process.exit(1);
  }
  if (code === 0 && okLine) {
    console.log(okLine.trim());
    process.exit(0);
  }
  console.error(`play FAILED (exit ${code})\n${failLine || log.slice(-1500)}`);
  process.exit(code || 1);
});
