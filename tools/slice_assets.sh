#!/usr/bin/env bash
#
# slice_assets.sh — turn 1024px master PNGs into every size both platforms need.
#
#   ./tools/slice_assets.sh art/masters
#
# Expects the layout described in ASSETS.md:
#   <masters>/symbols/sym_*.png
#   <masters>/scene/*.png
#   <masters>/ui/*.png
#   <masters>/app_icon.png
#
# Uses `sips`, which ships with macOS — nothing to install.
#
# Safe to re-run: it overwrites its own output and touches nothing else. Re-run it
# every time you revise a master.

set -euo pipefail

MASTERS="${1:-art/masters}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

IOS_ASSETS="$ROOT/ios/RoyalSpin/RoyalSpin/Assets.xcassets"
AND_RES="$ROOT/android/app/src/main/res"

if [[ ! -d "$MASTERS" ]]; then
  echo "error: masters directory not found: $MASTERS" >&2
  echo "       see ASSETS.md for the expected layout" >&2
  exit 1
fi

# Density ladder. iOS @1x is 1/4 of the master, which makes @3x = 768px and lines
# the whole thing up exactly with Android's mdpi→xxxhdpi steps.
IOS_SCALES=("1:0.25" "2:0.50" "3:0.75")
AND_DENSITIES=("mdpi:0.25" "hdpi:0.375" "xhdpi:0.50" "xxhdpi:0.75" "xxxhdpi:1.0")

made=0
skipped=0

# Resample $1 to $3 at $2 × its original width.
resize() {
  local src="$1" factor="$2" dst="$3"
  local w
  w=$(sips -g pixelWidth "$src" | awk '/pixelWidth/{print $2}')
  local out
  out=$(python3 -c "print(max(1, round($w * $factor)))")
  mkdir -p "$(dirname "$dst")"
  sips --resampleWidth "$out" "$src" --out "$dst" >/dev/null 2>&1
}

# Build an .imageset (iOS) and the five drawable densities (Android) for one master.
slice() {
  local src="$1"
  local name
  name="$(basename "$src" .png)"

  # ---- iOS: <name>.imageset with @1x/@2x/@3x + Contents.json ----
  local set_dir="$IOS_ASSETS/$name.imageset"
  mkdir -p "$set_dir"
  for entry in "${IOS_SCALES[@]}"; do
    local scale="${entry%%:*}" factor="${entry##*:}"
    local file="${name}@${scale}x.png"
    [[ "$scale" == "1" ]] && file="${name}.png"
    resize "$src" "$factor" "$set_dir/$file"
  done
  python3 - "$set_dir" "$name" <<'PY'
import json, sys, os
d, name = sys.argv[1], sys.argv[2]
imgs = []
for scale, suffix in ((1, ""), (2, "@2x"), (3, "@3x")):
    f = f"{name}{suffix}.png"
    if os.path.exists(os.path.join(d, f)):
        imgs.append({"idiom": "universal", "filename": f, "scale": f"{scale}x"})
json.dump({"images": imgs, "info": {"author": "royalspin-slice", "version": 1}},
          open(os.path.join(d, "Contents.json"), "w"), indent=2)
PY

  # ---- Android: res/drawable-<density>/<name>.png ----
  for entry in "${AND_DENSITIES[@]}"; do
    local density="${entry%%:*}" factor="${entry##*:}"
    resize "$src" "$factor" "$AND_RES/drawable-$density/$name.png"
  done

  made=$((made + 1))
  printf "  ✓ %-24s → 3 iOS scales, 5 Android densities\n" "$name"
}

echo ""
echo "Royal Spin — asset slicer"
echo "  masters: $MASTERS"
echo ""

for group in symbols scene ui; do
  if [[ ! -d "$MASTERS/$group" ]]; then
    echo "  · $group/ not present yet — skipping"
    skipped=$((skipped + 1))
    continue
  fi
  echo "  $group/"
  shopt -s nullglob
  for f in "$MASTERS/$group"/*.png; do slice "$f"; done
  shopt -u nullglob
done

# ---- App icon ----
ICON="$MASTERS/app_icon.png"
if [[ -f "$ICON" ]]; then
  echo ""
  echo "  app icon"
  # Xcode 14+ accepts a single 1024 icon for the whole set.
  ICON_SET="$IOS_ASSETS/AppIcon.appiconset"
  mkdir -p "$ICON_SET"
  sips --resampleWidth 1024 "$ICON" --out "$ICON_SET/app_icon_1024.png" >/dev/null 2>&1
  cat > "$ICON_SET/Contents.json" <<'JSON'
{
  "images" : [
    { "filename" : "app_icon_1024.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" }
  ],
  "info" : { "author" : "royalspin-slice", "version" : 1 }
}
JSON
  echo "  ✓ iOS AppIcon.appiconset"

  for entry in "mdpi:48" "hdpi:72" "xhdpi:96" "xxhdpi:144" "xxxhdpi:192"; do
    d="${entry%%:*}"; px="${entry##*:}"
    mkdir -p "$AND_RES/mipmap-$d"
    sips --resampleWidth "$px" "$ICON" --out "$AND_RES/mipmap-$d/ic_launcher.png" >/dev/null 2>&1
    sips --resampleWidth "$px" "$ICON" --out "$AND_RES/mipmap-$d/ic_launcher_round.png" >/dev/null 2>&1
  done
  echo "  ✓ Android mipmaps (48→192)"
else
  echo ""
  echo "  · app_icon.png not present yet — skipping"
fi

echo ""
echo "Done. $made asset(s) sliced."
[[ $skipped -gt 0 ]] && echo "($skipped group(s) not present — that's fine, add them when ready.)"
echo ""
