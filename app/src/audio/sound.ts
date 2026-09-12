// Synthesized, IP-clean Web Audio engine (no audio files) — a gentle lo-fi night-ambience loop + an SFX
// kit + a Music/SFX mixer + mute, persisted. Gesture-gated. Pinned to globalThis so HMR never spawns a
// duplicate loop (the build-gotchas rule). UI-only; the engine never imports this.

export interface AudioSettings { musicVol: number; sfxVol: number; muted: boolean }
type SfxName = 'coin' | 'clink' | 'door' | 'click' | 'register' | 'beat' | 'error';

const LS_KEY = 'spaeti_audio';
const PENTA = [0, 3, 5, 7, 10]; // minor pentatonic (cozy)

function loadSettings(): AudioSettings {
  try {
    const raw = typeof localStorage !== 'undefined' ? localStorage.getItem(LS_KEY) : null;
    if (raw) return { musicVol: 0.5, sfxVol: 0.7, muted: false, ...JSON.parse(raw) };
  } catch { /* ignore */ }
  return { musicVol: 0.5, sfxVol: 0.7, muted: false };
}

class AudioEngine {
  settings: AudioSettings = loadSettings();
  private ctx: AudioContext | null = null;
  private master: GainNode | null = null;
  private musicGain: GainNode | null = null;
  private sfxGain: GainNode | null = null;
  private timer: ReturnType<typeof setInterval> | null = null;
  private step = 0;

  /** Call from a user gesture (menu Start/Continue). Creates the context + starts the music loop. */
  start(): void {
    if (typeof window === 'undefined') return;
    if (!this.ctx) {
      const Ctor = window.AudioContext ?? (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
      this.ctx = new Ctor();
      this.master = this.ctx.createGain();
      this.musicGain = this.ctx.createGain();
      this.sfxGain = this.ctx.createGain();
      this.musicGain.connect(this.master);
      this.sfxGain.connect(this.master);
      this.master.connect(this.ctx.destination);
      this.applyGains();
    }
    void this.ctx.resume();
    if (!this.timer) this.timer = setInterval(() => this.tickMusic(), 480);
  }

  private applyGains(): void {
    if (!this.ctx || !this.master || !this.musicGain || !this.sfxGain) return;
    const t = this.ctx.currentTime;
    this.master.gain.setTargetAtTime(this.settings.muted ? 0 : 1, t, 0.02);
    this.musicGain.gain.setTargetAtTime(this.settings.musicVol * 0.5, t, 0.02);
    this.sfxGain.gain.setTargetAtTime(this.settings.sfxVol, t, 0.02);
  }

  private persist(): void {
    try { localStorage.setItem(LS_KEY, JSON.stringify(this.settings)); } catch { /* ignore */ }
  }
  setMusicVol(v: number): void { this.settings.musicVol = clamp01(v); this.persist(); this.applyGains(); }
  setSfxVol(v: number): void { this.settings.sfxVol = clamp01(v); this.persist(); this.applyGains(); }
  setMuted(m: boolean): void { this.settings.muted = m; this.persist(); this.applyGains(); }

  private note(freq: number, dur: number, type: OscillatorType, gain: number, dest: GainNode): void {
    if (!this.ctx) return;
    const t = this.ctx.currentTime;
    const osc = this.ctx.createOscillator();
    const g = this.ctx.createGain();
    osc.type = type; osc.frequency.value = freq;
    g.gain.setValueAtTime(0, t);
    g.gain.linearRampToValueAtTime(gain, t + 0.01);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    osc.connect(g); g.connect(dest);
    osc.start(t); osc.stop(t + dur + 0.02);
  }

  private tickMusic(): void {
    if (!this.ctx || !this.musicGain || this.settings.muted) return;
    // slow pad chord every 8 steps + a wandering pentatonic arpeggio note each step
    const root = 196; // G3
    if (this.step % 8 === 0) {
      [0, 7, 12].forEach((s) => this.note(root * Math.pow(2, s / 12), 3.4, 'sine', 0.16, this.musicGain!));
    }
    const semis = PENTA[(this.step * 3) % PENTA.length] + 12 * (this.step % 3 === 0 ? 2 : 1);
    this.note(root * Math.pow(2, semis / 12), 0.5, 'triangle', 0.1, this.musicGain!);
    this.step = (this.step + 1) % 64;
  }

  sfx(name: SfxName): void {
    if (!this.ctx || !this.sfxGain) return;
    const g = this.sfxGain;
    switch (name) {
      case 'coin': this.note(988, 0.08, 'square', 0.3, g); setTimeout(() => this.note(1319, 0.12, 'square', 0.3, g), 70); break;
      case 'register': this.noise(0.05, 0.2, g); this.note(1175, 0.1, 'square', 0.25, g); setTimeout(() => this.note(1568, 0.14, 'square', 0.25, g), 90); break;
      case 'clink': this.noise(0.04, 0.15, g); this.note(2200, 0.06, 'sine', 0.2, g); break;
      case 'door': this.note(660, 0.12, 'sine', 0.25, g); setTimeout(() => this.note(880, 0.18, 'sine', 0.25, g), 110); break;
      case 'click': this.note(440, 0.05, 'square', 0.18, g); break;
      case 'beat': this.note(330, 0.18, 'sine', 0.22, g); break;
      case 'error': this.note(160, 0.22, 'sawtooth', 0.22, g); break;
    }
  }

  private noise(dur: number, gain: number, dest: GainNode): void {
    if (!this.ctx) return;
    const t = this.ctx.currentTime;
    const buf = this.ctx.createBuffer(1, Math.floor(this.ctx.sampleRate * dur), this.ctx.sampleRate);
    const d = buf.getChannelData(0);
    for (let i = 0; i < d.length; i++) d[i] = (Math.random() * 2 - 1) * (1 - i / d.length);
    const src = this.ctx.createBufferSource();
    const g = this.ctx.createGain();
    src.buffer = buf; g.gain.value = gain;
    src.connect(g); g.connect(dest); src.start(t);
  }
}

function clamp01(v: number): number { return Math.max(0, Math.min(1, v)); }

const KEY = '__spaeti_audio__';
const g = globalThis as unknown as Record<string, AudioEngine>;
if (!g[KEY]) g[KEY] = new AudioEngine();
export const audio: AudioEngine = g[KEY];
