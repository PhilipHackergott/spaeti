import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';

// Temporary: log client boot errors POSTed by main.tsx to the dev terminal (remove with the main.tsx hook).
const bootErrorLogger = {
  name: 'boot-error-logger',
  configureServer(server: { middlewares: { use: (path: string, fn: (req: { on: (e: string, cb: (c?: unknown) => void) => void }, res: { end: (s: string) => void }) => void) => void } }) {
    server.middlewares.use('/__boot_error', (req, res) => {
      let body = '';
      req.on('data', (c?: unknown) => { body += String(c); });
      req.on('end', () => { console.error('\n=== CLIENT BOOT ERROR ===\n' + body + '\n=========================\n'); res.end('ok'); });
    });
  },
};

export default defineConfig({
  base: './',
  plugins: [react(), bootErrorLogger],
  test: {
    environment: 'node',
    include: ['tests/**/*.test.ts'],
  },
});
