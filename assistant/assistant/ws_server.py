"""WebSocket bridge between the Python brain and the Flutter panel.

Protocol (JSON messages, one per frame):
  Client -> server:  {"type": "text", "text": "poné las luces del living"}
                     {"type": "reset"}
                     {"type": "spotify", "action": "..."}
                     {"type": "lights", "id": "living", "on": true}
  Server -> client:  {"type": "transcript", "text": "..."}
                     {"type": "state",  "value": "thinking"|"idle"}
                     {"type": "action", "name": "set_lights", ...}
                     {"type": "say",    "text": "Listo, prendí el living."}
"""
from __future__ import annotations

import asyncio
import json
import logging

import websockets

from .brain import Brain
from .config import Config
from .services.spotify_service import SpotifyService
from .spotify_ws import handle_spotify_message

log = logging.getLogger("ws")


async def serve(
    cfg: Config,
    brain: Brain,
    spotify: SpotifyService | None = None,
    lights=None,
) -> None:
    loop = asyncio.get_running_loop()
    clients: set = set()
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
        elif lights is not None:
            if lights.ensure_connected():
                log.info("Cliente MQTT del asistente conectado al broker embebido")
            else:
                log.warning("Broker MQTT activo pero el cliente de luces no conectó")

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

    try:
        async with websockets.serve(handler, cfg.ws_host, cfg.ws_port):
            log.info("WebSocket escuchando en ws://%s:%s", cfg.ws_host, cfg.ws_port)
            await asyncio.Future()  # run forever
    finally:
        if mqtt_broker is not None:
            await mqtt_broker.shutdown()


async def _safe_send(ws, text: str) -> None:
    try:
        await ws.send(text)
    except Exception:  # noqa: BLE001
        pass
