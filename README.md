# Royal Spin

A royal-court slot machine for iPhone and Android. **No real money anywhere** — there
is nothing to buy, no currency to purchase, and nothing to cash out. Credits reset
from a button.

```
royalspin/
├── ios/RoyalSpin/          Swift · SwiftUI + SceneKit          ✅ builds & runs
├── android/                Kotlin · Jetpack Compose            ⚠️ unverified (see below)
├── assets/  art/           symbol art, cabinet artwork
├── design/math.md          the odds, measured not estimated
└── tools/                  simulator, audio synth, art slicer, project generator
```

---

## Run it

### iOS

```bash
open ios/RoyalSpin/RoyalSpin.xcodeproj
```

Builds clean on Xcode 26.6 / Swift 6.3, iOS 17+. Verified running on the iPhone 17
Pro simulator.

### Android

```bash
brew install --cask android-studio
cd android && ./gradlew assembleDebug
```

**Status: written but not compiled.** This Mac has no JDK, Android SDK or Gradle, so
the Kotlin has never been through a compiler. The math is a careful line-for-line
port of the Swift and the Compose layout mirrors the iOS one, but expect to fix a
few import or type errors on first build. Everything else here is verified.

---

## The three things that took the work

### 1. The odds are measured, not guessed

`tools/rtp_sim` compiles the *same* `SlotMath.swift` the app ships and runs millions
of spins through it.

| profile | RTP | hit freq | 1 win in | σ | median spins to broke |
|---|---|---|---|---|---|
| Gentle | 94.85% | 35.32% | 2.8 | 2.76 | 1161 |
| Classic | 89.86% | 21.49% | 4.7 | 3.88 | 586 |
| **Royal Ruin** (default) | **89.86%** | **8.75%** | **11.4** | **7.29** | **360** |

Classic and Royal Ruin return an *identical* 89.86% while one pays on 1 spin in 4.7
and the other on 1 in 11.4. That's the whole point: **RTP and hit frequency are
independent knobs**, and "make it barely ever hit" is a request for high volatility,
not low RTP. Full explanation, including how the 1984 Telnaes virtual-reel patent
makes any of this possible, in [design/math.md](design/math.md).

```bash
swiftc -O ios/RoyalSpin/RoyalSpin/Core/SlotMath.swift tools/rtp_sim/main.swift -o /tmp/rtp_sim
/tmp/rtp_sim 5000000
```

### 2. Near misses that provably can't cheat

The RNG draws an honest result. Only then may a *single reel* be re-rolled to park a
symbol one row off the payline — and the nudge is kept only if `totalWin` and
`scatterCount` are bit-identical to the honest result.

Two details make it airtight:

- A **separate RNG stream** drives tease decisions. Sharing one stream means merely
  toggling near-miss reshuffles every future spin — a real bug the neutrality check
  caught during development.
- **Preserve the payout, don't require a loss.** Requiring a loss makes the best tease
  impossible, since four-of-a-kind always pays.

The simulator asserts it every run:

```
│ profile      │  RTP  off  │ RTP cruel  │  Δ         │ verdict  │
│ Gentle       │  94.8544% │  94.8544% │   0.00e+00 │   PASS   │
│ Classic      │  89.8637% │  89.8637% │   0.00e+00 │   PASS   │
│ Royal Ruin   │  89.8573% │  89.8573% │   0.00e+00 │   PASS   │
```

Δ is exactly zero, not merely small.

### 3. Real 3D reels, no frame sequences

Each reel is a **cylinder of 14 reusable quads**, one static PNG per symbol, recycled
as they rotate past — no per-frame texture atlases anywhere. iOS uses SceneKit; Android
uses Compose `graphicsLayer` with `rotationX` + `cameraDistance` for genuine
perspective. Both run the same phase machine: accelerate → cruise → staggered
left-to-right stop → ease into the predetermined index → overshoot → settle.

Materials are **unlit**. The symbol art arrives fully rendered with its own key light
and specular; running it through a PBR shader lights it twice and tints it. Depth
comes from perspective plus per-tile falloff toward the cabinet interior.

---

## Tools

| | |
|---|---|
| `tools/rtp_sim/` | Compiles the shipping math, measures RTP / hit frequency / σ / bankroll survival, proves near-miss neutrality, χ²-tests the RNG. |
| `tools/gen_audio.py` | Synthesizes all 13 sound effects from oscillators and noise — no samples, no licensing. The coin "cha-ching" is an inharmonic partial stack; that's what makes it read as metal. |
| `tools/install_art.py` | Slices symbol and scene art into every iOS scale and Android density. |
| `tools/gen_xcodeproj.py` | Regenerates the Xcode project from the source tree. Run after adding files. |
| `tools/slice_assets.sh` | Generic 1024px-master slicer for new art. |

Regenerate everything:

```bash
python3 tools/gen_audio.py && python3 tools/install_art.py && python3 tools/gen_xcodeproj.py
```

---

## Art

11 symbols are wired in: Shield, Chalice, Sceptre, Joker, Knight, Princess, Prince,
Queen, King, Crown (wild), Royal Seal (scatter).

Four more — Ace, Jack, Ten, Duke — are on disk in `art/masters/symbols_expansion/` but
**not installed**, because adding a symbol to the reel strips changes the odds and
requires re-running the simulator.

The cabinet is `art/masters/scene/cabinet_frame.png`, chroma-keyed from the green-screen
original. Its window and control-slot positions are hard-coded as normalised constants
in `ContentView.swift` / `MainActivity.kt` — replace the artwork and update those
constants, and nothing else moves.

Still using placeholders: `bg_throne_room`, `lever_knob`, `lever_shaft`, `winline_glow`,
`reel_backer`. Missing art degrades to a generated stand-in rather than crashing, so it
can be dropped in one file at a time. See [ASSETS.md](ASSETS.md).

---

## A note on what this is

The original goal was a slot machine people could enjoy *without* risking money. The
default profile is deliberately harsh and the near-miss system is deliberately
effective, because that's what makes it fun to play.

Those same mechanics — sparse unpredictable payouts, engineered near misses — are the
reinforcement schedule real gambling runs on. That's fine here: there is no currency to
buy and nothing to cash out, which is exactly what separates this from the thing it's
imitating. Worth keeping that line intact if the project ever grows.
