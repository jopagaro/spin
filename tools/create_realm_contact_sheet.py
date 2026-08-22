from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "realm" / "masters" / "peasantry"
OUTPUT = ROOT / "assets" / "realm" / "realm_preview_01_10.png"

TITLES = [
    "Peasant", "Grunt", "Serf", "Mud Farmer", "Pot Scrubber",
    "Stable Hand", "Goose Herd", "Rookie", "Turnip Knight", "Apprentice",
]

# Placement is expressed in the 1,254-square master background coordinate system.
# Rank 10 replaces the first hut rather than adding a second home.
PLACEMENTS = {
    1: ("realm_01_peasant_hut.png", 235, 600, 310),
    2: ("realm_02_grunt_camp.png", 505, 690, 255),
    3: ("realm_03_serf_garden.png", 110, 360, 300),
    4: ("realm_04_mud_farmer_furrows.png", 510, 250, 330),
    5: ("realm_05_pot_scrubber_wash.png", 355, 410, 235),
    6: ("realm_06_stable_hand_stable.png", 720, 155, 300),
    7: ("realm_07_goose_herd_pond.png", 735, 475, 325),
    8: ("realm_08_rookie_training.png", 510, 555, 235),
    9: ("realm_09_turnip_knight_guard.png", 880, 650, 245),
    10: ("realm_10_apprentice_cottage.png", 205, 555, 390),
}

THUMB = 390
LABEL = 52
GAP = 18
COLUMNS = 5


def font(size: int, bold: bool = False):
    name = "Arial Bold.ttf" if bold else "Arial.ttf"
    for base in (Path("/System/Library/Fonts/Supplemental"), Path("/Library/Fonts")):
        path = base / name
        if path.exists():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()


def resized(path: Path, width: int) -> Image.Image:
    image = Image.open(path).convert("RGBA")
    height = round(image.height * width / image.width)
    return image.resize((width, height), Image.Resampling.LANCZOS)


def realm_at(level: int) -> Image.Image:
    realm = Image.open(SOURCE / "realm_base_mud.png").convert("RGBA")
    for rank in range(1, level + 1):
        if rank == 10:
            # Rebuild the background and replay ranks 2–9 before using the upgraded hut.
            realm = Image.open(SOURCE / "realm_base_mud.png").convert("RGBA")
            ranks = list(range(2, 10)) + [10]
            for replay_rank in ranks:
                name, x, y, width = PLACEMENTS[replay_rank]
                sprite = resized(SOURCE / name, width)
                realm.alpha_composite(sprite, (x, y))
            break
        name, x, y, width = PLACEMENTS[rank]
        sprite = resized(SOURCE / name, width)
        realm.alpha_composite(sprite, (x, y))
    return realm


canvas_width = GAP + COLUMNS * (THUMB + GAP)
canvas_height = 90 + GAP + 2 * (THUMB + LABEL + GAP)
canvas = Image.new("RGB", (canvas_width, canvas_height), "#10081f")
draw = ImageDraw.Draw(canvas)
draw.text((canvas_width // 2, 30), "MY REALM — PEASANTRY 1–10",
          fill="#f4d77b", font=font(34, True), anchor="ma")
draw.text((canvas_width // 2, 68), "One transparent unlock is added at each rank",
          fill="#c8b9db", font=font(20), anchor="ma")

for index, title in enumerate(TITLES, start=1):
    row, column = divmod(index - 1, COLUMNS)
    x = GAP + column * (THUMB + GAP)
    y = 90 + GAP + row * (THUMB + LABEL + GAP)
    realm = realm_at(index)
    realm.thumbnail((THUMB, THUMB), Image.Resampling.LANCZOS)
    tile = Image.new("RGB", (THUMB, THUMB), "#090510")
    tile.paste(realm.convert("RGB"), ((THUMB - realm.width) // 2, 0))
    canvas.paste(tile, (x, y))
    draw.rounded_rectangle((x, y + THUMB, x + THUMB, y + THUMB + LABEL),
                           radius=10, fill="#241637")
    draw.text((x + THUMB // 2, y + THUMB + LABEL // 2), f"{index:02d}  {title}",
              fill="#ffffff", font=font(19, True), anchor="mm")

OUTPUT.parent.mkdir(parents=True, exist_ok=True)
canvas.save(OUTPUT, optimize=True)
print(OUTPUT)
