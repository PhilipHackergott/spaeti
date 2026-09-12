import { useEffect, useRef, useState } from 'react';
import { Application, Container, Graphics, Sprite, Text, Assets, type Texture } from 'pixi.js';
import type { SpatiState } from '../engine';
import { ARCHETYPE_BY_ID, SKU_BY_ID } from '../engine';
import { ASSETS, assetUrl, type AssetId } from '../assets/manifest';

// THE one render swap-point (the rest of the UI stays DOM). This is a real PixiJS 8 scene at the HD logical
// canvas: it builds the behind-the-counter view from LAYERED sprites loaded from the asset manifest, and
// falls back to procedurally-drawn placeholder layers for any art that hasn't been generated yet. Drop a
// matching PNG into public/assets/ and it replaces its placeholder with zero code change (Coffee Talk Tokyo
// × Berlin Späti — see art-direction.md). The scene is purely visual; serving/HUD live in the DOM layer.

const W = 960, H = 540; // HD logical canvas (factory HD-pixel rule)
const COUNTER_Y = H - 96;

// palette
const C = { night: 0x161228, glassTop: 0x223052, glassLow: 0x2a2038, wall: 0x241c3a, shelf: 0x3a2c52,
  wood: 0x6a4a2e, woodTop: 0x8a6a44, neon: 0xf4c430, neonPink: 0xe05a8a, cold: 0x6fb8e0, txt: 0xb6a8d8 };

async function fileExists(url: string): Promise<boolean> {
  try { const r = await fetch(url, { method: 'HEAD' }); return r.ok && !(r.headers.get('content-type') ?? '').includes('text/html'); }
  catch { return false; }
}

/** A layer = the real PNG sprite if it exists, else a procedurally-drawn placeholder of the same footprint. */
async function buildLayer(id: AssetId, draw: (g: Graphics) => void): Promise<Container> {
  const url = assetUrl(id);
  if (await fileExists(url)) {
    try {
      const tex: Texture = await Assets.load(url);
      tex.source.scaleMode = 'nearest'; // crisp HD-pixel scaling
      const sp = new Sprite(tex);
      sp.width = W; sp.height = H;
      return sp;
    } catch { /* fall through to placeholder */ }
  }
  const g = new Graphics();
  draw(g);
  return g;
}

function drawBackdrop(g: Graphics): void {
  g.rect(0, 0, W, H).fill(C.night);
  // the window onto the night street
  g.roundRect(60, 40, W - 120, COUNTER_Y - 70, 10).fill(C.glassTop);
  g.roundRect(60, 40, W - 120, COUNTER_Y - 70, 10).stroke({ color: 0x3a2f60, width: 3 });
  // distant warm windows across the street
  for (let i = 0; i < 14; i++) {
    const x = 90 + (i * 61) % (W - 180), y = 70 + ((i * 53) % 120);
    g.rect(x, y, 14, 20).fill({ color: 0xffcf6e, alpha: 0.5 - (i % 3) * 0.12 });
  }
  // street + reflection
  g.rect(60, COUNTER_Y - 70, W - 120, 40).fill({ color: 0x12203a, alpha: 0.8 });
}

function drawShelves(g: Graphics): void {
  // fridge wall, left; product shelves, right — colored product blocks read as a stocked Späti
  g.roundRect(70, 60, 300, COUNTER_Y - 110, 8).fill(C.wall);
  g.roundRect(78, 70, 284, COUNTER_Y - 130, 6).fill({ color: C.cold, alpha: 0.12 }); // cold glow
  const cols = [0x4fa24f, 0xe6c84a, 0xd9442e, 0x6fb8e0, 0xc8b8e8];
  for (let r = 0; r < 4; r++) for (let c = 0; c < 7; c++) {
    g.rect(86 + c * 39, 80 + r * ((COUNTER_Y - 150) / 4), 30, 26).fill({ color: cols[(r + c) % cols.length], alpha: 0.85 });
  }
  // right-hand snack shelves
  g.roundRect(W - 360, 70, 280, COUNTER_Y - 130, 8).fill(C.shelf);
  for (let r = 0; r < 5; r++) g.rect(W - 350, 84 + r * ((COUNTER_Y - 160) / 5), 260, 8).fill({ color: 0x2a2440 });
}

function drawCounter(g: Graphics): void {
  g.rect(0, COUNTER_Y, W, H - COUNTER_Y).fill(C.wood);
  g.rect(0, COUNTER_Y, W, 5).fill(C.woodTop);
  g.rect(0, COUNTER_Y + 5, W, 3).fill({ color: 0x000000, alpha: 0.2 });
}

// Neon "SPÄTI" sign as a glow layer (placeholder for scene/shelves neon; cheap + characterful).
function neonSign(): Container {
  const c = new Container();
  const glow = new Text({ text: 'SPÄTI', style: { fill: C.neon, fontSize: 46, fontFamily: 'Trebuchet MS, sans-serif', fontWeight: 'bold', letterSpacing: 6 } });
  glow.x = W / 2 - glow.width / 2; glow.y = 64;
  const halo = new Text({ text: 'SPÄTI', style: { fill: C.neonPink, fontSize: 46, fontFamily: 'Trebuchet MS, sans-serif', fontWeight: 'bold', letterSpacing: 6 } });
  halo.x = glow.x; halo.y = glow.y; halo.alpha = 0.35; halo.scale.set(1.06); halo.x -= 3; halo.y -= 2;
  c.addChild(halo, glow);
  return c;
}

