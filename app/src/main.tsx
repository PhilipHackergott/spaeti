import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { App } from './ui/App';

// Temporary boot-time error surface: turn a white screen into the actual error (console + on-page + POST
// to the dev server so it shows in the terminal). Remove once the launch issue is diagnosed.
function report(label: string, err: unknown): void {
  const msg = err instanceof Error ? `${err.name}: ${err.message}\n${err.stack ?? ''}` : String(err);
  // eslint-disable-next-line no-console
  console.error(label, err);
  try { void fetch('/__boot_error', { method: 'POST', body: `${label}\n${msg}` }); } catch { /* ignore */ }
  const root = document.getElementById('root');
  if (root && !root.dataset.errShown) {
    root.dataset.errShown = '1';
    root.innerHTML = `<pre style="white-space:pre-wrap;color:#f4e9cf;background:#14102a;padding:16px;margin:0;min-height:100vh;font:13px/1.5 monospace">SPÄTI failed to start.\n\n${label}\n${msg.replace(/</g, '&lt;')}</pre>`;
  }
}
window.addEventListener('error', (e) => report('window error:', (e as ErrorEvent).error ?? (e as ErrorEvent).message));
window.addEventListener('unhandledrejection', (e) => report('unhandled rejection:', (e as PromiseRejectionEvent).reason));

try {
  createRoot(document.getElementById('root')!).render(
    <StrictMode>
      <App />
    </StrictMode>,
  );
} catch (err) {
  report('render threw:', err);
}
