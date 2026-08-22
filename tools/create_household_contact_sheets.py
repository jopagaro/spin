#!/usr/bin/env python3
"""Create the paired rank/Realm review sheets for ranks 11–20."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
RANK_SOURCE = ROOT / "assets" / "ranks" / "masters" / "household"
REALM_PEASANTRY = ROOT / "assets" / "realm" / "masters" / "peasantry"
REALM_HOUSEHOLD = ROOT / "assets" / "realm" / "masters" / "household"

TITLES = [
    "Errand Runner", "Torch Bearer", "Cup Bearer", "Page", "Footman",
    "Cook", "Brewer", "Blacksmith", "Falconer", "Huntsman",
]

RANK_FILES = [
    "11_errand_runner.png", "12_torch_bearer.png", "13_cup_bearer.png",
    "14_page.png", "15_footman.png", "16_cook.png", "17_brewer.png",
    "18_blacksmith.png", "19_falconer.png", "20_huntsman.png",
]

# asset path, normalized center x/y, normalized display width, replaced rank
UPGRADES = {
    1: (REALM_PEASANTRY / "realm_01_peasant_hut.png", .31, .66, .25, None),
    2: (REALM_PEASANTRY / "realm_02_grunt_camp.png", .51, .69, .21, None),
    3: (REALM_PEASANTRY / "realm_03_serf_garden.png", .20, .42, .24, None),
    4: (REALM_PEASANTRY / "realm_04_mud_farmer_furrows.png", .54, .32, .27, None),
    5: (REALM_PEASANTRY / "realm_05_pot_scrubber_wash.png", .39, .45, .19, None),
    6: (REALM_PEASANTRY / "realm_06_stable_hand_stable.png", .71, .28, .24, None),
    7: (REALM_PEASANTRY / "realm_07_goose_herd_pond.png", .73, .53, .27, None),
    8: (REALM_PEASANTRY / "realm_08_rookie_training.png", .53, .59, .19, None),
    9: (REALM_PEASANTRY / "realm_09_turnip_knight_guard.png", .79, .69, .20, None),
    10: (REALM_PEASANTRY / "realm_10_apprentice_cottage.png", .31, .64, .31, 1),
    11: (REALM_HOUSEHOLD / "realm_11_courier_post.png", .44, .18, .16, None),
    12: (REALM_HOUSEHOLD / "realm_12_torchlit_path.png", .49, .51, .22, None),
    13: (REALM_HOUSEHOLD / "realm_13_cupbearer_fountain.png", .49, .40, .16, None),
    14: (REALM_HOUSEHOLD / "realm_14_page_noticeboard.png", .14, .55, .16, None),
    15: (REALM_HOUSEHOLD / "realm_15_footman_gate.png", .50, .82, .25, None),
    16: (REALM_HOUSEHOLD / "realm_16_cookhouse.png", .14, .25, .23, None),
    17: (REALM_HOUSEHOLD / "realm_17_brewery.png", .84, .39, .23, None),
    18: (REALM_HOUSEHOLD / "realm_18_smithy.png", .65, .79, .23, None),
    19: (REALM_HOUSEHOLD / "realm_19_falcon_mews.png", .84, .18, .19, None),
    20: (REALM_HOUSEHOLD / "realm_20_hunting_lodge.png", .31, .62, .38, 10),
}

THUMB = 320
LABEL = 62
GAP = 24
COLUMNS = 5


def font(size: int, bold: bool = False):
    name = "Arial Bold.ttf" if bold else "Arial.ttf"
    for base in (Path("/System/Library/Fonts/Supplemental"), Path("/Library/Fonts")):
        path = base / name
        if path.exists():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()


def sheet(title: str, subtitle: str):
    width = GAP + COLUMNS * (THUMB + GAP)
    height = 118 + GAP + 2 * (THUMB + LABEL + GAP)
    canvas = Image.new("RGB", (width, height), "#10081f")
    draw = ImageDraw.Draw(canvas)
    draw.text((width // 2, 38), title, fill="#f4d77b", font=font(38, True), anchor="ma")
    draw.text((width // 2, 84), subtitle, fill="#c8b9db", font=font(22), anchor="ma")
    return canvas, draw


def tile_position(index: int):
    row, column = divmod(index, COLUMNS)
    return GAP + column * (THUMB + GAP), 118 + GAP + row * (THUMB + LABEL + GAP)


def draw_label(draw, x, y, rank, title):
    draw.rounded_rectangle((x, y + THUMB, x + THUMB, y + THUMB + LABEL),
                           radius=10, fill="#241637")
    draw.text((x + THUMB // 2, y + THUMB + LABEL // 2), f"{rank:02d}  {title}",
              fill="#ffffff", font=font(20, True), anchor="mm")


def create_rank_sheet():
    canvas, draw = sheet("ROYAL SPIN — RANKS 11–20",
                         "Each medallion is based only on its own class")
    mask = Image.new("L", (THUMB, THUMB), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, THUMB - 1, THUMB - 1), fill=255)
    for index, (filename, title) in enumerate(zip(RANK_FILES, TITLES)):
        x, y = tile_position(index)
        icon = Image.open(RANK_SOURCE / filename).convert("RGBA")
        icon.thumbnail((THUMB, THUMB), Image.Resampling.LANCZOS)
        centered = Image.new("RGBA", (THUMB, THUMB), "#090510")
        centered.alpha_composite(icon, ((THUMB - icon.width) // 2, (THUMB - icon.height) // 2))
        tile = Image.new("RGB", (THUMB, THUMB), "#090510")
        tile.paste(centered.convert("RGB"), (0, 0), mask)
        canvas.paste(tile, (x, y))
        draw_label(draw, x, y, index + 11, title)
    output = ROOT / "assets" / "ranks" / "rank_preview_11_20.png"
    canvas.save(output, optimize=True)
    print(output)


def resized(path: Path, width: int):
    image = Image.open(path).convert("RGBA")
    height = round(image.height * width / image.width)
    return image.resize((width, height), Image.Resampling.LANCZOS)


def realm_at(level: int):
    side = 1254
    realm = Image.open(REALM_PEASANTRY / "realm_base_mud.png").convert("RGBA")
    replaced = {UPGRADES[rank][4] for rank in range(1, level + 1) if UPGRADES[rank][4]}
    for rank in range(1, level + 1):
        if rank in replaced:
            continue
        path, cx, cy, normalized_width, _ = UPGRADES[rank]
        sprite = resized(path, round(side * normalized_width))
        x = round(side * cx - sprite.width / 2)
        y = round(side * cy - sprite.height / 2)
        realm.alpha_composite(sprite, (x, y))
    return realm


def create_realm_sheet():
    canvas, draw = sheet("MY REALM — HOUSEHOLD 11–20",
                         "Each rank adds one independently layered transparent asset")
    for index, title in enumerate(TITLES):
        rank = index + 11
        x, y = tile_position(index)
        realm = realm_at(rank)
        realm.thumbnail((THUMB, THUMB), Image.Resampling.LANCZOS)
        tile = Image.new("RGB", (THUMB, THUMB), "#090510")
        tile.paste(realm.convert("RGB"), ((THUMB - realm.width) // 2, 0))
        canvas.paste(tile, (x, y))
        draw_label(draw, x, y, rank, title)
    output = ROOT / "assets" / "realm" / "realm_preview_11_20.png"
    canvas.save(output, optimize=True)
    print(output)


create_rank_sheet()
create_realm_sheet()
