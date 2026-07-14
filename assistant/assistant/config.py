"""Central configuration, loaded once from environment / .env file."""
from __future__ import annotations

import os
from dataclasses import dataclass

from dotenv import load_dotenv

load_dotenv()


def _get(name: str, default: str = "") -> str:
    return os.getenv(name, default).strip()


def _get_int(name: str, default: int) -> int:
    raw = os.getenv(name)
    if raw is None or not raw.strip():
        return default
    try:
        return int(raw.strip())
    except ValueError:
        return default


def _get_float(name: str, default: float) -> float:
    raw = os.getenv(name)
    if raw is None or not raw.strip():
        return default
    try:
        return float(raw.strip())
    except ValueError:
        return default


def _get_bool(name: str, default: bool) -> bool:
    raw = os.getenv(name)
    if raw is None or not raw.strip():
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on", "si", "sí"}


@dataclass(frozen=True)
class Config:
    # Brain
    openai_api_key: str
    openai_model: str
    assistant_name: str

    # Location / time
    location_name: str
    latitude: float
    longitude: float
    timezone: str

    # WebSocket
    ws_host: str
    ws_port: int

    # MQTT (lights + optional embedded broker)
    mqtt_embed_broker: bool
    mqtt_broker_bind: str
    mqtt_host: str
    mqtt_port: int
    mqtt_username: str
    mqtt_password: str
    mqtt_lights_prefix: str
    mqtt_lights_on: str
    mqtt_lights_off: str

    # Spotify
    spotify_client_id: str
    spotify_client_secret: str
    spotify_redirect_uri: str
    spotify_market: str

    @property
    def mqtt_enabled(self) -> bool:
        return bool(self.mqtt_client_host)

    @property
    def mqtt_client_host(self) -> str:
        """Host the assistant client uses to publish/subscribe."""
        if self.mqtt_host:
            return self.mqtt_host
        if self.mqtt_embed_broker:
            return "127.0.0.1"
        return ""

    @property
    def spotify_enabled(self) -> bool:
        return bool(self.spotify_client_id and self.spotify_client_secret)


def load_config() -> Config:
    return Config(
        openai_api_key=_get("OPENAI_API_KEY"),
        openai_model=_get("OPENAI_MODEL", "gpt-4o-mini"),
        assistant_name=_get("ASSISTANT_NAME", "Casa"),
        location_name=_get("LOCATION_NAME", "Córdoba"),
        latitude=_get_float("LATITUDE", -31.4201),
        longitude=_get_float("LONGITUDE", -64.1888),
        timezone=_get("TIMEZONE", "America/Argentina/Cordoba"),
        ws_host=_get("WS_HOST", "127.0.0.1"),
        ws_port=_get_int("WS_PORT", 8765),
        mqtt_embed_broker=_get_bool("MQTT_EMBED_BROKER", False),
        mqtt_broker_bind=_get("MQTT_BROKER_BIND", "0.0.0.0"),
        mqtt_host=_get("MQTT_HOST"),
        mqtt_port=_get_int("MQTT_PORT", 1883),
        mqtt_username=_get("MQTT_USERNAME"),
        mqtt_password=_get("MQTT_PASSWORD"),
        mqtt_lights_prefix=_get("MQTT_LIGHTS_PREFIX", "home/switchman3g"),
        mqtt_lights_on=_get("MQTT_LIGHTS_ON", "ON"),
        mqtt_lights_off=_get("MQTT_LIGHTS_OFF", "OFF"),
        spotify_client_id=_get("SPOTIFY_CLIENT_ID"),
        spotify_client_secret=_get("SPOTIFY_CLIENT_SECRET"),
        spotify_redirect_uri=_get("SPOTIFY_REDIRECT_URI", "http://127.0.0.1:8888/callback"),
        spotify_market=_get("SPOTIFY_MARKET", "AR"),
    )
