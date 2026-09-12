// Shared paths + tiny helpers for the pipeline scripts. Override with env vars when the machine differs.
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import fs from 'node:fs';

export const REPO = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
export const GODOT_DIR = path.join(REPO, 'godot');
export const DOCS_DIR = path.join(REPO, 'docs');
export const RAW_ART_DIR = path.join(REPO, 'art', 'raw');       // native-size gpt-image output (git-ignored)
export const SHOTS_DIR = path.join(REPO, 'shots');               // Godot captures (git-ignored)
export const JUDGE_DIR = path.join(REPO, 'judge');               // Codex verdict JSON (git-ignored)

const GODOT_CANDIDATES = [
  process.env.GODOT_BIN,
  'C:/Users/phili/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe',
  'C:/Users/phili/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe',
].filter(Boolean);
export const GODOT_BIN = GODOT_CANDIDATES.find((p) => fs.existsSync(p));

export const BLENDER_BIN = process.env.BLENDER_BIN || 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe';

// Codex defaults — "max settings" as asked. gpt-5.6-sol also offers `ultra` above `max` (CODEX_EFFORT=ultra).
export const CODEX_MODEL = process.env.CODEX_MODEL || 'gpt-5.6-sol';
export const CODEX_EFFORT = process.env.CODEX_EFFORT || 'max';
export const CODEX_HOME = process.env.CODEX_HOME || path.join(process.env.USERPROFILE || '', '.codex');
export const CODEX_GENERATED = path.join(CODEX_HOME, 'generated_images');

// We launch Codex's JS entry with the current node — no .cmd shim, no shell quoting.
const NPM_GLOBAL_ROOT = process.env.NPM_GLOBAL_ROOT || path.join(process.env.APPDATA || '', 'npm', 'node_modules');
export function codexCommand() {
  const js = path.join(NPM_GLOBAL_ROOT, '@openai', 'codex', 'bin', 'codex.js');
  if (fs.existsSync(js)) return { cmd: process.execPath, argsPrefix: [js] };
  throw new Error(`codex.js not found under ${NPM_GLOBAL_ROOT}; set NPM_GLOBAL_ROOT`);
}

export function requireGodot() {
  if (!GODOT_BIN) throw new Error('Godot binary not found; set GODOT_BIN');
  return GODOT_BIN;
}

/**
 * Cross-process mutex around anything that runs Godot on the project dir: parallel agents importing /
 * capturing / snapping at once would race on `.godot/`. Sync acquire with retry; stale locks (>10 min) are broken.
 */
const GODOT_LOCK = path.join(GODOT_DIR, '.godot-lock');
const sleepSync = (ms) => Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
export function acquireGodotLock(waitMs = 10 * 60_000) {
  const start = Date.now();
  for (;;) {
    try {
      const fd = fs.openSync(GODOT_LOCK, 'wx');
      fs.writeSync(fd, `${process.pid} ${new Date().toISOString()}`);
      fs.closeSync(fd);
      const release = () => { try { if (fs.readFileSync(GODOT_LOCK, 'utf8').startsWith(`${process.pid} `)) fs.unlinkSync(GODOT_LOCK); } catch { /* gone */ } };
      process.once('exit', release);
      return release;
    } catch (e) {
      if (e.code !== 'EEXIST') throw e;
      try { if (Date.now() - fs.statSync(GODOT_LOCK).mtimeMs > 10 * 60_000) { fs.unlinkSync(GODOT_LOCK); continue; } } catch { continue; }
      if (Date.now() - start > waitMs) throw new Error('timed out waiting for the Godot lock');
      sleepSync(1500);
    }
  }
}

/** Kill a process tree on Windows. */
export function killTree(pid) {
  try { spawnSync('taskkill', ['/PID', String(pid), '/T', '/F'], { stdio: 'ignore' }); } catch { /* already gone */ }
}

/** Forward slashes for Godot / cross-shell use. */
export const fwd = (p) => String(p).replaceAll(String.fromCharCode(92), '/');

/** Minimal PNG header reader — width/height/colour type, no dependency. */
export function pngInfo(file) {
  const buf = fs.readFileSync(file);
  if (buf.subarray(0, 8).toString('hex') !== '89504e470d0a1a0a') throw new Error(`${file}: not a PNG`);
  return {
    width: buf.readUInt32BE(16),
    height: buf.readUInt32BE(20),
    bitDepth: buf[24],
    colourType: buf[25], // 6 = RGBA, 4 = grey+alpha, 2 = RGB, 3 = palette, 0 = grey
    hasAlpha: buf[25] === 6 || buf[25] === 4,
    bytes: buf.length,
  };
}

export function parseArgs(argv) {
  const out = { _: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith('--')) {
      const eq = a.indexOf('=');
      if (eq > 0) { push(out, a.slice(2, eq), a.slice(eq + 1)); continue; }
      const key = a.slice(2);
      const next = argv[i + 1];
      if (next === undefined || next.startsWith('--')) push(out, key, true);
      else { push(out, key, next); i++; }
    } else out._.push(a);
  }
  return out;
}
function push(o, k, v) {
  if (o[k] === undefined) o[k] = v;
  else if (Array.isArray(o[k])) o[k].push(v);
  else o[k] = [o[k], v];
}
export const asList = (v) => (v === undefined ? [] : Array.isArray(v) ? v : [v]);
export const isMain = (metaUrl) => process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(metaUrl);
