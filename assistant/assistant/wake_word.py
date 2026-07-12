"""Always-on wake-word detection.

Backends:
  - openwakeword (default): free, open-source, includes a pre-trained "hey_jarvis"
    model. No account or API key required.
  - porcupine: Picovoice (requires AccessKey + custom .ppn; often needs company email).

When the keyword is detected the mic is released, `on_wake` runs (record → brain →
TTS), then listening resumes after a cooldown so speaker echo does not re-trigger.
"""
from __future__ import annotations

import logging
import threading
import time
from typing import Callable, Protocol

from . import audio_io
from .config import Config

log = logging.getLogger("wake")


class _WakeBackend(Protocol):
    def stop(self) -> None: ...


class OpenWakeWordListener(threading.Thread):
    """Listens for a pre-trained phrase (default: hey_jarvis) via openWakeWord."""

    def __init__(self, cfg: Config, on_wake: Callable[[], None]) -> None:
        super().__init__(name="wake-openwakeword", daemon=True)
        self.cfg = cfg
        self._on_wake = on_wake
        self._stop = threading.Event()
        self._model = None
        self._mic = None
        self._last_trigger = 0.0

    def _init_model(self) -> bool:
        if self._model is not None:
            return True
        try:
            import openwakeword
            from openwakeword.model import Model
        except Exception as e:  # noqa: BLE001
            log.warning("openWakeWord no disponible (%s). pip install openwakeword", e)
            return False

        try:
            openwakeword.utils.download_models(model_names=[self.cfg.wake_word_model])
            self._model = Model(wakeword_models=[self.cfg.wake_word_model])
            return True
        except Exception as e:  # noqa: BLE001
            log.error("No pude cargar el modelo wake word: %s", e)
            return False

    def _resolve_mic(self) -> bool:
        self._mic = audio_io.resolve_mic(self.cfg.mic_device)
        return self._mic is not None

    def _create(self) -> bool:
        return self._init_model() and self._resolve_mic()

    def _drain_frames(self, stream, read_size: int, mic, count: int) -> None:
        """Read and discard frames to flush echo/noise from the mic buffer."""
        for _ in range(count):
            if self._stop.is_set():
                return
            chunk = audio_io.read_frame_16k(stream, read_size, mic.samplerate)
            self._model.predict(chunk)

    def _drain_after_wake(self, mic) -> None:
        """Brief open/close to flush echo after TTS without holding the device."""
        try:
            with audio_io.mic_stream(mic) as (stream, read_size):
                self._drain_frames(
                    stream, read_size, mic, self.cfg.wake_word_warmup_frames
                )
        except Exception:  # noqa: BLE001
            audio_io.invalidate_mic_cache()

    def _cooldown_sleep(self) -> None:
        """Keep the mic closed while the room settles after TTS."""
        deadline = time.monotonic() + self.cfg.wake_word_cooldown
        while time.monotonic() < deadline and not self._stop.is_set():
            time.sleep(0.05)

    def run(self) -> None:
        if not self._init_model():
            return
        while not self._stop.is_set():
            if not self._resolve_mic():
                time.sleep(10.0)
                continue
            try:
                self._run_loop()
            except Exception as e:  # noqa: BLE001
                log.error("Error en el listener openWakeWord: %s", e)
                audio_io.invalidate_mic_cache()
                log.warning("Reintentando micrófono en 5 s…")
                time.sleep(5.0)

    def _run_loop(self) -> None:
        model = self._model
        mic = self._mic
        threshold = self.cfg.wake_word_threshold
        model_name = self.cfg.wake_word_model
        confirm = max(1, self.cfg.wake_word_confirm_frames)

        log.info(
            'Wake word activa (openWakeWord: "%s", umbral %.2f, '
            "confirmación %d frames, cooldown %.1fs). Escuchando…",
            model_name.replace("_", " "),
            threshold,
            confirm,
            self.cfg.wake_word_cooldown,
        )

        triggered = False
        with audio_io.mic_stream(mic) as (stream, read_size):
            hits = 0
            while not self._stop.is_set():
                chunk = audio_io.read_frame_16k(stream, read_size, mic.samplerate)
                scores = model.predict(chunk)
                score = float(scores.get(model_name, 0.0))

                if score >= threshold:
                    hits += 1
                else:
                    hits = 0

                if hits < confirm:
                    continue

                now = time.monotonic()
                if now - self._last_trigger < self.cfg.wake_word_min_interval:
                    hits = 0
                    continue

                log.info('¡"%s" detectado! (%.2f)', model_name, score)
                self._last_trigger = now
                triggered = True
                break

        if not triggered or self._stop.is_set():
            return

        # Mic released — safe for the voice-turn recorder to open it.
        audio_io.invalidate_mic_cache()
        try:
            self._on_wake()
        except Exception as e:  # noqa: BLE001
            log.warning("Error en el turno de voz: %s", e)

        self._cooldown_sleep()
        self._drain_after_wake(mic)

    def stop(self) -> None:
        self._stop.set()


