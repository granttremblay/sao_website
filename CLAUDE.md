# CLAUDE.md — project guide

Static Smithsonian-branded site for the Smithsonian Astrophysical Observatory.
Live at <https://granttremblay.github.io/sao_website/> (GitHub Pages, `main` branch root,
repo `granttremblay/sao_website` — note the underscore; a stray hyphenated repo may still
exist and is NOT this site).

## Hard rules

- **Keep `README.md` up to date.** Any change to structure, workflows, URLs, scripts, or
  the stats/mosaic systems must be reflected there in the same commit.
- **Syntax-check JS before pushing**: `node --check js/main.js`. All of main.js is one IIFE;
  one syntax error blanks the entire site (scroll reveals never fire and content stays at
  opacity 0). This has happened once already (missing comma in ROTATING_STATS).
- **Optimize every image before it ships.** Nothing over ~500KB in the repo. Use `sips`:
  cards ~900px / hero & backdrops 1920px wide, JPEG quality 70–75. Original PNGs/screenshots
  stay local — `.gitignore` excludes them; keep it that way.
- **Verify in the preview before pushing** (`preview_start` config: `sao-website`, python
  http.server on port 4173). Browser caches aggressively; force-reload assets with
  `fetch(url, {cache: 'reload'})` before `location.reload()`.
- Push to deploy: plain `git push`, live in ~1 min. The user expects pushes after completed,
  verified work on this site.

## Architecture notes

- No build step. index.html + css/style.css + js/main.js. The user's editor reformats HTML
  (wraps long attribute lines) — match that style; re-grep before Edit if a match fails.
- Brand: Geologica (Google Fonts, matches science.si.edu), Smithsonian blue `#002554`,
  sunburst yellow `#ffcd00`, cyan `#38bdf8`→indigo `#6366f1` gradient for accents
  (CfA red/violet vars exist but are unused — user reverted them as too dark on navy).
- Logos in assets/logos. SI/AO SVGs contain live Minion Pro `<text>` (renders via serif
  fallback — acceptable, outlined versions would be better). CfA + Smithsonian Science
  logos are fully outlined. "Reversed" = white text for dark backgrounds. The white STARS
  logo is a generated recolor of the black one.
