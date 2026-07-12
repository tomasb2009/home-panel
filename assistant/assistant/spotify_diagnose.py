"""Quick Spotify connectivity check for the home panel."""
from __future__ import annotations

from .config import Config
from .services.spotify_service import SpotifyService


def run_spotify_diagnose(cfg: Config) -> int:
    print("=== Diagnóstico Spotify ===\n")

    if not cfg.spotify_client_id or not cfg.spotify_client_secret:
        print("Faltan SPOTIFY_CLIENT_ID / SPOTIFY_CLIENT_SECRET en assistant/.env")
        return 1

    print(f"Client ID configurado: {cfg.spotify_client_id[:6]}...{cfg.spotify_client_id[-4:]}")
    print(f"Redirect URI: {cfg.spotify_redirect_uri}\n")

    svc = SpotifyService(
        cfg.spotify_client_id,
        cfg.spotify_client_secret,
        cfg.spotify_redirect_uri,
        cfg.spotify_market,
    )
    if not svc.enabled:
        print("spotipy no está disponible o faltan credenciales.")
        return 1

    sp = svc._client()
    endpoints = [
        ("Perfil (/me)", lambda: sp.me()),
        ("Búsqueda", lambda: sp.search(q="test", type="track", limit=1, market=cfg.spotify_market)),
        ("Playlists", lambda: sp.current_user_playlists(limit=1)),
        ("Dispositivos", lambda: sp.devices()),
    ]

    ok = 0
    owner_premium_error = False
    for label, fn in endpoints:
        try:
            fn()
            print(f"  OK  {label}")
            ok += 1
        except Exception as e:  # noqa: BLE001
            msg = str(e)
            print(f"  FAIL {label}")
            print(f"       {msg[:220]}")
            if "owner of the app" in msg.lower():
                owner_premium_error = True

    print()
    if ok == len(endpoints):
        print("Todo bien. Spotify responde correctamente.")
        return 0

    if owner_premium_error:
        print("Spotify rechaza la app en modo DESARROLLO. Esto NO es un bug del panel.\n")
        print("Causas más comunes:")
        print("  1. La cuenta del Developer Dashboard (dueño de la app) NO es la misma")
        print("     que tu cuenta Premium, o Spotify no la ve como Premium.")
        print("  2. Tu usuario no está en la allowlist de la app (máx. 5 usuarios).")
        print("  3. Creaste la app con otra sesión (otro email / login con Google distinto).\n")
        print("Qué hacer (en orden):")
        print("  A) Entrá a https://developer.spotify.com/dashboard")
        print("     - abrí tu app - Settings - revisá el estado de la app")
        print("  B) Settings - User Management - Add new user")
        print("     - agregá el email EXACTO de tu cuenta Spotify Premium")
        print("  C) Cerrá sesión en el Dashboard y volvé a entrar con esa misma cuenta Premium")
        print("  D) Si la app la creó otra cuenta, creá una app NUEVA estando logueado")
        print("     con la cuenta Premium y actualizá Client ID/Secret en .env")
        print("  E) Borrá assistant/.spotify_cache y reiniciá el asistente para re-autorizar")
        print("  F) Abrí Spotify Desktop en la PC antes de probar\n")
        print("Nota: desde marzo 2026, apps en Development Mode exigen Premium del")
        print("DUEÑO de la app (cuenta del dashboard), no solo del usuario que escucha.")
        return 2

    print("Hay un error de Spotify distinto al de Premium. Revisá credenciales y token.")
    return 1
