"""Speech-to-text (OpenAI Whisper) and pluggable text-to-speech.

TTS provider is chosen with TTS_PROVIDER: "openai" (default) or "elevenlabs"
(custom / cloned voice). STT always uses OpenAI. Both providers stream raw
24 kHz PCM so playback goes straight through audio_io with no decoding.
"""
from __future__ import annotations

import logging

from openai import OpenAI

from . import audio_io
from .config import Config

log = logging.getLogger("voice")


class _OpenAiTts:
    def __init__(self, client: OpenAI, cfg: Config) -> None:
        self._client = client
        self._model = cfg.openai_tts_model
        self._voice = cfg.openai_tts_voice

    def synth(self, text: str) -> bytes:
        with self._client.audio.speech.with_streaming_response.create(
            model=self._model,
            voice=self._voice,
            input=text,
            response_format="pcm",
        ) as response:
            return b"".join(response.iter_bytes())


class _ElevenLabsTts:
    def __init__(self, cfg: Config) -> None:
        from elevenlabs.client import ElevenLabs
        from elevenlabs.types import VoiceSettings

        self._client = ElevenLabs(api_key=cfg.elevenlabs_api_key)
        self._voice_id = cfg.elevenlabs_voice_id
        self._model = cfg.elevenlabs_model
        self._settings = VoiceSettings(
            stability=cfg.elevenlabs_stability,
            similarity_boost=cfg.elevenlabs_similarity,
            style=cfg.elevenlabs_style,
            use_speaker_boost=cfg.elevenlabs_speaker_boost,
            speed=cfg.elevenlabs_speed,
        )

    def synth(self, text: str) -> bytes:
        stream = self._client.text_to_speech.convert(
            voice_id=self._voice_id,
            model_id=self._model,
            text=text,
            output_format="pcm_24000",
            voice_settings=self._settings,
        )
        return b"".join(stream)


class _FallbackTts:
    """Try ElevenLabs first; on failure (e.g. free-plan 402) fall back to OpenAI."""

    def __init__(self, primary, fallback, label: str) -> None:
        self._primary = primary
        self._fallback = fallback
        self._warned = False
        self._label = label

    def synth(self, text: str) -> bytes:
        try:
            return self._primary.synth(text)
        except Exception as e:  # noqa: BLE001
            err = str(e).lower()
            paid = "402" in err or "payment" in err or "paid_plan" in err
            if not self._warned:
                if paid:
                    log.warning(
                        "ElevenLabs requiere plan pago para voces del catálogo (James). "
                        "Usando voz OpenAI de respaldo. Subí a Starter en elevenlabs.io "
                        "o cambiá TTS_PROVIDER=openai."
                    )
                else:
                    log.warning("ElevenLabs falló (%s). Uso OpenAI de respaldo.", e)
                self._warned = True
            return self._fallback.synth(text)


class VoiceService:
    def __init__(self, cfg: Config) -> None:
        self.cfg = cfg
        self.client = OpenAI(api_key=cfg.openai_api_key)
        self._tts = self._make_tts(cfg)

    def _make_tts(self, cfg: Config):
        if cfg.tts_provider == "elevenlabs":
            if not cfg.elevenlabs_enabled:
                log.warning("TTS_PROVIDER=elevenlabs pero faltan API key/voice_id. Uso OpenAI.")
                return _OpenAiTts(self.client, cfg)
            try:
                eleven = _ElevenLabsTts(cfg)
                openai_tts = _OpenAiTts(self.client, cfg)
                log.info("TTS: ElevenLabs (voz %s) con respaldo OpenAI", cfg.elevenlabs_voice_id)
                return _FallbackTts(eleven, openai_tts, "elevenlabs")
            except Exception as e:  # noqa: BLE001
                log.warning("No pude iniciar ElevenLabs (%s). Uso OpenAI.", e)
                return _OpenAiTts(self.client, cfg)
        log.info("TTS: OpenAI (voz %s)", cfg.openai_tts_voice)
        return _OpenAiTts(self.client, cfg)

    @property
    def available(self) -> bool:
        return audio_io.audio_available()

    def listen(self) -> str:
        """Record a spoken command and return its transcription (Spanish)."""
        wav = audio_io.record_until_silence(
            threshold=self.cfg.mic_silence_threshold,
            max_seconds=self.cfg.mic_max_record_seconds,
            silence_hangover=self.cfg.mic_silence_hangover,
            device_hint=self.cfg.mic_device,
        )
        if not wav:
            return ""
        try:
            result = self.client.audio.transcriptions.create(
                model=self.cfg.openai_stt_model,
                file=("command.wav", wav, "audio/wav"),
                language="es",
            )
            return (result.text or "").strip()
        except Exception as e:  # noqa: BLE001
            log.warning("Error transcribiendo: %s", e)
            return ""

    def speak(self, text: str) -> None:
        """Synthesize `text` with the configured voice and play it."""
        text = text.strip()
        if not text:
            return
        try:
            pcm = self._tts.synth(text)
            audio_io.play_pcm(pcm, samplerate=audio_io.TTS_RATE)
        except Exception as e:  # noqa: BLE001
            log.warning("Error en TTS: %s", e)
