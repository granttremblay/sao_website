#!/usr/bin/env python3
"""Refresh the homepage "Latest from the CfA" feed.

Scrapes the Recent News Releases list on https://www.cfa.harvard.edu/news,
downloads and web-optimizes each item's image, and writes
assets/data/news.json for assets/js/main_v4.js to render. Run manually or via the
scheduled GitHub Action (.github/workflows/update-news.yml).

Requires: Pillow  (pip install Pillow)
"""

import hashlib
import html
import io
import json
import pathlib
import re
import sys
import urllib.request

from PIL import Image

NEWS_URL = "https://www.cfa.harvard.edu/news"
MAX_ITEMS = 6
IMG_WIDTH = 700
REPO = pathlib.Path(__file__).resolve().parent.parent.parent
IMG_DIR = REPO / "assets" / "images" / "news"
DATA_FILE = REPO / "assets" / "data" / "news.json"

UA = {"User-Agent": "Mozilla/5.0 (SAO website news updater)"}


def fetch(url: str) -> bytes:
    return urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=30).read()


def main() -> int:
    page = fetch(NEWS_URL).decode("utf-8", "replace")

    # Each item: <a class="copy-box" href="..."> ... news-photo-frame url('...')
    # ... <time datetime="..."> ... <h4>Title</h4>
    pattern = re.compile(
        r'<a class="copy-box" href="(?P<url>[^"]+)">.*?'
        r"news-photo-frame[^>]*url\('(?P<img>[^']+)'\).*?"
        r'datetime="(?P<date>[^"]+)".*?'
        r'<div class="label">(?P<label>[^<]*)</div>.*?'
        r"<h4>(?P<title>.*?)</h4>",
        re.S,
    )

    items = []
    for m in pattern.finditer(page):
        if len(items) >= MAX_ITEMS:
            break
        url = m["url"]
        slug = hashlib.md5(url.encode()).hexdigest()[:10]
        img_name = f"news_{slug}.jpg"
        img_path = IMG_DIR / img_name

        if not img_path.exists():
            try:
                raw = fetch(html.unescape(m["img"]))
                im = Image.open(io.BytesIO(raw)).convert("RGB")
                if im.width > IMG_WIDTH:
                    im = im.resize((IMG_WIDTH, round(im.height * IMG_WIDTH / im.width)))
                IMG_DIR.mkdir(parents=True, exist_ok=True)
                im.save(img_path, "JPEG", quality=75)
            except Exception as e:  # noqa: BLE001 — a bad image shouldn't kill the feed
                print(f"warn: image failed for {url}: {e}", file=sys.stderr)
                img_name = None

        items.append(
            {
                "title": html.unescape(re.sub(r"<[^>]+>", "", m["title"])).strip(),
                "url": url,
                "date": m["date"][:10],
                "label": html.unescape(m["label"]).strip() or "News",
                "image": f"assets/images/news/{img_name}" if img_name else None,
            }
        )

    if len(items) < 3:
        print(f"error: only parsed {len(items)} items — page layout may have changed", file=sys.stderr)
        return 1

    DATA_FILE.parent.mkdir(parents=True, exist_ok=True)
    DATA_FILE.write_text(json.dumps(items, indent=2) + "\n")

    # Prune cached images that no longer appear in the feed
    keep = {pathlib.Path(i["image"]).name for i in items if i["image"]}
    for old in IMG_DIR.glob("news_*.jpg"):
        if old.name not in keep:
            old.unlink()

    print(f"wrote {DATA_FILE.relative_to(REPO)} with {len(items)} items")
    return 0


if __name__ == "__main__":
    sys.exit(main())
