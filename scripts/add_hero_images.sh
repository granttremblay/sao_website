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

# Keep every existing entry's EXACT source text. We deliberately do NOT rebuild
# entries out of parsed fields: that older approach re-emitted each { file,
# focus?, tone?, credit } from individual regexes, so any field the regex failed
# to read was silently swapped for a placeholder (`credit or PLACEHOLDER`), and
# an entry whose file: didn't parse was dropped from `order` entirely and then
# re-added as "new" — i.e. hand-written credits could vanish with no warning.
# Now the only thing read from an entry is its file:, purely to identify it;
# everything you write inside an entry (credit, tone, focus, spacing, a comment,
# any field added later) survives byte-for-byte because it is never rewritten.
entries, order, unreadable = {}, [], []
for obj in re.finditer(r'\{[^{}]*\}', m.group(1), flags=re.S):
    raw = obj.group(0)
    fm = re.search(r'file:\s*("(?:[^"\\]|\\.)*")', raw)
    if not fm:
        unreadable.append(" ".join(raw.split())[:110])
        continue
    entries[json.loads(fm.group(1))] = raw.strip()
    order.append(json.loads(fm.group(1)))

# Never silently skip an entry we can't identify — that's exactly how a credit
# used to get replaced by a placeholder. Stop and let a human look.
if unreadable:
    sys.exit("Refusing to touch HERO_MANIFEST: could not read a file: key from "
             f"{len(unreadable)} entry/entries, e.g.\n    {unreadable[0]}\n"
             "Give it a plain file: \"name.jpg\" and re-run. (Rewriting now would "
             "replace that entry's credit with a placeholder.)")

PLACEHOLDER = "Placeholder credit — describe this image, then: Credit: [Name / Institution]."
PIN_FIRST = "milkyway_backdrop.jpg"  # always the opening frame; see README

kept    = [f for f in order if f in present]
new     = [f for f in present if f not in order]
retired = [f for f in order if f not in present]
ordered = kept + new
if PIN_FIRST in ordered:
    ordered.insert(0, ordered.pop(ordered.index(PIN_FIRST)))

def entry(f):
    if f in entries:
        return "    " + entries[f]  # verbatim — your text, untouched
    return ("    { file: %s, credit: %s }"
            % (json.dumps(f, ensure_ascii=False), json.dumps(PLACEHOLDER, ensure_ascii=False)))

lines = ",\n".join(entry(f) for f in ordered)
out = f"const HERO_MANIFEST = [\n{lines}\n  ];"
open(mainjs, "w").write(src[:m.start()] + out + src[m.end():])

print(f"Updated HERO_MANIFEST: {len(ordered)} image(s)")
if PIN_FIRST in ordered:
    print(f"  Pinned first: {PIN_FIRST}")
if new:
    print("  New (edit their placeholder credit in js/main.js): " + ", ".join(new))
# A master that is renamed rather than deleted looks exactly like "old one
# retired + new one added", so echo the credit we're dropping — otherwise the
# prose is gone and the terminal is the only place it still exists.
if retired:
    print(f"  Retired {len(retired)} image(s) (no master left in originals/):")
    for f in retired:
        cm = re.search(r'credit:\s*("(?:[^"\\]|\\.)*")', entries[f])
        print(f"    - {f}")
        if cm:
            print(f"        its credit was: {json.loads(cm.group(1))}")
    print("      If you meant to RENAME one, paste that credit onto the new entry.")
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
