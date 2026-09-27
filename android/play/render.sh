#!/bin/zsh
# Regenerates the Play Store PNGs in this folder from their sources, with only macOS tools.
#
#   ./android/play/render.sh
#
# icon-512.png         <- OlaBall/Resources/Assets.xcassets/AppIcon.appiconset/icon.png (sips)
# feature-graphic.png  <- feature-graphic.svg (qlmanage), cropped and made opaque
#
# Quick Look lays an SVG out on a 750pt page and crops anything wider, then pads its thumbnail
# to a square with the content at the top left. So the SVG goes in with its root sized 750 wide
# (the viewBox keeps the 1024x500 geometry), and the 1024x500 top-left corner is cropped back out
# and stripped of the alpha channel Quick Look always writes (every pixel of it is opaque).
set -e
cd "$(dirname "$0")"
REPO="$(cd ../.. && pwd)"
TMP="$(mktemp -d)"

sips -z 512 512 "$REPO/OlaBall/Resources/Assets.xcassets/AppIcon.appiconset/icon.png" --out icon-512.png >/dev/null
# Play's app-icon slot asks for a 32-bit PNG; the art has no transparency, so the alpha is opaque.
python3 pngtool.py rgba icon-512.png icon-512.png
python3 pngtool.py info icon-512.png

sed '/<svg /s/width="1024" height="500"/width="750" height="366.211"/' feature-graphic.svg > "$TMP/feature-graphic.svg"
qlmanage -t -s 1024 -o "$TMP" "$TMP/feature-graphic.svg" >/dev/null 2>&1
python3 pngtool.py crop "$TMP/feature-graphic.svg.png" feature-graphic.png 0 0 1024 500
rm -rf "$TMP"
sips -g pixelWidth -g pixelHeight -g hasAlpha icon-512.png feature-graphic.png