export function SceneStage({ s }: { s: SpatiState }) {
  const hostRef = useRef<HTMLDivElement>(null);
  const appRef = useRef<Application | null>(null);
  const charRef = useRef<Container | null>(null);
  const [ready, setReady] = useState(0); // bump to retrigger the reactive draw after async mount

  // Mount the Pixi app + static layers once. Carefully handles the React-18 StrictMode dev double-invoke
  // (mount → unmount → mount) and the async init/dispose race: NEVER destroy an Application before its
  // init() has resolved (its plugins aren't wired yet → destroy() would throw and tear down the React tree).
  useEffect(() => {
    const host = hostRef.current;
    if (!host) return;
    let disposed = false;
    const app = new Application();
    const destroy = () => { try { app.destroy(true, { children: true, texture: false }); } catch { /* ignore */ } };
    (async () => {
      try { await app.init({ width: W, height: H, background: C.night, antialias: false }); }
      catch { return; }
      if (disposed) { destroy(); return; } // unmounted before init finished — tear the now-initialised app down
      appRef.current = app;
      host.appendChild(app.canvas);
      app.canvas.style.width = '100%';
      app.canvas.style.height = 'auto';
      app.canvas.style.display = 'block';
      app.canvas.style.setProperty('image-rendering', 'pixelated');

      const backdrop = await buildLayer('scene/backdrop', drawBackdrop);
      const shelves = await buildLayer('scene/shelves', drawShelves);
      const counter = await buildLayer('scene/counter', drawCounter);
      if (disposed) { destroy(); return; }
      const charLayer = new Container();
      charRef.current = charLayer;
      app.stage.addChild(backdrop, shelves, neonSign(), charLayer, counter);
      setReady((n) => n + 1);
    })();
    return () => {
      disposed = true;
      charRef.current = null;
      if (appRef.current === app) { destroy(); appRef.current = null; } // only destroy once init has completed
    };
  }, []);

  // Reactive layer: the person at the counter (anonymous archetype silhouette + want bubble) or "quiet/closed".
  useEffect(() => {
    const layer = charRef.current;
    if (!layer) return;
    layer.removeChildren();
    const active = s.active;
    if (active) {
      const arch = ARCHETYPE_BY_ID[active.archetypeId];
      const wantDef = SKU_BY_ID[active.want];
      // silhouette bust rising behind the counter, tinted per archetype
      const hue = [0x8a6a44, 0x6a5d92, 0x4fa24f, 0xe6c84a, 0x6fb8e0, 0xe05a8a][hashName(arch?.name ?? '') % 6];
      const body = new Graphics();
      body.roundRect(W / 2 - 70, COUNTER_Y - 150, 140, 150, 16).fill({ color: hue, alpha: 0.92 });
      body.circle(W / 2, COUNTER_Y - 150, 40).fill({ color: hue });
      body.circle(W / 2, COUNTER_Y - 150, 40).stroke({ color: 0x000000, alpha: 0.25, width: 2 });
      layer.addChild(body);
      // name plate
      const name = new Text({ text: arch?.name ?? 'Customer', style: { fill: 0xf4e9cf, fontSize: 16, fontFamily: 'Trebuchet MS, sans-serif', fontWeight: 'bold' } });
      name.x = W / 2 - name.width / 2; name.y = COUNTER_Y - 184;
      layer.addChild(name);
      // speech bubble with what they want
      bubble(layer, `„…${wantDef ? wantDef.name : 'nur gucken'}?“`);
    } else {
      const msg = new Text({ text: s.phase === 'night' ? 'quiet for a moment…' : 'closed', style: { fill: C.txt, fontSize: 18, fontFamily: 'Trebuchet MS, sans-serif', fontStyle: 'italic' } });
      msg.x = W / 2 - msg.width / 2; msg.y = COUNTER_Y - 120;
      layer.addChild(msg);
    }
  }, [s.active?.id, s.active?.want, s.phase, ready]);

  return <div className="scene" ref={hostRef} aria-label="Späti counter scene" />;
}

function bubble(layer: Container, text: string): void {
  const t = new Text({ text, style: { fill: 0x2a1a05, fontSize: 16, fontFamily: 'Trebuchet MS, sans-serif' } });
  const pad = 12, bw = t.width + pad * 2, bh = t.height + pad * 1.4;
  const bx = W / 2 + 80, by = COUNTER_Y - 200;
  const g = new Graphics();
  g.roundRect(bx, by, bw, bh, 10).fill(0xf4e9cf);
  g.moveTo(bx + 16, by + bh).lineTo(bx + 4, by + bh + 16).lineTo(bx + 34, by + bh).fill(0xf4e9cf);
  t.x = bx + pad; t.y = by + pad * 0.7;
  layer.addChild(g, t);
}

function hashName(s: string): number {
  let h = 0; for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) >>> 0;
  return h;
}
