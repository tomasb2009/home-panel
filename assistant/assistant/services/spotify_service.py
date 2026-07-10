"""Spotify playback control via the Web API (requires Premium).

Lazily authenticates on first use (opens a browser once for OAuth, then caches
the token). Degrades gracefully with clear messages if not configured.
"""
from __future__ import annotations

import logging

try:
    import spotipy
    from spotipy.oauth2 import SpotifyOAuth
except Exception:  # noqa: BLE001
    spotipy = None  # type: ignore
    SpotifyOAuth = None  # type: ignore

log = logging.getLogger("spotify")

_SCOPE = (
    "user-modify-playback-state user-read-playback-state "
    "playlist-read-private user-read-currently-playing"
)


class SpotifyService:
    def __init__(
        self,
        client_id: str,
        client_secret: str,
        redirect_uri: str,
        market: str,
        cache_path: str = ".spotify_cache",
    ) -> None:
        self.enabled = bool(client_id and client_secret and spotipy is not None)
        self.market = market or "AR"
        self._sp = None
        if self.enabled:
            self._auth = SpotifyOAuth(
                client_id=client_id,
                client_secret=client_secret,
                redirect_uri=redirect_uri,
                scope=_SCOPE,
                cache_path=cache_path,
                open_browser=True,
            )

    def _client(self):
        if not self.enabled:
            return None
        if self._sp is None:
            self._sp = spotipy.Spotify(auth_manager=self._auth)
        return self._sp

    def _active_device(self, sp) -> str | None:
        """Return an active device id, transferring to the first one if needed."""
        try:
            devices = sp.devices().get("devices", [])
        except Exception:  # noqa: BLE001
            return None
        if not devices:
            return None
        for d in devices:
            if d.get("is_active"):
                return d.get("id")
        first = devices[0].get("id")
        try:
            sp.transfer_playback(first, force_play=False)
        except Exception:  # noqa: BLE001
            pass
        return first

    def play(self, query: str, kind: str = "track") -> dict:
        if not self.enabled:
            return {"ok": False, "message": "Spotify no está configurado todavía."}
        sp = self._client()
        kind = kind if kind in ("track", "playlist", "album", "artist") else "track"

        try:
            results = sp.search(q=query, type=kind, limit=1, market=self.market)
            items = results.get(f"{kind}s", {}).get("items", [])
            if not items:
                return {"ok": False, "message": f"No encontré '{query}' en Spotify."}
            item = items[0]
            name = item.get("name", query)

            device_id = self._active_device(sp)
            if device_id is None:
                return {
                    "ok": False,
                    "message": (
                        "No hay ningún dispositivo de Spotify activo. Abrí Spotify "
                        "en algún parlante o dispositivo y volvé a intentar."
                    ),
                }

            if kind == "track":
                sp.start_playback(device_id=device_id, uris=[item["uri"]])
                artist = item.get("artists", [{}])[0].get("name", "")
                label = f"{name} de {artist}" if artist else name
            else:
                sp.start_playback(device_id=device_id, context_uri=item["uri"])
                label = name

            return {"ok": True, "kind": kind, "name": name, "playing": label}
        except Exception as e:  # noqa: BLE001
            msg = str(e)
            if "Premium" in msg or "403" in msg:
                return {"ok": False, "message": "Controlar Spotify requiere cuenta Premium."}
            return {"ok": False, "message": f"Error con Spotify: {msg}"}

    def control(self, action: str) -> dict:
        if not self.enabled:
            return {"ok": False, "message": "Spotify no está configurado todavía."}
        sp = self._client()
        try:
            if action == "pause":
                sp.pause_playback()
            elif action in ("resume", "play"):
                sp.start_playback()
            elif action == "next":
                sp.next_track()
            elif action in ("previous", "prev"):
                sp.previous_track()
            else:
                return {"ok": False, "message": f"Acción desconocida: {action}"}
            return {"ok": True, "action": action}
        except Exception as e:  # noqa: BLE001
            return {"ok": False, "message": f"Error con Spotify: {e}"}
