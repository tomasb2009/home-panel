"""Light control over MQTT for the ESP32 devices.

If no broker is configured (MQTT_HOST empty) it runs in SIMULATED mode: it just
logs the topic/payload it *would* publish and keeps an in-memory state, so the
whole assistant can be developed and tested before the WiFi switches exist.
"""
from __future__ import annotations

import logging

try:
    import paho.mqtt.client as mqtt
except Exception:  # noqa: BLE001
    mqtt = None  # type: ignore

log = logging.getLogger("lights")

# Human area name (and aliases the LLM might pass) -> canonical topic slug.
AREAS = {
    "living": "living",
    "comedor": "comedor",
    "patio": "patio",
    "patio trasero": "patio",
    "patio_trasero": "patio",
    "fondo": "patio",
}


class LightsService:
    def __init__(
        self,
        host: str,
        port: int,
        username: str,
        password: str,
        prefix: str,
        payload_on: str,
        payload_off: str,
    ) -> None:
        self.prefix = prefix.rstrip("/")
        self.payload_on = payload_on
        self.payload_off = payload_off
        self._state: dict[str, bool] = {"living": False, "comedor": False, "patio": False}
        self._client = None
        self._connected = False

        if host and mqtt is not None:
            try:
                client = mqtt.Client(
                    mqtt.CallbackAPIVersion.VERSION2,
                    client_id="home-panel-assistant",
                )
                if username:
                    client.username_pw_set(username, password)
                client.connect(host, port, keepalive=30)
                client.loop_start()
                self._client = client
                self._connected = True
                log.info("MQTT conectado a %s:%s", host, port)
            except Exception as e:  # noqa: BLE001
                log.warning("No pude conectar a MQTT (%s). Modo simulado.", e)
        else:
            log.info("MQTT sin configurar. Luces en modo simulado.")

    @property
    def simulated(self) -> bool:
        return not self._connected

    def _resolve(self, area: str) -> str | None:
        return AREAS.get(area.strip().lower())

    def set_light(self, area: str, on: bool) -> dict:
        slug = self._resolve(area)
        if slug is None:
            return {
                "ok": False,
                "message": f"No conozco el área '{area}'. Disponibles: living, comedor, patio trasero.",
            }

        topic = f"{self.prefix}/{slug}/set"
        payload = self.payload_on if on else self.payload_off
        self._state[slug] = on

        if self._connected and self._client is not None:
            try:
                self._client.publish(topic, payload, qos=1, retain=True)
            except Exception as e:  # noqa: BLE001
                return {"ok": False, "message": f"Error publicando en MQTT: {e}"}
        else:
            log.info("[SIMULADO] publish %s -> %s", topic, payload)

        return {
            "ok": True,
            "area": slug,
            "on": on,
            "topic": topic,
            "simulated": self.simulated,
        }

    def set_many(self, areas: list[str], on: bool) -> dict:
        results = [self.set_light(a, on) for a in areas]
        applied = [r["area"] for r in results if r.get("ok")]
        errors = [r["message"] for r in results if not r.get("ok")]
        return {
            "ok": not errors or bool(applied),
            "applied": applied,
            "on": on,
            "errors": errors,
            "simulated": self.simulated,
        }

    def state(self) -> dict:
        return dict(self._state)

    def close(self) -> None:
        if self._client is not None:
            try:
                self._client.loop_stop()
                self._client.disconnect()
            except Exception:  # noqa: BLE001
                pass
