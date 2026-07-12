"""Spotify playback control via the Web API (requires Premium).

Lazily authenticates on first use (opens a browser once for OAuth, then caches
the token). Degrades gracefully with clear messages if not configured.
"""
from __future__ import annotations

import logging
from typing import Any

try:
    import spotipy
    from spotipy.oauth2 import SpotifyOAuth
except Exception:  # noqa: BLE001
    spotipy = None  # type: ignore
    SpotifyOAuth = None  # type: ignore

log = logging.getLogger("spotify")

_SCOPE = (
    "user-modify-playback-state user-read-playback-state "
    "user-read-currently-playing playlist-read-private "
    "user-library-read user-read-recently-played"
)


def _image_url(images: list[dict] | None, index: int = 1) -> str | None:
    if not images:
        return None
    idx = min(index, len(images) - 1)
    return images[idx].get("url")


def _artist_names(item: dict) -> str:
    artists = item.get("artists") or []
    return ", ".join(a.get("name", "") for a in artists if a.get("name"))


def _format_track(item: dict, *, context: str | None = None) -> dict:
    album = item.get("album") or {}
    return {
        "uri": item.get("uri"),
        "id": item.get("id"),
        "name": item.get("name", ""),
        "artist": _artist_names(item),
        "album": album.get("name", ""),
        "image": _image_url(album.get("images")),
        "duration_ms": item.get("duration_ms", 0),
        "context": context,
    }


def _format_album(item: dict) -> dict:
    return {
        "uri": item.get("uri"),
        "id": item.get("id"),
        "name": item.get("name", ""),
        "artist": _artist_names(item),
        "image": _image_url(item.get("images")),
        "type": "album",
    }


def _format_artist(item: dict) -> dict:
    return {
        "uri": item.get("uri"),
        "id": item.get("id"),
        "name": item.get("name", ""),
        "image": _image_url(item.get("images")),
        "type": "artist",
    }


def _format_playlist(item: dict) -> dict:
    meta = item.get("items") or item.get("tracks") or {}
    return {
        "uri": item.get("uri"),
        "id": item.get("id"),
        "name": item.get("name", ""),
        "owner": (item.get("owner") or {}).get("display_name", ""),
        "image": _image_url(item.get("images")),
        "tracks": meta.get("total", 0),
        "type": "playlist",
    }


