# Smithsonian Astrophysical Observatory — Website

A Smithsonian-branded static site for the **Smithsonian Astrophysical Observatory (SAO)**: SAO-led missions and projects, our history since 1890, and our place within the Center for Astrophysics | Harvard & Smithsonian. Design language follows [science.si.edu](https://science.si.edu/) (Geologica type, Smithsonian blue & sunburst yellow, vibrant full-bleed imagery).

**Live site: <https://granttremblay.github.io/sao_website/>**

Deployed via GitHub Pages from the `main` branch root — every push to `main` goes live in about a minute. No build step, no dependencies: plain HTML/CSS/JS.

## Structure

```
index.html                  Single-page site (hero, stats, impact, missions, history, CfA, footer)
css/style.css               All styles; brand colors as CSS variables in :root
js/main.js                  Interactions: nav, scroll reveals, hero backdrops,
                            rotating stat, photo mosaic, news feed,
                            impact accordion (incl. Our Top Discoveries), timeline
assets/
  logos/                    SI/AO, CfA, Smithsonian Science, STARS, AstroAI, NASA SciX (SVG)
  data/news.json            CfA news feed data (auto-generated — do not hand-edit)
  images/                   Web-optimized JPEGs used by the site
    card_images/            Mission card photos (~900px wide)
    discoveries/            Our Top Discoveries images (800x360 JPEGs, fade into card)
    impact/                 Impact card top images (800x360 JPEGs, fade into card)
    hero_images/            Static hero backdrops (high-res JPEGs; masters in originals/)
    history_images/         Timeline photos
    mosaic/                 600x600 tiles for the rotating stats mosaic
    mosaic_sources/         Raw drop folder for new mosaic images (gitignored)
    news/                   Cached CfA news images (auto-generated)
  favicon.svg               Smithsonian sunburst (+ PNG fallbacks)
scripts/
  add_mosaic_images.sh      Mosaic image pipeline (see below)
  add_hero_images.sh        Hero backdrop image pipeline (see below)
  add_discovery_images.sh   Our Top Discoveries image pipeline (see below)
  update_news.py            CfA news feed scraper (see below)
.github/workflows/
  update-news.yml           Daily Action that refreshes the news feed
```

Heavy source images (original PNGs/screenshots) stay local and are gitignored; the repo only ships web-optimized JPEGs. See `.gitignore`.

## Adding images to the mosaic rotation

1. Drop images — any size, any filename (jpg/png/heic/webp/tiff) — into `assets/images/mosaic_sources/`
2. Run:

   ```bash
   ./scripts/add_mosaic_images.sh          # process + update manifest locally
   ./scripts/add_mosaic_images.sh --push   # ...and commit + push to deploy
   ```

The script center-crops each image to a 600×600 JPEG tile named `mosaic_NN.jpg`, regenerates the `MOSAIC_MANIFEST` array in `js/main.js`, syntax-checks the result, and moves processed sources to `mosaic_sources/processed/`. It also rejects images that already exist in the roster under a different filename (perceptual hash comparison) — the on-page rotation guarantees no image ever appears in two grid tiles at once, but it can only do that if each image exists exactly once. macOS only (uses `sips`; duplicate detection needs Pillow, and is skipped gracefully without it).

## The news feed (Impact section)

"News from the Smithsonian Astrophysical Observatory" renders from `assets/data/news.json`, which
`scripts/update_news.py` builds by scraping the Recent News Releases list on
[cfa.harvard.edu/news](https://www.cfa.harvard.edu/news) (top 6 items, images downloaded and
optimized into `assets/images/news/`). A scheduled GitHub Action
(`.github/workflows/update-news.yml`) runs it daily and commits any changes, so the live site
stays current without manual work. To refresh on demand: run the script locally and push, or
trigger the Action from the repo's Actions tab ("Run workflow"). If the CfA page layout changes,
the script exits nonzero rather than writing a bad feed — check the Action logs.

### Keeping the feed fresh on a self-hosted server (not GitHub Pages)

The feed is just two static things the browser fetches — `assets/data/news.json` and
`assets/images/news/*.jpg` — and `update_news.py` writes them relative to its own location
(`scripts/../assets/...`). So on a server that hosts this site outside GitHub Pages, **no code,
HTML, or rebuild is needed** — just run the scraper on a daily cron so it regenerates those files
in place. As long as this `scripts/` folder ships inside (or one level above `assets/` in) the
docroot, the refresh lands directly in the live files.

Use the `scripts/refresh_news.sh` wrapper (stable working dir + timestamped logging + a clear
failure exit code). One-time setup, then a crontab line:

```bash
pip install Pillow                       # once, on the server (or in a venv)
# crontab -e — daily at 03:17 server time, appending to a log:
17 3 * * * /var/www/sao_website/scripts/refresh_news.sh >> /var/log/sao-news.log 2>&1
```

Notes: the scrape needs outbound HTTPS to `cfa.harvard.edu`; the cron user needs write access to
`assets/data/` and `assets/images/news/`; if system Python lacks Pillow, point the wrapper at a
virtualenv with `PYTHON=/path/to/venv/bin/python`. `update_news.py` exits nonzero **without**
touching `news.json` when the scrape fails or parses fewer than 3 items, so a bad run leaves the
last-good feed in place — watch the log (or alert on nonzero exit) to catch CfA markup changes.
The daily GitHub Action is harmless to leave enabled but is redundant for a self-hosted deploy;
disable it if you don't also publish to GitHub Pages.

The cards always render as a single row: when the viewport can't fit them all, the row scrolls
horizontally (hidden scrollbar, scroll-snap) behind circular arrow buttons that appear only when
there is actually overflow in that direction.

## "Our National & Global Impact" section (#impact)

This section holds one vertical **accordion** (`#impact-accordion`) of themed disclosure cards. The
last card, **"Our Top Discoveries,"** is a static list rather than a themed-link card, but it's
still just another `.impact-item` — same header/chevron/open-close controls, no separate JS. The
news feed above it (`#news`) is the only horizontal carousel left on the page; see the news section
below for `initScroller`.

**Impact accordion** — plain HTML `.impact-item`s in `index.html` (`#impact-accordion`), edit them
there. Each row's header is the disclosure toggle: an `<h3 class="impact-acc-h">` wrapping a
`<button class="impact-acc-header">` (heading wraps the button so heading order and a meaningful
accessible name are both preserved). The button holds the left image (`.impact-acc-art`), the text
column (`.impact-tag` kicker, `.impact-acc-title`, `.impact-sub`), and a `.impact-acc-chev` chevron.
The `.impact-acc-body` below it animates open via `grid-template-rows: 0fr→1fr` (inner wrapper clips
the overflow). Bodies render **open by default** so the section is fully readable with no JS;
`js/main.js` adds `.js` to `#impact-accordion`, which switches on the collapse, opens the first row,
and marks closed bodies `inert` (out of the tab order). One open at a time — this is generic and
applies uniformly to all seven `.impact-item`s, "Our Top Discoveries" included. The chevron is
hidden until JS wires it up.

For the first six (themed-link) cards, each row's links are `.impact-link`s (whole bullet is a
clickable external link with title + description), laid out in a responsive
`repeat(auto-fit, minmax(280px, 1fr))` grid inside the body. The four marked `.flagship` (Minor
Planet Center, HITRAN, AstroAI, NASA SciX/ADS) get the accent treatment; AstroAI, SciX, and STARS
additionally carry `.has-logo` and show a brand SVG (`astroAI_without_encoder.svg`,
`scix_light.svg`, `STARS_Logo_Lockup_Horizontal_White.svg` — light variants for the dark card) in
place of the text title, sized via `.impact-logo-astroai` / `.impact-logo-scix` /
`.impact-logo-stars`. **Keep the outbound URLs working** — they point at real resources (MPC,
HITRAN, AstroAI, scixplorer.org, chandra.si.edu, central-engineering, science-education-department,
etc.).

