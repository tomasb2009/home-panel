"""Always-on voice detection without a wake word.

Keeps the microphone open continuously and starts a command when speech is
detected (energy-based VAD). More fluid than push-to-talk; no keyword needed.
"""
from __future__ import annotations

import logging
import threading
import time
from typing import Callable

import numpy as np

from . import audio_io
from .config import Config

log = logging.getLogger("always_listen")


class AlwaysListenListener(threading.Thread):
    """Mic always open; triggers when the user starts speaking."""

    def __init__(self, cfg: Config, on_speech: Callable[[bytes], None]) -> None:
        super().__init__(name="always-listen", daemon=True)
        self.cfg = cfg
        self._on_speech = on_speech
        self._stop = threading.Event()
        self._last_trigger = 0.0

    def _cooldown_sleep(self) -> None:
        deadline = time.monotonic() + self.cfg.listen_cooldown
        while time.monotonic() < deadline and not self._stop.is_set():
            time.sleep(0.05)

    def _drain(self, stream, read_size, mic, count: int) -> None:
        for _ in range(count):
            if self._stop.is_set():
                return
            audio_io.read_frame_16k(stream, read_size, mic.samplerate)

    def _record_until_silence(
        self,
        stream,
        read_size: int,
        mic,
        prebuffer: list[np.ndarray],
    ) -> bytes:
        frames = list(prebuffer)
        silence_time = 0.0
        elapsed = len(prebuffer) * (audio_io._OWW_BLOCK / audio_io.REC_RATE)
        step = audio_io._OWW_BLOCK / audio_io.REC_RATE
        threshold = self.cfg.mic_silence_threshold
        hangover = self.cfg.mic_silence_hangover

        while elapsed < self.cfg.mic_max_record_seconds:
            chunk = audio_io.read_frame_16k(stream, read_size, mic.samplerate)
            frames.append(chunk)
            elapsed += step
            rms = float(np.sqrt(np.mean(np.square(chunk.astype(np.float32)))))
            if rms > threshold:
                silence_time = 0.0
            else:
                silence_time += step
                if silence_time >= hangover:
                    break

        if not frames:
            return b""
        audio = np.concatenate(frames)
        return audio_io.pcm_to_wav(audio.tobytes(), audio_io.REC_RATE)

    def _run_session(self) -> None:
        mic = audio_io.resolve_mic(self.cfg.mic_device)
        if mic is None:
            return

        threshold = self.cfg.mic_silence_threshold
        confirm = max(2, self.cfg.listen_confirm_frames)
        prebuffer_len = max(confirm, 3)

        log.info(
            "Escucha continua activa (%s, umbral %.0f, cooldown %.1fs). "
            "Hablá directo, sin palabra clave.",
            mic.label,
            threshold,
            self.cfg.listen_cooldown,
        )

        with audio_io.mic_stream(mic) as (stream, read_size):
            hits = 0
            prebuffer: list[np.ndarray] = []

            while not self._stop.is_set():
                chunk = audio_io.read_frame_16k(stream, read_size, mic.samplerate)
                rms = float(np.sqrt(np.mean(np.square(chunk.astype(np.float32)))))

                prebuffer.append(chunk)
                if len(prebuffer) > prebuffer_len:
                    prebuffer.pop(0)

                if rms >= threshold:
                    hits += 1
                else:
                    hits = 0

                if hits < confirm:
                    continue

                now = time.monotonic()
                if now - self._last_trigger < self.cfg.listen_min_interval:
                    hits = 0
                    continue

                log.info("Voz detectada (rms %.0f). Escuchando comando…", rms)
                self._last_trigger = now
                hits = 0

                wav = self._record_until_silence(stream, read_size, mic, prebuffer)
                prebuffer.clear()

                if wav:
                    try:
                        self._on_speech(wav)
                    except Exception as e:  # noqa: BLE001
                        log.warning("Error en el turno de voz: %s", e)

                if self._stop.is_set():
                    break

                self._cooldown_sleep()
                self._drain(stream, read_size, mic, self.cfg.wake_word_warmup_frames)

    def run(self) -> None:
        while not self._stop.is_set():
            try:
                self._run_session()
            except Exception as e:  # noqa: BLE001
                log.error("Escucha continua interrumpida: %s", e)
                audio_io.invalidate_mic_cache()
                log.warning("Reintentando micrófono en 5 s…")
                time.sleep(5.0)

    def stop(self) -> None:
        self._stop.set()


def create_always_listener(
    cfg: Config, on_speech: Callable[[bytes], None]
) -> AlwaysListenListener | None:
    if not cfg.always_listen_ready:
        return None
    if not audio_io.audio_available():
        log.warning("Escucha continua activada pero no hay audio (sounddevice).")
        return None
    return AlwaysListenListener(cfg, on_speech)
