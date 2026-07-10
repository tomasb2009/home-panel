"""Microphone capture (with a simple energy-based VAD) and speaker playback.

Records at 16 kHz mono int16 (what Whisper likes) and stops shortly after you
finish speaking. Plays back 24 kHz mono int16 PCM (what OpenAI TTS returns with
response_format="pcm"), so no audio decoding is needed.
"""
from __future__ import annotations

import io
import logging
import wave

log = logging.getLogger("audio")

REC_RATE = 16_000
TTS_RATE = 24_000
_BLOCK = 480  # 30 ms at 16 kHz

try:
    import numpy as np
    import sounddevice as sd
    _AVAILABLE = True
except Exception as e:  # noqa: BLE001
    np = None  # type: ignore
    sd = None  # type: ignore
    _AVAILABLE = False
    log.warning("Audio no disponible (%s). Instalá sounddevice/numpy.", e)


def audio_available() -> bool:
    return _AVAILABLE


def record_until_silence(
    threshold: float = 500.0,
    max_seconds: float = 12.0,
    start_timeout: float = 6.0,
    silence_hangover: float = 0.8,
) -> bytes:
    """Blocking capture. Returns WAV bytes, or empty bytes if nothing was said."""
    if not _AVAILABLE:
        return b""

    frames: list = []
    speech_started = False
    silence_time = 0.0
    waited = 0.0
    elapsed = 0.0
    step = _BLOCK / REC_RATE

    try:
        with sd.InputStream(samplerate=REC_RATE, channels=1, dtype="int16",
                            blocksize=_BLOCK) as stream:
            while elapsed < max_seconds:
                data, _ = stream.read(_BLOCK)
                frames.append(data.copy())
                rms = float(np.sqrt(np.mean(np.square(data.astype(np.float32)))))
                elapsed += step

                if rms > threshold:
                    speech_started = True
                    silence_time = 0.0
                elif speech_started:
                    silence_time += step
                    if silence_time >= silence_hangover:
                        break
                else:
                    waited += step
                    if waited >= start_timeout:
                        return b""  # user never spoke
    except Exception as e:  # noqa: BLE001
        log.warning("Error grabando: %s", e)
        return b""

    if not speech_started or not frames:
        return b""

    audio = np.concatenate(frames, axis=0)
    return _to_wav(audio.tobytes(), REC_RATE)


def play_pcm(pcm: bytes, samplerate: int = TTS_RATE) -> None:
    """Blocking playback of raw 16-bit mono PCM."""
    if not _AVAILABLE or not pcm:
        return
    try:
        samples = np.frombuffer(pcm, dtype=np.int16)
        sd.play(samples, samplerate=samplerate)
        sd.wait()
    except Exception as e:  # noqa: BLE001
        log.warning("Error reproduciendo: %s", e)


def _to_wav(pcm: bytes, samplerate: int) -> bytes:
    buf = io.BytesIO()
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(samplerate)
        wf.writeframes(pcm)
    return buf.getvalue()