class PorcupineWakeWordListener(threading.Thread):
    """Picovoice Porcupine — needs AccessKey + custom .ppn file."""

    def __init__(self, cfg: Config, on_wake: Callable[[], None]) -> None:
        super().__init__(name="wake-porcupine", daemon=True)
        self.cfg = cfg
        self._on_wake = on_wake
        self._stop = threading.Event()
        self._porcupine = None
        self._recorder = None
        self._last_trigger = 0.0

    def _create(self) -> bool:
        try:
            import pvporcupine
            from pvrecorder import PvRecorder
        except Exception as e:  # noqa: BLE001
            log.warning("Porcupine no disponible (%s). pip install pvporcupine pvrecorder", e)
            return False

        kwargs = {
            "access_key": self.cfg.picovoice_access_key,
            "keyword_paths": [self.cfg.wake_word_keyword_path],
            "sensitivities": [self.cfg.wake_word_sensitivity],
        }
        if self.cfg.wake_word_model_path:
            kwargs["model_path"] = self.cfg.wake_word_model_path

        try:
            self._porcupine = pvporcupine.create(**kwargs)
            self._recorder = PvRecorder(
                frame_length=self._porcupine.frame_length, device_index=-1
            )
            return True
        except Exception as e:  # noqa: BLE001
            log.error("No pude iniciar Porcupine: %s", e)
            return False

    def run(self) -> None:
        if not self._create():
            return
        recorder = self._recorder
        porcupine = self._porcupine
        assert recorder is not None and porcupine is not None

        log.info("Wake word activa (Porcupine). Esperando la palabra clave…")
        recorder.start()
        try:
            while not self._stop.is_set():
                pcm = recorder.read()
                if porcupine.process(pcm) >= 0:
                    now = time.monotonic()
                    if now - self._last_trigger < self.cfg.wake_word_min_interval:
                        continue
                    log.info("¡Palabra clave detectada!")
                    self._last_trigger = now
                    recorder.stop()
                    try:
                        self._on_wake()
                    except Exception as e:  # noqa: BLE001
                        log.warning("Error en el turno de voz: %s", e)
                    if not self._stop.is_set():
                        time.sleep(self.cfg.wake_word_cooldown)
                        recorder.start()
        finally:
            try:
                recorder.stop()
                recorder.delete()
            except Exception:  # noqa: BLE001
                pass
            try:
                porcupine.delete()
            except Exception:  # noqa: BLE001
                pass

    def stop(self) -> None:
        self._stop.set()


def create_wake_listener(cfg: Config, on_wake: Callable[[], None]) -> _WakeBackend | None:
    """Pick the configured backend and return a started-ready listener, or None."""
    if not cfg.wake_word_enabled:
        return None
    if not audio_io.audio_available():
        log.warning("Wake word activada pero no hay audio (sounddevice).")
        return None

    backend = cfg.wake_word_backend
    if backend == "porcupine":
        if not (cfg.picovoice_access_key and cfg.wake_word_keyword_path):
            log.warning("Porcupine requiere PICOVOICE_ACCESS_KEY y WAKE_WORD_KEYWORD_PATH.")
            return None
        return PorcupineWakeWordListener(cfg, on_wake)

    return OpenWakeWordListener(cfg, on_wake)


WakeWordListener = create_wake_listener
