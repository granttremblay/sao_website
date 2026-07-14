#!/bin/bash
# add_hero_images.sh — optimize hero backdrop images and refresh the manifest.
#
# Drop full-size image(s) — any size, any format (jpg/png/heic/webp/tiff) — into
#   assets/images/hero_images/originals/
# then run:
#   ./scripts/add_hero_images.sh          # optimize + update manifest
#   ./scripts/add_hero_images.sh --push   # ...and commit + push to deploy
#
# For each master in originals/ the script writes a web JPG to
#   assets/images/hero_images/<name>.jpg
# resized to at most MAX_WIDTH (never upscaled) at high quality, then
# regenerates the HERO_MANIFEST list in js/main.js, which the page reads to
# build the arrow-switchable hero backdrops.
#
# These backdrops are the site's showpiece, so quality is prioritized over
# file size: MAX_WIDTH is large and there is no ~500KB cap here (unlike other
# images). Existing per-image credit lines (and the optional tone: "light" flag
# for bright/snowy frames, and the optional focus: crop anchor) are preserved;
# brand-new images get a placeholder credit for you to edit in js/main.js.
#
# The originals/ masters are gitignored — only the optimized <name>.jpg ships.

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
HERO="$REPO/assets/images/hero_images"
ORIG="$HERO/originals"
MAINJS="$REPO/js/main.js"

MAX_WIDTH=3200   # crisp on large / retina displays
QUALITY=88       # visually lossless for photographic starfields
SOFT_CAP=2500000 # just a heads-up threshold (~2.5MB); not enforced

mkdir -p "$ORIG"

shopt -s nullglob nocaseglob
count=0
for src in "$ORIG"/*.{jpg,jpeg,png,heic,webp,tif,tiff}; do
  base=$(basename "$src"); base=${base%.*}
  out="$HERO/$base.jpg"

  # Skip if the shipping JPG is already newer than its master.
  if [ -f "$out" ] && [ "$out" -nt "$src" ]; then
    continue
  fi

  w=$(sips -g pixelWidth "$src" | awk '/pixelWidth/{print $2}')
  if [ -n "$w" ] && [ "$w" -gt "$MAX_WIDTH" ]; then
    sips -s format jpeg -s formatOptions "$QUALITY" --resampleWidth "$MAX_WIDTH" "$src" --out "$out" >/dev/null
  else
    sips -s format jpeg -s formatOptions "$QUALITY" "$src" --out "$out" >/dev/null
  fi

  size=$(stat -f%z "$out")
  echo "  $(basename "$src") -> $base.jpg ($(echo "$size" | awk '{printf "%.1fMB", $1/1048576}'))"
  [ "$size" -gt "$SOFT_CAP" ] && echo "    NOTE: large file — fine for a showpiece backdrop, but consider a narrower crop if load feels slow."
  count=$((count + 1))
done
shopt -u nullglob nocaseglob

if [ "$count" -eq 0 ]; then
  echo "No new masters to optimize in $ORIG (shipping JPGs are up to date)."
fi

# Always regenerate the manifest so removed images drop out and new ones appear.
python3 - "$MAINJS" "$HERO" "$ORIG" <<'EOF'
import re, sys, json, pathlib
mainjs, hero, orig = sys.argv[1], pathlib.Path(sys.argv[2]), pathlib.Path(sys.argv[3])

# Ship only JPGs that have a master in originals/ (so deleting a master retires it).
master_stems = {p.stem for p in orig.iterdir() if p.suffix.lower() in
                {".jpg", ".jpeg", ".png", ".heic", ".webp", ".tif", ".tiff"}}
present = sorted(p.name for p in hero.glob("*.jpg") if p.stem in master_stems)

src = open(mainjs).read()
m = re.search(r"const HERO_MANIFEST = \[(.*?)\];", src, flags=re.S)
assert m, "HERO_MANIFEST array not found in js/main.js"

# Preserve existing credits (keyed by filename) and the existing display order.
# Entries are { file, focus?, tone?, credit }; parse fields by key so the
# optional tone/focus survive a regen and field order doesn't matter. Any new
# optional field must be added here too, or a regen will silently drop it.
existing, order = {}, []
for obj in re.finditer(r'\{(.*?)\}', m.group(1), flags=re.S):
    body = obj.group(1)
    fm = re.search(r'file:\s*("(?:[^"\\]|\\.)*")', body)
    if not fm:
        continue
    f = json.loads(fm.group(1))
    cm = re.search(r'credit:\s*("(?:[^"\\]|\\.)*")', body)
    tm = re.search(r'tone:\s*("(?:[^"\\]|\\.)*")', body)
    xm = re.search(r'focus:\s*("(?:[^"\\]|\\.)*")', body)
    existing[f] = {"credit": json.loads(cm.group(1)) if cm else None,
                   "tone": json.loads(tm.group(1)) if tm else None,
                   "focus": json.loads(xm.group(1)) if xm else None}
    order.append(f)

PLACEHOLDER = "Placeholder credit — describe this image, then: Credit: [Name / Institution]."
ordered = [f for f in order if f in present] + [f for f in present if f not in order]

def entry(f):
    meta = existing.get(f, {})
    parts = [f"file: {json.dumps(f, ensure_ascii=False)}"]
    if meta.get("focus"):
        parts.append(f"focus: {json.dumps(meta['focus'], ensure_ascii=False)}")
    if meta.get("tone"):
        parts.append(f"tone: {json.dumps(meta['tone'], ensure_ascii=False)}")
    parts.append(f"credit: {json.dumps(meta.get('credit') or PLACEHOLDER, ensure_ascii=False)}")
    return "    { " + ", ".join(parts) + " }"

lines = ",\n".join(entry(f) for f in ordered)
out = f"const HERO_MANIFEST = [\n{lines}\n  ];"
open(mainjs, "w").write(src[:m.start()] + out + src[m.end():])
print(f"Updated HERO_MANIFEST: {len(ordered)} image(s)")
new = [f for f in present if f not in order]
if new:
    print("  New (edit their placeholder credit in js/main.js): " + ", ".join(new))
EOF

node --check "$MAINJS" && echo "js/main.js syntax OK"

if [ "${1:-}" = "--push" ]; then
  cd "$REPO"
  git add assets/images/hero_images js/main.js
  git commit -m "Update hero backdrop images"
  git push
  echo "Pushed — live in ~1 minute."
else
  echo "Review locally, then commit & push to deploy (or re-run with --push)."
fi
