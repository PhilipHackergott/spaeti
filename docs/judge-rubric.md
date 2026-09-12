# Judge rubric — how Codex scores a candidate against the concept art

The target is **a Berlin Späti version of Coffee Talk**, rendered as HD hand-drawn pixel art. Image 2 (the
protagonist "target state") defines the rendering bar; the Coffee Talk frames define framing, UI and palette.

Score each axis 0–100 (−1 = not applicable to this candidate):

- **composition** — Coffee Talk framing: fixed side-on counter view, character bust centred at the counter,
  the counter as a foreground band, a dense-but-readable "wall of cozy stuff" behind, dialogue box along the
  bottom, HUD tucked into corners. Depth via layered planes. Nothing cropped awkwardly, nothing floating.
- **palette_lighting** — warm amber interior pool vs. cool blue night outside; neon magenta/cyan accents;
  fridge glow; soft rim light on faces; overall contrast and mood match the references (bittersweet, cozy).
- **pixel_rendering** — ONE consistent pixel grid at the intended density (≈ 4 screen px per art px at
  1080p), crisp edges, cluster shading with 4–6 tones, deliberate dithering, clean outlines. Penalise hard:
  mixed pixel sizes, blur/anti-aliasing, smooth gradients, vector/3D/photo look, retro 8-bit blockiness,
  visible upscaling artefacts, noise.
- **character_fidelity** — for a character: does it match its design brief and the target-state rendering
  (proportions, face, hair, clothing, the signature prop); expression readable; consistent with the other
  cast members' style. For "You": is it the man in image 2.
- **ui_style** — dialogue box / panels / HUD look like Coffee Talk's: minimal dark translucent rounded boxes,
  coloured speaker name + white body text in a clean pixel font, small corner icons; legible at 1080p; no
  generic engine-default widgets (grey boxes, default fonts, drop-shadow buttons).
- **berlin_reskin** — reads as a Berlin Späti, not a café: glowing drinks fridges, generic stand-in
  products, Pfand crate, "SPÄTI" sign, U-Bahn/techno/football texture, stickers, rain on the glass.
  No real brands. No caricature.

**overall** is a holistic call: "would a Coffee Talk fan believe this is a screenshot from a sibling game?"
Roughly: 90+ = yes, ship; 80–89 = close, small fixes; 60–79 = clearly the right direction, specific gaps;
< 60 = wrong in a fundamental way (medium, framing, density).

Fixes must be concrete and locatable: *what* is wrong, *where* in the image, *how* to fix it (what to
generate/redraw/change in the scene). Prefer fixes that move the overall score the most.
