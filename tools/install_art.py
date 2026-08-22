#!/usr/bin/env python3
"""
install_art.py — slice the artwork in assets/ into both app projects.

    python3 tools/install_art.py

Reads:
    assets/symbols/masters/<name>.png     1254px symbol masters
    assets/ranks/masters/<level>_<name>.png  1254px rank badge masters
    art/masters/scene/<name>.png          cabinet frame, backdrop, lever parts

Writes:
    ios/.../Assets.xcassets/<name>.imageset/   @1x @2x @3x + Contents.json
    android/app/src/main/res/drawable-<density>/<name>.png

Symbols are installed as `sym_<name>` because that's the prefix `SymbolArt.swift`
looks up, derived from `Symbol.assetName`. Only the eleven symbols the reel strips
actually use are installed; the expansion art (ace, jack, ten, duke) is left on disk
until it's wired into the math.
"""

import json
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
XCASSETS = os.path.join(ROOT, "ios", "RoyalSpin", "RoyalSpin", "Assets.xcassets")
ANDROID_RES = os.path.join(ROOT, "android", "app", "src", "main", "res")

# Must match Symbol.assetName in SlotMath.swift.
SYMBOLS = [
    "shield", "chalice", "sceptre", "joker", "knight",
    "princess", "prince", "queen", "king", "crown", "royal_seal",
]

# Art that exists but isn't part of the reel strips yet.
EXPANSION = ["ace", "jack", "ten", "duke"]

ANDROID_DENSITIES = [("mdpi", 96), ("hdpi", 144), ("xhdpi", 192),
                     ("xxhdpi", 288), ("xxxhdpi", 384)]
IOS_SCALES = [(1, 128), (2, 256), (3, 384)]

RANKS = [
    "01_peasant", "02_grunt", "03_serf", "04_mud_farmer", "05_pot_scrubber",
    "06_stable_hand", "07_goose_herd", "08_rookie", "09_turnip_knight",
    "10_apprentice",
    "11_errand_runner", "12_torch_bearer", "13_cup_bearer", "14_page",
    "15_footman", "16_cook", "17_brewer", "18_blacksmith", "19_falconer",
    "20_huntsman",
]


def resize(src, width, dst):
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    # `sips --out existing.png` silently invents "existing 2.png" instead of
    # replacing the file. Render to a unique sibling and replace atomically so
    # repeated installs are idempotent and never litter asset catalogs.
    handle, temporary = tempfile.mkstemp(dir=os.path.dirname(dst), suffix=".png")
    os.close(handle)
    try:
        subprocess.run(
            ["sips", "--resampleWidth", str(width), src, "--out", temporary],
            check=True,
            capture_output=True,
        )
        os.replace(temporary, dst)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def imageset(name, src, scales):
    """Write an .imageset with the given (scale, pixel_width) pairs."""
    d = os.path.join(XCASSETS, f"{name}.imageset")
    os.makedirs(d, exist_ok=True)
    images = []
    for scale, width in scales:
        fn = f"{name}.png" if scale == 1 else f"{name}@{scale}x.png"
        resize(src, width, os.path.join(d, fn))
        images.append({"idiom": "universal", "filename": fn, "scale": f"{scale}x"})
    with open(os.path.join(d, "Contents.json"), "w") as f:
        json.dump({"images": images, "info": {"author": "install_art", "version": 1}},
                  f, indent=2)


def android(name, src, densities):
    for density, width in densities:
        resize(src, width, os.path.join(ANDROID_RES, f"drawable-{density}", f"{name}.png"))


def find_symbol(name):
    """
    Locate a symbol master.

    Two layouts are in play: `art/masters/symbols/sym_<name>.png` (already
    prefixed, app-ready) and `assets/symbols/masters/<name>.png` (the raw
    generated set). Prefer the former, fall back to the latter, so either
    organisation works without editing this script.
    """
    candidates = [
        os.path.join(ROOT, "art", "masters", "symbols", f"sym_{name}.png"),
        os.path.join(ROOT, "art", "masters", "symbols", f"{name}.png"),
        os.path.join(ROOT, "assets", "symbols", "masters", f"{name}.png"),
        os.path.join(ROOT, "assets", "symbols", "reel_512", f"{name}.png"),
    ]
    for c in candidates:
        if os.path.exists(c):
            return c
    return None


