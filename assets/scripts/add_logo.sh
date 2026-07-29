#!/bin/bash
# add_logo.sh — optimize partner/mission logos and wire up their --logo-h knob.
#
# Drop full-size logo master(s) — png/jpg/svg/webp/tif — into
#   assets/logos/originals/
# then run:
#   ./scripts/add_logo.sh          # optimize + add the CSS knob + print snippets
#   ./scripts/add_logo.sh --push   # ...and commit + push to deploy
#
# For each master this:
#   1. writes a shipping file to assets/logos/<name>.<ext> — rasters resampled
#      to at most MAX_HEIGHT tall (never upscaled); SVGs copied through as-is,
#      since they're vector and resampling them is meaningless.
#   2. ensures `.impact-logo-<name> { --logo-h: Npx; }` exists in assets/css/style_v5.css,
#      NEVER clobbering a height you've already tuned by hand.
#   3. prints paste-ready HTML for both placements, with the width/height
#      attributes computed from the real file so the aspect ratio is correct.
#
# It also reports how much of each raster is transparent padding. That number is
# why two logos at the same --logo-h can look wildly different sizes: --logo-h
# sets the box, and padding decides how much of the box is actual ink.
#
# The originals/ masters are gitignored — only the optimized file ships.

set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
LOGOS="$REPO/assets/logos"
ORIG="$LOGOS/originals"
CSS="$REPO/assets/css/style_v5.css"

MAX_HEIGHT=320       # plenty for a ~26-60px render on a 2x display
DEFAULT_LOGO_H=32    # starting knob value for a brand-new logo; tune by eye

mkdir -p "$ORIG"

