#!/usr/bin/env node
// tools/codex/run.mjs — the ONE way this repo calls Codex. art.mjs and judge.mjs build on it.
//
//   node tools/codex/run.mjs --prompt "text" | --prompt-file f.md
//        [--image=a.png ...] [--schema file.json] [--sandbox read-only|danger-full-access]
//        [--cwd dir] [--model gpt-5.6-sol] [--effort max] [--timeout 900] [--out last.txt] [--quiet]
//
// Windows lessons baked in (each one cost a stuck run):
//  * the prompt goes through stdin and stdin is CLOSED — an open stdin makes codex wait for EOF forever.
//  * `-i FILE...` is greedy and swallows the prompt; always `--image=FILE`.
//  * `workspace-write` silently degrades to read-only on native Windows in this build. Anything that must
//    write files runs as `danger-full-access` (there is no OS sandbox either way — keep --cwd tight).
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { REPO, CODEX_MODEL, CODEX_EFFORT, codexCommand, killTree, parseArgs, asList, isMain } from '../paths.mjs';

export function runCodex({ prompt, images = [], schema, sandbox = 'read-only', cwd = REPO,
  model = CODEX_MODEL, effort = CODEX_EFFORT, timeout = 900, out, quiet = false } = {}) {
  return new Promise((resolve) => {
    const { cmd, argsPrefix } = codexCommand();
    const lastFile = out ? path.resolve(REPO, out) : path.join(os.tmpdir(), `codex-last-${process.pid}-${Date.now()}.txt`);
    fs.mkdirSync(path.dirname(lastFile), { recursive: true });
    const args = [...argsPrefix, 'exec', '--skip-git-repo-check', '--color', 'never',
      '-m', model || CODEX_MODEL, '-c', `model_reasoning_effort="${effort || CODEX_EFFORT}"`,
      '-s', sandbox || 'read-only', '-C', cwd, '-o', lastFile];
    for (const im of images) args.push(`--image=${path.resolve(REPO, im)}`);
    if (schema) args.push('--output-schema', path.resolve(REPO, schema));
    args.push('-');
    const started = Date.now();
    const child = spawn(cmd, args, { cwd, stdio: ['pipe', 'pipe', 'pipe'], windowsHide: true });
    let log = '';
    child.stdout.on('data', (d) => { log += d; if (!quiet) process.stdout.write(d); });
    child.stderr.on('data', (d) => { log += d; if (!quiet) process.stderr.write(d); });
    child.stdin.on('error', () => {});
    child.stdin.end(prompt);
    let timedOut = false;
    const killer = setTimeout(() => { timedOut = true; killTree(child.pid); }, (timeout || 900) * 1000);
    child.on('exit', (code) => {
      clearTimeout(killer);
      const last = fs.existsSync(lastFile) ? fs.readFileSync(lastFile, 'utf8').trim() : '';
      const m = log.match(/tokens used\s*\n\s*([\d.,]+)/);
      // Account-level refusals: surface them by name so callers abort instead of retrying blind. Only Codex's own
      // `ERROR ...` lines count — matching prose anywhere in the log once aborted a finished run because a doc it
      // echoed contained the words "usage limits".
      const blockLine = (log.match(/^(?:\S+\s+)?ERROR\b.*(spend cap|usage limit|rate limit|quota|too many requests|\b429\b|not logged in|login required).*$/im) || [])[0];
      const blocked = blockLine ? (/spend cap/i.test(blockLine) ? 'spend-cap' : /login|logged/i.test(blockLine) ? 'auth' : 'rate-limit') : null;
      // The session id scopes any look-up under ~/.codex/generated_images — never scan other lanes' sessions.
      const sessionId = (log.match(/session id:\s*([0-9a-f-]{8,})/i) || [])[1] || '';
      resolve({ code: timedOut ? 124 : code, last, log, seconds: Math.round((Date.now() - started) / 1000), tokens: m ? m[1] : '', timedOut, blocked, blockLine: blockLine ? blockLine.trim() : '', sessionId });
    });
  });
}

if (isMain(import.meta.url)) {
  const a = parseArgs(process.argv.slice(2));
  let prompt = a.prompt;
  if (a['prompt-file']) prompt = fs.readFileSync(path.resolve(REPO, a['prompt-file']), 'utf8');
  if (!prompt) { console.error('need --prompt or --prompt-file'); process.exit(2); }
  const r = await runCodex({ prompt, images: asList(a.image), schema: a.schema, sandbox: a.sandbox,
    cwd: a.cwd ? path.resolve(REPO, a.cwd) : REPO, model: a.model, effort: a.effort,
    timeout: a.timeout ? Number(a.timeout) : undefined, out: a.out, quiet: !!a.quiet });
  if (a.quiet) console.log(r.last);
  if (r.blocked) console.error(`[codex] BLOCKED (${r.blocked}): ${r.blockLine}`);
  console.error(`[codex] exit=${r.code} ${r.seconds}s tokens=${r.tokens}${r.timedOut ? ' TIMEOUT' : ''}`);
  process.exit(r.blocked ? 75 : (r.code ?? 1));
}
