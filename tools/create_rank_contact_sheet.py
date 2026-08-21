from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "ranks" / "masters"
OUTPUT = ROOT / "assets" / "ranks" / "rank_preview_01_10.png"

TITLES = [
    "Peasant",
    "Grunt",
    "Serf",
    "Mud Farmer",
    "Pot Scrubber",
    "Stable Hand",
    "Goose Herd",
    "Rookie",
    "Turnip Knight",
    "Apprentice",
]

THUMBNAIL = 320
LABEL_HEIGHT = 62
GAP = 24
COLUMNS = 5
ROWS = 2


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    name = "Arial Bold.ttf" if bold else "Arial.ttf"
    paths = [
        Path("/System/Library/Fonts/Supplemental") / name,
        Path("/Library/Fonts") / name,
    ]
    for path in paths:
        if path.exists():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()


canvas_width = GAP + COLUMNS * (THUMBNAIL + GAP)
canvas_height = 118 + GAP + ROWS * (THUMBNAIL + LABEL_HEIGHT + GAP)
canvas = Image.new("RGB", (canvas_width, canvas_height), "#10081f")
draw = ImageDraw.Draw(canvas)

heading = "ROYAL SPIN — RANKS 1–10"
draw.text((canvas_width // 2, 38), heading, fill="#f4d77b", font=font(38, True), anchor="ma")
draw.text(
    (canvas_width // 2, 84),
    "Each character is based only on its own rank name",
    fill="#c8b9db",
    font=font(22),
    anchor="ma",
)

for index, (path, title) in enumerate(zip(sorted(SOURCE.glob("*.png")), TITLES), start=1):
    row, column = divmod(index - 1, COLUMNS)
    x = GAP + column * (THUMBNAIL + GAP)
    y = 118 + GAP + row * (THUMBNAIL + LABEL_HEIGHT + GAP)

    icon = Image.open(path).convert("RGBA")
    icon.thumbnail((THUMBNAIL, THUMBNAIL), Image.Resampling.LANCZOS)
    tile = Image.new("RGBA", (THUMBNAIL, THUMBNAIL), "#090510")
    tile.alpha_composite(icon, ((THUMBNAIL - icon.width) // 2, (THUMBNAIL - icon.height) // 2))
    canvas.paste(tile.convert("RGB"), (x, y))

    draw.rounded_rectangle(
        (x, y + THUMBNAIL, x + THUMBNAIL, y + THUMBNAIL + LABEL_HEIGHT),
        radius=10,
        fill="#241637",
    )
    draw.text(
        (x + THUMBNAIL // 2, y + THUMBNAIL + LABEL_HEIGHT // 2),
        f"{index:02d}  {title}",
        fill="#ffffff",
        font=font(21, True),
        anchor="mm",
    )

OUTPUT.parent.mkdir(parents=True, exist_ok=True)
canvas.save(OUTPUT, optimize=True)
print(OUTPUT)