shopt -s nullglob nocaseglob
masters=("$ORIG"/*.{png,jpg,jpeg,svg,webp,tif,tiff})
shopt -u nullglob nocaseglob

if [ ${#masters[@]} -eq 0 ]; then
  echo "No logo masters found in $ORIG"
  echo "Drop your full-size logo file(s) there and re-run."
  exit 0
fi

echo "Optimizing logos:"
shipped=()
for src in "${masters[@]}"; do
  file=$(basename "$src")
  base="${file%.*}"
  ext="${file##*.}"
  ext_lc=$(echo "$ext" | tr '[:upper:]' '[:lower:]')

  if [ "$ext_lc" = "svg" ]; then
    out="$LOGOS/$base.svg"
    if [ ! -f "$out" ] || [ "$src" -nt "$out" ]; then
      cp "$src" "$out"
      echo "  $file -> $base.svg (vector, copied as-is)"
    fi
  else
    out="$LOGOS/$base.png"
    if [ ! -f "$out" ] || [ "$src" -nt "$out" ]; then
      h=$(sips -g pixelHeight "$src" | awk '/pixelHeight/{print $2}')
      if [ -n "$h" ] && [ "$h" -gt "$MAX_HEIGHT" ]; then
        sips -s format png --resampleHeight "$MAX_HEIGHT" "$src" --out "$out" >/dev/null
      else
        sips -s format png "$src" --out "$out" >/dev/null
      fi
      size=$(stat -f%z "$out")
      echo "  $file -> $base.png ($(echo "$size" | awk '{printf "%.0fKB", $1/1024}'))"
    fi
  fi
  shipped+=("$base")
done

# Ensure a --logo-h knob exists for each logo, without clobbering tuned values.
python3 - "$CSS" "$DEFAULT_LOGO_H" "${shipped[@]}" <<'EOF'
import re, sys
css_path, default_h, names = sys.argv[1], sys.argv[2], sys.argv[3:]
src = open(css_path).read()

anchor = re.search(r'(\.impact-logo-[a-z0-9-]+ \{ --logo-h: \d+px; \}\n)+', src)
if not anchor:
    sys.exit("Could not find the .impact-logo-* knob block in assets/css/style_v5.css")

added, kept = [], []
block = anchor.group(0)
for name in names:
    slug = re.sub(r'[^a-z0-9]+', '-', name.lower()).strip('-')
    if re.search(rf'\.impact-logo-{re.escape(slug)}\s*\{{', src):
        m = re.search(rf'\.impact-logo-{re.escape(slug)} \{{ --logo-h: (\d+)px; \}}', src)
        kept.append(f"{slug} (already set to {m.group(1)}px)" if m else f"{slug} (already present)")
        continue
    block += f".impact-logo-{slug} {{ --logo-h: {default_h}px; }}\n"
    added.append(slug)

if added:
    src = src[:anchor.start()] + block + src[anchor.end():]
    open(css_path, "w").write(src)

print("\nCSS size knobs (assets/css/style_v5.css):")
for a in added:
    print(f"  + .impact-logo-{a} {{ --logo-h: {default_h}px; }}   <- NEW, tune this by eye")
for k in kept:
    print(f"  = .impact-logo-{k} — left alone")
EOF

# Print paste-ready snippets with true aspect-ratio attributes.
python3 - "$LOGOS" "${shipped[@]}" <<'EOF'
import sys, pathlib, re, xml.etree.ElementTree as ET
logos, names = pathlib.Path(sys.argv[1]), sys.argv[2:]

def dims(p):
    if p.suffix.lower() == ".svg":
        try:
            root = ET.parse(p).getroot()
            vb = root.get("viewBox")
            if vb:
                _, _, w, h = [float(x) for x in re.split(r"[ ,]+", vb.strip())]
                return w, h, None
        except Exception:
            pass
        return None, None, None
    try:
        from PIL import Image
        im = Image.open(p).convert("RGBA")
        bb = im.getchannel("A").getbbox()
        ink = None
        if bb:
            ink = (bb[3] - bb[1]) / im.height
        return im.width, im.height, ink
    except Exception:
        return None, None, None

print("\nPaste-ready markup:")
for name in names:
    p = next((logos / f"{name}{e}" for e in (".png", ".svg") if (logos / f"{name}{e}").exists()), None)
    if not p:
        continue
    w, h, ink = dims(p)
    slug = re.sub(r'[^a-z0-9]+', '-', name.lower()).strip('-')
    print(f"\n  --- {p.name} ---")
    if ink is not None:
        pct = ink * 100
        note = " (lots of built-in padding — it'll read small; consider cropping the master)" if pct < 75 else ""
        print(f"  ink fills {pct:.0f}% of the file's height{note}")
    if w and h:
        # Attributes only declare aspect ratio; scale to a sane 2-digit pair.
        ah = 40
        aw = round(w / h * ah)
        attrs = f'width="{aw}" height="{ah}"'
    else:
        attrs = 'width="40" height="40"'
    print(f"""
  Accordion flagship link (logo replaces the text name — needs a wordmark):
    <li><a class="impact-link flagship has-logo" href="https://example.org" target="_blank" rel="noopener">
        <span class="impact-logo-row">
          <img class="impact-logo impact-logo-{slug}" src="assets/logos/{p.name}"
            alt="Full Name Here" {attrs}>
          <span class="impact-arrow" aria-hidden="true">&#8599;</span>
        </span>
        <span class="impact-link-desc">One or two sentences.</span>
      </a></li>

  Mission card (logo sits over the photo; the card's <h3> still names it —
  this is the placement that works for a mark with no wordmark):
    <img class="card-logo" src="assets/logos/{p.name}" alt="" {attrs}>""")
EOF

echo ""
echo "Tune size with --logo-h — never the width/height attributes (CSS beats them;"
echo "they only declare the aspect ratio that prevents layout shift). Override one"
echo "instance inline in index.html with style=\"--logo-h: 52px\"."

if [ "${1:-}" = "--push" ]; then
  cd "$REPO"
  git add assets/logos assets/css/style_v5.css index.html
  git commit -m "Add partner/mission logo(s)"
  git push
  echo "Pushed — live in ~1 minute."
else
  echo "Review in the preview, then commit & push (or re-run with --push)."
fi
