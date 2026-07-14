"""Light control over MQTT for the ESP32 devices (Sonoff SwitchMan 3G).

Topic layout (matches the ESP32 firmware):
  {prefix}/relay1/set|state   -> living
  {prefix}/relay2/set|state   -> comedor
  {prefix}/relay3/set|state   -> patio

If no broker is reachable it runs in SIMULATED mode: it logs what it would
publish and keeps an in-memory state for development without hardware.
"""
from __future__ import annotations

import logging
import re
from collections.abc import Callable

try:
    import paho.mqtt.client as mqtt
except Exception:  # noqa: BLE001
    mqtt = None  # type: ignore

log = logging.getLogger("lights")

# Individual light slugs (match Flutter LightsModel device ids).
DEVICE_IDS = ("living", "comedor", "patio")

# Slug -> relay index on the 3-gang switch (1-based, as in firmware topics).
SLUG_TO_RELAY: dict[str, int] = {
    "living": 1,
    "comedor": 2,
    "patio": 3,
}
RELAY_TO_SLUG: dict[int, str] = {v: k for k, v in SLUG_TO_RELAY.items()}

StateCallback = Callable[[str, bool, str], None]

# Spoken / LLM target -> one or more device slugs.
AREA_GROUPS: dict[str, list[str]] = {
    "living": ["living"],
    "comedor": ["comedor"],
    "patio": ["patio"],
    "patio trasero": ["patio"],
    "patio_trasero": ["patio"],
    "fondo": ["patio"],
    # Rooms (match the Flutter dashboard cards).
    "sala de estar": ["living", "comedor"],
    "sala_de_estar": ["living", "comedor"],
    "sala": ["living", "comedor"],
    "estar": ["living", "comedor"],
    # Whole home.
    "todas": list(DEVICE_IDS),
    "todas las luces": list(DEVICE_IDS),
    "todo": list(DEVICE_IDS),
    "casa": list(DEVICE_IDS),
    "todas las luces de la casa": list(DEVICE_IDS),
}


def expand_areas(areas: list[str]) -> list[str]:
    """Turn tool areas (possibly room groups) into concrete device slugs."""
    expanded: list[str] = []
    for raw in areas:
        key = raw.strip().lower().replace("_", " ")
        group = AREA_GROUPS.get(key)
        if group:
            expanded.extend(group)
        elif key in DEVICE_IDS:
            expanded.append(key)
    # Dedupe, preserve order.
    seen: set[str] = set()
    out: list[str] = []
    for slug in expanded:
        if slug not in seen:
            seen.add(slug)
            out.append(slug)
    return out


_ALL_HINTS = (
    "toda la casa",
    "toda la luz",
    "apaga todo",
    "apagá todo",
    "prende todo",
    "prendé todo",
    "apagar todo",
    "prender todo",
)
_SALA_HINTS = (
    "sala de estar",
    "sala del estar",
    "luces de la sala",
    "luces del living y comedor",
    "living y comedor",
    "del living y del comedor",
)
_PATIO_HINTS = (
    "patio trasero",
    "del patio",
    "en el patio",
    "luces del patio",
    "la del patio",
)


def _wants_all(t: str) -> bool:
    """User asked to affect every light in some scope (room or whole home)."""
    if any(h in t for h in _ALL_HINTS):
        return True
    if "todas" in t:
        return True
    return bool(re.search(r"\btodo\b", t))


def _mentions_sala(t: str) -> bool:
    return any(h in t for h in _SALA_HINTS)


def _mentions_patio(t: str) -> bool:
    return any(h in t for h in _PATIO_HINTS)


