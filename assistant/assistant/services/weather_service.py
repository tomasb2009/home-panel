"""Rich, dynamic weather from Open-Meteo (same source as the Flutter panel).

Returns a compact but complete snapshot (current + next hours + today/tomorrow)
so the LLM can answer *any* phrasing: "¿llueve más tarde?", "¿qué temperatura
a la noche?", "¿cómo está mañana a la mañana?", etc.
"""
from __future__ import annotations

import time
from datetime import datetime
from zoneinfo import ZoneInfo

import httpx

# Open-Meteo WMO weather codes -> Spanish description.
_CONDITIONS = {
    0: "despejado",
    1: "mayormente despejado",
    2: "parcialmente nublado",
    3: "nublado",
    45: "niebla",
    48: "niebla con escarcha",
    51: "llovizna leve",
    53: "llovizna",
    55: "llovizna intensa",
    56: "llovizna helada",
    57: "llovizna helada intensa",
    61: "lluvia leve",
    63: "lluvia",
    65: "lluvia intensa",
    66: "lluvia helada",
    67: "lluvia helada intensa",
    71: "nieve leve",
    73: "nieve",
    75: "nieve intensa",
    77: "granos de nieve",
    80: "chubascos leves",
    81: "chubascos",
    82: "chubascos fuertes",
    85: "chubascos de nieve",
    86: "chubascos de nieve fuertes",
    95: "tormenta",
    96: "tormenta con granizo leve",
    99: "tormenta con granizo",
}


def _describe(code: int) -> str:
    return _CONDITIONS.get(int(code), "sin datos")


class WeatherService:
    def __init__(self, latitude: float, longitude: float, timezone: str,
                 location_name: str) -> None:
        self.lat = latitude
        self.lon = longitude
        self.timezone = timezone
        self.location_name = location_name
        try:
            self._tz = ZoneInfo(timezone)
        except Exception:
            self._tz = ZoneInfo("UTC")
        self._cache: dict | None = None
        self._cache_at: float = 0.0
        self._cache_ttl = 600  # 10 minutes

    def forecast(self) -> dict:
        """Comprehensive forecast, cached for a few minutes."""
        now = time.time()
        if self._cache is not None and (now - self._cache_at) < self._cache_ttl:
            return self._cache

        params = {
            "latitude": self.lat,
            "longitude": self.lon,
            "timezone": self.timezone,
            "current": (
                "temperature_2m,apparent_temperature,relative_humidity_2m,"
                "weather_code,wind_speed_10m,precipitation,is_day"
            ),
            "hourly": (
                "temperature_2m,apparent_temperature,precipitation_probability,"
                "weather_code,wind_speed_10m"
            ),
            "daily": (
                "temperature_2m_max,temperature_2m_min,weather_code,"
                "precipitation_probability_max,sunrise,sunset"
            ),
            "forecast_days": 3,
        }
        try:
            res = httpx.get(
                "https://api.open-meteo.com/v1/forecast",
                params=params,
                timeout=12,
            )
            res.raise_for_status()
            data = res.json()
            snapshot = self._shape(data)
            self._cache = snapshot
            self._cache_at = now
            return snapshot
        except Exception as e:  # noqa: BLE001
            return {"error": f"No pude obtener el clima: {e}"}

    def _shape(self, data: dict) -> dict:
        cur = data.get("current", {})
        current = {
            "temperature": cur.get("temperature_2m"),
            "feels_like": cur.get("apparent_temperature"),
            "humidity": cur.get("relative_humidity_2m"),
            "wind_kmh": cur.get("wind_speed_10m"),
            "precipitation_mm": cur.get("precipitation"),
            "condition": _describe(cur.get("weather_code", -1)),
            "is_day": bool(cur.get("is_day", 1)),
        }

        # Trim hourly to the current hour .. +18h so it stays cheap in tokens.
        hourly = []
        h = data.get("hourly", {})
        times = h.get("time", [])
        now_local = datetime.now(self._tz).replace(minute=0, second=0, microsecond=0)
        for i, t in enumerate(times):
            try:
                dt = datetime.fromisoformat(t).replace(tzinfo=self._tz)
            except ValueError:
                continue
            if dt < now_local:
                continue
            if len(hourly) >= 18:
                break
            hourly.append({
                "time": dt.strftime("%H:%M"),
                "hour": dt.hour,
                "temp": h.get("temperature_2m", [None] * len(times))[i],
                "feels_like": h.get("apparent_temperature", [None] * len(times))[i],
                "rain_prob": h.get("precipitation_probability", [None] * len(times))[i],
                "wind_kmh": h.get("wind_speed_10m", [None] * len(times))[i],
                "condition": _describe(h.get("weather_code", [-1] * len(times))[i]),
            })

        daily = []
        d = data.get("daily", {})
        labels = ["hoy", "mañana", "pasado mañana"]
        for i, day in enumerate(d.get("time", [])[:3]):
            daily.append({
                "label": labels[i] if i < len(labels) else day,
                "date": day,
                "temp_max": d.get("temperature_2m_max", [None] * 3)[i],
                "temp_min": d.get("temperature_2m_min", [None] * 3)[i],
                "rain_prob_max": d.get("precipitation_probability_max", [None] * 3)[i],
                "condition": _describe(d.get("weather_code", [-1] * 3)[i]),
                "sunrise": (d.get("sunrise", [""] * 3)[i] or "")[-5:],
                "sunset": (d.get("sunset", [""] * 3)[i] or "")[-5:],
            })

        return {
            "location": self.location_name,
            "current": current,
            "hourly_next_18h": hourly,
            "daily": daily,
        }
