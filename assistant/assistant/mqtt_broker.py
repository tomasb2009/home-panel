"""Embedded MQTT broker for the Raspberry Pi (runs 24/7 with --serve).

Uses aMQTT (asyncio) so it shares the same event loop as the WebSocket server.
ESP32 switches connect to MQTT_BROKER_BIND:MQTT_PORT (default 0.0.0.0:1883).
"""
from __future__ import annotations

import logging
from typing import Any

log = logging.getLogger("mqtt.broker")

try:
    from amqtt.broker import Broker
except Exception:  # noqa: BLE001
    Broker = None  # type: ignore[misc, assignment]


def broker_config(bind_host: str, port: int, username: str, password: str) -> dict[str, Any]:
    """Build an aMQTT config dict from assistant settings."""
    cfg: dict[str, Any] = {
        "listeners": {
            "default": {
                "type": "tcp",
                "bind": f"{bind_host}:{port}",
            },
        },
        "plugins": {
            "amqtt.plugins.logging_amqtt.EventLoggerPlugin": {},
            "amqtt.plugins.sys.broker.BrokerSysPlugin": {"sys_interval": 20},
        },
    }

    if username:
        # Home LAN: prefer anonymous on ESP32; auth plugin left for future use.
        log.warning(
            "MQTT broker embebido: auth de usuario no implementado aún; "
            "dejá MQTT_USERNAME vacío o usá Mosquitto externo."
        )

    cfg["plugins"]["amqtt.plugins.authentication.AnonymousAuthPlugin"] = {
        "allow_anonymous": True,
    }

    return cfg


async def start_embedded_broker(
    bind_host: str,
    port: int,
    username: str = "",
    password: str = "",
) -> Broker | None:
    """Start the broker and return the instance (call shutdown() on exit)."""
    if Broker is None:
        log.error("amqtt no instalado. Corré: pip install amqtt")
        return None

    broker = Broker(broker_config(bind_host, port, username, password))
    await broker.start()
    log.info("Broker MQTT escuchando en %s:%s", bind_host, port)
    return broker


async def run_standalone(bind_host: str, port: int, username: str, password: str) -> None:
    """Run only the broker until interrupted (for systemd on the Pi)."""
    import asyncio

    broker = await start_embedded_broker(bind_host, port, username, password)
    if broker is None:
        raise SystemExit(1)
    try:
        await asyncio.Future()
    finally:
        await broker.shutdown()
