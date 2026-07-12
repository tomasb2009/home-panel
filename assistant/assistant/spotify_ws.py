"""WebSocket handler for direct Spotify UI commands (no LLM)."""
from __future__ import annotations

import logging
from typing import Any

from .services.spotify_service import SpotifyService

log = logging.getLogger("spotify_ws")


def handle_spotify_message(msg: dict, spotify: SpotifyService) -> dict:
    action = (msg.get("action") or "").strip()
    params = {k: v for k, v in msg.items() if k not in ("type", "action", "request_id")}
    result = spotify.handle_action(action, params)
    payload: dict[str, Any] = {"type": "spotify", "action": action, **result}
    request_id = msg.get("request_id")
    if request_id is not None:
        payload["request_id"] = request_id
    if not result.get("ok", True) and result.get("message"):
        log.info("Spotify %s: %s", action, result["message"])
    return payload