def normalize_light_areas(user_text: str, areas: list[str]) -> list[str]:
    """Fix common LLM mistakes without breaking multi-action commands."""
    if not areas:
        return areas

    t = user_text.lower()
    raw = [a.strip().lower() for a in areas]

    # Trust explicit per-call targets (e.g. patio on while sala off in same turn).
    _EXPLICIT = frozenset({
        "living", "comedor", "patio",
        "sala_de_estar", "patio_trasero", "todas",
    })
    if any(a in _EXPLICIT for a in raw):
        expanded = expand_areas(areas)
        if raw == ["todas"]:
            if _wants_all(t) and _mentions_sala(t) and not _mentions_patio(t):
                return ["sala_de_estar"]
            if _wants_all(t) and _mentions_patio(t) and not _mentions_sala(t):
                return ["patio_trasero"]
            return areas
        if _mentions_sala(t) and expanded in (["living"], ["comedor"]):
            return ["sala_de_estar"]
        return areas

    expanded = expand_areas(areas)

    if _wants_all(t):
        if _mentions_sala(t) and _mentions_patio(t):
            return areas
        if _mentions_sala(t):
            return ["sala_de_estar"]
        if _mentions_patio(t):
            return ["patio_trasero"]
        return ["todas"]

    if _mentions_sala(t) and expanded in (["living"], ["comedor"], ["living", "comedor"]):
        return ["sala_de_estar"]

    return areas


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
        *,
        defer_connect: bool = False,
    ) -> None:
        self._host = host
        self._port = port
        self._username = username
        self._password = password
        self.prefix = prefix.rstrip("/")
        self.payload_on = payload_on
        self.payload_off = payload_off
        self._state: dict[str, bool] = {d: False for d in DEVICE_IDS}
        self._client: mqtt.Client | None = None
        self._connected = False
        self._state_callback: StateCallback | None = None
        self._updating_from_mqtt = False

        if host and mqtt is not None and not defer_connect:
            self.ensure_connected()
        elif not host:
            log.info("MQTT sin configurar. Luces en modo simulado.")

    def ensure_connected(self) -> bool:
        """Connect (or reconnect) to the broker. Safe to call after embed broker starts."""
        if not self._host or mqtt is None:
            return False
        if self._connected and self._client is not None:
            return True

        try:
            client = mqtt.Client(
                mqtt.CallbackAPIVersion.VERSION2,
                client_id="home-panel-assistant",
            )
            if self._username:
                client.username_pw_set(self._username, self._password)
            client.on_message = self._on_message
            client.connect(self._host, self._port, keepalive=30)
            client.loop_start()
            self._client = client
            self._connected = True
            self._subscribe_state_topics()
            log.info("MQTT conectado a %s:%s", self._host, self._port)
            return True
        except Exception as e:  # noqa: BLE001
            log.warning("No pude conectar a MQTT (%s). Modo simulado.", e)
            self._connected = False
            self._client = None
            return False

    def set_state_callback(self, callback: StateCallback | None) -> None:
        """Called when relay state changes (physical button or remote /set)."""
        self._state_callback = callback

    @property
    def simulated(self) -> bool:
        return not self._connected

    def _relay_topic(self, relay: int, suffix: str) -> str:
        return f"{self.prefix}/relay{relay}/{suffix}"

    def _slug_for_topic(self, topic: str) -> str | None:
        for relay, slug in RELAY_TO_SLUG.items():
            if topic == self._relay_topic(relay, "state"):
                return slug
        return None

    def _subscribe_state_topics(self) -> None:
        if self._client is None:
            return
        for relay in RELAY_TO_SLUG:
            topic = self._relay_topic(relay, "state")
            self._client.subscribe(topic)
            log.debug("Suscrito a %s", topic)

    def _on_message(self, client, userdata, msg) -> None:  # noqa: ANN001, ARG002
        slug = self._slug_for_topic(msg.topic)
        if slug is None:
            return

        payload = msg.payload.decode("utf-8", errors="replace").strip().upper()
        if payload == self.payload_on.upper():
            on = True
        elif payload == self.payload_off.upper():
            on = False
        else:
            return

        if self._state.get(slug) == on:
            return

        self._state[slug] = on
        log.info("Estado físico %s -> %s (topic %s)", slug, "ON" if on else "OFF", msg.topic)

        if self._state_callback is not None:
            self._updating_from_mqtt = True
            try:
                self._state_callback(slug, on, "mqtt")
            finally:
                self._updating_from_mqtt = False

    def set_light(self, slug: str, on: bool, *, source: str = "assistant") -> dict:
        if slug not in DEVICE_IDS:
            return {
                "ok": False,
                "message": (
                    f"No conozco el área '{slug}'. "
                    "Disponibles: living, comedor, patio, sala de estar, todas."
                ),
            }

        relay = SLUG_TO_RELAY[slug]
        topic = self._relay_topic(relay, "set")
        payload = self.payload_on if on else self.payload_off
        self._state[slug] = on

        if self._connected and self._client is not None:
            try:
                # Commands on /set are not retained; ESP32 publishes retained /state.
                self._client.publish(topic, payload, qos=1, retain=False)
            except Exception as e:  # noqa: BLE001
                return {"ok": False, "message": f"Error publicando en MQTT: {e}"}
        else:
            log.info("[SIMULADO] publish %s -> %s", topic, payload)

        if self._state_callback is not None and not self._updating_from_mqtt:
            self._state_callback(slug, on, source)

        return {
            "ok": True,
            "area": slug,
            "on": on,
            "topic": topic,
            "simulated": self.simulated,
        }

    def set_many(self, areas: list[str], on: bool) -> dict:
        slugs = expand_areas(areas)
        if not slugs:
            return {
                "ok": False,
                "message": "No reconocí ninguna zona. Usá living, comedor, patio, sala de estar o todas.",
                "applied": [],
                "on": on,
            }
        results = [self.set_light(slug, on) for slug in slugs]
        applied = [r["area"] for r in results if r.get("ok")]
        errors = [r["message"] for r in results if not r.get("ok")]
        return {
            "ok": not errors or bool(applied),
            "applied": applied,
            "requested": areas,
            "on": on,
            "errors": errors,
            "simulated": self.simulated,
        }

    def state(self) -> dict[str, bool]:
        return dict(self._state)

    def close(self) -> None:
        if self._client is not None:
            try:
                self._client.loop_stop()
                self._client.disconnect()
            except Exception:  # noqa: BLE001
                pass
