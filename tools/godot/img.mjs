#!/usr/bin/env node
// Snap an image to the pixel grid via headless Godot (options documented in godot/tools/img.gd).
//   node tools/godot/img.mjs --in art/raw/char/lena_neutral.png --out godot/assets/char/lena_neutral.png --w 160 --h 200
//        [--mode fit|cover|exact] [--filter lanczos|bilinear|cubic|nearest] [--crop 16:9] [--alpha-threshold 0.5] [--trim 1]
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import fs from 'node:fs';
import { GODOT_DIR, REPO, requireGodot, parseArgs, pngInfo, fwd, isMain, acquireGodotLock } from '../paths.mjs';

export function snapImage(opts) {
  const godot = requireGodot();
  const releaseLock = acquireGodotLock();
  const inp = fwd(path.resolve(REPO, opts.in));
  const out = fwd(path.resolve(REPO, opts.out));
  fs.mkdirSync(path.dirname(out), { recursive: true });
  const extra = [`--in=${inp}`, `--out=${out}`];
  for (const k of ['w', 'h', 'mode', 'filter', 'crop', 'alpha-threshold', 'trim', 'key', 'key-tol', 'auto-key', 'auto-bg', 'bg-tol', 'quantize']) {
    if (opts[k] !== undefined && opts[k] !== null && opts[k] !== '') extra.push(`--${k}=${opts[k]}`);
  }
  const r = spawnSync(godot, ['--headless', '--path', '.', '--script', 'res://tools/img.gd', '--', ...extra],
    { cwd: GODOT_DIR, encoding: 'utf8', timeout: 120_000, stdio: ['ignore', 'pipe', 'pipe'] });
  releaseLock();
  const all = (r.stdout || '') + (r.stderr || '');
  const line = all.split('\n').find((l) => l.startsWith('IMG ')) || '';
  if (r.status !== 0 || !fs.existsSync(out)) throw new Error(`img.gd failed (exit ${r.status}): ${all.slice(-800)}`);
  const m = line.match(/alpha0=([\d.]+)/);
  const k = line.match(/keyed=(\d+)/);
  return { line: line.trim(), out, transparentFrac: m ? Number(m[1]) : 0, keyedPixels: k ? Number(k[1]) : 0, ...pngInfo(out) };
}

if (isMain(import.meta.url)) {
  const a = parseArgs(process.argv.slice(2));
  if (!a.in || !a.out) { console.error('need --in and --out'); process.exit(2); }
  const r = snapImage(a);
  console.log(`${r.line}\nOK ${r.out} ${r.width}x${r.height} transparent=${Math.round(r.transparentFrac * 100)}%`);
}
