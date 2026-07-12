"""Microphone capture (with a simple energy-based VAD) and speaker playback.

Records at 16 kHz mono int16 (what Whisper likes) and stops shortly after you
finish speaking. Plays back 24 kHz mono int16 PCM (what OpenAI TTS returns with
response_format="pcm"), so no audio decoding is needed.
"""
from __future__ import annotations

import io
import logging
import wave
from contextlib import contextmanager
from dataclasses import dataclass
from typing import Iterator

log = logging.getLogger("audio")

REC_RATE = 16_000
TTS_RATE = 24_000
_BLOCK = 480  # 30 ms at 16 kHz
_OWW_BLOCK = 1280  # 80 ms at 16 kHz

_cached_mic: MicConfig | None = None
_devices_logged = False

try:
    import numpy as np
    import sounddevice as sd
    _AVAILABLE = True
except Exception as e:  # noqa: BLE001
    np = None  # type: ignore
    sd = None  # type: ignore
    _AVAILABLE = False
    log.warning("Audio no disponible (%s). Instalá sounddevice/numpy.", e)


@dataclass(frozen=True)
class MicConfig:
    device: int
    samplerate: int
    label: str


def audio_available() -> bool:
    return _AVAILABLE


def list_input_devices() -> list[str]:
    """Human-readable list of input devices (for diagnostics)."""
    if not _AVAILABLE:
        return []
    lines = []
    for i, d in enumerate(sd.query_devices()):
        if d["max_input_channels"] > 0:
            api = sd.query_hostapis(d["hostapi"])["name"]
            lines.append(f"  [{i}] {d['name']} @ {int(d['default_samplerate'])}Hz ({api})")
    return lines


def _is_input_device(index: int) -> bool:
    d = sd.query_devices(index)
    name = d["name"].lower()
    # Skip loopback / speaker-only pseudo inputs.
    if "stereo mix" in name or "pc speaker" in name:
        return False
    return d["max_input_channels"] > 0


def invalidate_mic_cache() -> None:
    """Call after stream errors so the next open re-probes devices."""
    global _cached_mic
    _cached_mic = None


def _log_devices_once() -> None:
    global _devices_logged
    if _devices_logged:
        return
    _devices_logged = True
    for line in list_input_devices():
        log.error(line)


def _stream_extra_settings(hostapi_index: int):
    try:
        api = sd.query_hostapis(hostapi_index)["name"]
        if "WASAPI" in api:
            return sd.WasapiSettings(exclusive=False)
    except Exception:  # noqa: BLE001
        pass
    return None


def _try_open_input(index: int, rate: int) -> bool:
    d = sd.query_devices(index)
    extra = _stream_extra_settings(d["hostapi"])
    block = max(_OWW_BLOCK, int(rate * 0.08))
    for blocksize in (block, _OWW_BLOCK, 512):
        try:
            with sd.InputStream(
                device=index,
                samplerate=rate,
                channels=1,
                dtype="int16",
                blocksize=blocksize,
                extra_settings=extra,
            ) as stream:
                stream.read(blocksize)
            return True
        except Exception:  # noqa: BLE001
            continue
    return False


def _resample_to_16k(frame: np.ndarray, source_rate: int) -> np.ndarray:
    if source_rate == REC_RATE:
        return frame.flatten()
    n_out = int(len(frame) * REC_RATE / source_rate)
    if n_out < 1:
        return frame.flatten()
    idx = np.linspace(0, len(frame) - 1, n_out).astype(np.int32)
    return frame.flatten()[idx]


