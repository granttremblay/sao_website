#!/bin/bash
# add_discovery_images.sh — optimize images for "Our Top Discoveries".
#
# Drop image(s) — any size, any format (jpg/png/heic/webp/tiff) — into
#   assets/images/discoveries/
# then run:
#   ./scripts/add_discovery_images.sh          # optimize in place
#   ./scripts/add_discovery_images.sh --push   # ...and commit + push to deploy
#
# Each image is center-cropped to 800x360 JPEG (quality auto-stepped to stay
# under ~500KB) — the same aspect used by assets/images/impact/*.jpg, since
# both the accordion header art and the discovery-row thumbnails share that
# convention (see .impact-acc-art / .discovery-row-art in assets/css/style_v5.css).
#
# "Our Top Discoveries" is now static HTML (index.html, inside #impact-accordion,
# the last .impact-item) — there's no DISCOVERIES JS array to stub anymore.
# After running this script, add or update the matching <li class="discovery-row">
# by hand with the new filename, title, blurb, and credit.
# Heavy originals stay on disk as gitignored masters.

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DISC="$REPO/assets/images/discoveries"
ORIG="$DISC/originals"

CW=800; CH=360
MAX_BYTES=512000
QUALITIES=(82 78 74 70 66)

mkdir -p "$DISC" "$ORIG"

# cover <source> <output.jpg> — center-crop to CWxCH, step quality to fit budget.
cover() {
  local src="$1" out="$2" q size sw sh tmp
  sw=$(sips -g pixelWidth "$src" | awk '/pixelWidth/{print $2}')
  sh=$(sips -g pixelHeight "$src" | awk '/pixelHeight/{print $2}')
  tmp=$(mktemp -t disc).png
  # Enlarge whichever dimension is short, then center-crop to exact size.
  if [ "$((sw*CH))" -ge "$((sh*CW))" ]; then
    sips --resampleHeight "$CH" "$src" --out "$tmp" >/dev/null
  else
    sips --resampleWidth "$CW" "$src" --out "$tmp" >/dev/null
  fi
  sips --cropToHeightWidth "$CH" "$CW" "$tmp" >/dev/null
  for q in "${QUALITIES[@]}"; do
    sips -s format jpeg -s formatOptions "$q" "$tmp" --out "$out" >/dev/null
    size=$(stat -f%z "$out")
    [ "$size" -le "$MAX_BYTES" ] && break
  done
  rm -f "$tmp"
  echo "$size"
}

shopt -s nullglob nocaseglob
count=0

# Pass 1: non-jpg masters -> optimized <name>.jpg.
for src in "$DISC"/*.{png,heic,webp,tif,tiff}; do
  base=$(basename "$src"); base=${base%.*}
  out="$DISC/$base.jpg"
  if [ -f "$out" ] && [ "$out" -nt "$src" ] && [ "$(stat -f%z "$out")" -le "$MAX_BYTES" ]; then continue; fi
  size=$(cover "$src" "$out")
  echo "  $(basename "$src") -> $base.jpg ($(echo "$size" | awk '{printf "%dKB", $1/1024}'))"
  count=$((count + 1))
done

# Pass 2: standalone jpgs (not a pass-1 output) that aren't already the right
# size -> crop in place, backing up the original first.
for src in "$DISC"/*.{jpg,jpeg}; do
  base=$(basename "$src"); base=${base%.*}
  for m in "$DISC/$base".{png,heic,webp,tif,tiff}; do [ -f "$m" ] && continue 2; done
  w=$(sips -g pixelWidth "$src" | awk '/pixelWidth/{print $2}')
  h=$(sips -g pixelHeight "$src" | awk '/pixelHeight/{print $2}')
  if [ "$w" != "$CW" ] || [ "$h" != "$CH" ]; then
    cp "$src" "$ORIG/$(basename "$src")"
    size=$(cover "$ORIG/$(basename "$src")" "$DISC/$base.jpg")
    echo "  $(basename "$src") cropped to ${CW}x${CH} ($(echo "$size" | awk '{printf "%dKB", $1/1024}'); original kept in originals/)"
    count=$((count + 1))
  fi
done
shopt -u nullglob nocaseglob

if [ "$count" -eq 0 ]; then
  echo "No new/changed images in $DISC."
else
  echo "Now add or update the matching <li class=\"discovery-row\"> in index.html by hand"
  echo "(title, blurb, credit) — see the existing rows in #impact-accordion for the pattern."
fi

if [ "${1:-}" = "--push" ]; then
  cd "$REPO"
  git add assets/images/discoveries
  git commit -m "Add SAO discovery image(s)"
  git push
  echo "Pushed — live in ~1 minute."
else
  echo "Review locally, then commit & push to deploy (or re-run with --push)."
fi
