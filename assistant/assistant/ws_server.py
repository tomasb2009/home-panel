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
from .voice import VoiceService

log = logging.getLogger("ws")


async def serve(cfg: Config, brain: Brain, voice: VoiceService | None = None) -> None:
    loop = asyncio.get_running_loop()
    clients: set = set()
    mic_lock = threading.Lock()

    def broadcast(event: dict) -> None:
        """Thread-safe send to every connected panel."""
        if not clients:
            return
        text = json.dumps(event, ensure_ascii=False)
        for ws in list(clients):
            asyncio.run_coroutine_threadsafe(_safe_send(ws, text), loop)

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
        except websockets.ConnectionClosed:
            pass
        finally:
            clients.discard(ws)
            log.info("Panel desconectado: %s", peer)

    listener = _maybe_start_wake_word(cfg, brain, voice, broadcast, mic_lock)

    try:
        async with websockets.serve(handler, cfg.ws_host, cfg.ws_port):
            log.info("WebSocket escuchando en ws://%s:%s", cfg.ws_host, cfg.ws_port)
            await asyncio.Future()  # run forever
    finally:
        if listener is not None:
            listener.stop()


async def _safe_send(ws, text: str) -> None:
    try:
        await ws.send(text)
    except Exception:  # noqa: BLE001
        pass


def _voice_turn(brain: Brain, voice: VoiceService, emit, mic_lock: threading.Lock) -> None:
    """One full spoken turn: record -> transcribe -> think -> speak.

    Serialized by `mic_lock` so wake word and push-to-talk never fight the mic.
    """
    if not mic_lock.acquire(blocking=False):
        return  # a turn is already in progress
    try:
        emit({"type": "state", "value": "listening"})
        text = voice.listen()
        if not text:
            emit({"type": "say", "text": "No te escuché, ¿probamos de nuevo?"})
            emit({"type": "state", "value": "idle"})
            return
        emit({"type": "transcript", "text": text})
        reply = brain.handle(text, emit)
        emit({"type": "state", "value": "speaking"})
        voice.speak(reply)
        emit({"type": "state", "value": "idle"})
    finally:
        mic_lock.release()


def _maybe_start_wake_word(cfg, brain, voice, broadcast, mic_lock):
    if not cfg.wake_word_ready:
        return None
    if voice is None or not voice.available:
        log.warning("Wake word activada pero la voz no está disponible.")
        return None

    from .wake_word import WakeWordListener

    def on_wake() -> None:
        broadcast({"type": "wake"})
        _voice_turn(brain, voice, broadcast, mic_lock)

    listener = WakeWordListener(cfg, on_wake)
    listener.start()
    return listener
