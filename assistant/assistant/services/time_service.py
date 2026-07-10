"""Current date/time in the configured timezone."""
from __future__ import annotations

from datetime import datetime
from zoneinfo import ZoneInfo

_WEEKDAYS = [
    "lunes", "martes", "miércoles", "jueves", "viernes", "sábado", "domingo",
]
_MONTHS = [
    "enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto",
    "septiembre", "octubre", "noviembre", "diciembre",
]


class TimeService:
    def __init__(self, timezone: str) -> None:
        try:
            self._tz = ZoneInfo(timezone)
        except Exception:
            self._tz = ZoneInfo("UTC")

    def now(self) -> datetime:
        return datetime.now(self._tz)

    def snapshot(self) -> dict:
        """Structured now(), so the model can phrase the answer naturally."""
        n = self.now()
        return {
            "iso": n.isoformat(),
            "time_24h": n.strftime("%H:%M"),
            "hour": n.hour,
            "minute": n.minute,
            "weekday": _WEEKDAYS[n.weekday()],
            "day": n.day,
            "month": _MONTHS[n.month - 1],
            "year": n.year,
            "date_es": f"{_WEEKDAYS[n.weekday()]} {n.day} de {_MONTHS[n.month - 1]} de {n.year}",
        }
