# 09 — The cast: persona cards, expression sets, arcs and test dialogues

*Eleven faces at the counter. Three you already have, eight new. One expression vocabulary, eleven
dialogue trees that are valid against `godot/engine/content/dialogues.gd` **as it stands today**, and
the persona-card data shape for `godot/engine/content/characters.gd`.*

Every id, stat, DC, flag, expression and brand token in this document is meant to be typed straight
into the engine or into `docs/asset-spec.json` without a translation step. Where a line here needs an
engine change, the file and the function are named.

---

## 0. The contracts this document is written against

Read these first; every section below depends on them.

**The six stats.** Ids are D&D, names are Späti (`Rules.STAT_NAMES` / `Strings`, guarded by
`test_scenes.gd::test_the_two_stat_tables_agree`):

`str` **Muscle** · `dex` **Hands** · `con` **Stamina** · `int` **Brains** · `wis` **Kiez Sense** · `cha` **Schnauze**

Defaults at `new_game` are **10 / 11 / 12 / 13 / 12 / 14** → modifiers **+0 / +0 / +1 / +1 / +1 / +2**.

**Checks vs gates.** A `check: {stat, dc}` rolls d20 + modifier on the seeded Rng; ≥ DC is a success
and `next_fail` catches the miss. A `requires: {stat, min}` is a **gate**: shown but locked and
un-clickable while `Rules.stat_score(s, stat) < min` (`rules.gd:508` — a locked gate is an *illegal
action*, not a failed roll). Both wear their tag inside the label — `"[Schnauze 12] …"` — because
`test_dialogue.gd::test_every_graph_is_playable` asserts the label `begins_with("[")`.

**The DC calibration that makes a gate mean something.** A gate that is already open on night one
reads as a free choice, not as aspiration. So the *minimum locking* `min` per stat is:

| Gate on | default score | lowest `min` that is **locked** on day 1 | what it should mean |
|---|---|---|---|
| `str` Muscle | 10 | **11** | lifting, the top row of the wall, carrying the bag up four floors |
| `dex` Hands | 11 | **12** | rolling one for someone, writing the price card, catching |
| `con` Stamina | 12 | **13** | staying open later, shutting the shop and going with them |
| `int` Brains | 13 | **14** | the clause, the lawyer German, the term sheet |
| `wis` Kiez Sense | 12 | **13** | seeing the thing a person is hiding |
| `cha` Schnauze | 14 | **15** | saying the thing out loud: naming it, asking for it, closing it |

