"""WebSocket bridge between the Python brain and the Flutter panel.

Protocol (JSON messages, one per frame):
  Client -> server:  {"type": "text", "text": "poné las luces del living"}
                     {"type": "listen"}   (push-to-talk voice turn)
                     {"type": "reset"}
  Server -> client:  {"type": "wake"}     (wake word detected)
                     {"type": "transcript", "text": "..."}
                     {"type": "state",  "value": "listening"|"thinking"|"speaking"|"idle"}
                     {"type": "action", "name": "set_lights", ...}
                     {"type": "say",    "text": "Listo, prendí el living."}
"""
from __future__ import annotations

import asyncio
import json
import logging
import threading

import websockets

from .brain import Brain
from .config import Config
from .services.spotify_service import SpotifyService
from .spotify_ws import handle_spotify_message
from .voice import VoiceService

log = logging.getLogger("ws")

# Transcripts shorter than this after wake word are treated as noise/echo.
_MIN_TRANSCRIPT_LEN = 4


def _is_noise_transcript(text: str) -> bool:
    """Filter echo/noise that Whisper sometimes turns into garbage text."""
    cleaned = "".join(c for c in text if c.isalnum() or c.isspace()).strip()
    if len(cleaned) < _MIN_TRANSCRIPT_LEN:
        return True
    low = cleaned.lower()
    noise = {
        "ah", "eh", "um", "uh", "mmm", "hmm", "gracias", "thank you",
        "thanks", "sí", "si", "no", "ok", "okay", "hola", "hello",
        "hey", "jarvis", "hey jarvis",
    }
    return low in noise


async def serve(
    cfg: Config,
    brain: Brain,
    voice: VoiceService | None = None,
    spotify: SpotifyService | None = None,
    lights=None,
) -> None:
    loop = asyncio.get_running_loop()
    clients: set = set()
    mic_lock = threading.Lock()
    mqtt_broker = None

    def broadcast(event: dict) -> None:
        """Thread-safe send to every connected panel."""
        if not clients:
            return
        text = json.dumps(event, ensure_ascii=False)
        for ws in list(clients):
            asyncio.run_coroutine_threadsafe(_safe_send(ws, text), loop)

    if lights is not None:
        def on_physical_light(slug: str, on: bool, source: str) -> None:
            if source != "mqtt":
                return
            broadcast({
                "type": "action",
                "name": "set_lights",
                "areas": [slug],
                "on": on,
                "source": "physical",
            })

        lights.set_state_callback(on_physical_light)

    if cfg.mqtt_embed_broker:
        from .mqtt_broker import start_embedded_broker

        mqtt_broker = await start_embedded_broker(
            cfg.mqtt_broker_bind,
            cfg.mqtt_port,
            cfg.mqtt_username,
            cfg.mqtt_password,
        )
        if mqtt_broker is None:
            log.warning("Broker MQTT embebido no pudo iniciarse")

    async def handler(ws):
        peer = getattr(ws, "remote_address", "?")
        clients.add(ws)
        log.info("Panel conectado: %s", peer)
        try:
            async for raw in ws:
                try:
                    msg = json.loads(raw)
                except json.JSONDecodeError:
                    continue

                kind = msg.get("type")
                if kind == "reset":
                    brain.reset()
                elif kind == "listen":
                    if voice is None or not voice.available:
                        broadcast({"type": "say", "text": "La voz no está disponible."})
                        broadcast({"type": "state", "value": "idle"})
                    else:
                        await asyncio.to_thread(_voice_turn, brain, voice, broadcast, mic_lock)
                elif kind == "text":
                    text = (msg.get("text") or "").strip()
                    if text:
                        broadcast({"type": "transcript", "text": text})
                        await asyncio.to_thread(brain.handle, text, broadcast)
                elif kind == "spotify" and spotify is not None:
                    result = await asyncio.to_thread(
                        handle_spotify_message, msg, spotify
                    )
                    await _safe_send(ws, json.dumps(result, ensure_ascii=False))
                elif kind == "lights" and lights is not None:
                    slug = (msg.get("id") or "").strip()
                    on = msg.get("on") is True
                    if slug:
                        await asyncio.to_thread(lights.set_light, slug, on, source="panel")
        except websockets.ConnectionClosed:
            pass
        finally:
            clients.discard(ws)
            log.info("Panel desconectado: %s", peer)

    listener = _maybe_start_listener(cfg, brain, voice, broadcast, mic_lock)

    try:
        async with websockets.serve(handler, cfg.ws_host, cfg.ws_port):
            log.info("WebSocket escuchando en ws://%s:%s", cfg.ws_host, cfg.ws_port)
            await asyncio.Future()  # run forever
    finally:
        if listener is not None:
            listener.stop()
        if mqtt_broker is not None:
            await mqtt_broker.shutdown()


async def _safe_send(ws, text: str) -> None:
    try:
        await ws.send(text)
    except Exception:  # noqa: BLE001
        pass


def _voice_turn(
    brain: Brain,
    voice: VoiceService,
    emit,
    mic_lock: threading.Lock,
    wav: bytes | None = None,
) -> None:
    """One full spoken turn: record (or use `wav`) -> transcribe -> think -> speak.

    Serialized by `mic_lock` so background listening and push-to-talk never fight.
    """
    if not mic_lock.acquire(blocking=False):
        return
    try:
        emit({"type": "state", "value": "listening"})
        if wav is not None:
            text = voice.transcribe(wav)
        else:
            text = voice.listen()
        if not text or _is_noise_transcript(text):
            log.info("Transcripción descartada (ruido/eco): %r", text)
            emit({"type": "state", "value": "idle"})
            return
        emit({"type": "transcript", "text": text})
        reply = brain.handle(text, emit)
        emit({"type": "state", "value": "speaking"})
        voice.speak(reply)
        emit({"type": "state", "value": "idle"})
    finally:
        mic_lock.release()


def _maybe_start_listener(cfg, brain, voice, broadcast, mic_lock):
    if voice is None or not voice.available:
        if cfg.always_listen_ready or cfg.wake_word_ready:
            log.warning("Escucha activada pero la voz no está disponible.")
        return None

    if cfg.always_listen_ready:
        from .always_listen import create_always_listener

        def on_speech(wav: bytes) -> None:
            broadcast({"type": "wake"})
            _voice_turn(brain, voice, broadcast, mic_lock, wav=wav)

        listener = create_always_listener(cfg, on_speech)
        if listener is not None:
            listener.start()
        return listener

    if not cfg.wake_word_ready:
        return None

    from .wake_word import create_wake_listener

    def on_wake() -> None:
        broadcast({"type": "wake"})
        _voice_turn(brain, voice, broadcast, mic_lock)

    listener = create_wake_listener(cfg, on_wake)
    if listener is not None:
        listener.start()
    return listener