- Partner/mission logos (TEMPO, STARS, AstroAI, NASA SciX, GMT, EHT, SMA, FLWO, VERITAS, CXC):
  drop the master in assets/logos/originals/ (gitignored) and run `scripts/add_logo.sh` — it
  resizes rasters to <=320px tall, copies SVGs through, appends a `.impact-logo-<name>` --logo-h
  knob without clobbering tuned values, and prints paste-ready markup. Placement + alt text are
  still a human call — see README "Adding a partner/mission logo". Two hard placement rules:
  (1) an accordion `has-logo` link ALWAYS keeps its `.impact-link-name` — the `.impact-logo-row`
  goes ABOVE the title, never in place of it, and the logo duplicating the title text (gmt.png over
  the words "Giant Magellan Telescope") is intended, not a bug. The user asked for this explicitly
  after logo-only links shipped; don't "tidy" the titles away again. Every logo img there takes
  alt="" since the title names the link (an alt would double-announce). This is also why a bare mark
  like cxc.svg needs no special handling. (2) card logos sit on a photo with only a drop-shadow, so
  a white wordmark dies on a bright frame (sma.png washed out on the snowy SMA card and was pulled
  back to accordion-only).
  Two placements, both optional independently:
  `.card-logo` (uniform 46px, bottom-left of a mission card's `.card-art`) and the accordion's
  `.impact-link.flagship.has-logo` + `.impact-logo-row` (each logo gets its own
  `.impact-logo-<name>` rule — wordmarks ~26-32px, squarish badges like TEMPO ~40px
  since they have less horizontal reach at the same height). SIZING: the knob is the `--logo-h`
  custom property — both `.impact-logo` (`height: var(--logo-h, 30px)`) and `.card-logo`
  (`var(--logo-h, 46px)`) read it, settable per-logo in CSS or per-instance inline from index.html
  (`style="--logo-h: 52px"`). The `<img>` width/height ATTRIBUTES are not a styling knob — CSS
  height beats a presentational attribute, so editing them does nothing visually; they exist only
  to declare the aspect ratio against layout shift, so keep them accurate. --logo-h values are NOT
  comparable across logos: each file has its own transparent padding (eventhorizon.png is ~34%
  vertical padding vs gmt.png's ~12%, which is why EHT at 38px looks smaller than GMT at 40px) —
  tune by eye, or crop the file's dead margin. Raster logos land oversized from
  media kits (TEMPO's was 3300px/958KB) — always `sips --resampleHeight 320` before shipping;
  keep the master in `assets/logos/originals/` (gitignored).
- Hero backdrops: `HERO_MANIFEST` in js/main.js, refreshed by `scripts/add_hero_images.sh` from
  masters in assets/images/hero_images/originals/ (gitignored). INVARIANT: the script copies
  existing entries VERBATIM — it reads only each `file:` key to identify the entry and never
  rewrites the rest, so credit/tone/focus/field-order/anything-added-later survive byte-for-byte.
  Do not "improve" this back into rebuilding entries from parsed fields: that's what it used to do,
  and it silently placeholdered any credit whose regex missed and silently dropped (then re-added as
  "new") any entry whose file: didn't parse — exiting 0 while destroying hand-written prose. It now
  hard-exits 1 naming the entry rather than write a manifest it can't fully read. `PIN_FIRST` (=
  milkyway_backdrop.jpg) is hoisted to index 0 on every run; everything else keeps the author's
  order, new images append. A RENAMED master is indistinguishable from retire+add, so the script
  echoes the credit of anything it retires — that print is the only copy left.
- Mosaic: `scripts/add_mosaic_images.sh` is the only sanctioned way to add tiles — it
  numbers tiles, regenerates `MOSAIC_MANIFEST` in js/main.js, and syntax-checks. In dev the
  mosaic auto-discovers via directory listing; on Pages it uses the manifest. The rotation
  uses a reservation set so the same image never appears in two tiles at once, including
  while loading or mid-crossfade (reserved from assignment until fade-out completes) —
  preserve this invariant when touching the rotation code.
- Rotating stats: `ROTATING_STATS` in js/main.js. Numeric `big` values (optional trailing
  `+`) count up; words render as text, `.long` class auto-applies over 6 chars.
- News feed (Impact section): assets/data/news.json + assets/images/news/ are generated by
  scripts/update_news.py (scrapes cfa.harvard.edu/news; regex tied to their Drupal markup —
  a.copy-box / news-photo-frame / h4). A daily GitHub Action commits refreshes. Never
  hand-edit news.json. On a self-hosted deploy (not Pages), the same script runs from cron via
  scripts/refresh_news.sh, writing straight into the served assets/ — no site change needed
  (see README "Keeping the feed fresh on a self-hosted server"). The script exits nonzero WITHOUT
  writing when it parses <3 items, so a failed scrape never blanks the feed — preserve that guard.
- Impact accordion (#impact-accordion): a vertical stack of `.impact-item` themed disclosures
  (this replaced a horizontal carousel). Each header is an `<h3 class="impact-acc-h">` wrapping a
  `.impact-acc-header` button (heading wraps button → heading order + accessible name both kept);
  the `.impact-acc-art` image fades into the navy via a mask-image that ROTATES with the layout:
  left→right as a left strip above 560px, top→bottom as a full-width banner above the text at/below
  560px (the header just `flex-wrap: wrap`s — art gets its own line, text + chevron share the next;
  same flex row, no bespoke mobile structure). Keep them the same gesture rotated 90°. Never set the
  title over a full-bleed photo — tried and reverted; these frames are too busy/bright and no
  workable scrim leaves the photo worth showing. That reverted version also had an invisible scrim:
  an absolute `::before` generates BEFORE `.impact-acc-art`, so at z-index:auto the photo painted
  over its own scrim — mind paint order if you ever layer behind that art. `.impact-acc-lede` is
  justified on desktop but `left` below 560px (rivers at ~28 chars); that override must stay AFTER
  the base rule — equal specificity, so source order decides.
  Bodies (`.impact-acc-body`) expand via grid-template-rows 0fr→1fr, accordion-style (one open at
  a time). Bodies render OPEN by default so the section works with no JS; main.js adds `.js` to the
  container to switch on the collapse, open the first row, and mark closed bodies `inert`. The
  chevron is `display:none` until `.js` is present. Preserve the no-JS-open / JS-collapse invariant.
  News (#news) is its own always-visible section above #impact; its JS-rendered cards must use <h3>
  (heading-order: section h2 → card h3).
  WARNING: when splicing index.html with regex, anchor extraction patterns precisely —
  a greedy initiative-grid regex once swallowed the news block and half the missions
  section, duplicating them. Sanity-check section counts after any large splice.
  NOTE: rAF-driven animation (incl. smooth scrolling) stalls in the preview tool's
  throttled background window; also preview_click double-fires on elements with click
  handlers (toggles open+shut) — use element.click() via preview_eval to test toggles.
- Arrow/chevron icons (hero prev/next, carousel `.scroll-btn`s, accordion `.impact-acc-chev`)
  are all one shared `.icon-chevron` inline SVG (a simple `<polyline>`, points down by default),
  rotated per direction with CSS `transform: rotate()`. Never go back to text glyphs (‹ › ⌄) for
  these — font glyphs have uneven side-bearings, so they render off-center in a flex-centered
  circle and visibly shift sideways when rotated (this happened to both the hero arrows and the
  accordion chevron). The SVG's own point geometry is bounding-box-symmetric, so it stays
  centered under any rotation.
- Section vertical spacing follows one scale: base `.section { padding: clamp(3rem, 6vw, 5rem) ... }`
  (also mirrored explicitly on `.stats`, which isn't `.section`-classed) is used for every
  "topic change" boundary (stats→news, missions→history, history→cfa, etc.). The one exception is
  news→impact, which is intentionally half that (`clamp(1.5rem, 3vw, 2.5rem)` on each side) because
  those two are meant to read as one continuous flow rather than a hard break. If you add a new
  section, let it inherit the base padding rather than inventing a new value — that consistency was
  a deliberate fix.
- "Our Top Discoveries" is NOT a separate section — it's the 7th and last `.impact-item` inside
  `#impact-accordion`, reusing that exact same header/chevron/open-close JS with zero bespoke code.
  Its body is a plain static `<ul class="discovery-list">` (hardcoded `<li>`s, no JS array, no
  carousel — everything is visible at once when expanded). Each row's image is flush against the
  card's own left edge (`.discovery-list` has zero horizontal padding) and mask-fades right into
  the navy, exactly like `.impact-acc-art` — this is deliberate: don't add padding or a border-radius
  to `.discovery-row-art` itself, or you'll break the flush-edge look and the "only the very first/
  last row's corner rounds" behavior that comes for free from the parent's own `overflow:hidden`.
  There used to be a separate `#discoveries` carousel section (JS-array-driven, `.discovery-card`s,
  autoplay) — fully replaced; if you see references to `DISCOVERIES` array, `discovery-grid`,
  `discovery-card`, or `.carousel-toggle`, they're stale, not a pattern to follow.
- The mobile nav overlay is a fixed-position child of the header: never put
  `backdrop-filter`/`filter`/`transform` on `.site-header` itself (it becomes the containing
  block and pins the overlay inside the 60px bar — the frosted background lives on
  `.site-header::before` for exactly this reason).
- Header layout: nav LEFT, SAO logo RIGHT — matching the si.edu fork, adopted on request.
  **This is done by DOM order (`<nav>` then `.brand`), never by `order: 1`.** The fork gets the
  same look by leaving `.brand` first and setting `order: 1` on it, which paints the logo right
  while it stays first in the tab order — measured on their build, focus lands at x=959 and then
  jumps back to x=48 (WCAG 2.4.3 focus order / 1.3.2 meaningful sequence). Ours is verified the
  other way: no positive `tabindex` anywhere, so DOM order *is* tab order, and the header's
  focusables run x = 48 → 124 → 213 → 315 → 440 → 690 → 800 → 1138, strictly left to right.
  If you ever need to move the logo again, move the element, not the paint order.
  The logo still only fades in on scroll, via `.brand-visible` (an IntersectionObserver on
  `.hero-logo`, so the header lockup never doubles the hero one). Two non-obvious constraints:
  (1) the full nav row (~900px, since the external "Careers" link was added alongside the
  "Support SAO" CTA) plus the horizontal lockup (~215px, ~176px once `.scrolled` shrinks it —
  and the logo only ever shows while scrolled) plus padding don't fit until ~1200px, and the
  hamburger only takes over at <=880px (the nav row alone needs ~825px to sit uncramped), so
  `.brand` is `display:none` in the 881-1200px band — the nav wins.
  **Re-measure this band whenever a nav label changes**: renaming "Support" → "Support SAO"
  widened the row ~43px and cut the logo/nav clearance at the old 1150 bound to 16px, which is
  why the bound moved to 1200 (verified: 55.1px clearance at 1201px). At the very bottom of the
  band (881-920px) the row sits ~15px into the header padding; still fits, CTA on-screen, no
  document overflow, but there's little left to give — raise the 880px hamburger bound before
  adding another link. Note the overflow failure mode FLIPPED with this layout: the logo is now
  the trailing item, so without the band it is the LOGO that runs off the right edge, and an
  invisible logo clipping off-screen is something nobody notices — check the logo's right edge
  against the viewport when re-measuring, not just the Support CTA. This bites at page top too:
  `visibility: hidden` still reserves the layout box, so `.brand` holds its full width while
  invisible (see the accessibility note below — `opacity: 0` alone left it in the tab order).
  Hide `.brand`, not `.brand-logo`, or you leave a focusable link with no accessible name.
  (2) There is deliberately NO auto margin on `.site-nav` or `.brand` — the header's plain
  `space-between` covers all three regimes: >1200px `[nav, brand]` → nav left/logo right;
  881-1200px `.brand` is `display:none` so nav is the lone item and a lone space-between item
  sits at the START, i.e. left, which is now the goal (this used to be the bug `margin-left:auto`
  worked around under the old nav-right layout); <=880px `.site-nav` is `position:fixed inset:0`
  so the in-flow items are `[brand, toggle]` → logo left, hamburger right. An auto margin on
  `.brand` would break that last case by shoving the logo against the hamburger.

## Accessibility baseline (do not regress)

axe-core reports zero violations. Every img has alt (decorative → `alt=""`), skip link +
`<main>` landmark, `:focus-visible` outlines, closed mobile menu is `visibility: hidden`
(out of tab order), Escape closes it and refocuses the toggle, ↗ arrows are aria-hidden,
all animation respects `prefers-reduced-motion`. Re-run axe after meaningful UI changes
(snippet in README).

## Social card

`assets/images/social_card.jpg` (1200×630) rendered from an HTML comp via headless Chrome
(source pattern: /tmp/social_card.html — VERITAS backdrop + vertical SAO logo + tagline).
OG/Twitter tags in index.html use absolute URLs — update them if the domain ever changes,
and regenerate the card if branding/tagline changes.