def _search_items(results: dict, key: str) -> list[dict]:
    section = results.get(key) or {}
    raw = section.get("items") or []
    return [item for item in raw if isinstance(item, dict)]


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

    def _not_configured(self) -> dict:
        return {"ok": False, "message": "Spotify no está configurado todavía."}

    def _active_device(self, sp) -> str | None:
        """Return an active device id, transferring to the first one if needed."""
        try:
            devices = (sp.devices() or {}).get("devices", [])
        except Exception:  # noqa: BLE001
            return None
        if not devices:
            return None
        for d in devices:
            if d.get("is_active"):
                return d.get("id")
        first = devices[0].get("id")
        try:
            # force_play wakes an idle Spotify Desktop session on this PC.
            sp.transfer_playback(first, force_play=True)
        except Exception:  # noqa: BLE001
            pass
        return first

    def _spotify_error(self, e: Exception) -> dict:
        msg = str(e)
        if "owner of the app" in msg.lower():
            return {
                "ok": False,
                "message": (
                    "Spotify bloquea la app (modo desarrollo). Verificá en developer.spotify.com "
                    "que la cuenta dueña de la app tenga Premium, agregate en User Management "
                    "con tu email de Spotify, y re-autorizá borrando .spotify_cache."
                ),
            }
        if "Premium" in msg or "403" in msg:
            return {"ok": False, "message": "Controlar Spotify requiere cuenta Premium."}
        if "NO_ACTIVE_DEVICE" in msg or "No active device" in msg:
            return {
                "ok": False,
                "message": (
                    "No hay ningún dispositivo de Spotify activo. Abrí Spotify "
                    "en la PC y volvé a intentar."
                ),
            }
        return {"ok": False, "message": f"Error con Spotify: {msg}"}

    def playback_state(self) -> dict:
        if not self.enabled:
            return self._not_configured()
        sp = self._client()
        try:
            pb = sp.current_playback()
            if not pb or not pb.get("item"):
                return {"ok": True, "playing": False}
            item = pb["item"]
            return {
                "ok": True,
                "playing": pb.get("is_playing", False),
                "progress_ms": pb.get("progress_ms", 0),
                "volume": (pb.get("device") or {}).get("volume_percent", 50),
                "track": _format_track(item),
                "context": (pb.get("context") or {}).get("type"),
            }
        except Exception as e:  # noqa: BLE001
            return self._spotify_error(e)

    def search(self, query: str, kind: str = "track") -> dict:
        if not self.enabled:
            return self._not_configured()
        sp = self._client()
        query = (query or "").strip()
        if not query:
            return {"ok": False, "message": "Escribí algo para buscar."}

        kinds = (
            ["track", "album", "artist", "playlist"]
            if kind in ("all", "any", "")
            else [kind if kind in ("track", "album", "artist", "playlist") else "track"]
        )
        try:
            results = sp.search(q=query, type=",".join(kinds), limit=8, market=self.market)
            payload: dict[str, list] = {}
            if "track" in kinds:
                payload["tracks"] = [
                    _format_track(t) for t in _search_items(results, "tracks")
                ]
            if "album" in kinds:
                payload["albums"] = [
                    _format_album(a) for a in _search_items(results, "albums")
                ]
            if "artist" in kinds:
                payload["artists"] = [
                    _format_artist(a) for a in _search_items(results, "artists")
                ]
            if "playlist" in kinds:
                payload["playlists"] = [
                    _format_playlist(p) for p in _search_items(results, "playlists")
                ]
            return {"ok": True, "query": query, **payload}
        except Exception as e:  # noqa: BLE001
            return self._spotify_error(e)

    def user_playlists(self, limit: int = 20) -> dict:
        if not self.enabled:
            return self._not_configured()
        sp = self._client()
        try:
            data = sp.current_user_playlists(limit=limit)
            items = [
                _format_playlist(p)
                for p in (data.get("items") or [])
                if isinstance(p, dict)
            ]
            return {"ok": True, "playlists": items}
        except Exception as e:  # noqa: BLE001
            return self._spotify_error(e)

    def saved_tracks(self, limit: int = 20) -> dict:
        if not self.enabled:
            return self._not_configured()
        sp = self._client()
        try:
            data = sp.current_user_saved_tracks(limit=limit)
            tracks = [
                _format_track(entry["track"], context="liked")
                for entry in data.get("items", [])
                if entry.get("track")
            ]
            return {"ok": True, "tracks": tracks}
        except Exception as e:  # noqa: BLE001
            return self._spotify_error(e)

    def recently_played(self, limit: int = 20) -> dict:
        if not self.enabled:
            return self._not_configured()
        sp = self._client()
        try:
            data = sp.current_user_recently_played(limit=limit)
            tracks = [
                _format_track(entry["track"], context="recent")
                for entry in data.get("items", [])
                if entry.get("track")
            ]
            return {"ok": True, "tracks": tracks}
        except Exception as e:  # noqa: BLE001
            return self._spotify_error(e)

    def recommendations(self, limit: int = 12) -> dict:
        if not self.enabled:
            return self._not_configured()
        sp = self._client()
        try:
            recent = sp.current_user_recently_played(limit=5)
            seeds = [
                entry["track"]["id"]
                for entry in recent.get("items", [])
                if entry.get("track", {}).get("id")
            ][:5]
            if not seeds:
                featured = sp.featured_playlists(limit=1, country=self.market)
                playlists = featured.get("playlists", {}).get("items", [])
                if playlists:
                    return {
                        "ok": True,
                        "playlists": [_format_playlist(playlists[0])],
                        "tracks": [],
                    }
                return {"ok": True, "tracks": [], "playlists": []}

            recs = sp.recommendations(seed_tracks=seeds, limit=limit, market=self.market)
            tracks = [_format_track(t) for t in recs.get("tracks", [])]
            return {"ok": True, "tracks": tracks, "playlists": []}
        except Exception as e:  # noqa: BLE001
            return self._spotify_error(e)

    def play_uri(self, uri: str, context_uri: str | None = None) -> dict:
        if not self.enabled:
            return self._not_configured()
        sp = self._client()
        uri = (uri or "").strip()
        if not uri:
            return {"ok": False, "message": "No se indicó qué reproducir."}
        try:
            device_id = self._active_device(sp)
            if device_id is None:
                return {
                    "ok": False,
                    "message": (
                        "No hay ningún dispositivo de Spotify activo. Abrí Spotify "
                        "en la PC y volvé a intentar."
                    ),
                }
            if context_uri:
                sp.start_playback(device_id=device_id, context_uri=context_uri)
            elif uri.startswith("spotify:track:"):
                sp.start_playback(device_id=device_id, uris=[uri])
            else:
                sp.start_playback(device_id=device_id, context_uri=uri)
            return {"ok": True, "uri": uri}
        except Exception as e:  # noqa: BLE001
            return self._spotify_error(e)

    def play(self, query: str, kind: str = "track") -> dict:
        if not self.enabled:
            return self._not_configured()
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
            return self._spotify_error(e)

    def control(self, action: str) -> dict:
        if not self.enabled:
            return self._not_configured()
        sp = self._client()
        try:
            if action in ("resume", "play"):
                device_id = self._active_device(sp)
                if device_id is None:
                    return {
                        "ok": False,
                        "message": (
                            "No hay ningún dispositivo de Spotify activo. Abrí Spotify "
                            "Desktop en esta PC y volvé a intentar."
                        ),
                    }
                sp.start_playback(device_id=device_id)
            elif action == "pause":
                sp.pause_playback()
            elif action == "next":
                sp.next_track()
            elif action in ("previous", "prev"):
                sp.previous_track()
            else:
                return {"ok": False, "message": f"Acción desconocida: {action}"}
            return {"ok": True, "action": action}
        except Exception as e:  # noqa: BLE001
            return self._spotify_error(e)

    def set_volume(self, level: int) -> dict:
        if not self.enabled:
            return self._not_configured()
        sp = self._client()
        level = max(0, min(100, int(level)))
        try:
            device_id = self._active_device(sp)
            if device_id is None:
                return {
                    "ok": False,
                    "message": "No hay dispositivo activo para cambiar el volumen.",
                }
            sp.volume(level, device_id=device_id)
            return {"ok": True, "volume": level}
        except Exception as e:  # noqa: BLE001
            return self._spotify_error(e)

    def handle_action(self, action: str, params: dict[str, Any]) -> dict:
        """Dispatch UI / panel commands."""
        if action == "state":
            return self.playback_state()
        if action == "search":
            return self.search(params.get("query", ""), params.get("kind", "all"))
        if action == "playlists":
            return self.user_playlists(int(params.get("limit", 20)))
        if action == "saved":
            return self.saved_tracks(int(params.get("limit", 20)))
        if action == "recent":
            return self.recently_played(int(params.get("limit", 20)))
        if action == "recommendations":
            return self.recommendations(int(params.get("limit", 12)))
        if action == "play":
            return self.play_uri(params.get("uri", ""), params.get("context_uri"))
        if action == "control":
            return self.control(params.get("command", ""))
        if action == "volume":
            return self.set_volume(int(params.get("level", 50)))
        return {"ok": False, "message": f"Acción Spotify desconocida: {action}"}
