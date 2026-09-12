// Public API of the pure Späti engine. UI/render consume ONLY this. No React/Pixi/DOM in engine/.
export * from './types';
export { makeRng, weightedIndex } from './rng';
export { createState, defaultConfig, actOf } from './setup';
export { reduce } from './rules';
export { legalView, type LegalView } from './legal';
export { priceTier, satisfaction, nightTraffic, ownsUpgrade, moduleOptions, unlockReason, cornerStatus, type ModuleOption, type CornerStatus } from './economy';
export { resolveFinale, pickEnding, type Finale, type Ending } from './finale';
export { STRANDS, STRAND_BY_ID } from './content/story';
export * from './content';
