#!/bin/bash
# add_mosaic_images.sh — turn raw images into rotating-mosaic tiles.
#
# Drop any images (jpg/png/heic/webp/tiff, any size, any filename) into
#   assets/images/mosaic_sources/
# then run:
#   ./scripts/add_mosaic_images.sh          # process + update manifest
#   ./scripts/add_mosaic_images.sh --push   # ...and commit + push to deploy
#
# Each image is center-cropped to a 600x600 JPEG (~50-100KB), named
# mosaic_NN.jpg continuing from the highest existing number, and the
# MOSAIC_MANIFEST list in assets/js/main_v4.js is regenerated to match the mosaic
# folder. Processed sources are moved to mosaic_sources/processed/ so
# re-running only picks up new files.

set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
SOURCES="$REPO/assets/images/mosaic_sources"
MOSAIC="$REPO/assets/images/mosaic"
DONE="$SOURCES/processed"
MAINJS="$REPO/assets/js/main_v4.js"

mkdir -p "$SOURCES" "$MOSAIC" "$DONE"

# Next tile number = highest existing mosaic_NN + 1
next=$(ls "$MOSAIC" 2>/dev/null | sed -n 's/^mosaic_\([0-9]*\)\.jpg$/\1/p' | sort -n | tail -1)
next=$((10#${next:-0} + 1))

shopt -s nullglob nocaseglob
count=0
dupes=0
for src in "$SOURCES"/*.{jpg,jpeg,png,heic,webp,tif,tiff}; do
  out=$(printf 'mosaic_%02d.jpg' "$next")
  w=$(sips -g pixelWidth "$src" | awk '/pixelWidth/{print $2}')
  h=$(sips -g pixelHeight "$src" | awk '/pixelHeight/{print $2}')
  if [ -z "$w" ] || [ -z "$h" ]; then
    echo "SKIP (could not read): $(basename "$src")" >&2
    continue
  fi
  tmp=$(mktemp -t mosaic).png
  # Resize the short side to 600, then center-crop to a square
  if [ "$w" -lt "$h" ]; then
    sips --resampleWidth 600 "$src" --out "$tmp" >/dev/null
  else
    sips --resampleHeight 600 "$src" --out "$tmp" >/dev/null
  fi
  sips --cropToHeightWidth 600 600 "$tmp" >/dev/null
  sips -s format jpeg -s formatOptions 72 "$tmp" --out "$MOSAIC/$out" >/dev/null
  rm -f "$tmp"

  # Reject images that already exist in the roster under another name
  # (perceptual average-hash; the no-repeats rotation can only dedupe filenames).
  dupe=$(python3 - "$MOSAIC/$out" "$MOSAIC" <<'PYEOF'
import sys, pathlib
try:
    from PIL import Image
except ImportError:
    sys.exit(0)  # Pillow unavailable: skip dedupe rather than fail
def ahash(p, size=16):
    px = list(Image.open(p).convert("L").resize((size, size)).getdata())
    avg = sum(px) / len(px)
    return [v > avg for v in px]
new = pathlib.Path(sys.argv[1])
h = ahash(new)
for other in pathlib.Path(sys.argv[2]).glob("*.jpg"):
    if other.name == new.name:
        continue
    if sum(a != b for a, b in zip(h, ahash(other))) <= 12:
        print(other.name)
        break
PYEOF
)
  if [ -n "$dupe" ]; then
    rm -f "$MOSAIC/$out"
    mv "$src" "$DONE/"
    echo "  DUPLICATE: $(basename "$src") matches existing $dupe — skipped"
    dupes=$((dupes + 1))
    continue
  fi

  mv "$src" "$DONE/"
  echo "  $(basename "$src") -> $out ($(du -h "$MOSAIC/$out" | cut -f1 | tr -d ' '))"
  next=$((next + 1))
  count=$((count + 1))
done
shopt -u nullglob nocaseglob

if [ "$count" -eq 0 ]; then
  if [ "$dupes" -gt 0 ]; then
    echo "No new tiles added ($dupes duplicate(s) skipped)."
  else
    echo "No new images found in $SOURCES"
  fi
  exit 0
fi

# Regenerate MOSAIC_MANIFEST in assets/js/main_v4.js from the mosaic folder contents
python3 - "$MAINJS" "$MOSAIC" <<'EOF'
import re, sys, pathlib
mainjs, mosaic = sys.argv[1], pathlib.Path(sys.argv[2])
files = sorted(p.name for p in mosaic.glob("*.jpg"))
entries = ",\n".join(f'    "{f}"' for f in files)
src = open(mainjs).read()
new, n = re.subn(
    r"const MOSAIC_MANIFEST = \[.*?\];",
    f"const MOSAIC_MANIFEST = [\n{entries}\n  ];",
    src, flags=re.S)
assert n == 1, "MOSAIC_MANIFEST array not found in assets/js/main_v4.js"
open(mainjs, "w").write(new)
print(f"Updated MOSAIC_MANIFEST: {len(files)} tiles")
EOF

node --check "$MAINJS" && echo "assets/js/main_v4.js syntax OK"

echo "Done: $count new tile(s)."

if [ "${1:-}" = "--push" ]; then
  cd "$REPO"
  git add assets/images/mosaic assets/js/main_v4.js
  git commit -m "Add $count new mosaic tile(s)"
  git push
  echo "Pushed — live in ~1 minute."
else
  echo "Review locally, then commit & push to deploy (or re-run with --push)."
fi
