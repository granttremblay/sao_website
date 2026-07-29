#!/usr/bin/env bash
# refresh_news.sh — cron entry point for the news feed on a self-hosted server.
#
# For deployments OUTSIDE GitHub Pages (i.e. served from your own web server),
# run this from cron once a day. It calls update_news.py, which scrapes
# cfa.harvard.edu/news and writes assets/data/news.json + assets/images/news/
# straight into the assets/ the page already fetches — no site rebuild, no git,
# no deploy step. As long as this scripts/ folder ships inside (or one level
# above assets/ in) the docroot, the refresh lands in the live files.
#
# update_news.py exits non-zero WITHOUT touching news.json if the scrape fails
# or parses fewer than 3 items, so a bad run leaves the last-good feed in place.
# This wrapper just pins a stable working dir, timestamps the log, and surfaces
# a clear failure exit code for cron / monitoring to catch.
#
# Requires: python3 + Pillow  (pip install Pillow). If system Python lacks
# Pillow, point this at a virtualenv:  PYTHON=/opt/sao/venv/bin/python
#
# Example crontab — daily at 03:17 server time, appending to a log:
#   17 3 * * * /var/www/sao_website/assets/scripts/refresh_news.sh >> /var/log/sao-news.log 2>&1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON="${PYTHON:-python3}"
stamp() { date '+%Y-%m-%d %H:%M:%S %z'; }

echo "[$(stamp)] refreshing CfA news feed…"
if "$PYTHON" "$SCRIPT_DIR/update_news.py"; then
  echo "[$(stamp)] done."
else
  status=$?
  echo "[$(stamp)] update_news.py failed (exit $status) — feed left unchanged." >&2
  exit "$status"
fi
