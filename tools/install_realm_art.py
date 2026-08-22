#!/usr/bin/env python3
"""Install optimized My Realm masters into the iOS asset catalog."""

import json
import os
import tempfile
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "realm" / "masters" / "peasantry"
CATALOG = ROOT / "ios" / "RoyalSpin" / "RoyalSpin" / "Assets.xcassets"

ASSETS = {
    "realm_base_mud": ("realm_base_mud.png", 1400),
    "realm_01_peasant_hut": ("realm_01_peasant_hut.png", 700),
    "realm_02_grunt_camp": ("realm_02_grunt_camp.png", 700),
    "realm_03_serf_garden": ("realm_03_serf_garden.png", 700),
    "realm_04_mud_farmer_furrows": ("realm_04_mud_farmer_furrows.png", 700),
    "realm_05_pot_scrubber_wash": ("realm_05_pot_scrubber_wash.png", 700),
    "realm_06_stable_hand_stable": ("realm_06_stable_hand_stable.png", 700),
    "realm_07_goose_herd_pond": ("realm_07_goose_herd_pond.png", 700),
    "realm_08_rookie_training": ("realm_08_rookie_training.png", 700),
    "realm_09_turnip_knight_guard": ("realm_09_turnip_knight_guard.png", 700),
    "realm_10_apprentice_cottage": ("realm_10_apprentice_cottage.png", 700),
}


def install(asset_name: str, source_name: str, max_edge: int) -> None:
    source = SOURCE / source_name
    target_dir = CATALOG / f"{asset_name}.imageset"
    target_dir.mkdir(parents=True, exist_ok=True)
    target_image = target_dir / f"{asset_name}.png"

    image = Image.open(source).convert("RGBA" if image_has_alpha(source) else "RGB")
    image.thumbnail((max_edge, max_edge), Image.Resampling.LANCZOS)
    handle, temporary_name = tempfile.mkstemp(suffix=".png", dir=target_dir)
    os.close(handle)
    temporary = Path(temporary_name)
    try:
        image.save(temporary, optimize=True)
        temporary.replace(target_image)
    finally:
        temporary.unlink(missing_ok=True)

    contents = {
        "images": [{"filename": target_image.name, "idiom": "universal", "scale": "1x"}],
        "info": {"author": "xcode", "version": 1},
    }
    (target_dir / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")


def image_has_alpha(path: Path) -> bool:
    with Image.open(path) as image:
        return image.mode in ("RGBA", "LA") or "transparency" in image.info


for name, (source, edge) in ASSETS.items():
    install(name, source, edge)
    print(name)
