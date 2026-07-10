"""Persistent long-term memory.

Short-term conversational context lives in the Brain's message history (so
follow-ups like "¿y en una hora?" work automatically). This service stores the
*durable* facts the user asks the assistant to remember (preferences, names,
"mi playlist para cocinar es tal"), surviving restarts via a small JSON file.
"""
from __future__ import annotations

import json
import logging
import os
from datetime import datetime, timezone

log = logging.getLogger("memory")


class MemoryService:
    def __init__(self, path: str = "memory.json") -> None:
        self.path = path
        self._facts: list[dict] = []
        self._load()

    def _load(self) -> None:
        if os.path.exists(self.path):
            try:
                with open(self.path, "r", encoding="utf-8") as f:
                    self._facts = json.load(f)
            except (json.JSONDecodeError, OSError) as e:
                log.warning("No pude leer memoria (%s). Empiezo vacía.", e)
                self._facts = []

    def _save(self) -> None:
        try:
            with open(self.path, "w", encoding="utf-8") as f:
                json.dump(self._facts, f, ensure_ascii=False, indent=2)
        except OSError as e:
            log.warning("No pude guardar memoria: %s", e)

    def all(self) -> list[dict]:
        return list(self._facts)

    def texts(self) -> list[str]:
        return [f["text"] for f in self._facts]

    def add(self, text: str) -> dict:
        text = text.strip()
        if not text:
            return {"ok": False, "message": "No había nada para recordar."}
        # Avoid trivial duplicates.
        for f in self._facts:
            if f["text"].lower() == text.lower():
                return {"ok": True, "text": text, "duplicate": True}
        entry = {"text": text, "at": datetime.now(timezone.utc).isoformat()}
        self._facts.append(entry)
        self._save()
        return {"ok": True, "text": text}

    def forget(self, query: str) -> dict:
        query = query.strip().lower()
        if not query:
            return {"ok": False, "message": "Decime qué querés que olvide."}
        before = len(self._facts)
        self._facts = [f for f in self._facts if query not in f["text"].lower()]
        removed = before - len(self._facts)
        self._save()
        if removed == 0:
            return {"ok": False, "message": f"No encontré nada sobre '{query}'."}
        return {"ok": True, "removed": removed}

    def clear(self) -> dict:
        self._facts = []
        self._save()
        return {"ok": True}
