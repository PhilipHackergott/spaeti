# Späti Simulator — Playtest Report (round 1)

| | |
|---|---|
| **Build** | M5 + M2b (Pixi scene framework) + balance pass |
| **Date** | 2026-05-25 |
| **Method** | Automated: full `engine`/`sim` suite + a headless balance sweep across strategies. Static: UX/feel review against the GDD pillars. **Not yet** human-played with real art (scene is procedural placeholders behind the asset seam). |
| **Verdict** | **Mechanically sound and fun on paper; ready for a human play-through.** Two real balance bugs found and fixed this round. Remaining items are polish + art, not blockers. |

---

## 1. Correctness — ✅ green

`tsc --noEmit` clean · `vite build` OK (Pixi bundles) · **22/22 vitest**:
- Night P&L bookkeeping, price-tier elasticity, Pfand credit/payout.
- Build & Customize gradual-unlock gating.
- **Determinism**: byte-identical season per `{config, seed}`.
- Narrative: arc fires day-1, strands branch to outcomes, tapestry weaves the met cast; vignettes fire on quiet days, resolve once, never repeat, never block a cast beat.
- Balance sweeps (below).

## 2. Balance findings (headless sweep, Normal, per-strategy)

| Strategy | End cash | Integrity | Sales | Raids/season | Ending |
|---|---|---|---|---|---|
| Honest baseline | ~1796 | **75** | 2073 | 0 | **Institution** |
| + Open Sundays | ~1995 | 75 | 2235 | 0 | Institution |
| + Dark path | **~2596** | **30** | 2775 | ~1.2 | **Sold Out** |
| + Dark path + security cam | ~2386 | 32 | — | ~1.0 | Sold Out |
| + Sunday + dark path | ~2781 | 26 | 2949 | ~1.7 | Sold Out |

**Reads correctly:** honest play keeps your hands clean (Integrity 75 → Institution); the dark path is a genuine **temptation** — clearly *more money* (+45%) bought with a crashing Integrity that locks in **Sold Out**; the security cam trades cash for fewer brutal raids; Sundays are a mild positive-EV gamble (more trade, occasional fine). All locked behind assertions in `tests/sim/balance.test.ts`.

### Bugs found & fixed this round
1. **Integrity always hit 0 → every ending was "Sold Out."** The only Integrity sink was selling restricted items to minors, and nothing — not the sim, not the UI — surfaced *who was underage*, so it happened on every applicable sale. **Fix:** `legalView` now exposes `activeUnderage / activeWantRestricted / activeIllegalSale`; the headless "competent shopkeeper" refuses those sales; the **Night UI shows a `🔞 underage · ID?` tag and a ⚠ on the Sell button** so the human can make the same moral call. Honest play now holds Integrity at 75.
2. **The dark path was a pure trap** (less cash *and* worse ending — nobody would take it). **Fix:** raised the "extra menu" traffic gain (1.15→1.4) and made raids rarer but brutal (14%→8% nightly, 7%→4% with security). It's now *more money, worse soul* — a real choice.

## 3. Feel / fun — review against the pillars

- **Management loop** — the night has genuine moment-to-moment pressure (queue, clock, stock-outs, balking, Pfand). Pause/speed controls make it readable. ✅
- **Build & Customize (ongoing pillar)** — modules + décor trickle out over the season; the new "Your corner" panel makes progression legible. Strong sense of *growing a place*. ✅
- **Narrative + endings** — main arc + 6 cast strands branch to a personalized **ending tapestry**; one-off vignettes keep quiet nights alive. The four endings are reachable and meaningfully distinct. ✅
- **Community evolution** — community modules (foodsharing, bench, open-mic) + flags (flyers, busker) visibly turn a "till" into a "place." ✅
- **Risk / temptation** — dark path and Sundays now both present real, legible risk/reward (above). ✅

## 4. Open issues / recommendations (non-blocking)

| # | Item | Severity | Note |
|---|---|---|---|
| 1 | Real art (scene + portraits) not yet present | expected | Framework is art-ready; drop Gemini PNGs into `public/assets/` to replace placeholders with zero code change. |
| 2 | Sunday opening is mildly +EV with low early risk | low | Could ramp Ordnungsamt heat faster if it becomes an auto-pick. Acceptable for MVP. |
| 3 | Security cam is net-negative on cash (insurance has a cost) | low | Defensible (it cuts variance/worst-case raids); flag if players feel it's a trap. |
| 4 | Cozy may be a touch generous | low | Survival 6/6 with comfortable cash; intended as the "soak in the stories" mode. |
| 5 | Test suite ~62s (structuredClone per tick over full seasons) | low | A perf-tuning item; consider a lighter headless tick path. |
| 6 | Kiez-Trust saturates at 100 with fair play | low | Consider a softer cap / decay so it stays a live dial late-season. |

## 5. Next steps
1. **Human play-through** for feel once art lands (the one thing automation can't judge).
2. Drop in Gemini scene layers + cast portraits (manifest seam ready).
3. Optional: the scheduled content-depth pass (more strands toward ~14, wider vignette bank).
4. Then the **ship gate**.
