"""Events API client for pytorch.org/wp-json/tec/v1/events."""

from __future__ import annotations

import asyncio
import json
from typing import Any
from urllib.parse import urlencode
from urllib.request import Request, urlopen

EVENTS_API_BASE = "https://pytorch.org/wp-json/tribe/events/v1/events"

_USER_AGENT = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"


class EventsClient:
    """Client for the PyTorch Events API (WordPress TEC REST)."""

    async def get_events(
        self,
        *,
        start_date: str | None = None,
        end_date: str | None = None,
        search: str | None = None,
        featured: bool | None = None,
        per_page: int = 50,
    ) -> list[dict[str, Any]]:
        """Fetch events from the PyTorch Events API."""
        params: dict[str, Any] = {"per_page": per_page}
        if start_date:
            params["start_date"] = start_date
        if end_date:
            params["end_date"] = end_date
        if search:
            params["search"] = search
        if featured is not None:
            params["featured"] = str(featured).lower()

        data = await asyncio.to_thread(self._fetch, params)
        return data.get("events", [])

    @staticmethod
    def _fetch(params: dict[str, Any]) -> dict[str, Any]:
        url = f"{EVENTS_API_BASE}?{urlencode(params)}"
        req = Request(url, headers={"User-Agent": _USER_AGENT})
        with urlopen(req, timeout=30) as resp:  # noqa: S310
            return json.loads(resp.read().decode())