def _candidate_devices(device_hint: str) -> list[int]:
    """Build an ordered list of device indices to try."""
    if not _AVAILABLE:
        return []

    hints: list[int] = []
    if device_hint:
        if device_hint.isdigit():
            hints.append(int(device_hint))
        else:
            hint = device_hint.lower()
            for i, d in enumerate(sd.query_devices()):
                if d["max_input_channels"] > 0 and hint in d["name"].lower():
                    hints.append(i)

    # Prefer WASAPI mics, then the rest.
    wasapi_id = next(
        (i for i, h in enumerate(sd.query_hostapis()) if "WASAPI" in h["name"]),
        None,
    )
    ordered: list[int] = list(hints)
    for i, d in enumerate(sd.query_devices()):
        if not _is_input_device(i):
            continue
        if wasapi_id is not None and d["hostapi"] == wasapi_id:
            ordered.append(i)
    for i, d in enumerate(sd.query_devices()):
        if _is_input_device(i) and i not in ordered:
            ordered.append(i)
    default_in = sd.default.device[0]
    if isinstance(default_in, int) and default_in >= 0 and default_in not in ordered:
        ordered.insert(0, default_in)
    return ordered


def resolve_mic(device_hint: str = "", *, use_cache: bool = True) -> MicConfig | None:
    """Pick the first mic that can actually open an input stream."""
    global _cached_mic
    if not _AVAILABLE:
        return None

    if use_cache and _cached_mic is not None:
        return _cached_mic

    for index in _candidate_devices(device_hint):
        d = sd.query_devices(index)
        name = d["name"]
        rates = [int(d["default_samplerate"])]
        if REC_RATE not in rates:
            rates.append(REC_RATE)
        for rate in rates:
            if _try_open_input(index, rate):
                api = sd.query_hostapis(d["hostapi"])["name"]
                label = f"[{index}] {name} @ {rate}Hz ({api})"
                log.info("Micrófono: %s", label)
                _cached_mic = MicConfig(device=index, samplerate=rate, label=label)
                return _cached_mic

    log.error("No encontré ningún micrófono usable.")
    _log_devices_once()
    return None


@contextmanager
def mic_stream(
    mic: MicConfig,
    blocksize_16k: int = _OWW_BLOCK,
) -> Iterator[tuple[object, int]]:
    """Yield (stream, read_size) where read_size is in frames at the device rate."""
    read_size = blocksize_16k if mic.samplerate == REC_RATE else int(
        blocksize_16k * mic.samplerate / REC_RATE
    )
    extra = _stream_extra_settings(sd.query_devices(mic.device)["hostapi"])
    stream = sd.InputStream(
        device=mic.device,
        samplerate=mic.samplerate,
        channels=1,
        dtype="int16",
        blocksize=read_size,
        extra_settings=extra,
    )
    stream.start()
    try:
        yield stream, read_size
    finally:
        try:
            stream.stop()
            stream.close()
        except Exception:  # noqa: BLE001
            pass


def read_frame_16k(stream, read_size: int, source_rate: int) -> np.ndarray:
    data, _ = stream.read(read_size)
    return _resample_to_16k(data, source_rate)


def record_until_silence(
    threshold: float = 500.0,
    max_seconds: float = 12.0,
    start_timeout: float = 6.0,
    silence_hangover: float = 0.8,
    device_hint: str = "",
) -> bytes:
    """Blocking capture. Returns WAV bytes, or empty bytes if nothing was said."""
    if not _AVAILABLE:
        return b""

    mic = resolve_mic(device_hint)
    if mic is None:
        return b""

    frames: list = []
    speech_started = False
    silence_time = 0.0
    waited = 0.0
    elapsed = 0.0
    step = _BLOCK / REC_RATE

    try:
        with mic_stream(mic, blocksize_16k=_BLOCK) as (stream, read_size):
            while elapsed < max_seconds:
                chunk = read_frame_16k(stream, read_size, mic.samplerate)
                frames.append(chunk)
                rms = float(np.sqrt(np.mean(np.square(chunk.astype(np.float32)))))
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
                        return b""
    except Exception as e:  # noqa: BLE001
        log.warning("Error grabando: %s", e)
        invalidate_mic_cache()
        return b""

    if not speech_started or not frames:
        return b""

    audio = np.concatenate(frames)
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


def pcm_to_wav(pcm: bytes, samplerate: int = REC_RATE) -> bytes:
    """Public helper for other modules that already captured PCM."""
    return _to_wav(pcm, samplerate)
