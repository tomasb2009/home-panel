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
from .voice import VoiceService


def build_brain(cfg: Config) -> tuple[Brain, ToolRunner]:
    time_service = TimeService(cfg.timezone)
    weather_service = WeatherService(
        cfg.latitude, cfg.longitude, cfg.timezone, cfg.location_name
    )
    lights_service = LightsService(
        cfg.mqtt_host, cfg.mqtt_port, cfg.mqtt_username, cfg.mqtt_password,
        cfg.mqtt_lights_prefix, cfg.mqtt_lights_on, cfg.mqtt_lights_off,
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


def run_cli(cfg: Config, voice_mode: bool = False) -> None:
    brain, runner = build_brain(cfg)
    if runner.lights.simulated:
        print("  (luces en modo SIMULADO: MQTT sin configurar)")
    if not runner.spotify.enabled:
        print("  (Spotify sin configurar)")

    voice = VoiceService(cfg) if voice_mode else None
    if voice_mode and (voice is None or not voice.available):
        print("Audio no disponible. Instalá sounddevice/numpy o usá el modo texto.", file=sys.stderr)
        return

    try:
        if voice_mode:
            print(f"— {cfg.assistant_name} en modo voz. Enter para hablar, 'q'+Enter para salir.")
            while True:
                cmd = input("[Enter para hablar] ").strip().lower()
                if cmd in {"q", "salir", "exit", "quit"}:
                    break
                print("  escuchando…")
                text = voice.listen()  # type: ignore[union-attr]
                if not text:
                    print("  (no te escuché)")
                    continue
                print(f"  vos: {text}")
                reply = brain.handle(text, _print_event)
                voice.speak(reply)  # type: ignore[union-attr]
        else:
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

    brain, runner = build_brain(cfg)
    voice = VoiceService(cfg)
    if not voice.available:
        print("  (voz no disponible: sin sounddevice/numpy o sin micrófono)")
    if cfg.wake_word_ready:
        print("  (wake word activada)")
    elif cfg.wake_word_enabled:
        print("  (wake word: configuración incompleta — revisá .env)")
    else:
        print("  (wake word desactivada — poné WAKE_WORD_ENABLED=true en .env)")
    try:
        asyncio.run(serve(cfg, brain, voice))
    except KeyboardInterrupt:
        pass
    finally:
        runner.lights.close()


def main() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
        datefmt="%H:%M:%S",
    )
    parser = argparse.ArgumentParser(description="Home Panel voice assistant brain")
    parser.add_argument("--serve", action="store_true", help="Run the WebSocket server")
    parser.add_argument("--voice", action="store_true", help="CLI en modo voz (push-to-talk)")
    parser.add_argument("--list-mics", action="store_true", help="Listar micrófonos disponibles")
    args = parser.parse_args()

    cfg = load_config()
    if not cfg.openai_api_key and not args.list_mics:
        print("Falta OPENAI_API_KEY. Copiá .env.example a .env y completalo.", file=sys.stderr)
        sys.exit(1)

    if args.list_mics:
        from . import audio_io
        print("Micrófonos de entrada detectados:")
        for line in audio_io.list_input_devices():
            print(line)
        mic = audio_io.resolve_mic(cfg.mic_device)
        if mic:
            print(f"\nSeleccionado: {mic.label}")
        else:
            print("\nNo se pudo abrir ningún micrófono.")
        return

    if args.serve:
        run_server(cfg)
    else:
        run_cli(cfg, voice_mode=args.voice)


if __name__ == "__main__":
    main()
