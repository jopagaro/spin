# Royal Spin symbol assets

## Folders

- `reel_512/` contains the 512 x 512 PNGs intended for the live reel carousel.
- `masters/` contains the original 1254 x 1254 generated PNGs for future exports.
- `manifest.json` maps stable symbol IDs to filenames. IDs 0 through 10 match `SlotMath.swift`.

The Joker replaces the former Jester without changing raw value `3`, reel frequency, or payout math. Ace, Jack, Ten, and Duke are expansion art and are not yet part of the mathematical reel strips.

## Reel animation

Use one static PNG per symbol. Build each reel as a reusable vertical list with at least one extra symbol above and below the visible three-row window, clip the list to the viewport, and animate its vertical offset. Recycle symbols that pass below the mask back to the top.

Recommended feel:

1. Accelerate for about 120–180 ms.
2. Scroll at constant speed while the result is prepared.
3. Stop reels left-to-right with roughly 100–160 ms stagger.
4. Decelerate over roughly 250–400 ms to the predetermined stop index.
5. Overshoot by 4–8% of one cell, then settle back in 80–140 ms.

The final result must come from the game math before the visual stop sequence begins. The animation only reveals that result. Motion blur should be a runtime effect on the moving reel container or a reusable translucent overlay; do not duplicate every symbol into frame-by-frame blur images.

Optional per-symbol texture frames are useful later for win celebrations or idle personality, but not for the basic spin itself. If added, keep every frame the same pixel dimensions and anchor point.
