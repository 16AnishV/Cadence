#!/usr/bin/env bash
# Build Cadence.icns from Cadence/Resources/AppIcon.svg.
# Output: Cadence/Resources/AppIcon.icns
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="$ROOT/Cadence/Resources/AppIcon.svg"
OUT="$ROOT/Cadence/Resources/AppIcon.icns"

if [[ ! -f "$SRC" ]]; then
  echo "Source SVG not found: $SRC" >&2
  exit 1
fi

WORK="$(mktemp -d)"
ICONSET="$WORK/AppIcon.iconset"
mkdir -p "$ICONSET"

# Render the SVG once at the largest size we need (1024) and downscale via sips.
RENDER_DIR="$WORK/render"
mkdir -p "$RENDER_DIR"
qlmanage -t -s 1024 -o "$RENDER_DIR" "$SRC" >/dev/null
BIG="$RENDER_DIR/AppIcon.svg.png"

if [[ ! -f "$BIG" ]]; then
  echo "qlmanage failed to produce a PNG from $SRC" >&2
  exit 1
fi

# Required iconset sizes: 16, 32, 64, 128, 256, 512, 1024 (each at 1x and 2x).
declare -a SIZES=(
  "16:icon_16x16.png"
  "32:icon_16x16@2x.png"
  "32:icon_32x32.png"
  "64:icon_32x32@2x.png"
  "128:icon_128x128.png"
  "256:icon_128x128@2x.png"
  "256:icon_256x256.png"
  "512:icon_256x256@2x.png"
  "512:icon_512x512.png"
  "1024:icon_512x512@2x.png"
)

for entry in "${SIZES[@]}"; do
  size="${entry%%:*}"
  name="${entry##*:}"
  cp "$BIG" "$ICONSET/$name"
  sips -z "$size" "$size" "$ICONSET/$name" >/dev/null
done

iconutil -c icns "$ICONSET" -o "$OUT"
echo "==> wrote $OUT"
