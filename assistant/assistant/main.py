"""Entrypoint. Two modes:

  python -m assistant            -> interactive text REPL (test the brain)
  python -m assistant --serve    -> WebSocket server for the Flutter panel
"""
from __future__ import annotations

import argparse
import asyncio
import logging
import sys

from .brain import Brain
from .config import Config, load_config
from .services.lights_service import LightsService
from .services.memory_service import MemoryService
from .services.spotify_service import SpotifyService
from .services.time_service import TimeService
from .services.weather_service import WeatherService
from .tools import ToolRunner


def build_brain(cfg: Config, *, defer_mqtt: bool = False) -> tuple[Brain, ToolRunner]:
    time_service = TimeService(cfg.timezone)
    weather_service = WeatherService(
        cfg.latitude, cfg.longitude, cfg.timezone, cfg.location_name
    )
    lights_service = LightsService(
        cfg.mqtt_client_host, cfg.mqtt_port, cfg.mqtt_username, cfg.mqtt_password,
        cfg.mqtt_lights_prefix, cfg.mqtt_lights_on, cfg.mqtt_lights_off,
        defer_connect=defer_mqtt,
    )
    spotify_service = SpotifyService(
        cfg.spotify_client_id, cfg.spotify_client_secret,
        cfg.spotify_redirect_uri, cfg.spotify_market,
    )
    memory_service = MemoryService()
    runner = ToolRunner(
        time_service, weather_service, lights_service, spotify_service, memory_service
    )
    return Brain(cfg, runner), runner


def _print_event(event: dict) -> None:
    kind = event.get("type")
    if kind == "state":
        return
    if kind == "action":
        print(f"  · acción: {event}")
    elif kind == "say":
        print(f"\n{event.get('text', '')}\n")


def run_cli(cfg: Config) -> None:
    brain, runner = build_brain(cfg)
    if runner.lights.simulated:
        print("  (luces en modo SIMULADO: MQTT sin configurar)")
    if not runner.spotify.enabled:
        print("  (Spotify sin configurar)")

    try:
        print(f"— {cfg.assistant_name} lista. Escribí un comando (o 'salir').")
        while True:
            try:
                text = input("> ").strip()
            except EOFError:
                break
            if not text:
                continue
            if text.lower() in {"salir", "exit", "quit"}:
                break
            brain.handle(text, _print_event)
    finally:
        runner.lights.close()


def run_server(cfg: Config) -> None:
    from .ws_server import serve

    brain, runner = build_brain(cfg, defer_mqtt=cfg.mqtt_embed_broker)
    if cfg.mqtt_embed_broker:
        print(f"  (broker MQTT embebido en {cfg.mqtt_broker_bind}:{cfg.mqtt_port})")
    elif runner.lights.simulated:
        print("  (luces en modo SIMULADO: MQTT sin configurar)")
    if not runner.spotify.enabled:
        print("  (Spotify sin configurar — completá SPOTIFY_CLIENT_ID/SECRET en .env)")
    elif cfg.spotify_enabled:
        print("  (Spotify listo — abrí Spotify Desktop en esta PC)")
    try:
        asyncio.run(serve(cfg, brain, runner.spotify, runner.lights))
    except KeyboardInterrupt:
        pass
    finally:
        runner.lights.close()


def run_mqtt_broker(cfg: Config) -> None:
    from .mqtt_broker import run_standalone

    print(f"Broker MQTT en {cfg.mqtt_broker_bind}:{cfg.mqtt_port} (Ctrl+C para salir)")
    try:
        asyncio.run(
            run_standalone(
                cfg.mqtt_broker_bind,
                cfg.mqtt_port,
                cfg.mqtt_username,
                cfg.mqtt_password,
            )
        )
    except KeyboardInterrupt:
        pass


def main() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
        datefmt="%H:%M:%S",
    )
    parser = argparse.ArgumentParser(description="Home Panel assistant brain")
    parser.add_argument("--serve", action="store_true", help="Run the WebSocket server")
    parser.add_argument(
        "--mqtt-broker",
        action="store_true",
        help="Run only the embedded MQTT broker (for systemd on the Pi)",
    )
    parser.add_argument("--spotify-diagnose", action="store_true", help="Probar conexión con Spotify")
    args = parser.parse_args()

    cfg = load_config()
    if not cfg.openai_api_key and not args.spotify_diagnose and not args.mqtt_broker:
        print("Falta OPENAI_API_KEY. Copiá .env.example a .env y completalo.", file=sys.stderr)
        sys.exit(1)

    if args.spotify_diagnose:
        from .spotify_diagnose import run_spotify_diagnose
        sys.exit(run_spotify_diagnose(cfg))

    if args.mqtt_broker:
        run_mqtt_broker(cfg)
    elif args.serve:
        run_server(cfg)
    else:
        run_cli(cfg)


if __name__ == "__main__":
    main()