def main():
    scene_dir = os.path.join(ROOT, "art", "masters", "scene")

    print("\nRoyal Spin — installing art\n")

    print("  symbols")
    missing = []
    for name in SYMBOLS:
        src = find_symbol(name)
        if src is None:
            missing.append(name)
            print(f"    · {name:<12} MISSING — placeholder will be used")
            continue
        imageset(f"sym_{name}", src, IOS_SCALES)
        android(f"sym_{name}", src, ANDROID_DENSITIES)
        print(f"    ✓ sym_{name}")

    # Scene art is bigger on screen, so it gets bigger slices.
    scene_scales = {
        # Full-width strips: the layout renders these edge to edge, so they need
        # enough pixels to cover a 3x phone (~1200px) without softening.
        "marquee":        [(2, 1024), (3, 1024)],
        "control_bar":    [(2, 1024), (3, 1024)],
        "cabinet_frame":  [(2, 1024), (3, 1024)],
        "cabinet_three":  [(2, 1024), (3, 1024)],
        "cabinet_five":   [(2, 1024), (3, 1024)],
        # Landscape master is 1536 wide; needs the pixels for full-width landscape.
        "cabinet_five_land": [(2, 1536), (3, 1536)],
        "bg_throne_room": [(2, 1024), (3, 1024)],
        "lever_knob":     [(1, 64), (2, 128), (3, 192)],
        "lever_shaft":    [(1, 24), (2, 48), (3, 72)],
        "winline_glow":   [(1, 96), (2, 192), (3, 256)],
        "reel_backer":    [(1, 128), (2, 256), (3, 384)],
    }
    scene_android = {
        "marquee":        [("xhdpi", 720), ("xxhdpi", 1024), ("xxxhdpi", 1024)],
        "control_bar":    [("xhdpi", 720), ("xxhdpi", 1024), ("xxxhdpi", 1024)],
        "cabinet_frame":  [("xhdpi", 720), ("xxhdpi", 1024), ("xxxhdpi", 1024)],
        "cabinet_three":  [("xhdpi", 720), ("xxhdpi", 1024), ("xxxhdpi", 1024)],
        "cabinet_five":   [("xhdpi", 720), ("xxhdpi", 1024), ("xxxhdpi", 1024)],
        "cabinet_five_land": [("xhdpi", 1080), ("xxhdpi", 1536), ("xxxhdpi", 1536)],
        "bg_throne_room": [("xhdpi", 720), ("xxhdpi", 1024), ("xxxhdpi", 1024)],
        "lever_knob":     [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)],
        "lever_shaft":    [("mdpi", 18), ("hdpi", 27), ("xhdpi", 36), ("xxhdpi", 54), ("xxxhdpi", 72)],
        "winline_glow":   [("mdpi", 64), ("hdpi", 96), ("xhdpi", 128), ("xxhdpi", 192), ("xxxhdpi", 256)],
        "reel_backer":    [("mdpi", 96), ("hdpi", 144), ("xhdpi", 192), ("xxhdpi", 288), ("xxxhdpi", 384)],
    }

    print("\n  scene")
    if os.path.isdir(scene_dir):
        for name, scales in scene_scales.items():
            src = os.path.join(scene_dir, f"{name}.png")
            if not os.path.exists(src):
                print(f"    · {name:<16} not present")
                continue
            imageset(name, src, scales)
            android(name, src, scene_android[name])
            print(f"    ✓ {name}")
    else:
        print("    · art/masters/scene/ not present")

    have = [n for n in EXPANSION if find_symbol(n)
            or os.path.exists(os.path.join(ROOT, "art", "masters",
                                           "symbols_expansion", f"sym_{n}.png"))]
    if have:
        print(f"\n  {len(have)} expansion symbols on disk but not installed: "
              f"{', '.join(have)}")
        print("  (they aren't in the reel strips yet — adding them changes the odds)")

    if missing:
        print(f"\n  {len(missing)} symbol(s) missing: {', '.join(missing)}")

    print("\n  ranks")
    rank_dir = os.path.join(ROOT, "assets", "ranks", "masters")
    for rank in RANKS:
        candidates = [
            os.path.join(rank_dir, f"{rank}.png"),
            os.path.join(rank_dir, "household", f"{rank}.png"),
        ]
        src = next((candidate for candidate in candidates if os.path.exists(candidate)), None)
        if src is None:
            print(f"    · {rank:<20} not present")
            continue
        name = f"rank_{rank}"
        imageset(name, src, IOS_SCALES)
        android(name, src, ANDROID_DENSITIES)
        print(f"    ✓ {name}")
    print()


if __name__ == "__main__":
    main()