Each row's `.impact-acc-art` image (set via inline `background-image`) sits on the left and fades
**left-to-right** into the navy via a horizontal `mask-image` (the image itself fades to transparent
so the card's own background shows through — no seam). Images live in `assets/images/impact/`
(800×360 JPEGs: `leadership`, `defending`, `ai`, `xray`, `engineering`, `stars`, `education`). To
swap one, replace the file (keep the name) or point the row's `background-image` at a new file —
optimize to ~800px wide / under ~150KB first.

**Our Top Discoveries** (the 7th, last `.impact-item`) is a plain `<ul class="discovery-list">` of
`<li class="discovery-row">` entries hardcoded in `index.html` — no JS array, no carousel, nothing
to render at runtime, so every discovery is visible at once once the card is expanded. It's a
curated, non-ranked showcase despite the name. Each row is:

```html
<li class="discovery-row">
  <span class="discovery-row-art" aria-hidden="true" style="background-image:url('assets/images/discoveries/<file>.jpg')"></span>
  <span class="discovery-row-text">
    <span class="discovery-row-tag"><!-- category, e.g. "Black holes" --></span>
    <h4 class="discovery-row-title"><!-- headline --></h4>
    <p class="discovery-row-blurb"><!-- one or two sentences --></p>
    <p class="discovery-row-credit"><!-- image credit --></p>
  </span>
</li>
```

To add, edit, or reorder a discovery: edit these `<li>`s directly (order in the HTML is the display
order). Deliberately non-interactive — no link, no hover lift — since there's nothing to click
through to; see the code comment above `.discovery-list` in `css/style.css` if that's ever
reconsidered. Each row's image is flush against the accordion card's own left edge (zero padding on
`.discovery-list`) and fades right into the navy via the same `mask-image` technique as
`.impact-acc-art` — the only rounding comes from the outer `.impact-item`'s own `overflow:hidden`,
so only the very first and last row's image corners round at all; that's intentional, not a bug.

To add a new discovery image:

1. Drop it (any size/format) into `assets/images/discoveries/` and run:

   ```bash
   ./scripts/add_discovery_images.sh          # crop to 800x360, <500KB
   ./scripts/add_discovery_images.sh --push   # ...and commit + push to deploy
   ```

   The script center-crops to 800×360 (the same shape as `assets/images/impact/*.jpg`) with quality
   auto-stepped under ~500KB. Heavy originals stay gitignored in `discoveries/originals/`.
2. Add or edit the matching `<li class="discovery-row">` in `index.html` by hand (see the pattern
   above) — title, blurb, credit, category tag, and the image filename.

## Adding a partner/mission logo (e.g. TEMPO, STARS, AstroAI)

There's no script for this one — logos each need a human to pick where they go and write real alt
text, so it's a two-step manual copy-paste-and-edit. Takes a few minutes.

**1. Get the file into `assets/logos/`, optimized.**

- If it's already an SVG, just drop it in — nothing to optimize.
- If it's a raster PNG/JPG (like `TEMPO-Logo.png`), it's almost always way oversized straight out of
  a media-kit download (the original TEMPO logo was 3300px, 958KB for a graphic that displays at
  ~40px tall). Back up the original, then downsize with `sips` — a logo never needs to be taller
  than ~320px even for retina displays:

  ```bash
  cd assets/logos
  mkdir -p originals && cp YourLogo.png originals/
  sips --resampleHeight 320 YourLogo.png --out YourLogo.png
  ```

  That alone (no quality flags needed for a mostly-flat-color logo) took TEMPO's logo from 958KB to
  91KB. `originals/` is gitignored — keep the master there, ship only the resized file.

**2. Add it in one or both of two places, matching an existing logo exactly:**

- **A mission card** under "Our Missions" (`.card`) — add a second `<img class="card-logo">` right
  after the card's photo, inside `.card-art`. No new CSS needed; `.card-logo` is a single shared
  rule (46px tall, bottom-left, drop-shadow) used by every card logo:

  ```html
  <div class="card-art">
    <img src="assets/images/card_images/whatever.jpg" alt="..." loading="lazy">
    <img class="card-logo" src="assets/logos/YourLogo.png" alt="">
    <span class="card-tag">...</span>
  </div>
  ```

- **An accordion flagship link** inside `#impact-accordion` (see AstroAI, NASA SciX, STARS, TEMPO
  for examples) — add `flagship has-logo` to the `<a class="impact-link">`, then swap
  `.impact-link-name` for an `.impact-logo-row` containing the logo image and the arrow:

  ```html
  <li><a class="impact-link flagship has-logo" href="https://example.org" target="_blank" rel="noopener">
      <span class="impact-logo-row">
        <img class="impact-logo impact-logo-yourlogo" src="assets/logos/YourLogo.png" alt="Your Org"
          width="42" height="40">
        <span class="impact-arrow" aria-hidden="true">↗</span>
      </span>
      <span class="impact-link-desc">One or two sentences about it.</span>
    </a></li>
  ```

  Then add one line to `css/style.css` next to `.impact-logo-astroai` / `.impact-logo-scix` /
  `.impact-logo-stars` / `.impact-logo-tempo`, sizing your logo to read at a comfortable height —
  wordmarks usually want ~26–32px, a squarish badge (like TEMPO's) wants a bit taller (~40px) since
  it has less horizontal reach at the same height:

  ```css
  .impact-logo-yourlogo { height: 32px; }
  ```

  Match the `width`/`height` HTML attributes to the logo's real aspect ratio (`sips -g pixelWidth -g
  pixelHeight file.png` if unsure) so the browser reserves the right space before the image loads.

You don't have to do both placements — TEMPO's mission card and accordion link both got the logo
here because it fit well in both spots, but a logo that's only relevant to one context (e.g. a
tool-only flagship link with no dedicated mission card) only needs the one snippet.

## Hero backdrops

The landing hero shows a **static** backdrop that the visitor switches with the ‹ › arrow controls
(bottom-right) — no auto-advance, no Ken Burns. The images, order, and per-image credit lines live
in the `HERO_MANIFEST` array in [`js/main.js`](js/main.js) (search "Hero backdrop") —
`{ file, credit, tone? }` per image. The page builds the `.hero-slide` layers from it, crossfades
between them on arrow press, and shows the active image's `credit` verbatim in the small
`.hero-credit` caption (bottom-left).

### Adding / changing images

These backdrops are the site's showpiece, so quality is prioritized over file size. Drop full-size
master image(s) — any size, any format (jpg/png/heic/webp/tiff) — into
`assets/images/hero_images/originals/` and run:

```bash
./scripts/add_hero_images.sh          # optimize + refresh the manifest
./scripts/add_hero_images.sh --push   # ...and commit + push to deploy
```

For each master the script writes a web `<name>.jpg` to `assets/images/hero_images/` — resized to
at most **3200px** wide (never upscaled) at **quality 88**, deliberately with **no ~500KB cap** so
the backdrops stay gorgeous on large / retina displays (galactic.jpg is ~1.6MB, and that's fine).
It then regenerates `HERO_MANIFEST`, **preserving the credit text and the optional `tone` flag**
you've written for existing images and giving brand-new ones a placeholder credit to edit. The
`originals/` masters are gitignored — only the optimized `<name>.jpg` ships. Deleting a master and
re-running retires that image from the hero.

- **Reorder** by editing the order of `HERO_MANIFEST` entries (new images are appended at the end).
- **Edit a credit** by changing its `credit:` string in `HERO_MANIFEST`.
- With a single image the arrow controls hide themselves automatically.

### Framing — put the subject bottom-left

`.hero-slide` uses `background: cover` with **`background-position: left bottom`**, so the hero's
crop is anchored to the image's **bottom-left corner**, which is always in frame at every viewport
size. Compose (or pre-crop) masters accordingly: **the subject belongs in the lower-left of the
frame.** `cover` only ever overflows one axis, and which one flips with the viewport, so a single
value covers both regimes:

| Viewport | Overflows | What gets cropped | Roughly what's visible |
|---|---|---|---|
| Phone (375×812) | horizontally | the right of the frame | leftmost **~26%** of the image's width |
| Laptop (1440×900) | horizontally | the right of the frame | leftmost ~90% |
| Ultrawide (2560×1080) | vertically | the **top** of the frame | bottom ~64–84% |

The phone case is why this matters: every backdrop is landscape (aspect 1.5–2.0) against a `100svh`
hero, so a phone throws away about three quarters of the image's width. Centring used to cut the
subject off the left edge. A dead-centre subject (e.g. the Milky Way panorama's galactic bulge)
will read as empty sky on mobile — crop such a master left-of-centre before adding it. Don't set
`background-position` back to `center`.

### Contrast (dark vs. light frames)

There is **no darkening overlay** — backdrops show as-is. For the usual dark-sky frames, legibility
of the centred logo/tagline comes from text-shadows on the text itself (`.hero-logo img`,
`.hero-title`, `.hero-sub`), which protect the glyphs without tinting the photo.

For a **bright frame** (a snowy scene, a white sky) white text washes out, so tag that image
`tone: "light"` in `HERO_MANIFEST`. On that slide `applyTone()` in `js/main.js` sets
`.hero[data-tone="light"]` (and `[data-hero-tone]` on the header) and swaps the hero lockup to the
colour logo (`si_AO_rgb_verical_color.svg`); the CSS block under `/* Light-tone hero */` flips the
logo halo, title, tagline, credit, arrows, ghost button, and the transparent nav to dark navy ink.
The header only follows the frame while it's transparent (`:not(.scrolled)`), and the dark mobile
menu keeps white links (`.site-nav:not(.open)`) and a white close ✕ (`.nav-toggle:not([aria-expanded="true"])`).
Colour transitions live on the base rules so the flip cross-fades with the 1.1s slide change.
Default (no `tone`, or `"dark"`) keeps the white treatment. Re-run axe after adding a light frame —
the point is that both tones pass contrast.

## Adding to the rotating stats

Edit the `ROTATING_STATS` array near the top of [`js/main.js`](js/main.js):

```js
{ big: "1890", label: "Exploring the cosmos<br>since our founding" },
```

- `big` — the headline. Pure numbers (optionally with a trailing `+`, e.g. `"16+"`) count up
  each time they appear; anything else (`"Two"`, `"Thousands"`) displays as text, automatically
  smaller when longer than 6 characters.
- `label` — the line underneath; `<br>` is allowed.
- **Mind the commas between entries** — a missing comma is a syntax error that breaks the whole
  page (every section waits on JS-driven reveal animations). Check before pushing:

  ```bash
  node --check js/main.js
  ```

## Accessibility checks

The site is built to WCAG-minded standards. After meaningful changes, verify:

- **Automated audit** — run [axe-core](https://github.com/dequelabs/axe-core) against the page
  (e.g. paste into DevTools console):

  ```js
  const s = document.createElement("script");
  s.src = "https://cdnjs.cloudflare.com/ajax/libs/axe-core/4.10.2/axe.min.js";
  s.onload = () => axe.run().then(r => console.log(r.violations));
  document.head.appendChild(s);
  ```

  Target: **zero violations** (the current baseline).

- **Images** — every `<img>` needs `alt` text; purely decorative images (logo overlays whose
  names appear in adjacent headings, the aria-hidden mosaic) use `alt=""`.
- **Keyboard** — Tab from the top: the "Skip to main content" link appears first; all links show
  a visible cyan focus outline; on mobile widths the closed menu must NOT be tabbable, Escape
  closes the open menu and returns focus to the toggle.
- **Motion** — with `prefers-reduced-motion` enabled, reveals/mosaic/stat rotation all go static;
  the hero backdrop is already static (visitor-switched, no crossfade transition under reduced
  motion). Nothing on the page auto-advances anymore (the news feed's arrows are manual-only), so
  there's no pause/play control to maintain — if a future carousel *does* auto-advance, give it one
  (WCAG 2.2.2).
- **Structure** — one `<h1>`, logical heading order, `<main>` landmark present, nav landmarks
  labeled, decorative glyphs (↗ arrows) wrapped in `aria-hidden` spans.

## Social sharing

Open Graph / Twitter card tags live in `index.html` and point at
`assets/images/social_card.jpg` (1200×630). If the site URL changes (e.g. a custom domain),
update the absolute `og:url` / `og:image` / `twitter:image` URLs.
