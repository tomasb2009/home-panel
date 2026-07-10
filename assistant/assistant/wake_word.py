"""Always-on wake-word detection with Picovoice Porcupine.

Runs in a background thread reading the microphone through PvRecorder. When the
keyword is detected it PAUSES the recorder (freeing the mic), invokes the
blocking `on_wake` callback (which records + processes the command through the
normal voice pipeline), then resumes listening.
"""
from __future__ import annotations

import logging
import threading
from typing import Callable

from .config import Config

log = logging.getLogger("wake")


class WakeWordListener(threading.Thread):
    def __init__(self, cfg: Config, on_wake: Callable[[], None]) -> None:
        super().__init__(name="wake-word", daemon=True)
        self.cfg = cfg
        self._on_wake = on_wake
        self._stop = threading.Event()
        self._porcupine = None
        self._recorder = None

    def _create(self) -> bool:
        try:
            import pvporcupine
            from pvrecorder import PvRecorder
        except Exception as e:  # noqa: BLE001
            log.warning("Wake word no disponible (%s). Instalá pvporcupine/pvrecorder.", e)
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
            self._recorder = PvRecorder(frame_length=self._porcupine.frame_length, device_index=-1)
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

        log.info("Wake word activa. Esperando la palabra clave…")
        recorder.start()
        try:
            while not self._stop.is_set():
                pcm = recorder.read()
                if porcupine.process(pcm) >= 0:
                    log.info("¡Palabra clave detectada!")
                    # Release the mic so the command recorder can use it.
                    recorder.stop()
                    try:
                        self._on_wake()
                    except Exception as e:  # noqa: BLE001
                        log.warning("Error en el turno de voz: %s", e)
                    if not self._stop.is_set():
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
