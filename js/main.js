/* Smithsonian Astrophysical Observatory — site interactions */

(() => {
  "use strict";

  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  /* ---------- Header state ---------- */

  const header = document.querySelector(".site-header");
  const onScroll = () => header.classList.toggle("scrolled", window.scrollY > 40);
  window.addEventListener("scroll", onScroll, { passive: true });
  onScroll();

  // Show the header logo only once the hero logo has scrolled out of view,
  // so the SAO lockup never appears twice at the same time.
  const heroLogo = document.querySelector(".hero-logo");
  if (heroLogo) {
    new IntersectionObserver(([entry]) => {
      header.classList.toggle("brand-visible", !entry.isIntersecting);
    }).observe(heroLogo);
  } else {
    header.classList.add("brand-visible");
  }

  /* ---------- Mobile nav ---------- */

  const toggle = document.querySelector(".nav-toggle");
  const nav = document.querySelector(".site-nav");
  toggle.addEventListener("click", () => {
    const open = nav.classList.toggle("open");
    toggle.setAttribute("aria-expanded", String(open));
  });
  nav.addEventListener("click", (e) => {
    if (e.target.tagName === "A") {
      nav.classList.remove("open");
      toggle.setAttribute("aria-expanded", "false");
    }
  });
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && nav.classList.contains("open")) {
      nav.classList.remove("open");
      toggle.setAttribute("aria-expanded", "false");
      toggle.focus();
    }
  });

  // Crossing the 760px breakpoint mid-resize flips .site-nav from an
  // in-flow desktop row to a fixed, translateY(-100%)/hidden overlay in the
  // same style recalc that the CSS transition rule turns on — so the browser
  // treats "no transform" -> "translateY(-100%)" as a real transition and
  // the closed overlay briefly flashes in before animating back out. Kill
  // the transition for exactly the one recalc where the breakpoint flips,
  // so the closed state snaps in instantly instead of animating.
  const navBreakpoint = window.matchMedia("(max-width: 760px)");
  const suppressNavTransition = () => {
    nav.style.transition = "none";
    requestAnimationFrame(() => requestAnimationFrame(() => { nav.style.transition = ""; }));
  };
  navBreakpoint.addEventListener("change", suppressNavTransition);

  /* ---------- Scroll-reveal ---------- */

  const revealObserver = new IntersectionObserver((entries) => {
    for (const entry of entries) {
      if (entry.isIntersecting) {
        entry.target.classList.add("visible");
        revealObserver.unobserve(entry.target);
      }
    }
  }, { threshold: 0.12 });

  document.querySelectorAll(".reveal").forEach((el, i) => {
    el.style.transitionDelay = `${(i % 4) * 70}ms`;
    revealObserver.observe(el);
  });

  /* ---------- Hero backdrop ----------
     Static backdrops the visitor switches with the arrow controls — no
     auto-advance, no Ken Burns. Slides are built from HERO_MANIFEST below,
     each { file, credit, tone?, focus? }, with credit shown in .hero-credit. Set
     tone: "light" on any image with a bright background (e.g. a snowy or
     white-sky frame) — it flips the logo, tagline, nav, and controls to dark
     ink for contrast (see applyTone below and .hero[data-tone] in the CSS).
     Omit it (or use "dark") for the usual dark-sky frames.

     focus: the point of the image to hold in frame as `cover` crops it — any
     CSS background-position value ("center", "50% 100%", "30% 40%", …). Omit
     it to inherit the .hero-slide default of `left bottom`, which suits the
     usual subject-in-the-lower-left photo; set focus: "center" for a frame
     whose subject sits mid-image (the Milky Way panorama's galactic bulge),
     since left-anchoring would crop it to empty sky on a phone.

     To add/optimize images and regenerate this list, drop full-size files into
     assets/images/hero_images/originals/ and run scripts/add_hero_images.sh
     (it preserves the credit, tone, and focus you write here). */

  const HERO_DIR = "assets/images/hero_images/";
  const HERO_LOGO = {
    dark: "assets/logos/si_AO_rgb_vertical_color-reversed.svg", // white lockup, for dark frames
    light: "assets/logos/si_AO_rgb_verical_color.svg"           // colour lockup w/ dark wordmark
  };
  const HERO_MANIFEST = [
    { file: "milkyway_backdrop.jpg", focus: "center", credit: "Our home galaxy, the Milky Way. Credit: ESO/S. Brunier" },
    { file: "veritas.jpg", credit: "SAO's VERITAS Gamma-ray Observatory in Amado, AZ" },
    { file: "chandra_launch.jpg", credit: "The launch of NASA's Chandra X-ray Observatory aboard the Space Shuttle Columbia, July 23, 1999. Credit: NASA" },
    { file: "galactic_center.jpg", credit: "Chandra's X-ray view of the Galactic Center. Credit: NASA/CXC" },
    { file: "mmt.jpg", credit: "SAO's MMT Telescope in Arizona. " },
    { file: "sma.jpg", credit: "SAO's Submillimeter Array in Hawaii.", tone: "light" },
    { file: "Screenshot 2026-07-01 at 4.12.49 PM.jpg", credit: "Placeholder credit — describe this image, then: Credit: [Name / Institution]." }
  ];

  const slideshow = document.querySelector(".hero-slideshow");
  if (slideshow && HERO_MANIFEST.length) {
    const hero = document.querySelector(".hero");
    const heroLogoImg = document.querySelector(".hero-logo img");
    const credit = document.querySelector(".hero-credit");
    const prevBtn = document.querySelector(".hero-prev");
    const nextBtn = document.querySelector(".hero-next");
    let idx = 0;

    // Preload the alternate logo so the swap on a light frame doesn't flash.
    new Image().src = HERO_LOGO.light;

    // Flip the hero (and the transparent header over it) between dark/light
    // ink for the current frame. CSS keys off .hero[data-tone] and, for the
    // header, [data-hero-tone] gated on :not(.scrolled).
    const applyTone = (tone) => {
      const t = tone === "light" ? "light" : "dark";
      if (hero) hero.dataset.tone = t;
      if (header) header.dataset.heroTone = t;
      if (heroLogoImg) heroLogoImg.src = HERO_LOGO[t];
    };

    // Build the slide layers from the manifest. An entry's optional `focus`
    // overrides the .hero-slide default crop anchor (`left bottom`) for that
    // one image; anything else keeps the default.
    const slides = HERO_MANIFEST.map((item) => {
      const slide = document.createElement("div");
      slide.className = "hero-slide";
      slide.style.backgroundImage = `url("${HERO_DIR}${item.file}")`;
      if (item.focus) slide.style.backgroundPosition = item.focus;
      slideshow.append(slide);
      return slide;
    });

    const show = (i) => {
      slides[idx].classList.remove("is-active");
      idx = (i + slides.length) % slides.length;
      slides[idx].classList.add("is-active");
      if (credit) credit.textContent = HERO_MANIFEST[idx].credit || "";
      applyTone(HERO_MANIFEST[idx].tone);
    };

    slides[0].classList.add("is-active");
    if (credit) credit.textContent = HERO_MANIFEST[0].credit || "";
    applyTone(HERO_MANIFEST[0].tone);

    // A single backdrop needs no controls.
    const nav = document.querySelector(".hero-nav");
    if (slides.length < 2) {
      if (nav) nav.hidden = true;
    } else {
      if (prevBtn) prevBtn.addEventListener("click", () => show(idx - 1));
      if (nextBtn) nextBtn.addEventListener("click", () => show(idx + 1));
    }
  }

  /* ---------- Rotating lead stat ----------
     Numbers (with optional "+") count up each time they appear;
     word stats ("Two", "Thousands") slide in as text. */

  const ROTATING_STATS = [
    { big: "1890", label: "Exploring the cosmos<br>since our founding" },
    { big: "600", label: "People pushing the frontiers of astrophysics" },
    { big: "2", label: "Nobel prizes" },
    { big: "50", label: "States where our science has impact" },
    { big: "16+", label: "World-class observatories" },
    { big: "16 million", label: "Annual users of the SciX/ADS astronomy literature database" },
    { big: "6", label: "Scientific divisions spanning all of astrophysics" },
    { big: "1", label: "NASA Great Observatory: the Chandra X-ray Observatory" },
    { big: "1st", label: "Image of a black hole" }
  ];

  const lead = document.querySelector(".stat-lead");
  if (lead) {
    const numEl = lead.querySelector(".stat-number");
    const labelEl = lead.querySelector(".stat-lead-label");

    const countTo = (el, target, suffix, duration) => {
      const start = performance.now();
      const tick = (now) => {
        const p = Math.min(1, (now - start) / duration);
        const eased = 1 - Math.pow(1 - p, 3);
        el.textContent = String(Math.round(target * eased)) + (p === 1 ? suffix : "");
        if (p < 1) requestAnimationFrame(tick);
      };
      requestAnimationFrame(tick);
    };

    const showStat = (stat, animateNumbers) => {
      const m = stat.big.match(/^(\d+)(\+?)$/);
      numEl.classList.toggle("long", stat.big.length > 6);
      if (m && animateNumbers) countTo(numEl, parseInt(m[1], 10), m[2], 1000);
      else numEl.textContent = stat.big;
      labelEl.innerHTML = stat.label;
    };

    let idx = 0;

    const rotate = () => {
      lead.classList.add("stat-leaving");
      setTimeout(() => {
        idx = (idx + 1) % ROTATING_STATS.length;
        lead.classList.remove("stat-leaving");
        lead.classList.add("stat-entering");
        showStat(ROTATING_STATS[idx], true);
        setTimeout(() => lead.classList.remove("stat-entering"), 800);
      }, 400);
    };

    const leadObserver = new IntersectionObserver(([entry]) => {
      if (!entry.isIntersecting) return;
      leadObserver.disconnect();
      if (reduceMotion) {
        showStat(ROTATING_STATS[0], false);
        return;
      }
      showStat(ROTATING_STATS[0], true);
      setInterval(rotate, 4200);
    }, { threshold: 0.6 });

    leadObserver.observe(lead);
  }

  /* ---------- Rotating image mosaic (stats section) ----------
     Drop square images into assets/images/mosaic/ and they are picked up
     automatically when the server lists directories (python -m http.server
     does). On hosts that don't, add the filenames to MOSAIC_MANIFEST. */

  const MOSAIC_DIR = "assets/images/mosaic/";
  const MOSAIC_MANIFEST = [
    "mosaic_01.jpg",
    "mosaic_02.jpg",
    "mosaic_03.jpg",
    "mosaic_04.jpg",
    "mosaic_05.jpg",
    "mosaic_06.jpg",
    "mosaic_08.jpg",
    "mosaic_09.jpg",
    "mosaic_10.jpg",
    "mosaic_11.jpg",
    "mosaic_12.jpg",
    "mosaic_13.jpg",
    "mosaic_14.jpg",
    "mosaic_15.jpg",
    "mosaic_16.jpg",
    "mosaic_17.jpg",
    "mosaic_18.jpg"
  ];

  const mosaic = document.querySelector(".stats-mosaic");
  if (mosaic) {
    const TILE_COUNT = 6;

    const discoverImages = async () => {
      try {
        const res = await fetch(MOSAIC_DIR);
        if (res.ok && (res.headers.get("content-type") || "").includes("html")) {
          const html = await res.text();
          const files = [...html.matchAll(/href="([^"?]+\.(?:jpe?g|png|webp|avif))"/gi)]
            .map((m) => decodeURIComponent(m[1]).split("/").pop());
          if (files.length) return [...new Set(files)];
        }
      } catch (_) { /* static host: fall back to the manifest */ }
      return MOSAIC_MANIFEST;
    };

    discoverImages().then((files) => {
      const tiles = [];
      // An image is "reserved" from the moment it is assigned to a tile until
      // it has fully faded out — so no two tiles can ever show it at once,
      // even mid-crossfade or while a swap is still loading.
      const reserved = new Set();

      for (let i = 0; i < TILE_COUNT; i++) {
        const tile = document.createElement("div");
        tile.className = "mosaic-tile";
        const a = new Image();
        const b = new Image();
        const file = files[i % files.length];
        a.src = MOSAIC_DIR + file;
        a.className = "front";
        a.alt = "";
        b.alt = "";
        tile.append(a, b);
        mosaic.append(tile);
        reserved.add(file);
        tiles.push({ imgs: [a, b], front: 0, current: file, pending: false });
      }

      // Rotation only makes sense with more images than tiles.
      if (reduceMotion || files.length <= TILE_COUNT) return;

      const FADE_MS = 1300; // a hair over the 1.2s CSS opacity transition
      let cursor = TILE_COUNT;

      setInterval(() => {
        const t = tiles[Math.floor(Math.random() * tiles.length)];
        if (t.pending) return; // tile is mid-swap; skip this beat

        let candidate = null;
        for (let tries = 0; tries < files.length; tries++) {
          const f = files[cursor % files.length];
          cursor++;
          if (!reserved.has(f)) { candidate = f; break; }
        }
        if (!candidate) return; // every image is on screen or still fading

        reserved.add(candidate);
        t.pending = true;
        const outgoing = t.current;
        const back = t.imgs[1 - t.front];
        back.onload = () => {
          back.classList.add("front");
          t.imgs[t.front].classList.remove("front");
          t.front = 1 - t.front;
          t.current = candidate;
          t.pending = false;
          // Release the outgoing image only after its crossfade completes.
          setTimeout(() => reserved.delete(outgoing), FADE_MS);
        };
        back.onerror = () => {
          reserved.delete(candidate);
          t.pending = false;
        };
        back.src = MOSAIC_DIR + candidate;
      }, 1800);
    });
  }

  /* ---------- Horizontal carousel helper ----------
     Overflow-aware prev/next arrows plus optional auto-advance with a
     pause/play toggle. Auto-advance and smooth scrolling both respect
     prefers-reduced-motion. Shared by the news, impact, and discovery rows. */

  const initScroller = (track, opts = {}) => {
    const { prev, next, toggle, autoplay = false, interval = 6000 } = opts;
    if (!track) return { update: () => { } };

    const hasOverflow = () => track.scrollWidth > track.clientWidth + 4;
    const atEnd = () => track.scrollLeft >= track.scrollWidth - track.clientWidth - 4;

    const update = () => {
      const overflow = hasOverflow();
      if (prev) prev.hidden = !overflow || track.scrollLeft <= 4;
      if (next) next.hidden = !overflow || atEnd();
      // The pause/play control is only meaningful when the row actually auto-scrolls.
      if (toggle) toggle.hidden = !(overflow && autoplay && !reduceMotion);
    };

    const step = () => {
      const card = track.firstElementChild;
      const gap = parseFloat(getComputedStyle(track).columnGap) || 22;
      return card ? card.getBoundingClientRect().width + gap : 320;
    };
    const slide = (dir) =>
      track.scrollBy({ left: dir * step(), behavior: reduceMotion ? "auto" : "smooth" });

    if (prev) prev.addEventListener("click", () => slide(-1));
    if (next) next.addEventListener("click", () => slide(1));
    track.addEventListener("scroll", update, { passive: true });
    new ResizeObserver(update).observe(track);
    update();

    if (autoplay && !reduceMotion) {
      let timer = null;
      let userPaused = false;

      const tick = () =>
        atEnd() ? track.scrollTo({ left: 0, behavior: "smooth" }) : slide(1);
      const start = () => {
        if (timer || userPaused || !hasOverflow()) return;
        timer = window.setInterval(tick, interval);
      };
      const stop = () => { window.clearInterval(timer); timer = null; };

      if (toggle) {
        toggle.setAttribute("aria-pressed", "false");
        toggle.addEventListener("click", () => {
          userPaused = !userPaused;
          if (userPaused) stop(); else start();
          toggle.setAttribute("aria-pressed", String(userPaused));
        });
      }
      // Transient pause while the user hovers or keyboard-focuses the row.
      track.addEventListener("pointerenter", stop);
      track.addEventListener("pointerleave", start);
      track.addEventListener("focusin", stop);
      track.addEventListener("focusout", start);

      start();
    }

    return { update };
  };

  /* ---------- News feed ----------
     Rendered from assets/data/news.json, which scripts/update_news.py
     (run daily by a GitHub Action) refreshes from cfa.harvard.edu/news. */

  const newsGrid = document.getElementById("news-grid");
  if (newsGrid) {
    const newsScroller = initScroller(newsGrid, {
      prev: document.querySelector(".news-scroller .scroll-prev"),
      next: document.querySelector(".news-scroller .scroll-next")
    });

    fetch("assets/data/news.json")
      .then((r) => (r.ok ? r.json() : Promise.reject(r.status)))
      .then((items) => {
        for (const item of items) {
          const card = document.createElement("a");
          card.className = "news-card";
          card.href = item.url;
          card.target = "_blank";
          card.rel = "noopener";

          const date = new Date(item.date + "T12:00:00");
          const dateText = isNaN(date) ? item.date
            : date.toLocaleDateString("en-US", { month: "long", day: "numeric", year: "numeric" });

          card.innerHTML = `
            ${item.image ? `<div class="news-card-photo"><img src="${item.image}" alt="" loading="lazy"></div>` : ""}
            <div class="news-card-body">
              <div class="news-card-meta"><span>${item.label}</span><time datetime="${item.date}">${dateText}</time></div>
              <h3></h3>
            </div>`;
          card.querySelector("h3").textContent = item.title;
          newsGrid.append(card);
        }
        newsScroller.update();
      })
      .catch(() => {
        const fallback = document.createElement("a");
        fallback.className = "card-link";
        fallback.href = "https://www.cfa.harvard.edu/news";
        fallback.textContent = "Read the latest discoveries at cfa.harvard.edu/news";
        newsGrid.append(fallback);
      });
  }

  /* ---------- Impact accordion ----------
     Themed disclosures, one open at a time. Bodies render open (no-JS safe);
     here we switch on the collapse, open the first row, and keep closed bodies
     out of the tab order via `inert`. */

  const impactAcc = document.getElementById("impact-accordion");
  if (impactAcc) {
    impactAcc.classList.add("js");
    const items = Array.from(impactAcc.querySelectorAll(".impact-item"));

    const setOpen = (item, open) => {
      item.classList.toggle("open", open);
      item.querySelector(".impact-acc-header").setAttribute("aria-expanded", String(open));
      item.querySelector(".impact-acc-body").inert = !open;
    };

    items.forEach((item, i) => setOpen(item, i === 0));

    items.forEach((item) => {
      item.querySelector(".impact-acc-header").addEventListener("click", () => {
        const willOpen = !item.classList.contains("open");
        items.forEach((other) => setOpen(other, false));
        if (willOpen) setOpen(item, true);
      });
    });
  }

  /* ---------- Timeline progress line ---------- */

  const timeline = document.querySelector(".timeline");
  const progress = document.querySelector(".timeline-progress");
  if (timeline && progress) {
    const updateProgress = () => {
      const rect = timeline.getBoundingClientRect();
      const viewportMid = window.innerHeight * 0.6;
      const pct = Math.max(0, Math.min(1, (viewportMid - rect.top) / rect.height));
      progress.style.height = `${pct * 100}%`;
    };
    window.addEventListener("scroll", updateProgress, { passive: true });
    updateProgress();
  }

  /* ---------- Footer year ---------- */

  document.getElementById("year").textContent = new Date().getFullYear();
})();