Use exactly these numbers for new gates unless you mean "two upgrades away". Jürgen's existing
`[Muscle 12]` gate is legacy and stays as written. **As shipped across all 77 trees** the gate
distribution is `con` 13 ×24 · `cha` 15 ×17 · `dex` 12 ×15 · `str` 11 ×14 · `int` 14 ×14 · `wis` 13 ×4
(plus Jürgen's legacy `str` 12) — Schnauze turned out to be the cast's most-gated stat, not its
rarest, because most of what these guests need is for somebody to *say* something. The draft's
"rarely — keep it for rolls" is corrected here rather than left to contradict the content.

**Checks sit at DC 11–13.** Schnauze 12 = 55 % · Schnauze 13 = 50 % · Brains 13 = 45 % · Kiez Sense
11 = 60 % · Kiez Sense 12 = 55 %. Nothing below 45 %, nothing above 65 %: a check should feel like a
real coin, never a tax.

**The authoring rule the tests enforce:** **choice 0 of every node is never gated**, so the headless
AutoPlayer (and any "just take the top line" player) always gets out. Every tree below obeys it.

**Trees are keyed by CHARACTER ID — and, since the seasons landed, by ARC STEP.**
`Content.dialogue_id_for(character_id, state)` (`registry.gd`) resolves three tiers, first hit wins:
**`<char>_<season letter><step>`** → **`<char>`** → the nameless parade's **`oneoff`**. Letters are
summer `s` · autumn `a` · winter `w` · **spring `p`** (summer already owns `s`), and the letter comes
from the STEP's season, never from the calendar — so `lena_s2` is her summer step 2 whether she plays
it in July or, catching up, in February. A tree named `achim_t` is still silently unreachable: an id
has to be one of those two shapes. Every tree below is keyed `"achim"`, `"karim"`, `"bley"` and is
therefore that guest's **step 1**, auto-wired for free. Full rules: docs/06 §8.

**One engine change is required, and it is five lines.** `Talk.node_of` (`engine/talk.gd:44`)
currently substitutes only `{want}`, at **two** sites: line 63 (the node's `lines`) and line 67 (each
choice's `label`). The new serving model needs the basket tokens in both, or the brand vanishes from
the choice text:

```gdscript
# engine/talk.gd :: node_of — replace the two .replace("{want}", want_name) calls with one map
var subs := Talk.subs_for(s)                       # {want} + {qty.<sku>} + {brand.<sku>} + {logo.<sku>}
for line in raw.get("lines", []):
    lines.append(_apply(String(line), subs))
...
copy["label"] = _apply(String(copy.get("label", "")), subs)

static func subs_for(s: Dictionary) -> Dictionary:
    var out := {"{want}": want_name_of(s)}
    for entry in (s.get("active", {}) as Dictionary).get("basket", []):
        var sku := String((entry as Dictionary).get("sku", ""))
        out["{qty."   + sku + "}"] = str(int((entry as Dictionary).get("qty", 1)))
        out["{brand." + sku + "}"] = Content.brand_spoken(String((entry as Dictionary).get("brand", "")))
        out["{logo."  + sku + "}"] = Content.brand_logo(String((entry as Dictionary).get("brand", "")))
    return out
```

Substitution is **per basket line**, not per character: Achim orders three different tobacco products
in one breath and a single `habits.brand` field cannot serve that sentence. `_apply` leaves an
unmatched token alone, so a tree is never *broken* by a basket that lacks the SKU — but `test_tokens.gd`
(§6) fails the build if that ever happens, which is the same rule as the soft-lock that shipped:
**never trust a name, assert against the read-model.**

---

## 1. The brand slots

A customer orders tobacco by **pointing at the wall**: a logo, a colour, a spoken word. **`docs/08` §2
is the canonical catalogue**, and it now ships as `godot/engine/content/brands.gd` (22 rows: 8
cigarettes, 4 rolling tobaccos, 6 paper variants, 4 filter variants). The cast lane only ever writes
the *token*, so a rename is one edit in one table and zero edits in any line of dialogue.

The eleven guests draw on these rows; the rest of the catalogue is wall filler and wrong-pack fodder,
which is exactly what a matching game needs.

| brand id | mark (the shape) | colour | spoken as (`Content.brand_spoken`) | logo phrase | tier / form |
|---|---|---|---|---|---|
| `kranich` | S-hook crane neck, 2 blocks | `#2f7a5f` jade | "Kranich cigarettes" | "the crane" | mainstream full-flavour cigarettes |
| `fuchs` | two ear triangles over a muzzle block | `#d2691e` orange | "Fuchs cigarettes" | "the fox" | cheapest cigarettes on the wall |
| `luxor` | stepped pyramid, 3 rows | `#c9a227` gold | "Luxor cigarettes" | "the pyramid" | **filterless**, one row, being delisted |
| `nordstern` | 8-point star, one core block and 4 arms | `#1e3a63` navy | "Nordstern cigarettes" | "the star" | premium cigarettes |
| `perle` | filled circle with one highlight block | `#c8c3bb` pearl | "Perle cigarettes" | "the pearl" | capsule / menthol cigarettes |
| `zunder` | 4-block flint spark | `#2a2a30` charcoal | "Zunder tobacco" | "the black pouch" | rolling tobacco, strong |
| `dreiringe` | three rings in a row | `#6b7a3a` olive | "Drei Ringe tobacco" | "the green pouch" | rolling tobacco, organic |
| `pap_feder_lang` · `pap_feder_kurz` | tall · short booklet, single thin foot band | `#e6dcc2` cream | "long Feder papers" · "short Feder papers" | "the cream booklet" | rolling papers, by length |
| `fil_slim` · `fil_reg` | narrow · wide box, three plain round tips | `#cfc7b4` putty · `#b9a982` sand | "slim filters" · "regular filters" | "the slim ones" · "the fat ones" | filter tips, by gauge |

**The remap, for anyone reading an older draft.** This section used to carry its own placeholder ids;
they are gone, and every basket below was rewritten onto the canonical ones.

| was | is | what travelled |
|---|---|---|
| `kranich` | `kranich` | the crane; the colour became jade |
| `sperling` | `fuchs` | cheapest on the wall, a warm animal mark — "the brown bird" becomes "the fox" |
| `roter_stern` | `luxor` | the filterless relic being delisted; a gold pyramid instead of a red star |
| `nachtfalter` | `nordstern` | premium, night-blue; the moth becomes the star |
| `polarfuchs` | `perle` | the pale cool pack; capsule / menthol |
| `zunder` | `zunder` | unchanged |
| `halm` | `dreiringe` | the organic green pouch |
| `linde` | `pap_feder_lang` / `pap_feder_kurz` | a paper *brand* is a paper *variant*: the length is the id |
| `wolke` | `fil_slim` / `fil_reg` | a filter *brand* is a filter *variant*: the gauge is the id |

**Three rules that fall out of the canonical table, and every line below obeys them.**

1. **The variant IS the id.** `long`/`short` and `slim`/`regular` live in `pap_*` / `fil_*`, not in a
   parallel `variant` field, so one lookup answers "what is this facing". (`30 g`/`50 g` on a pouch has
   no id in docs/08 §2 and is flavour text only; "extra-slim" collapses onto `fil_slim`, the only slim
   gauge that exists.)
2. **`spoken` is a whole noun phrase, not a bare name** — "long Feder papers", not "Linde". So a line
   never writes the modifier twice: `long {brand.papers}` would read *"long long Feder papers"*. Write
   `{brand.papers}` and let the table carry the length.
3. **`{logo.<sku>}` is a picture, not a word.** `Content.brand_logo(id)` returns the facing's **asset
   id** (`tob/pack_fuchs`), which is what `BrandMark` crops its 16×16 window out of — so the token is an
   inline mark glyph in a line, never spoken text. The "logo phrase" column above is still
   authoring-only: it has **no accessor yet**, and the day a line needs to *say* "the fox" the table
   gains a `phrase` field and `Content.brand_phrase(id)` beside the other two.

**`filters` is a real SKU and it now exists** — `{"id": "filters", "cost": 0.35, "base_price": 1.0,
"fair_lo": 0.8, "fair_hi": 1.6, "category": "tobacco", "icon": "sku/filters"}`, shipped in `skus.gd`
alongside the brand catalogue, so it reaches the ManageBoard with stock and a price band like
everything else. Three trees below order it by gauge.

## 2. The cast

Eleven guests. Lena, Jürgen and Mehmet keep their ids, portraits, colours and existing trees — they
get the opening line as a list order, plus (for Lena and Mehmet) the one locked gate every arc step
owes (§4.9). The other eight come from
`narrative-design.md` §8; seven of them already have a strand in `story.gd`, so the wiring cost is one
`characters.gd` row plus one tree. Herr Bley is the only new strand.

Arc steps are Truby's seven, keyed to the year: **Summer = steps 1–2 · Autumn = 3–4 · Winter = 5–6 ·
Spring = 7.** Step titles are the **beat ids** a later season will ship — "The Night He Doesn't Come"
is shippable; "Battle" is not.

> **STATUS 2026-09-13 — the arcs are SHIPPED, content and all.** Every step title listed in §2.1–2.11
> below now exists twice over: as a **beat** in that guest's `story.gd` strand (all eleven chains are
> seven beats deep, one per step) and as a **dialogue tree** keyed `<char>_<season letter><step>` in
> `dialogues.gd`. Seventy-seven trees: the eleven plain ones, which *are* step 1, plus sixty-six
> written by four content lanes. They reach the counter through `Content.dialogue_id_for` with no
> engine edit per tree — the rules are docs/06 §8, the cast-wide acceptance tests are `test_arcs.gd`
> §12, and a headless four-season year puts **all eleven guests on step 7 with an outcome recorded**.
>
> Three things a writer touching a beat title should know. **(1)** A step number names exactly one
> tree, for ever: the season letter comes from the *step's* season, never the calendar. **(2)** A beat
> from step 2 on carries a `requires_flag` written by an earlier beat in the same chain — that is how
> a step *reads* the step before it, because a dialogue tree cannot gate on a flag. **(3)** Renaming a
> beat id is cheap; renaming the flag it gates on is not — `eligible_beats` drops a strand whose gate
> can never be met, which is a guest who silently stops existing (docs/06 §8.6).
>
> **What the shipped 28-night year actually delivers is 2–4 of the seven steps per guest.** That is a
> pacing decision still open, not a defect — the measured table and the three levers are in docs/06 §8.7.

Every guest carries two mandatory clauses, **Stake** (to the Späti) and **Arc link** (to the main
gentrification arc and to Frau Brandt, the developer's agent). No guest may be written without both.

---

### 2.1 `lena` — Lena Voigt · 23 · painting student · `#e8a1b8` · archetype `student` · strand `lena`

Third year at the art school, a studio she shares with four people and one radiator that died in
1994. Grew up in Cottbus, came for the school, stayed for the city, and has been fifty cents short at
this counter since Cem's time — he kept her tab on the back of a Pfand receipt and never mentioned it
once. She rolls her own because a pack is a week of lunches. She is proud in the specific way that
costs money: she would go hungry before she said the word "hungry", and she pays her debts in things
she made.

- **Stake:** the Späti is her canteen and her clock, and her tab on the fridge door is the only credit
  anyone has ever extended her.
- **Arc link:** her half of the flat is in the building Lindner is buying. A "professionalised"
  Spätkauf has no line item for a tab on a fridge door — she is the first person the corner loses.
- **Habits:** Mate (stood on the laminate label-out, like she works here), Schrippe, and on a good week
  `1× {brand.tobacco}` (`dreiringe`, the green pouch) + `{brand.papers}` (`pap_feder_lang`) +
  `{brand.filters}` (`fil_reg`). Never takes the Pfand
  back; leaves it as a tip she can pretend isn't one. **Arrives** ~23:30, most nights.
- **Voice:** quick, deflecting, jokes ahead of the sentence that would hurt. Short clauses. Says "ähm"
  when she means *I am about to ask you for something*.

| # | Season | Beat id | Line |
|---|---|---|---|
| 1 | Summer | *Fifty Cents Short* | The tab starts, and she would rather owe you than say she is broke. |
| 2 | Summer | *The Honest Piece* | She shows you what she is actually making. |
| 3 | Autumn | *The Gallerist* | He will hang her only if she makes it sellable. |
| 4 | Autumn | *Nights In The Studio* | She stops eating; the tab grows; the radiator stays dead. |
| 5 | Winter | *The Show* | The honest piece, or the one that sells. |
| 6 | Winter | *Help Isn't Failing* | She lets you feed her, and the honesty *is* the work. |
| 7 | Spring | *The Wall* | She clears the tab in paint, on your wall, and becomes a regular who gives. |

---

### 2.2 `juergen` — "Bottle" Jürgen Massek · 61 · Flaschensammler · `#9fb7a3` · archetype `regular` · strand `juergen`

Thirty years a fitter at a works that closed in 1996, and he has not said the word "unemployed" out
loud since. Does the Pfand round between the S-Bahn arches and the park: two carrier bags and a crate
he found. He is never wrong about a count and has never once said so. He calls you *Chef* because
using your first name would make it a friendship, and he does not accept friendships, only
transactions and weather reports.

- **Stake:** the Pfand crate you leave out is the only door on this street that opens for him.
- **Arc link:** the chain Spätkauf locks its bins. When the chain opens, half his route dies — he is
  the human cost of the main arc's squeeze, standing in front of you, in a jacket that is not a winter
  jacket.
- **Habits:** whatever the Pfand covers, in this order: a Schrippe, a Sterni, and
  `1× {brand.cigarettes}` (`fuchs`) if the count runs past six euro. Pays entirely by offsetting the
  deposit against the bill — his line at the register *is* the Pfand-offset case. **Arrives** ~22:00
  and again ~01:30.
- **Voice:** short, formal, exact numbers. Deflects care with logistics.

| # | Season | Beat id | Line |
|---|---|---|---|
| 1 | Summer | *Forty-One Bottles* | The count, twice, and never wrong. |
| 2 | Summer | *The Crate Is Yours* | You start leaving it out where he can reach it. |
| 3 | Autumn | *The Chain Locks Its Bins* | Half the route dies in a week. |
| 4 | Autumn | *Not A Winter Jacket* | The rhythm gets thinner; the cold does not. |
| 5 | Winter | *The Night He Doesn't Come* | |
| 6 | Winter | *Seen* | The bench inside the door is his, and nobody asks. |
| 7 | Spring | *Night-Watch* | He tells you the weather before the app does. |

---

### 2.3 `mehmet` — Mehmet Aydın · 58 · greengrocer two doors down · `#d8a05a` · archetype `regular` · strand `mehmet`

Came at nineteen to a job his uncle had already quit, stayed for a woman who stayed for him, and has
sold fruit on this street since the year the Wall opened. Cem's oldest friend — they argued about
football for three decades and about nothing else that mattered. His son Deniz went to Munich for a
consultancy and calls on Sundays; Mehmet answers on the third ring so it does not look eager. He has
the Kiez's whole memory in his head and a drawer of letters in lawyer German he will not admit he
cannot read.

- **Stake:** he is the conscience — the ally who will tell you, out loud, the night you start pricing
  people instead of serving them.
- **Arc link:** same envelope, same lawyer's name, six weeks from Friday. He is your co-defendant, and
  Brandt has already been in his shop buying two lemons and staying twenty minutes.
- **Habits:** `1× {brand.cigarettes}` (`kranich`) — the same pack for thirty-one years, "the green one,
  don't ask which green" — a Mate, a large water. The "**the usual**" order: the register must let you
  ring his basket from memory. **Arrives** ~20:30, after he shuts.
- **Voice:** warm, blunt, arrives at the point sideways. Says "Quatsch." Uses your uncle as a yardstick
  and knows exactly what he is doing when he does it.

| # | Season | Beat id | Line |
|---|---|---|---|
| 1 | Summer | *Lawyer German* | The letter lands on your counter, flattened with the side of his hand. |
| 2 | Summer | *Cem Would Have Made A Week Of It* | |
| 3 | Autumn | *Eleven Percent* | The Umlage cap is written wrong, in their favour. |
| 4 | Autumn | *Knock On Every Door* | Or don't, and be second instead of first. |
| 5 | Winter | *You're Becoming Them* | The lease renewal lands the week Deniz visits. |
| 6 | Winter | *Legacy Is People* | |
| 7 | Spring | *Deniz Comes For The Versammlung* | — or doesn't, and Mehmet stands with you anyway. |

---

### 2.4 `schulz` — Christa Schulz · 79 · retired Reichsbahn dispatcher · `#b8a9c0` · archetype `regular` · strand `schulz` *(S5)*

Born four streets away, put on the trains at nineteen, ran night traffic out of Ostkreuz until 1993,
when a man from Hannover explained her job to her and then took it. Watched the Wall open from this
corner, at this window, with a Mokka going cold in her hand. Sharp-tongued about the new people and
secretly desperate for one of them to ask her one real question. Prices everything in the old money
first, and can tell you what stood on any corner within four streets, and in which year it stopped.

- **Stake:** she has bought bread on this corner under three different signs, and Cem wrote her prices
  by hand on card because her eyes went.
- **Arc link:** Brandt's people have already been to her door with a *Modernisierungsangebot* and a
  slow, kind voice "for the old lady". They expect her to be the easiest tenant in the Haus. She is not.
- **Habits:** two Schrippen, milk, a block of chocolate on Fridays, and `1× {brand.cigarettes}`
  (`luxor`) **filterless** — the last row of it on your wall, which the wholesaler has stopped
  listing. When that row runs out it is a story beat, not a stock-out. **Arrives** ~18:40, daily.
- **Voice:** dry, declarative, small cruelties followed by an unexpected tenderness. Calls you *Junge*.
  Never explains a reference.

| # | Season | Beat id | Line |
|---|---|---|---|
| 1 | Summer | *The Konsum Stood Here* | Until March '91, then a video shop, then four years of nothing. |
| 2 | Summer | *Prices In Her Hand* | You write the strips the old way, and she watches you do it. |
| 3 | Autumn | *A Man From The Verwaltung Came* | Brandt's soft approach, at her door, in a good coat. |
| 4 | Autumn | *Holding Court* | She tells it whether you listen or not. |
| 5 | Winter | *They Take The Signal Box Down* | The last landmark she worked in. |
| 6 | Winter | *They Do Want The Stories* | They were hers to give, not to hoard. |
| 7 | Spring | *The Corner's Memory* | She narrates the Kiezversammlung and the room goes quiet. |

---

### 2.5 `achim` — Achim Kolbe · 57 · sound engineer, ex-squatter · `#c2564a` · archetype `insomniac` · strand `achim` *(S7)*

Came over in 1984 to dodge the Bundeswehr, like everyone, and stayed for the noise. Squatted a
Vorderhaus on the next street for eleven years; ran the PA in three venues that are now a gym, a
co-working space and a hole. Does festival load-ins twice a year and mixes small rooms when somebody
remembers to call him. Two of his crew moved to Brandenburg, one runs a café in Lisbon, one is dead.
He is the last of them in the postcode and he has contempt for every single person who left, which is
all of them.

- **Stake:** your window is his noticeboard and your counter is his stage.
- **Arc link:** when the fight comes, Achim already knows how to run one. He has the folding table, the
  laminator, a PA in a cupboard and no shame whatsoever. He is your campaign, badly dressed.
- **Habits:** the deepest register order in the game — `{brand.tobacco}` (`zunder`, the 50 g) +
  `{brand.papers}` (`pap_feder_lang`) + `{brand.filters}` (`fil_slim`, "not the fat ones") + one Sterni + the cheap lighter,
  never the branded one. Three separate reaches at the wall, and he *will* correct you on the filter
  gauge. **Arrives** after a load-in, ~01:00, and he is loud about it.
- **Voice:** loud, funny, five clauses where one would do, lands on a hard consonant. Softens exactly
  once per conversation and then covers it.

| # | Season | Beat id | Line |
|---|---|---|---|
| 1 | Summer | *Everything Good Gets Sold* | The rant, free, unrequested. |
| 2 | Summer | *Can I Put This In Your Window* | |
| 3 | Autumn | *The Spätkauf Opens* | He is unbearable about it and completely right. |
| 4 | Autumn | *The Folding Table* | He starts organising before anybody asks him to. |
| 5 | Winter | *The Squat Becomes Lofts* | With a plaque about its history, next to a keypad. |
| 6 | Winter | *The Fight Is The Scene* | Your stand is the scene, reborn, small. |
| 7 | Spring | *Elder Agitator* | Useful at last, and insufferable about it. |

---

### 2.6 `karim` — Karim Hadid · 31 · kitchen shifts, trained civil engineer · `#8fae5a` · archetype `regular` · strand `karim` *(S6)*

Two years here via Aleppo and four years in Beirut; a degree three offices have politely failed to
recognise; prep cook on the late shift at a Vietnamese place on the big street. His German is better
than he thinks and deserts him completely at counters — he builds a sentence like a shelf, checking
the level, and then ruins it on purpose with a joke, because if he is the one laughing first it does
not sting. He orders by pointing at the wall, which is how the tobacco display becomes a language
problem, and a way in. Keeps every letter in a plastic sleeve.

- **Stake:** your counter is his evening class, and the fact that you wait while he finishes a sentence
  is not a small thing.
- **Arc link:** he is what the corner is *for*. A Kiez that can absorb a stranger is worth defending; a
  lobby with a keypad is not. Brandt's plan has no floor for the person who needs somewhere to be bad
  at German in public.
- **Habits:** `2× {brand.cigarettes}` (`fuchs`) ordered as *"the fox, the one with the ears"*, a large
  water, a Mate, a chocolate for the girl in the flat below on Fridays. Orders by logo and colour, never
  by brand name, until the night he doesn't. **Arrives** ~00:20, after his shift.
- **Voice:** careful, formal, short. Rehearses before he speaks. Apologises for language that is fine.
  When he relaxes, the jokes are very dry and arrive a beat late.

| # | Season | Beat id | Line |
|---|---|---|---|
| 1 | Summer | *A Careful Sentence* | |
| 2 | Summer | *The Berlin Way To Say It* | You teach him "zackig"; he uses it wrong, gloriously. |
| 3 | Autumn | *The Letter In His Jacket* | A Behörde deadline, four days unopened. |
| 4 | Autumn | *Ten Minutes Of German, Every Night* | |
| 5 | Winter | *Something Gets Said To Him At The Corner* | And what you do about it. |
| 6 | Winter | *This Is Already Home* | He already has people; he just had not counted them. |
| 7 | Spring | *He Cooks For The Street Party* | And four Germans learn to say his name properly. |

---

### 2.7 `nadia` — Nadia Ferreira · 34 · ITU night nurse, single mother · `#7fbfb0` · archetype `nurse` · strand `nadia` *(S9)*

Twelve years on the wards, the last six at night because nights pay the difference between the rent
and the rent. Her son Leo is six and sleeps at her mother's three nights a week, and her mother
complains about it every one of them. Nadia quit smoking eleven years ago on the day of the scan, and
your tobacco wall is the only thing in the Kiez that still argues with her about it. She arrives with
the flat calm of someone who has been calm since seven the previous evening, and triages everything,
including conversations.

- **Stake:** the 04:00 coffee is the only ten minutes of the day that belongs to her.
- **Arc link:** she is why "open at four" is not a business decision. **The chain shuts at 23:00.** When
  the corner goes, she is the person the Kiez loses, and there is no line in the development plan where
  she would appear.
- **Habits:** two coffees (one for whoever is on the door downstairs), two Schrippen, painkillers about
  once a fortnight — *the children's one*. **No tobacco**, and the register must register that absence:
  the night she looks at the `nordstern` row is a beat, not a sale. **Arrives 03:40**, between a
  double.
- **Voice:** quiet, economical, medical precision, gallows humour delivered without a smile. Never asks
  for anything. Says "it's fine" in four different meanings.

| # | Season | Beat id | Line |
|---|---|---|---|
| 1 | Summer | *03:40, Coffee, Two Schrippen* | |
| 2 | Summer | *She Never Asks* | |
| 3 | Autumn | *The Doubles Stack Up* | |
| 4 | Autumn | *Counting Coins At The Till* | Twice — and the second count tells you everything. |
| 5 | Winter | *Childcare Falls Through Mid-Shift* | On the coldest night of the year. |
| 6 | Winter | *It Takes A Kiez* | Asking is not weakness, and it costs her everything to do it. |
| 7 | Spring | *Leo Does Homework On The Crate* | Behind your counter, Thursdays. |

---

### 2.8 `tobias` — Tobias Lange · 33 · product lead, mobility startup · `#c9b07a` · archetype `tourist` · strand `tobias` *(S8)*

Düsseldorf, then Munich, then a two-bedroom in the front building with the good windows for what
Mehmet's whole family pays. He genuinely loves this corner — learns names, tips absurdly, calls it "my
Späti" to colleagues — comes in four nights a week, and nobody has ever come in *with* him. His
employer's office is four floors of a Lindner-refurbished block, which he has never once connected to
the rent letters he hears about at your counter. Warm, lonely, generous and structurally the problem.

- **Stake:** your best customer and your worst omen.
- **Arc link:** the **fake-ally opponent**. His company's Series B was led by a fund with Lindner three
  layers down, and its office lease carries a break clause tied to the block's residential conversion
  completing by March. When he offers to help save the Späti he will mean it, and it will cost you.
- **Habits:** four Sternis on a Thursday, chips, `1× {brand.cigarettes}` (`nordstern`) — "only when I
  drink, so, twice a week" — and a vape the week you stock them. Card out before you have scanned the
  first bottle, every time, and he apologises for it. Tips the change and then some. **Arrives** ~21:00
  Thursdays, and whenever he has nowhere to be.
- **Voice:** fluent, over-friendly, product vocabulary leaking into human sentences. Asks questions he
  does not wait for the answer to — except once.

| # | Season | Beat id | Line |
|---|---|---|---|
| 1 | Summer | *Big Tip, Big Ideas* | |
| 2 | Summer | *You Should Make This A Destination* | |
| 3 | Autumn | *The Kiez Fund* | His "help", with strings he cannot see. |
| 4 | Autumn | *He Brings Six Colleagues* | And the corner changes for a night. |
| 5 | Winter | *His Company Or The Corner* | |
| 6 | Winter | *Belonging Is Paid In Care* | |
| 7 | Spring | *Throws In* | — signs the tenants' letter and loses something at work — *or moves to the next authentic postcode*, and the epilogue is a postcard from Leipzig. |

---

### 2.9 `robin` — Robin Kessler · 19 · café shift · `#c07ad8` · archetype `student` · strand `robin` *(S10)*

Left a town near Halberstadt eleven months ago with a rucksack and a chosen name, and has been braced
for the flinch ever since. Tests everyone: a flat, slightly rude opener, delivered deadpan, to see
what comes back. If nothing bad comes back they are funny, fast, and about fifteen years younger than
their guard. Rolls at the counter, badly, and will not accept help with it. Their mother thinks they
are coming home in the summer.

- **Stake:** the safest-looking light on the street at one in the morning, which is not nothing when
  you are nineteen.
- **Arc link:** the corner is the reason they stayed in Berlin instead of going back. A lobby with a
  keypad is not a place you can stand outside of at 1am without a reason. If the corner goes, they go.
- **Habits:** an energy drink, gummi bears, `1× {brand.tobacco}` (`dreiringe`, the green pouch),
  `{brand.papers}` (`pap_feder_kurz`), `{brand.filters}` (`fil_slim`) — and they will specify the gauge. **Arrives** ~01:10,
  four nights a week, and stays outside longer than the transaction.
- **Voice:** flat, deadpan, very fast once the guard drops. The grin arrives a second late, which is
  how you know it is real.

| # | Season | Beat id | Line |
|---|---|---|---|
| 1 | Summer | *The Flat Opener* | The test, delivered without a smile. |
| 2 | Summer | *The Name They Use Now* | And what you write on the fridge list. |
| 3 | Autumn | *A Call Home* | Forty seconds, then nothing for a week. |
| 4 | Autumn | *Orbiting The Light* | |
| 5 | Winter | *First Heartbreak, 2am, Your Counter* | |
| 6 | Winter | *Chosen Family Is Real And It's Here* | |
| 7 | Spring | *They Bring The Crew* | Four of them on your bench, loud, at home. |

---

### 2.10 `aylin` — Aylin Demir · 29 · live-sound engineer · `#d6e05e` · archetype `raver` · strand `aylinjonas` *(S4)*

**Staging decision: Aylin is solo; Jonas is offstage.** Two people cannot share one 160×193 leaning
bust without either shrinking both faces or cropping one to a shoulder, so S4 is written as *her* arc
and Jonas's absence becomes the arc itself — one bag instead of two. This costs `story.gd` a two-field
edit on the `aylinjonas` strand: `"character": "Aylin"`, `"character_id": "aylin"`. The strand id stays
`aylinjonas` so its beats, outcomes and epilogue keys are untouched.

She arrives Sunday at 07:40 still glittering, talking at one and a half speed about a set that ended
an hour ago, in the specific radiant condition of a person who will crash hard at nine. Plans things
constantly: next weekend, next summer, a bar in Portugal, a van. Jonas held the second bag for seven
years of Sundays. Lately, sometimes, he doesn't.

- **Stake:** the bench out front is where their Sundays happen; your corner has hosted more of that
  relationship than either of their flats.
- **Arc link:** the bench is public, free and unbuyable, which is precisely what the development plan
  has no line item for. The first thing a "professionalised" corner removes is somewhere to sit for
  nothing — and she is the one who notices the fence notice on the door.
- **Habits:** two Mate, a water, `1× {brand.cigarettes}` (`perle`) — and **a lighter**, every
  single time, without exception. **Arrives Sunday 07:40**, and only then.
- **Voice:** fast, warm, radiant, plans stated as facts. Goes very even when something costs her.

| # | Season | Beat id | Line |
|---|---|---|---|
| 1 | Summer | *Sunday, 07:40, Glitter* | |
| 2 | Summer | *The Van And The Bar* | The plans, stated like a contract. |
| 3 | Autumn | *Jonas Isn't With Her* | One bag. Seven years of Sundays and it has always been two. |
| 4 | Autumn | *One More Season Of Sundays* | |
| 5 | Winter | *The Job In Leipzig* | One of them has to choose. |
| 6 | Winter | *The Magic Was Each Other* | Not the club. |
| 7 | Spring | *They Come At Eight In The Evening Now* | And still buy a lighter. |

---

### 2.11 `bley` — Rüdiger Bley · 61 · corporate real-estate financing · `#8a949c` · archetype `insomniac` · **new strand** *(S13)*

Arrives at 03:10 in a good coat and orders with the crispness of a man who considers you staff, then
stands at the counter nine minutes over a four-euro transaction. A wife in a house in Grunewald that
he leaves at midnight to drive around a city he despises on paper. Calls you "young man" for three
months and then, one night, doesn't. He is not a conspirator: he is a man who read a term sheet on a
Tuesday and went to lunch.

- **Stake:** the only place in his life where nobody wants anything from him.
- **Arc link:** **he is the lever.** He signed off the Lindner financing on page eleven, and what he
  lets slip at three in the morning — that the facility is conditional on *vacant possession by a fixed
  date* — arrives through a customer relationship, months before Brandt hands you hers, and pairs with
  Tobias's break clause rather than duplicating it. Sets `main_lever_hint`.
- **Habits:** still water, never sparkling. One bar of chocolate he leaves on the counter most nights.
  `1× {brand.cigarettes}` (`nordstern`), a pack a night, most of it thrown away. Pays cash, exact,
  and does not want a bag. **Arrives 03:10**, nightly, never at any other hour.
- **Voice:** clipped, formal, sentences with the subject fully specified. One unguarded clause per
  night, immediately covered by an ordinary one.

| # | Season | Beat id | Line |
|---|---|---|---|
| 1 | Summer | *Still Water, Never Sparkling* | |
| 2 | Summer | *"Young Man"* | The armour, worn politely. |
| 3 | Autumn | *He Stays Eleven Minutes* | Over a four-euro transaction. |
| 4 | Autumn | *What He Read On A Tuesday* | Page eleven, mentioned as small talk. |
| 5 | Winter | *The Armour Comes Off* | A divorce, a collapse, 3am. |
| 6 | Winter | *Somebody Saw Him* | The corner did what his world didn't. |
| 7 | Spring | *A Quiet Patron* | He pays the Mieterverein retainer and asks you never to mention it — *or relapses into the coat*, and the epilogue is a man ordering water from a stranger. |

> **On the bench, in this order, when the cast grows:** `yusuf` (the underage ID beat — the only owner
> of `sell_restricted`, and the tobacco wall's moral hinge; take him first), `schmidt` (already a
> strand), `esra`/`nilay` (S12 — two people, one slot: needs the same staging decision Aylin got),
> `diego`/`pohl` (S14), `bruno` (S15 — a dog, not a bust). **Frau Brandt** (`brandt`, `#8fa8c8`) is
> already in the registry and is **not a guest**: she arrives as a main-arc beat and is pressure on all
> eleven above, not a twelfth regular. She gets the same six expressions so the third-act turn has a
> face for it.

---

## 3. The expression set

**Six ids, identical across the whole cast.** The art lane draws **one leaning identity** per character
(160×193, transparent, cut at the underside of the forearms on the counter line, hands and prop visible
above the laminate) and then re-renders the face five times. Every re-render prompt carries the IDENTITY
clause already used for `char/lena_warm`: *same face shape, same hair, same clothes, same palette, same
framing — change only the expression*, with the character's own `_neutral` raw in `refs`.

| id | direction — pixel-level, identical for every character |
|---|---|
| `neutral` | Default counter face: level gaze, closed mouth, brows relaxed, weight settled evenly on both forearms. This is the identity render; everything else is a face swap on top of it. |
| `warm` | Closed-lip smile lifting the cheeks two pixels, eyes softened and crinkled at the outer corner, head tilted a touch toward you. The one you earn. |
| `wary` | Chin down a few pixels, one brow lower than the other, mouth a flat short line, eyes holding steady. Guarded, never hostile. |
| `upset` | Brows pulled in and up at the inner ends, mouth pressed or turned down at one corner, gaze dropped off-camera to the left. Hurt for some of the cast, angry for others — the brow does the work. |
| `surprised` | Brows high and level, eyes a row taller with more white above the iris, mouth a small open oval, head pulled back one pixel. The hands stop moving. |
| `tired` | Upper lids low and heavy, shadow blocks under the eyes, mouth slack and slightly open, head and shoulders dropped two pixels, one forearm taking real weight on the laminate. |

**Two per-character deviations are allowed, and must be written into the `asset-spec.json` entry rather
than improvised.** They are cheap variety on top of a deliberately frozen face set:

1. **A signature prop**, present in every expression: Lena's Mate bottle · Jürgen's crate handle ·
   Mehmet's folded letter · Schulz's net bag · Achim's flyers · Karim's plastic sleeve · Nadia's
   coffee · Tobias's card · Robin's rolling tin · Aylin's lighter · Bley's still-water bottle.
2. **One prop state change**, in exactly one expression: Aylin's lighter is **lit** in `warm`; Achim's
   flyers are **crushed** in `upset`; Bley's chocolate is **untouched on the counter** in `tired`;
   Robin's tin is **shut** in `wary`.

**Framing note the art lane must action.** The three leaning busts on disk (`lena`, `juergen`,
`mehmet`) are **160×193, `"stage": "leaning"`**. `brandt`, `tobias`, `schulz`, `nadia`, `you` and both
one-offs are still the **old 144×174** framing. Every portrait in this document is 160×193 leaning, so
those guests need **re-specced and regenerated** entries, not merely new expressions — a 144×174 bust
standing next to a leaning one reads as a different game.

**Cost and build order.** 11 guests × 6 = **66 portraits**; 8 exist on disk and 6 more are specced but
ungenerated. `Content.portrait_asset` checks the character's `expressions` array before falling back to
`_neutral`, so every wave ships playable — **but the `expressions` array must list only what is actually
on disk**, because a stamped placeholder standing next to a finished bust reads as a broken character.
Promotion is one array edit plus one asset-spec entry.

- **Wave 1 (11 assets):** `neutral` for all eleven, at 160×193 leaning. The queue and the counter both
  work; nothing is half-drawn.
- **Wave 2 (22):** `warm` + `wary` for all eleven — every tree below reaches both.
- **Wave 3 (11):** `upset`.
- **Wave 4 (22):** `surprised` + `tired`.

**No duplicate guest sprites — the nameless parade.** The brief is explicit, and the parade is where it
currently breaks: six of the eight archetypes in `customers.gd` point at `char/oneoff_clubber`. With
eleven named regulars in rotation the counter will visibly double a face. Grow the pool to **five
silhouettes before the next capture pass** — `oneoff_clubber`, `oneoff_tourist` (exist),
`oneoff_lateworker`, `oneoff_dogwalker`, `oneoff_kassenkind` (new) — and remap:

`regular` → lateworker · `tourist` → tourist · `raver` → clubber · `nurse` → lateworker ·
`student` → clubber · `insomniac` → dogwalker · `party` → clubber · `kid` → kassenkind

**Not done yet, and here is the exact blocker.** The remap is one `portrait` field per archetype in
`customers.gd`, but `char/oneoff_lateworker_neutral`, `char/oneoff_dogwalker_neutral` and
`char/oneoff_kassenkind_neutral` are in **neither `docs/asset-spec.json` nor `Assets.SIZES`**, and
`test_dialogue.gd::test_the_queue_view_is_fifo_and_carries_portraits` asserts that every portrait in
the queue is an id the art pipeline knows. Pointing an archetype at an unspecced id fails that test on
the next build. Placeholder rows in `characters.gd` are deliberately absent for the same reason a
half-drawn expression is: a row listing a `neutral` that is not on disk is exactly the broken
character `test_content.gd::test_the_expression_vocabulary_is_frozen_and_honest` exists to catch.
**Order of operations:** three spec entries + three SIZES rows (orchestrator) → three `neutral` busts
at 144×174 (art lane) → three `characters.gd` rows and eight `customers.gd` `portrait` fields (cast
lane, ten minutes).

(The QueueStrip itself is safe either way: its chips are code-drawn silhouettes in the speaker's
`colour`, not shrunken portraits — which is exactly why all eleven colours above are distinct hues.)

---

## 4. The test dialogue trees

Eleven trees in the exact shape of `dialogues.gd`. Keys used: `speaker`, `expression`, `lines`,
`choices[{label, check{stat,dc}, requires{stat,min}, effects{cash,kiez,profit,integrity,flags},
effects_success, effects_fail, next, next_fail, serve, sell_restricted}]`.

Every new tree: **5–8 nodes · ≥ 1 d20 check · ≥ 1 gate that is locked at default stats · an expression
change per node · ≥ 1 flag a later season reads · the order woven into the first node · choice 0 never
gated · every `next`/`next_fail` resolving to a written node or `""`.**

**SHIPPED.** All eight are in `godot/engine/content/dialogues.gd`, and the blocks below are kept
identical to it — `dialogues.gd` is the source of truth and this section is its mirror. Two edits
happened between the draft and the build, both of them content bugs the tests would not have caught:

1. **Labels were trimmed to fit the counter.** `test_content.gd::test_no_authored_choice_outgrows_the_counter`
   measures every authored label against the real Jersey 10 face in the real box width
   (`DIALOGUE_W_QUEUE 300`, minus panel margins and row padding, minus a rolled choice's tag) and
   allows two lines. About a dozen labels lost a clause; none lost a meaning.
2. **Robin's order stuttered.** The draft read `short {brand.papers}` and `the extra-slim
   {brand.filters}`, which render *"short short Feder papers"* and *"the extra-slim slim filters"* —
   §1 rule 2 again, one draft later. The shipped line is `{brand.papers}, and {brand.filters}. The
   slim, not the fat ones.`, which keeps the gauge-specifying characterisation and says it once.

### 4.1 Frau Schulz — the price strip, and what stood on this corner before

```gdscript
	"schulz": {
		"start": "prices",
		"nodes": {
			"prices": {
				"speaker": "schulz", "expression": "neutral",
				"lines": ["\"Two Schrippen, the milk, one chocolate. And {qty.cigarettes}× {brand.cigarettes}. Without filter.\"", "A pause exactly long enough to be a test. \"You still have them. Or is that finished too.\""],
				"choices": [
					{"label": "\"Two left on the wall. I'll put one aside for Friday.\"", "effects": {"kiez": 1.0, "flags": ["schulz_reserved"]}, "next": "strip"},
					{"label": "[Kiez Sense 12] She is not asking about cigarettes.", "check": {"stat": "wis", "dc": 12}, "next": "konsum", "next_fail": "strip"},
					{"label": "\"Wholesaler's dropped them. That's the last row.\"", "effects": {"kiez": -0.5}, "next": "strip"},
				],
			},
			"konsum": {
				"speaker": "schulz", "expression": "warm",
				"lines": ["It is not the cigarette. The Konsum stood here until March '91, then a video shop, then four years of nothing, and now a price strip in a font.", "\"I dispatched night trains out of Ostkreuz for twenty-nine years, Junge. I know what a schedule is. This Kiez has no schedule any more.\""],
				"choices": [
					{"label": "\"Tell me what stood on the other corner.\"", "effects": {"kiez": 1.5, "flags": ["schulz_listen"]}, "next": "strip"},
					{"label": "\"March '91. You're sure?\" (She is sure.)", "effects": {"kiez": 0.5, "flags": ["schulz_listen"]}, "next": "strip"},
				],
			},
			"strip": {
				"speaker": "schulz", "expression": "wary",
				"lines": ["\"Your uncle wrote the prices by hand. On card. You could read them from the street.\"", "She counts the coins out of a purse with a clasp older than you are, one at a time, which takes a while and is meant to."],
				"choices": [
					{"label": "\"I'll write the next lot by hand.\"", "effects": {"kiez": 0.5}, "next": "bag"},
					{"label": "[Hands 12] Let her dictate the dispatcher's hand.", "requires": {"stat": "dex", "min": 12}, "effects": {"kiez": 2.0, "flags": ["schulz_hand"]}, "next": "bag"},
					{"label": "\"The strips came with the shelf.\"", "next": "bag"},
				],
			},
			"bag": {
				"speaker": "schulz", "expression": "neutral",
				"lines": ["The net bag goes over her wrist. Milk, two Schrippen, chocolate, {logo.cigarettes} on top. It hangs lower than her hand wants it to.", "\"Fourth floor. No lift. It was a beautiful building in 1968.\""],
				"choices": [
					{"label": "\"Bis morgen, Frau Schulz.\"", "next": "door"},
					{"label": "[Muscle 11] Carry it up the four floors.", "requires": {"stat": "str", "min": 11}, "effects": {"kiez": 2.0, "flags": ["schulz_bag"]}, "next": "landing"},
					{"label": "[Schnauze 13] Who knocked on her door last week?", "check": {"stat": "cha", "dc": 13}, "next": "brandt", "next_fail": "door"},
				],
			},
			"landing": {
				"speaker": "schulz", "expression": "surprised",
				"lines": ["Four floors. She talks the whole way up and is not out of breath. You are.", "At the door she takes the bag back and looks at you one second too long. \"Cem carried it too. He never said it was heavy either.\""],
				"choices": [
					{"label": "\"Same time tomorrow.\"", "effects": {"kiez": 1.0, "flags": ["schulz_bag"]}, "next": ""},
				],
			},
			"brandt": {
				"speaker": "schulz", "expression": "wary",
				"lines": ["\"A young woman. Good coat. She said Modernisierung, and she said it slowly. For the old lady.\"", "\"I have been offered a better flat by better-dressed people before, Junge. In '92 as well.\""],
				"choices": [
					{"label": "\"Don't sign anything. Bring it to me first.\"", "effects": {"kiez": 2.0, "flags": ["schulz_brandt_visit"]}, "next": "door"},
					{"label": "\"What did you tell her?\" (\"Nothing.\")", "effects": {"kiez": 1.0, "flags": ["schulz_brandt_visit"]}, "next": "door"},
				],
			},
			"door": {
				"speaker": "schulz", "expression": "tired",
				"lines": ["\"Na dann. Friday, if the world is still standing.\" The bell takes her out into it. She checks both ways twice, out of habit from a different city."],
				"choices": [{"label": "\"Friday, Frau Schulz.\"", "next": ""}],
			},
		},
	},
```

### 4.2 Achim — three reaches at the wall, and a poster that is already printed

```gdscript
	"achim": {
		"start": "order",
		"nodes": {
			"order": {
				"speaker": "achim", "expression": "neutral",
				"lines": ["\"Fifty of {brand.tobacco}, {brand.papers}, and {brand.filters} — slim, not the fat ones, I'm not a plumber.\"", "\"And a Sterni and the cheap lighter. Not the branded one. I'm not paying two euro for fire.\" Three separate reaches at the wall. He watches all three like a man marking a load-in."],
				"choices": [
					{"label": "Ring all five through, slims included.", "effects": {"kiez": 0.5}, "next": "chain"},
					{"label": "[Brains 11] The fifty is cheaper than two thirties.", "check": {"stat": "int", "dc": 11}, "next": "maths", "next_fail": "chain"},
					{"label": "[Muscle 11] Reach the top-row box without the stool.", "requires": {"stat": "str", "min": 11}, "next": "reach"},
				],
			},
			"maths": {
				"speaker": "achim", "expression": "warm",
				"lines": ["\"One euro sixty. Over a year that is — hang on — that is a PA cable.\" He is delighted in a way he would deny under questioning.", "\"Cem never did the maths for me. Cem just took the money.\""],
				"choices": [
					{"label": "\"Cem was a businessman. I'm just bored.\"", "effects": {"kiez": 1.0, "flags": ["achim_maths"]}, "next": "chain"},
				],
			},
			"reach": {
				"speaker": "achim", "expression": "surprised",
				"lines": ["You go up on the counter edge and have it down in one. No stool, no wobble.", "\"…Alright. Alright. Your uncle used the stool like a pensioner.\""],
				"choices": [
					{"label": "\"My uncle never dropped a box on a customer.\"", "effects": {"kiez": 1.0}, "next": "chain"},
				],
			},
			"chain": {
				"speaker": "achim", "expression": "upset",
				"lines": ["\"You seen it? Down the block. Neon sign, app, a QR code where the till should be. They've got a CONCEPT.\"", "\"And they've done the Vorderhaus. The one we held for eleven years. Lofts. There's a plaque, mate. A PLAQUE. About us. Next to a keypad we couldn't get through.\""],
				"choices": [
					{"label": "Let him run. Don't fill the gap.", "effects": {"kiez": 0.5}, "next": "poster"},
					{"label": "[Schnauze 13] \"So do it again. Here. This winter.\"", "check": {"stat": "cha", "dc": 13}, "next": "scene", "next_fail": "poster"},
					{"label": "\"It's a shop, Achim. Not the Stasi.\"", "effects": {"kiez": -0.5}, "next": "poster"},
				],
			},
			"scene": {
				"speaker": "achim", "expression": "warm",
				"lines": ["He goes quiet for the first time in four years. Rolls one with the long papers, doesn't light it.", "\"…I've still got the small PA. And I know every printer in this postcode. Say when, Chef.\""],
				"choices": [
					{"label": "\"When. Thursday. Bring the PA.\"", "effects": {"kiez": 2.0, "flags": ["achim_ally"]}, "next": "poster"},
				],
			},
			"poster": {
				"speaker": "achim", "expression": "neutral",
				"lines": ["Out of the jacket comes an A3, still warm from somebody's work printer. KIEZVERSAMMLUNG. DONNERSTAG. The typeface is a crime and the message is not.", "\"Your window. It's the only glass on this street anyone still reads.\""],
				"choices": [
					{"label": "Tape it up, centre of the window.", "effects": {"kiez": 1.5, "flags": ["achim_poster"]}, "next": "off"},
					{"label": "\"Inside the door. The window is my livelihood.\"", "effects": {"kiez": 0.5, "flags": ["achim_poster_inside"]}, "next": "off"},
					{"label": "[Stamina 13] Shut the shop, do the poster route with him.", "requires": {"stat": "con", "min": 13}, "effects": {"kiez": 2.5, "cash": -18.0, "flags": ["achim_route", "achim_ally"]}, "next": "four_am"},
				],
			},
			"four_am": {
				"speaker": "achim", "expression": "warm",
				"lines": ["Four in the morning, sixty posters, and one long silence somewhere around Wühlischplatz where he does not rant at all.", "\"Cem did this with us once. Ninety-six. Rent strike. He printed the flyers on the shop's paper and told the Vermieter it was a menu.\""],
				"choices": [
					{"label": "\"He never told me that.\"", "effects": {"kiez": 1.0, "flags": ["achim_cem_story"]}, "next": ""},
					{"label": "\"Then we've done this before. Good.\"", "effects": {"kiez": 1.5, "flags": ["achim_cem_story"]}, "next": ""},
				],
			},
			"off": {
				"speaker": "achim", "expression": "upset",
				"lines": ["\"Thursday. Bring the whole Kiez or bring nobody, but bring yourself.\"", "He takes his five things and leaves the exact money, to the cent, as always. The door bangs harder than it needs to."],
				"choices": [{"label": "\"Thursday.\"", "effects": {"kiez": 0.5}, "next": ""}],
			},
		},
	},
```

### 4.3 Karim — he points at the wall, and there is a letter he has not opened

```gdscript
	"karim": {
		"start": "point",
		"nodes": {
			"point": {
				"speaker": "karim", "expression": "neutral",
				"lines": ["\"Good evening. One water — still — one Mate, and… {qty.cigarettes}. The fox. {logo.cigarettes}.\"", "His finger goes over your shoulder, precise, to exactly the right row. He builds the sentence like a shelf, checking the level, and lands it."],
				"choices": [
					{"label": "\"{qty.cigarettes}× {brand.cigarettes}.\" Ring it, no fuss.", "next": "lesson"},
					{"label": "[Kiez Sense 11] He mouthed the word before he pointed.", "check": {"stat": "wis", "dc": 11}, "next": "practice", "next_fail": "lesson"},
					{"label": "[Schnauze 12] Say the brand once, slowly, like it's nothing.", "check": {"stat": "cha", "dc": 12}, "next": "word", "next_fail": "stiff"},
				],
			},
			"word": {
				"speaker": "karim", "expression": "warm",
				"lines": ["\"{brand.cigarettes}.\" He says it back, then again to himself while you bag it. \"{brand.cigarettes}. The fox is a {brand.cigarettes}.\"", "\"Tomorrow I will not point.\""],
				"choices": [
					{"label": "\"Point anyway. I like the pointing.\"", "effects": {"kiez": 1.0, "flags": ["karim_word"]}, "next": "lesson"},
					{"label": "\"Say it the Kiez way: einmal die {brand.cigarettes}, und zwar zackig.\"", "effects": {"kiez": 1.5, "flags": ["karim_word", "karim_zackig"]}, "next": "lesson"},
				],
			},
			"practice": {
				"speaker": "karim", "expression": "surprised",
				"lines": ["He had the whole sentence ready outside, under the sign, and it left him at the counter. It happens every night.", "\"…You saw this. Sorry. It is stupid.\""],
				"choices": [
					{"label": "\"It's not stupid. Try it on me. Nobody's behind you.\"", "effects": {"kiez": 1.5, "flags": ["karim_word"]}, "next": "lesson"},
					{"label": "\"Happens to me in my own language, most nights.\"", "effects": {"kiez": 1.0}, "next": "lesson"},
				],
			},
			"stiff": {
				"speaker": "karim", "expression": "wary",
				"lines": ["He hears the lesson inside the sentence and goes very polite, which is how he goes away.", "\"Yes. Thank you. {qty.cigarettes}. Correct.\""],
				"choices": [
					{"label": "Drop it. Bag the water.", "next": "lesson"},
				],
			},
			"lesson": {
				"speaker": "karim", "expression": "neutral",
				"lines": ["\"In Aleppo I built bridges. Here I am very good at cutting onions.\" He says it lightly, which is how you know it is not light.", "\"Six years of study, and my problem is the articles. Der, die, das. A child knows them.\""],
				"choices": [
					{"label": "\"A child has had six years of practice too.\"", "effects": {"kiez": 1.0}, "next": "sleeve"},
					{"label": "\"Nobody in this Kiez gets them right either.\"", "effects": {"kiez": 0.5}, "next": "sleeve"},
				],
			},
			"sleeve": {
				"speaker": "karim", "expression": "wary",
				"lines": ["A plastic sleeve comes out of the jacket, flattened at the corners from being carried a long time. The top envelope is the window kind, and it is still sealed.", "\"Four days. I read the sender, and then I put it in my jacket, and I have been very busy for four days.\""],
				"choices": [
					{"label": "\"Bring it tomorrow, early. We'll go through it.\"", "effects": {"kiez": 1.0, "flags": ["karim_form"]}, "next": "goodnight"},
					{"label": "[Brains 14] Read the paragraph under the date.", "requires": {"stat": "int", "min": 14}, "next": "read"},
					{"label": "\"That's Behörde business, Karim. I sell Mate.\"", "effects": {"kiez": -1.0}, "next": "goodnight"},
				],
			},
			"read": {
				"speaker": "karim", "expression": "surprised",
				"lines": ["It is not a refusal. It is a request for one document he already has, in the sleeve, second from the back.", "He looks at the counter for a while. \"Six weeks I did not sleep for this paper.\""],
				"choices": [
					{"label": "Photocopy it out back. On the house.", "effects": {"kiez": 2.0, "flags": ["karim_form", "karim_helped"]}, "next": "goodnight"},
				],
			},
			"goodnight": {
				"speaker": "karim", "expression": "warm",
				"lines": ["\"Gute Nacht.\" A beat. \"…Und zwar zackig.\" He gets the rhythm right on the third try and leaves pleased with himself."],
				"choices": [{"label": "\"Gute Nacht, Karim.\"", "next": ""}],
			},
		},
	},
```

### 4.4 Nadia — 03:40, and the Paracetamol is not for her

```gdscript
	"nadia": {
		"start": "four",
		"nodes": {
			"four": {
				"speaker": "nadia", "expression": "tired",
				"lines": ["\"Two coffees — one's for the porter, he's been on since six as well — two Schrippen, and the Paracetamol. The children's one, if you have it.\"", "03:52. Scrubs under the coat. She is very still, the way people are when moving costs something."],
				"choices": [
					{"label": "Ring the four. Make the porter's the strong one.", "effects": {"kiez": 0.5}, "next": "wall"},
					{"label": "[Kiez Sense 12] The children's one.", "check": {"stat": "wis", "dc": 12}, "next": "leo", "next_fail": "wall"},
					{"label": "\"Long one?\" (Everyone asks her that.)", "effects": {"kiez": -0.5}, "next": "wall"},
				],
			},
			"leo": {
				"speaker": "nadia", "expression": "upset",
				"lines": ["The children's dose. At twenty to four, on her way *in* to a shift, not out of one.", "\"He's six. Thirty-eight nine at ten o'clock. My mother's with him and she'll call if it climbs.\" Her jaw is doing a lot of work."],
				"choices": [
					{"label": "\"Then you should be at home, and you know it.\"", "effects": {"kiez": 0.5}, "next": "wall"},
					{"label": "Turn the box round. Read the weight column out loud.", "effects": {"kiez": 1.0}, "next": "dose"},
					{"label": "\"Take it. Pay me whenever.\"", "effects": {"cash": -3.0, "kiez": 2.0, "flags": ["nadia_tab"]}, "next": "wall"},
				],
			},
			"dose": {
				"speaker": "nadia", "expression": "surprised",
				"lines": ["She lets you get all the way to the end before she says anything.", "\"…I know the table. I'm an ICU nurse.\" A breath. \"I wanted somebody to say it to me. Nobody says anything to me.\""],
				"choices": [
					{"label": "\"Then I'll say it again tomorrow at twenty to four.\"", "effects": {"kiez": 2.0, "flags": ["nadia_seen"]}, "next": "wall"},
					{"label": "Say nothing. Push the coffee across.", "effects": {"kiez": 1.5, "flags": ["nadia_seen"]}, "next": "wall"},
				],
			},
			"wall": {
				"speaker": "nadia", "expression": "wary",
				"lines": ["The star row, second from the top. She has been looking at it for the length of a coffee.", "\"Eleven years. I stopped the day of the scan. And that wall still talks to me every single night.\""],
				"choices": [
					{"label": "\"Nothing off that wall tonight. Coffee's poured.\"", "effects": {"kiez": 1.0, "flags": ["nadia_held"]}, "next": "childcare"},
					{"label": "\"Your call, Nadia. I'll ring it if you say so.\"", "effects": {"flags": ["nadia_offered"]}, "next": "childcare"},
					{"label": "Switch the display light off. \"Wall's shut.\"", "effects": {"kiez": 1.5, "flags": ["nadia_held"]}, "next": "childcare"},
				],
			},
			"childcare": {
				"speaker": "nadia", "expression": "upset",
				"lines": ["Her phone goes on the counter face-up, which it never does. Her mother has the flu. Leo is asleep four streets away and will not be, at seven.", "\"It's fine. I'll sort it. It's fine.\""],
				"choices": [
					{"label": "\"What would actually help? Say the thing.\"", "effects": {"kiez": 1.0}, "next": "bye"},
					{"label": "[Stamina 13] \"I'll open at six. Bring him here.\"", "requires": {"stat": "con", "min": 13}, "effects": {"kiez": 2.5, "flags": ["nadia_kid"]}, "next": "bye"},
					{"label": "\"You always say it's fine.\"", "effects": {"kiez": 0.5, "flags": ["nadia_seen"]}, "next": "bye"},
				],
			},
			"bye": {
				"speaker": "nadia", "expression": "warm",
				"lines": ["She takes the porter's coffee and holds it against her wrist for a second, for the warmth.", "\"This is the only place open that isn't a petrol station. You know that, ja? The chain shuts at eleven.\" A beat. \"You should sleep, by the way. Professionally speaking.\""],
				"choices": [
					{"label": "\"I'll be open at four. That's the whole offer.\"", "effects": {"kiez": 1.0, "flags": ["nadia_open_at_four"]}, "next": ""},
					{"label": "\"Professionally noted.\"", "next": ""},
				],
			},
		},
	},
```

### 4.5 Tobias — the big tip, the lanyard, and whose money is under the fund

```gdscript
	"tobias": {
		"start": "order",
		"nodes": {
			"order": {
				"speaker": "tobias", "expression": "warm",
				"lines": ["\"Four Sternis, the chips, and one {brand.cigarettes} — love the pack, honestly, it's such a clean design. I only smoke when I drink, so, you know. Twice a week.\"", "Card out before you've scanned the first bottle. \"Keep the change. No — keep it, I mean it. This place is the reason I moved to this Kiez.\""],
				"choices": [
					{"label": "\"Thanks, Tobias.\" Take the tip, ring it straight.", "effects": {"cash": 5.0, "kiez": 0.5}, "next": "fund"},
					{"label": "[Kiez Sense 12] Read the lanyard he forgot to remove.", "check": {"stat": "wis", "dc": 12}, "next": "lanyard", "next_fail": "fund"},
					{"label": "[Schnauze 13] Ring the pack at tourist price.", "check": {"stat": "cha", "dc": 13}, "effects_success": {"cash": 3.0, "integrity": -2.0, "flags": ["tobias_gouged"]}, "effects_fail": {"kiez": -1.0}, "next": "fund", "next_fail": "fund"},
				],
			},
			"lanyard": {
				"speaker": "tobias", "expression": "surprised",
				"lines": ["A building pass. Fourth floor of the block on the corner — the one with the new glass and the old address.", "\"Oh — yeah, we moved in in August. Amazing space. Really respectful refurb, actually.\""],
				"choices": [
					{"label": "\"Respectful to who, Tobias?\"", "effects": {"flags": ["tobias_lindner"]}, "next": "lonely"},
					{"label": "Say nothing. File it.", "effects": {"flags": ["tobias_lindner"]}, "next": "fund"},
				],
			},
			"lonely": {
				"speaker": "tobias", "expression": "upset",
				"lines": ["He comes in four nights a week. He knows your name, Mehmet's name and the dog's name. Nobody has ever come in *with* him.", "\"…You do the thing my dad does. With the face.\" He laughs at it and it doesn't quite take."],
				"choices": [
					{"label": "\"Come Thursday. There's a thing. Bring nobody.\"", "effects": {"kiez": 1.0, "flags": ["tobias_invited"]}, "next": "fund"},
					{"label": "\"Four Sternis and a packet. That's all I'm reading into it.\"", "next": "fund"},
				],
			},
			"fund": {
				"speaker": "tobias", "expression": "neutral",
				"lines": ["\"Actually — real thing. We're putting together a little Kiez fund. Local businesses, small grants, no strings. I put your name in.\"", "\"It'd cover, like, a year of your rent increase.\""],
				"choices": [
					{"label": "\"That's kind. I'll think about it.\"", "effects": {"flags": ["tobias_fund_offered"]}, "next": "night"},
					{"label": "[Brains 13] A fund needs a funder.", "check": {"stat": "int", "dc": 13}, "next": "lindner", "next_fail": "night"},
					{"label": "[Schnauze 15] Make him say the investor's name.", "requires": {"stat": "cha", "min": 15}, "effects": {"flags": ["tobias_fund_offered"]}, "next": "lindner"},
				],
			},
			"lindner": {
				"speaker": "tobias", "expression": "surprised",
				"lines": ["Three questions in he says it himself and doesn't hear it: the fund sits under the community budget, the Series B was led by a property group's venture arm, and the office lease has a break clause tied to the block's residential conversion completing by March.", "\"…Lindner. Yeah. But that's just capital, they don't *do* anything, they're an LP.\" A pause. \"That's bad, isn't it. That's why you went quiet.\""],
				"choices": [
					{"label": "\"March. Say that date again, slowly.\"", "effects": {"kiez": 1.0, "flags": ["tobias_digging", "main_lever_hint"]}, "next": "ask"},
					{"label": "\"Then I'll take the money and keep our prices.\"", "effects": {"cash": 60.0, "integrity": -3.0, "flags": ["tobias_lindner", "took_fund"]}, "next": "night"},
					{"label": "\"No fund. Just come in and buy beer like a person.\"", "effects": {"kiez": 1.0, "flags": ["tobias_lindner"]}, "next": "ask"},
				],
			},
			"ask": {
				"speaker": "tobias", "expression": "upset",
				"lines": ["He puts the card away and pays cash, badly, counting twice.", "\"I didn't — I chose the office off a floorplan. That's genuinely how it happened.\""],
				"choices": [
					{"label": "\"I know. That's the whole problem, mate.\"", "effects": {"kiez": 1.0, "flags": ["tobias_warned"]}, "next": "night"},
					{"label": "\"Then find out what else you signed off a floorplan.\"", "effects": {"kiez": 1.0, "flags": ["tobias_warned", "tobias_digging"]}, "next": "night"},
				],
			},
			"night": {
				"speaker": "tobias", "expression": "warm",
				"lines": ["\"Schönen Abend!\" — pronounced beautifully, practised — and he holds the door for the next guest, because he is, genuinely, quite nice."],
				"choices": [{"label": "\"Schönen Abend.\"", "next": ""}],
			},
		},
	},
```

### 4.6 Robin — the flat opener, which is a test, and the name they use now

```gdscript
	"robin": {
		"start": "counter",
		"nodes": {
			"counter": {
				"speaker": "robin", "expression": "wary",
				"lines": ["\"{brand.tobacco} — {logo.tobacco} — {brand.papers}, and {brand.filters}. The slim ones, not the fat ones. And an energy and the gummi bears.\"", "\"This place is kind of depressing, by the way.\" Delivered completely flat, eyes on you, waiting."],
				"choices": [
					{"label": "\"It's a Späti at one in the morning. That's the genre.\"", "effects": {"kiez": 0.5}, "next": "roll"},
					{"label": "[Kiez Sense 12] That was a test, not an insult.", "check": {"stat": "wis", "dc": 12}, "next": "test", "next_fail": "roll"},
					{"label": "\"Then buy your gummi bears somewhere cheerful.\"", "effects": {"kiez": -1.5}, "next": "", "serve": false},
				],
			},
			"test": {
				"speaker": "robin", "expression": "surprised",
				"lines": ["They say something rude to everyone on the first go. Eleven months of it. It is cheaper to be thrown out on your own terms than on somebody else's.", "You put the tin down without a word and don't rise to it. Their whole face resets a millimetre."],
				"choices": [
					{"label": "\"Sit on the crate. It's warmer inside the door.\"", "effects": {"kiez": 1.5, "flags": ["robin_crate"]}, "next": "roll"},
					{"label": "\"Depressing is free. The energy drink is two twenty.\"", "effects": {"kiez": 1.0}, "next": "roll"},
				],
			},
			"roll": {
				"speaker": "robin", "expression": "neutral",
				"lines": ["They roll one on the counter, badly — too much in one end, the paper going soft at the seam. Third attempt.", "\"Don't. I know. I'm learning.\""],
				"choices": [
					{"label": "\"You're learning fine.\"", "next": "name"},
					{"label": "[Hands 12] Roll one and slide it over, no comment.", "requires": {"stat": "dex", "min": 12}, "effects": {"kiez": 1.5, "flags": ["robin_rolled"]}, "next": "name"},
					{"label": "\"Buy the ready-mades. Cheaper by the hour.\"", "next": "name"},
				],
			},
			"name": {
				"speaker": "robin", "expression": "wary",
				"lines": ["\"Put it on the tab thing. If you do tabs.\" A pause. \"Robin. With an i-n. Not what my bank card says — the card's my mum's old account, it's a whole thing.\"", "Said fast and flat, and their hand is very still on the counter."],
				"choices": [
					{"label": "Write ROBIN on the fridge list. \"Done.\"", "effects": {"kiez": 2.0, "flags": ["robin_name"]}, "next": "home"},
					{"label": "\"Robin. Got it.\" Use it again later, naturally.", "effects": {"kiez": 2.0, "flags": ["robin_name"]}, "next": "home"},
					{"label": "\"The card has to match the name, sorry.\"", "effects": {"kiez": -2.5, "integrity": -1.0}, "next": "home"},
				],
			},
			"home": {
				"speaker": "robin", "expression": "neutral",
				"lines": ["\"Halberstadt. Well — near it. Nobody's ever heard of the actual place, which was the best thing about leaving.\"", "\"Eleven months. My mum thinks I'm coming back in the summer.\""],
				"choices": [
					{"label": "\"Are you?\"", "effects": {"flags": ["robin_summer"]}, "next": "out"},
					{"label": "\"Berlin's full of people from near somewhere.\"", "effects": {"kiez": 1.0}, "next": "out"},
				],
			},
			"out": {
				"speaker": "robin", "expression": "warm",
				"lines": ["\"Anyway. Still depressing in here.\" The grin arrives about a second late, which is how you know it's real."],
				"choices": [{"label": "\"Bis morgen, Robin.\"", "next": ""}],
			},
		},
	},
```

### 4.7 Aylin — Sunday, 07:40, glitter, and a lighter. Always a lighter.

```gdscript
	"aylin": {
		"start": "dawn",
		"nodes": {
			"dawn": {
				"speaker": "aylin", "expression": "warm",
				"lines": ["\"Two Mate, a water, {qty.cigarettes}× {brand.cigarettes} — {logo.cigarettes} — und ein Feuerzeug.\"", "\"Don't say it. I know. Fourth one this month. They *leave*, Chef. I don't lose them, they emigrate.\""],
				"choices": [
					{"label": "Put the lighter on the counter without comment.", "next": "set"},
					{"label": "\"I'm starting a jar. Yours live here now.\"", "effects": {"kiez": 1.0, "flags": ["aylin_lighter_jar"]}, "next": "set"},
					{"label": "[Kiez Sense 12] She is holding one bag, not two.", "check": {"stat": "wis", "dc": 12}, "next": "jonas", "next_fail": "set"},
				],
			},
			"jonas": {
				"speaker": "aylin", "expression": "neutral",
				"lines": ["One bag. Seven years of Sundays and it has always been two bags, and Jonas holding both of them.", "\"He went home at two. He's been going home at two since March.\" The sentence is very even, which costs her something."],
				"choices": [
					{"label": "\"Two's a reasonable time to go home.\"", "effects": {"kiez": 0.5, "flags": ["aylin_jonas_two"]}, "next": "set"},
					{"label": "\"And you've been staying till seven.\"", "effects": {"kiez": 1.5, "flags": ["aylin_jonas_two", "aylin_named_it"]}, "next": "set"},
					{"label": "Ring it up. Not your business.", "effects": {"kiez": -0.5}, "next": "set"},
				],
			},
			"set": {
				"speaker": "aylin", "expression": "warm",
				"lines": ["\"Second room, half four, this Italian woman with a modular rig — unbelievable. I nearly cried at a hi-hat.\"", "She is talking at about one and a half speed, which means the crash is due around nine."],
				"choices": [
					{"label": "\"Go home and sleep before it lands.\"", "next": "plans"},
					{"label": "[Stamina 13] Stay on the bench with her until it does.", "requires": {"stat": "con", "min": 13}, "effects": {"kiez": 2.0, "flags": ["aylin_bench"]}, "next": "bench"},
				],
			},
			"bench": {
				"speaker": "aylin", "expression": "tired",
				"lines": ["It lands at twenty past eight, mid-sentence, somewhere between the van they're going to buy and the bar they're going to open in Portugal.", "\"…The bar's not real, is it.\" The Mate goes down on the bench between you. \"It was real in 2019.\""],
				"choices": [
					{"label": "\"The bench is real. Sunday's real. Start there.\"", "effects": {"kiez": 2.0, "flags": ["aylin_bench_talk"]}, "next": "plans"},
					{"label": "Say nothing. Let the street get light.", "effects": {"kiez": 1.5, "flags": ["aylin_bench_talk"]}, "next": "plans"},
				],
			},
			"plans": {
				"speaker": "aylin", "expression": "warm",
				"lines": ["\"Next Sunday. Bench. Both of us, I'll drag him.\" She says *next Sunday* the way other people say *contract*.", "The glitter has got onto your counter and will still be there on Wednesday."],
				"choices": [
					{"label": "\"Bench is yours. It always was.\"", "effects": {"kiez": 1.0}, "next": "door"},
					{"label": "\"Bring him. I'll do two coffees.\"", "effects": {"kiez": 1.0, "flags": ["aylin_bring_jonas"]}, "next": "door"},
				],
			},
			"door": {
				"speaker": "aylin", "expression": "surprised",
				"lines": ["Halfway out she turns round. \"They're putting a fence round the bench side. Did you know that? There was a paper taped to the door.\""],
				"choices": [
					{"label": "\"…No. Bring me the paper, Aylin.\"", "effects": {"kiez": 1.0, "flags": ["aylin_fence", "main_lever_hint"]}, "next": ""},
					{"label": "\"I'll look tomorrow.\"", "effects": {"flags": ["aylin_fence"]}, "next": ""},
				],
			},
		},
	},
```

### 4.8 Herr Bley — 03:10, still water, and a term sheet he read on a Tuesday

```gdscript
	"bley": {
		"start": "three_am",
		"nodes": {
			"three_am": {
				"speaker": "bley", "expression": "neutral",
				"lines": ["\"Water. Still — the other is undrinkable. A chocolate. And {qty.cigarettes}× {brand.cigarettes}.\"", "Good coat, good watch, and he has been standing at this counter for nine minutes over a four-euro transaction."],
				"choices": [
					{"label": "Ring it up at the speed he seems to want.", "next": "stays"},
					{"label": "\"Long night, or a short one?\"", "effects": {"kiez": 0.5}, "next": "stays"},
					{"label": "[Schnauze 12] Talk to him like a person, not a customer.", "check": {"stat": "cha", "dc": 12}, "next": "armour", "next_fail": "stays"},
				],
			},
			"stays": {
				"speaker": "bley", "expression": "wary",
				"lines": ["He does not leave. He turns the water bottle a quarter turn on the laminate. Twice.", "\"You are open at three. Remarkable. In Grunewald there is nothing open at three. Not even the people.\""],
				"choices": [
					{"label": "\"Somebody's always awake. I just sell to them.\"", "next": "tuesday"},
					{"label": "\"You drive here from Grunewald?\" (He does.)", "effects": {"kiez": 0.5}, "next": "tuesday"},
				],
			},
			"armour": {
				"speaker": "bley", "expression": "surprised",
				"lines": ["\"Young man—\" and then he stops, and starts again without the young man. \"…Rüdiger. Bley. Since we appear to be doing this.\"", "\"Thirty-one years in corporate finance, and nobody at three in the morning has asked me a question that was not about a price.\""],
				"choices": [
					{"label": "\"Then I'll ask you one every night at three.\"", "effects": {"kiez": 1.5, "flags": ["bley_talks"]}, "next": "tuesday"},
					{"label": "\"Rüdiger. Noted. Chocolate's one forty.\"", "effects": {"kiez": 1.0, "flags": ["bley_talks"]}, "next": "tuesday"},
				],
			},
			"tuesday": {
				"speaker": "bley", "expression": "neutral",
				"lines": ["\"This street, by the way. Somebody put a paper in front of me on Tuesday. Block acquisition, mixed use. A very tidy structure.\"", "\"I signed off the financing on page eleven and went to lunch. One does not look at the street name.\""],
				"choices": [
					{"label": "\"It's this street. You're standing in page eleven.\"", "effects": {"flags": ["bley_lindner"]}, "next": "close"},
					{"label": "\"Tidy for who?\"", "effects": {"kiez": 0.5, "flags": ["bley_lindner"]}, "next": "close"},
					{"label": "[Brains 14] What does page eleven actually give them?", "requires": {"stat": "int", "min": 14}, "effects": {"kiez": 1.0, "flags": ["bley_lindner"]}, "next": "clause"},
				],
			},
			"clause": {
				"speaker": "bley", "expression": "wary",
				"lines": ["The facility is conditional. Vacant possession on a fixed date, or the tranche is repriced — which means every week a tenant stays is a number on somebody's spreadsheet going the wrong way.", "\"…You understood that faster than my analyst.\" He looks at the shelf, the fridge, the hand-written prices. \"I would not repeat where you heard it.\""],
				"choices": [
					{"label": "\"I won't. What's the date?\"", "effects": {"kiez": 1.5, "flags": ["bley_tip", "main_lever_hint"]}, "next": "close"},
					{"label": "\"Write it down. Nothing with your name on it.\"", "effects": {"kiez": 2.0, "flags": ["bley_tip", "main_lever_hint"]}, "next": "close"},
					{"label": "\"You financed it. You can unfinance it.\"", "effects": {"kiez": 0.5, "integrity": 1.0, "flags": ["bley_tip"]}, "next": "close"},
				],
			},
			"close": {
				"speaker": "bley", "expression": "tired",
				"lines": ["He takes the water and leaves the chocolate. He leaves the chocolate most nights; you have started putting it out again.", "\"Same time tomorrow, then. Presumably you will still be open.\" It is, from him, an enormous sentence."],
				"choices": [
					{"label": "\"I'll be open.\"", "effects": {"kiez": 0.5}, "next": ""},
				],
			},
		},
	},
```

### 4.9 The three existing trees — two edits each at most, not a rewrite

`lena`, `juergen` and `mehmet` keep every node, every check and every flag they have. When the register
lands, each opening line becomes a **list order** so the till has something to scan:

| tree | node | new first line |
|---|---|---|
| `lena` | `hello` | `"Mate, ein Schrippe, und {brand.tobacco} mit {brand.papers}. …And I'm fifty cents short. Again."` |
| `juergen` | `crate` | append: `"Und einmal die {brand.cigarettes}. Die kleinen. If it reaches."` |
| `mehmet` | `letter` | prepend: `"Die {brand.cigarettes}, ein Mate, ein Wasser — und pack die Kippen unten hin, my wife has eyes like a Zollbeamter."` |

**The second edit (2026-09-13, the arc integration pass): Lena and Mehmet each gained one LOCKED
gate.** These three trees predate §4's "≥ 1 gate that is locked at day-one stats", and
`test_content.gd::test_every_new_tree_locks_at_least_one_door` was written over the *eight new* guests
only — so the rule never reached them. The moment the plain trees became **arc step 1** they owed the
same bar as the other seventy-four, and `test_arcs.gd` §12's cast-wide sweep is what found it (Jürgen
already had his legacy `[Muscle 12]`). Both new gates use the §0 minimum-locking number for their stat
and re-use a flag that already has a reader, so no `FLAG_READERS` row moved:

| tree | node | added choice |
|---|---|---|
| `lena` | `studio` (the hub every path crosses) | `[Schnauze 15] "Put it on the tab and go home, Lena."` → `kiez +1.5`, `lena_credit`, → `notice` |
| `mehmet` | `plan` (he will not be the first to make noise) | `[Brains 14] Write his Widerspruch in lawyer German.` → `kiez +1.5`, `mehmet_evidence`, → `rally` |

Mehmet's is the door his tree's own opening line asks for — *"My German is fine. Lawyer German is
another language."* — which is what a gate should be: the thing the scene already wanted.

### 4.10 The flag economy

- **Namespace:** `<character_id>_<event>` for strand-local, `kiez_*` for corner-wide, `main_*` for
  anything the 22-step arc reads. Lower snake, set-only, never cleared, stored in `story.flags`.
- **Budget:** 2–5 flags per guest per season. The trees above spend 2–5 each.
- **Every flag must have a declared reader** — a beat's `requires_flag`, an `epilogue` branch key, or a
  later-season tree's gate. A flag nobody reads is a lie in the save file.
- **And the declaration is now data, not prose.** The list below shipped as
  `StoryData.FLAG_READERS` (re-exported as `Content.FLAG_READERS`, one accessor
  `Content.flag_reader(flag)`), because a reader named only in a design document cannot fail a build.
  `test_flags.gd::test_every_flag_set_has_a_reader` accepts **three** reader kinds and requires
  exactly one of them per flag: **(1)** a real `requires_flag` gate, **(2)** an `Economy.FLAG_LABEL`
  entry (the Manage screen's corner-status panel prints it), **(3)** a `FLAG_READERS` row naming the
  beat that *will* consume it. Kind 3 is a promise with a deadline:
  `test_flags.gd::test_no_declared_reader_is_dead` fails the build the day a real gate or a
  `FLAG_LABEL` takes over and the row is not deleted, so the table cannot drift into fiction of its
  own. `bley_tip` was the first flag to graduate — `bley/b_patron.requires_flag` reads it for real —
  and five more followed it in the arc pass (below).
- **Declared readers:** the prose list that stood here named ~40 flags and is no longer the truth —
  the four content lanes added **~220 rows** to `StoryData.FLAG_READERS` between them, one per flag
  their trees write, each naming the step or the Finale that consumes it. **The table is the list.**
  Read it in `godot/engine/content/story.gd` or ask `Content.flag_reader(flag)`; do not maintain a
  second copy in prose, which is exactly how this one rotted. What is worth recording *here* is the
  rule the lanes kept converging on:
  **a flag has exactly one reader kind, and promoting it deletes the old row.** Five flags graduated
  from kind 3 to kind 1 in this pass — `bley_tip` (→ `bley/b_patron`), `bley_talks` (→ `bley/b_armour`),
  `tobias_fund_offered` (→ `tobias/t_six`), `aylin_jonas_two` (→ `aylinjonas/aj_sundays`) — and two
  went the other way, `schulz_listen` and `achim_listen` losing their declarations when
  `schulz/sc_corner` and `achim/a_elder` started gating on them for real.
  `test_flags.gd::test_no_declared_reader_is_dead` fails the build on either mistake.
- **`main_lever_hint`** is set by three independent routes — Bley's clause, Tobias's March date, Aylin's
  fence notice — and read once, at the main arc's step 17. The lever is reachable without any single
  guest, which is what keeps it a discovery rather than a required node.

---

## 5. The persona-card data shape

`characters.gd` stays one flat `Array[Dictionary]`. Every new key is **optional and read with
`.get(k, default)`**, so nothing existing breaks and the reducer never reads any of them — they are
display and authoring data.

```gdscript
	{"id": "achim", "name": "Achim", "portrait": "char/achim",
		"expressions": ["neutral"],                      # ONLY what is on disk — see §3
		"archetype_id": "insomniac", "colour": "#c2564a",
		"wants": {"tobacco": 3, "papers": 2, "beer": 2},  # legacy weighted spawn — keep it

		# ── persona card ────────────────────────────────────────────────────────────
		"age": 57, "job": "Sound engineer, ex-squatter", "strand_id": "achim",
		"story": "Came over in '84 to dodge the draft and stayed for the noise. Squatted the Vorderhaus on the next street for eleven years; the venues he ran the PA in are now a gym, a co-working space and a hole. Last of his crew still in the postcode.",
		"stake": "Your window is his noticeboard and your counter is his stage.",
		"arc_link": "When the fight comes he already knows how to run one: folding table, laminator, a PA in a cupboard, no shame. He is your campaign, badly dressed.",
		"voice": "Loud, funny, five clauses where one would do. Softens once, then covers it.",
		"quirk": "Corrects you on the filter gauge. Every time.",
		"signature_prop": "a fistful of flyers",           # in every expression (§3)
		"schedule": {"after_hour": 1, "days": "any"},      # DEFERRED: nothing reads this yet

		# ── what the register serves ────────────────────────────────────────────────
		"basket": [
			{"sku": "tobacco", "qty": 1, "brand": "zunder"},
			{"sku": "papers",  "qty": 1, "brand": "pap_feder_lang"},
			{"sku": "filters", "qty": 1, "brand": "fil_slim"},
			{"sku": "beer",    "qty": 1},
			{"sku": "lighter", "qty": 1},
		],
		"order_line": "Fifty of {brand.tobacco}, {brand.papers}, and {brand.filters}.",
		"pays": "exact coins", "pfand": "never returns", "tip": 0.0,

		# ── the seven steps, keyed by season, labelled with shippable beat ids ───────
		"arc": {
			"summer": ["Everything Good Gets Sold", "Can I Put This In Your Window"],
			"autumn": ["The Spätkauf Opens", "The Folding Table"],
			"winter": ["The Squat Becomes Lofts", "The Fight Is The Scene"],
			"spring": ["Elder Agitator"],
		},
	},
```

**SHIPPED, with three registry hooks.** All eleven rows are in `characters.gd`, persona keys and
all. Alongside them: `const EXPRESSIONS` (the frozen six of §3, re-exported as `Content.EXPRESSIONS`),
`Content.basket_for(character_id)` — the one call the register and `Talk.subs_for` both make, so the
want-list and the spoken line read the same rows — and `Content.FLAG_READERS` / `flag_reader()` from
§4.10. `expressions` lists **only what is on disk today**, which currently means `["neutral"]` for
eight of the eleven: `schulz`, `nadia`, `tobias` and `brandt` were *trimmed* from arrays that claimed
faces the art lane never drew. Promotion stays one array edit per delivered portrait.

**Three coordination rules.**

1. **`basket` is the single source of the order.** The register topic seeds `state.active.basket` from
   it rather than inventing a parallel table, and `Talk.subs_for` builds `{brand.*}` / `{qty.*}` /
   `{logo.*}` out of the same rows. `wants` stays for the weighted-spawn path; where both exist,
   `basket` wins — one line in StoryFlow, no engine surgery. **Both halves shipped:**
   `Rules._place_basket` reads the card's rows (`rules.gd:469`) and `Talk.subs_for` substitutes from
   what it placed (`talk.gd:87`).
   **And therefore ROW ORDER IS LOAD-BEARING.** `_place_basket` truncates to the reducer's caps —
   `BASKET_MAX_LINES 4`, `BASKET_MAX_UNITS 6`, `BASKET_MAX_PLACED 3` (`rules.gd:30`) — and also skips
   any SKU the shop has not unlocked yet. A dropped row takes its `{brand.*}` token with it, `_apply`
   leaves what it cannot match alone, and the box then PRINTS `{brand.filters}` into a sentence. Three
   cards carry five rows (Lena, Achim, Robin) and one is capped by placed units (Aylin), so every
   token-bearing line is written FIRST and the prose-only line is the one that gives. Robin's draft
   ordering shipped the bug and `test_tokens.gd::test_no_token_survives_to_the_screen` caught it by
   walking his whole tree through `Rules.view` — the authored table said the basket was fine; only the
   read-model knew it was not. Four rows per card is the safe number; five is a deliberate bet on
   ordering, and the register lane raising `BASKET_MAX_LINES` to 5 would retire it.
2. **`order_line` is the authored spoken order**, and it must use the same tokens as the tree's first
   node. It exists so the register's want-list and the dialogue's first line can never drift apart, and
   so a plain (no-tree) arrival still says a sentence a person would say.
3. **`stake` and `arc_link` are mandatory.** No guest gets written without a stated relationship to the
   Späti and to the developer pressure; `test_content.gd` fails the build on a card that omits either.

### How the UI shows a card — three steps, in cost order

Nothing new enters `view`. A persona card is **static content**, so the reader calls
`Content.character(id)` directly, exactly as `QueueStrip` already reads `colour`.

1. **Now, free — the QueueStrip subtitle.** `queue_strip.gd:80` already sets `%Name` from
   `view.queue[0].name`. Add one dim line under it from `Content.character(id).job`. **Constraint:**
   `Palette.QUEUE_RECT` is `132×84` and every font is 16px, so it is **job only, one line, elided** —
   "Sound engineer" fits; "57 · Sound engineer, ex-squatter" does not. Age belongs on the card, not on
   the strip. Zero new nodes, zero engine change.
2. **Cheap, later — the card behind Tab.** `night.gd:257` already toggles `%StatsStrip` on `KEY_TAB`.
   Make it a two-page toggle (`←`/`→`): page 1 the six stats, page 2 the card for whoever is at the
   counter, rendered in the existing `Modal` — portrait at `_neutral`, name / age / job, the `story`
   paragraph, `quirk`, the usual basket as `ItemSlot` icons, and **the current season's arc line only**.
   Future-season lines are a spoiler sitting in a data file; never render them.
3. **Only if it earns it — the Kiez page.** A grid of everyone you have met: one `neutral` bust per cell
   at native size, the name under it in their own `colour`; select one and the right half of the same
   `Modal` shows the card. `Modal` + `Portrait` + `ItemSlot` + `Palette` — every component already in
   `docs/04`, no new scene, keyboard-reachable because `Modal.open()` already traps focus.
   **Drive it off `story.met`**, the real array `storyflow.gd:227` appends to and `finale.gd` already
   walks. Note its shape: `met` holds `strand["character"]` — the **display name**, not an id — so the
   page walks `Content.STRANDS`, keeps those whose `character` is in `story.met`, and renders
   `Content.character(strand["character_id"])`. No invented `met_<id>` flags; that set does not exist in
   this engine.

---

## 6. Groundwork: now vs later

**Status, cast lane, this pass.** Shipped: items **1, 2 (minus the three one-off silhouettes), 4, 5,
6 and 7** — eleven persona rows, the eight trees plus the three one-line edits, the `bley` strand
(seven beats, three outcomes, twelve epilogue lines) and the `aylinjonas` two-field edit, `const
EXPRESSIONS`, `test_tokens.gd` / `test_flags.gd` / the cast half of `test_content.gd`, and `REGULARS`
in `test_dialogue.gd` widened from three ids to eleven. **Item 3 has since shipped too** —
`Talk.subs_for` builds the token map once per node and both `_apply` sites read it, so `{qty.*}` /
`{brand.*}` / `{logo.*}` resolve for real and `test_tokens.gd` + `test_arcs.gd` §12 assert that none
of them reaches the box unsubstituted, on any of the 77 trees. Still owed by other lanes: the three
one-off silhouettes and the archetype remap they gate (§3), and **item 8/9** (art wave 1 and the
QueueStrip job subtitle).

### Now — the things that are expensive to retrofit

1. **Eleven complete `characters.gd` rows**, persona-card keys and all, *including* the six whose
   portraits are still placeholders. Data first, art after: `portrait_asset` already falls back, so the
   cast can be **played tonight and drawn over three weeks**.
2. **Six new character entries** — `achim`, `karim`, `robin`, `aylin`, `bley` (and `brandt` kept as a
   non-guest) — plus re-specced `schulz` / `nadia` / `tobias` / `brandt` at 160×193 leaning. Five of the
   new ids already have a strand in `story.gd` and need nothing but the row; **`bley` needs a new
   strand** (7 beats + local outcome + four epilogue lines), and **`aylinjonas` needs its two-field
   edit** (`"character": "Aylin"`, `"character_id": "aylin"`).
3. **The token substitution in `Talk.node_of`** — `subs_for()` + `Content.brand_spoken()` +
   `Content.brand_logo()` + the nine-row brand table, applied at **both** replace sites (`talk.gd:63`
   and `:67`). Five lines of engine; every tobacco line in every future tree depends on it. The register
   topic must add the **`filters` SKU** in the same commit.
4. **The six expression ids frozen in one place** — a `const EXPRESSIONS` in `characters.gd` — with
   `test_scenes.gd` extended to fail if any tree names an expression outside it, or any character lists
   one with no `asset-spec.json` entry. Expression-id drift is the failure that ships silently.
5. **The eight new trees + three one-line edits in `dialogues.gd`.** `test_every_graph_is_playable`
   already iterates *all* of `Content.DIALOGUES`, so the new trees are covered the moment they land.
   Extend `REGULARS` in `test_dialogue.gd` from three ids to all eleven so the 5–8-node / ≥2-checks
   budget is enforced on the whole cast.
6. **Three new tests**, all of them the soft-lock rule (*never trust a name — assert against the
   read-model*) applied to data:
   - `test_tokens.gd` — every `{brand.<sku>}` / `{logo.<sku>}` / `{qty.<sku>}` token appearing in any
     line **or label** names a SKU that the speaker's `basket` contains, and a brand row that exists.
   - `test_flags.gd::test_every_flag_set_has_a_reader` — walk `DIALOGUES` + `STRANDS`, collect every
     `effects.flags` / `flags` entry, fail on any that no `requires_flag` or `epilogue` branch consumes.
   - `test_content.gd` — every character with a `strand_id` has `age`, `job`, `story`, `stake`,
     `arc_link`, `voice`, `basket`, `order_line` and a four-season `arc`; every `colour` is unique.
7. **`basket` populated for all eleven**, because the register topic needs eleven *real* baskets to
   design the scan / void / quantity flow against — not eleven invented ones. Nadia's has **no tobacco
   line** on purpose; that is a test case, not an omission.
8. **Art wave 1** (eleven `neutral` busts at 160×193 leaning) and **the three new one-off silhouettes**
   with the archetype remap (§3) — one leaning identity prompt per character, the signature prop written
   into the entry.
9. **The QueueStrip job subtitle** (§5 step 1). The cheapest possible proof that the cast reads as
   eleven distinct people.

### Later — designed for, deliberately not built

- **Expression waves 2–4** (55 of 66 portraits). The trees already name them and already degrade to
  `_neutral`. Ship `neutral` for all eleven first so no character is half-drawn next to a finished one.
- ~~**The seasonal tree swaps.**~~ **SHIPPED** (docs/06 §8). `Content.dialogue_id_for(character_id,
  state)` now prefers **`<char>_<season letter><step>`** — summer `s` · autumn `a` · winter `w` · spring
  `p`, the letter taken from the STEP's season — then the plain `<char>` tree, then `oneoff`. It is
  data-driven (`DIALOGUES.has(id)`), so a lane ships `karim_a3` and it is live with no engine edit. The
  plain trees above keep their ids and remain each guest's step 1, exactly as promised.
- ~~**The seven-step arcs as `story.gd` beats with season triggers.**~~ **SHIPPED — machinery *and*
  content (2026-09-13).** `story.strands[id]` carries `step` (1..7) and `season_seen`; a strand's
  current beat IS its current arc step; `StoryFlow` will not schedule a step before its season and
  never skips one (a missed season catches up one step per encounter). And the content landed behind
  it: **all eleven strands are seven beats deep**, one per Truby step, against the beat ids in §2, and
  **all 77 step trees are written** — the eleven plain trees (each guest's step 1) plus sixty-six
  `<char>_<letter><step>` trees. Four content lanes wrote them; `test_arcs.gd` §12 is the cast-wide
  sweep that holds every one of them to the same bar. See the status block at the top of §2.
- **`epilogue[main_ending][local_outcome]`** for `achim`, `karim`, `robin`, `aylin`, `bley` — eleven
  guests × four endings × ~three outcomes is a writing job, not an engineering one. The shape exists.
- **The persona-card overlay and the Kiez page** (§5 steps 2–3). The data ships now; the page is an
  afternoon whenever it is wanted.
- **`schedule`.** One unread key on every card until StoryFlow reads it. At a 24-hour counter, arrival
  time *is* characterisation — Nadia at 03:40, Bley at 03:10, Aylin only Sunday at 07:40 — and it costs
  nothing to record today and is expensive to retrofit into eleven hand-written cards later.
- **The `luxor` filterless stock-out as a real inventory event** rather than a line of dialogue. It wants the
  register's stock model first.
- **The rest of the bench:** `yusuf` first (the underage ID beat is the tobacco wall's moral hinge and
  the only owner of `sell_restricted`), then `schmidt`, then the two-person strands S12 and S14 once
  they get the staging decision Aylin got.
