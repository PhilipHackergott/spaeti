// Asset-manifest seam. The engine NEVER imports this; only the render/UI layer (M2) does.
// Gemini-generated pixel art lands in `public/assets/...`; until a file exists, render falls back to a
// labelled placeholder rect — so the build runs with zero art. Keep ids ⇆ ASSET-SPEC.md in sync.

export const ASSET_BASE = 'assets';

/** Logical asset ids → file paths (under public/). Add files; no code change needed to swap placeholders. */
export const ASSETS = {
  // Scene (side-on, behind-the-counter — Coffee Talk Tokyo × Berlin Späti). Layered for parallax.
  'scene/backdrop': `${ASSET_BASE}/scene/backdrop.png`, // window + street night beyond the glass
  'scene/shelves': `${ASSET_BASE}/scene/shelves.png`, // fridge wall + product shelves + neon
  'scene/counter': `${ASSET_BASE}/scene/counter.png`, // the wood counter (foreground)

  // Cast portraits (bust facing the player, transparent bg). Expression suffixes: _neutral/_warm/_wary/_upset.
  'char/you_neutral': `${ASSET_BASE}/char/you_neutral.png`,
  'char/cem_neutral': `${ASSET_BASE}/char/cem_neutral.png`,
  'char/brandt_neutral': `${ASSET_BASE}/char/brandt_neutral.png`,
  'char/mehmet_neutral': `${ASSET_BASE}/char/mehmet_neutral.png`,
  'char/lena_neutral': `${ASSET_BASE}/char/lena_neutral.png`,
  'char/juergen_neutral': `${ASSET_BASE}/char/juergen_neutral.png`,
  'char/yusuf_neutral': `${ASSET_BASE}/char/yusuf_neutral.png`,
  'char/schmidt_neutral': `${ASSET_BASE}/char/schmidt_neutral.png`,
  'char/aylin_neutral': `${ASSET_BASE}/char/aylin_neutral.png`,
  'char/karim_neutral': `${ASSET_BASE}/char/karim_neutral.png`,
  'char/achim_neutral': `${ASSET_BASE}/char/achim_neutral.png`,
  'char/tobias_neutral': `${ASSET_BASE}/char/tobias_neutral.png`,
  'char/nadia_neutral': `${ASSET_BASE}/char/nadia_neutral.png`,
  'char/robin_neutral': `${ASSET_BASE}/char/robin_neutral.png`,
  'char/schulz_neutral': `${ASSET_BASE}/char/schulz_neutral.png`,

  // UI
  'ui/dialogue_box': `${ASSET_BASE}/ui/dialogue_box.png`,
  'ui/panel': `${ASSET_BASE}/ui/panel.png`,
  'ui/icon_clock': `${ASSET_BASE}/ui/icon_clock.png`,
  'ui/icon_cash': `${ASSET_BASE}/ui/icon_cash.png`,
} as const;

export type AssetId = keyof typeof ASSETS;

export function assetPath(id: AssetId): string {
  return ASSETS[id];
}

/** Full URL for an asset id, honouring Vite's base path. */
export function assetUrl(id: AssetId): string {
  return `${import.meta.env.BASE_URL}${ASSETS[id]}`;
}

// Map a dialogue speaker (strand character display-name or beat speaker) → a portrait asset id, when one
// exists. Vignette strangers and unnamed speakers return null (the overlay shows a procedural avatar).
const SPEAKER_TO_PORTRAIT: Record<string, AssetId> = {
  'You': 'char/you_neutral',
  'Onkel Cem': 'char/cem_neutral',
  'Frau Brandt': 'char/brandt_neutral',
  'Mehmet': 'char/mehmet_neutral',
  'Lena': 'char/lena_neutral',
  '"Bottle" Jürgen': 'char/juergen_neutral',
  'Yusuf': 'char/yusuf_neutral',
  'Frau Schmidt': 'char/schmidt_neutral',
  'Aylin & Jonas': 'char/aylin_neutral',
  'Aylin': 'char/aylin_neutral',
  'Karim': 'char/karim_neutral',
  'Achim': 'char/achim_neutral',
  'Tobias': 'char/tobias_neutral',
  'Nadia': 'char/nadia_neutral',
  'Robin': 'char/robin_neutral',
  'Frau Schulz': 'char/schulz_neutral',
};

export function portraitFor(speaker: string): AssetId | null {
  return SPEAKER_TO_PORTRAIT[speaker] ?? null;
}
