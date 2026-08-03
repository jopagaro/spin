# Royal Spin — Art Asset Manifest

Everything the two apps load, with exact filenames. **Filenames are load-bearing** —
they're referenced from `SlotMath.swift` (`Symbol.assetName`) and the Kotlin port. Get
the name right and the asset drops in with zero code changes.

## The one rule that matters

**Author every symbol at 1024 × 1024 PNG, transparent background, RGBA.**

Hand me a folder of those and run:

```bash
./tools/slice_assets.sh ~/path/to/your/masters
```

That generates every iOS scale (@1x/@2x/@3x) and every Android density
(mdpi → xxxhdpi) into the right folders in both projects. You never make more than
one size by hand.

---

## 1. Symbols — 11 required

These are the reel faces. Drop them in `art/masters/symbols/`.

| Filename | Character | Tier | Notes |
|---|---|---|---|
| `sym_king.png` | **King** | High | Crowned, bearded, imposing. Top non-wild payer. |
| `sym_queen.png` | **Queen** | High | Regal, jeweled. Reads as clearly distinct from King at 80px. |
| `sym_prince.png` | **Prince** | Mid-high | Younger, lighter crown/circlet. |
| `sym_princess.png` | **Princess** | Mid-high | Tiara. Must not be confusable with Queen. |
| `sym_knight.png` | **Knight** | Mid | Helmed, visor. Steel/blue palette. |
| `sym_joker.png` | **Joker** | Mid | Traditional playing-card harlequin with a belled cap; playful, never villainous. |
| `sym_sceptre.png` | **Sceptre** | Low | Object, not a face. |
| `sym_chalice.png` | **Chalice** | Low | Object. Gold cup, gems. |
| `sym_shield.png` | **Shield** | Low | Object. Heraldic. |
| `sym_crown.png` | **Crown — WILD** | Wild | Substitutes for all but the Seal. Should look *special* — brightest, most gold, maybe a glow baked into the alpha. |
| `sym_royal_seal.png` | **Royal Seal — SCATTER** | Scatter | Wax seal / signet. Triggers free spins. Must be instantly recognizable as "the bonus one." |

### Design constraints (these come from how the 3D reel works)

1. **Square, centered, ~8% padding.** The symbol sits on a curved cylinder face.
   Anything touching the edge gets clipped when the face rotates away.
2. **Readable at 80 × 80 px.** That's roughly the on-screen size mid-spin on a small
   phone. Silhouette matters more than detail — squint-test each one.
3. **Distinct silhouettes.** King / Queen / Prince / Princess are four crowned humans;
   if their outlines are similar the grid becomes unreadable. Vary headwear shape,
   shoulder width, posture.
4. **No baked drop shadow.** The renderer lights and shadows the face in 3D. A painted
   shadow will fight the real one and look doubled.
5. **Consistent light direction: top-left.** Every symbol, same key light. This is the
   single biggest thing that makes a set look like one set.
6. **Tier legible by color temperature.** Low symbols cooler/duller (silver, bronze,
   muted), high symbols hotter/richer (gold, crimson, deep purple). Players learn
   value at a glance before they learn the paytable.

---

## 2. Cabinet & scene — 6 required

Drop in `art/masters/scene/`.

| Filename | Size | Purpose |
|---|---|---|
| `bg_throne_room.png` | 2048 × 2732 | Backdrop behind the machine. Portrait. Will be cropped on wide/short screens — keep the focus centered and the outer 12% expendable. |
| `cabinet_frame.png` | 1536 × 2048 | The machine bezel that overlays the reels. **Needs a transparent window** where the 5×3 grid shows through. |
| `reel_backer.png` | 512 × 1536 | Sits behind one reel column, under the symbols. Dark, subtly gradiented. Tiles vertically. |
| `lever_knob.png` | 256 × 256 | The ball on top of the pull lever. Sphere with a hot specular. |
| `lever_shaft.png` | 64 × 512 | Chrome/brass rod. Tiles vertically as the lever extends. |
| `winline_glow.png` | 256 × 256 | Soft radial glow, white/gold, additive-blended over winning symbols. Alpha only — color is tinted in code. |

---

## 3. UI — 7 required

Drop in `art/masters/ui/`.

| Filename | Size | Purpose |
|---|---|---|
| `btn_spin.png` | 512 × 512 | Round spin button, idle state. |
| `btn_spin_pressed.png` | 512 × 512 | Pressed state. Darker / inset. |
| `icon_coin.png` | 256 × 256 | Credit currency icon. |
| `icon_bet_up.png` | 128 × 128 | Chevron / plus, in a royal frame. |
| `icon_bet_down.png` | 128 × 128 | Mirror of above. |
| `banner_win.png` | 1024 × 512 | Ribbon behind the "BIG WIN" text. Text is rendered in code, not baked. |
| `banner_freespins.png` | 1024 × 512 | Same, for the free-spins award. |

---

## 4. App icon — 1 required

| Filename | Size | Purpose |
|---|---|---|
| `app_icon.png` | 1024 × 1024 | **No transparency, no rounded corners** — both stores reject those and apply their own mask. Full-bleed square. |

`slice_assets.sh` generates the full iOS `AppIcon.appiconset` and all Android
mipmap densities from this one file.

---

## Priority if you want to start small

You don't need all 25 to see the game run. In order:

1. **The 11 symbols** — without these there's nothing on the reels.
2. `bg_throne_room.png`, `cabinet_frame.png` — makes it look like a game.
3. Everything else — the code ships tinted placeholder shapes for these, so the app
   builds and plays with them missing.

Any asset that's absent falls back to a generated placeholder rather than crashing, so
you can drop them in one at a time and watch it fill out.
