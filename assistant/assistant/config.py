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

    # Voice
    openai_stt_model: str
    openai_tts_model: str
    openai_tts_voice: str
    mic_silence_threshold: float
    mic_silence_hangover: float
    mic_max_record_seconds: float
    mic_device: str

    # TTS provider
    tts_provider: str
    elevenlabs_api_key: str
    elevenlabs_voice_id: str
    elevenlabs_model: str
    elevenlabs_stability: float
    elevenlabs_similarity: float
    elevenlabs_style: float
    elevenlabs_speed: float
    elevenlabs_speaker_boost: bool

    # Wake word
    wake_word_enabled: bool
    wake_word_backend: str
    wake_word_model: str
    wake_word_threshold: float
    wake_word_cooldown: float
    wake_word_confirm_frames: int
    wake_word_warmup_frames: int
    wake_word_min_interval: float
    picovoice_access_key: str
    wake_word_keyword_path: str
    wake_word_model_path: str
    wake_word_sensitivity: float

    # Location / time
    location_name: str
    latitude: float
    longitude: float
    timezone: str

    # WebSocket
    ws_host: str
    ws_port: int

    # MQTT (lights)
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
        return bool(self.mqtt_host)

    @property
    def spotify_enabled(self) -> bool:
        return bool(self.spotify_client_id and self.spotify_client_secret)

    @property
    def elevenlabs_enabled(self) -> bool:
        return bool(self.elevenlabs_api_key and self.elevenlabs_voice_id)

    @property
    def wake_word_ready(self) -> bool:
        if not self.wake_word_enabled:
            return False
        if self.wake_word_backend == "porcupine":
            return bool(self.picovoice_access_key and self.wake_word_keyword_path)
        # openwakeword — solo necesita estar habilitado.
        return True


def load_config() -> Config:
    return Config(
        openai_api_key=_get("OPENAI_API_KEY"),
        openai_model=_get("OPENAI_MODEL", "gpt-4o-mini"),
        assistant_name=_get("ASSISTANT_NAME", "Casa"),
        openai_stt_model=_get("OPENAI_STT_MODEL", "whisper-1"),
        openai_tts_model=_get("OPENAI_TTS_MODEL", "gpt-4o-mini-tts"),
        openai_tts_voice=_get("OPENAI_TTS_VOICE", "coral"),
        mic_silence_threshold=_get_float("MIC_SILENCE_THRESHOLD", 500.0),
        mic_silence_hangover=_get_float("MIC_SILENCE_HANGOVER", 2.0),
        mic_max_record_seconds=_get_float("MIC_MAX_RECORD_SECONDS", 15.0),
        mic_device=_get("MIC_DEVICE"),
        tts_provider=_get("TTS_PROVIDER", "openai").lower(),
        elevenlabs_api_key=_get("ELEVENLABS_API_KEY"),
        elevenlabs_voice_id=_get("ELEVENLABS_VOICE_ID"),
        elevenlabs_model=_get("ELEVENLABS_MODEL", "eleven_multilingual_v2"),
        elevenlabs_stability=_get_float("ELEVENLABS_STABILITY", 0.78),
        elevenlabs_similarity=_get_float("ELEVENLABS_SIMILARITY", 0.82),
        elevenlabs_style=_get_float("ELEVENLABS_STYLE", 0.08),
        elevenlabs_speed=_get_float("ELEVENLABS_SPEED", 0.92),
        elevenlabs_speaker_boost=_get_bool("ELEVENLABS_SPEAKER_BOOST", True),
        wake_word_enabled=_get_bool("WAKE_WORD_ENABLED", False),
        wake_word_backend=_get("WAKE_WORD_BACKEND", "openwakeword").lower(),
        wake_word_model=_get("WAKE_WORD_MODEL", "hey_jarvis"),
        wake_word_threshold=_get_float("WAKE_WORD_THRESHOLD", 0.5),
        wake_word_cooldown=_get_float("WAKE_WORD_COOLDOWN", 4.0),
        wake_word_confirm_frames=_get_int("WAKE_WORD_CONFIRM_FRAMES", 3),
        wake_word_warmup_frames=_get_int("WAKE_WORD_WARMUP_FRAMES", 6),
        wake_word_min_interval=_get_float("WAKE_WORD_MIN_INTERVAL", 8.0),
        picovoice_access_key=_get("PICOVOICE_ACCESS_KEY"),
        wake_word_keyword_path=_get("WAKE_WORD_KEYWORD_PATH"),
        wake_word_model_path=_get("WAKE_WORD_MODEL_PATH"),
        wake_word_sensitivity=_get_float("WAKE_WORD_SENSITIVITY", 0.6),
        location_name=_get("LOCATION_NAME", "Córdoba"),
        latitude=_get_float("LATITUDE", -31.4201),
        longitude=_get_float("LONGITUDE", -64.1888),
        timezone=_get("TIMEZONE", "America/Argentina/Cordoba"),
        ws_host=_get("WS_HOST", "127.0.0.1"),
        ws_port=_get_int("WS_PORT", 8765),
        mqtt_host=_get("MQTT_HOST"),
        mqtt_port=_get_int("MQTT_PORT", 1883),
        mqtt_username=_get("MQTT_USERNAME"),
        mqtt_password=_get("MQTT_PASSWORD"),
        mqtt_lights_prefix=_get("MQTT_LIGHTS_PREFIX", "home/luces"),
        mqtt_lights_on=_get("MQTT_LIGHTS_ON", "ON"),
        mqtt_lights_off=_get("MQTT_LIGHTS_OFF", "OFF"),
        spotify_client_id=_get("SPOTIFY_CLIENT_ID"),
        spotify_client_secret=_get("SPOTIFY_CLIENT_SECRET"),
        spotify_redirect_uri=_get("SPOTIFY_REDIRECT_URI", "http://127.0.0.1:8888/callback"),
        spotify_market=_get("SPOTIFY_MARKET", "AR"),
    )
