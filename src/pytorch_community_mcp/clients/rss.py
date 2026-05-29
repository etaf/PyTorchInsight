"""RSS feed parser for pytorch.org/blog/feed/."""

from __future__ import annotations

from typing import Any
from urllib.request import Request, urlopen

import feedparser

PYTORCH_RSS_URL = "https://pytorch.org/blog/feed/"

_USER_AGENT = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"


class RSSClient:
    """feedparser wrapper for PyTorch blog RSS."""

    def get_entries(self) -> list[dict[str, Any]]:
        """Parse the PyTorch RSS feed and return entries."""
        req = Request(PYTORCH_RSS_URL, headers={"User-Agent": _USER_AGENT})
        with urlopen(req, timeout=15) as resp:  # noqa: S310
            body = resp.read().decode()

        feed = feedparser.parse(body)
        entries = []
        for entry in feed.entries:
            published = ""
            if hasattr(entry, "published_parsed") and entry.published_parsed:
                from time import strftime
                published = strftime("%Y-%m-%d", entry.published_parsed)

            entries.append(
                {
                    "title": entry.get("title", ""),
                    "url": entry.get("link", ""),
                    "date": published,
                    "author": entry.get("author", ""),
                    "summary": entry.get("summary", "")[:300],
                }
            )
        return entries
