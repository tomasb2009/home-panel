"""Tool catalogue exposed to the LLM (OpenAI function-calling) + dispatcher.

Each tool maps 1:1 to a service method. The dispatcher runs the tool, emits a
UI-facing `action` event (so the Flutter panel can reflect it), and returns a
JSON-serialisable result that goes back to the model.
"""
from __future__ import annotations

import json
from typing import Any, Callable

from .services.lights_service import LightsService
from .services.memory_service import MemoryService
from .services.spotify_service import SpotifyService
from .services.time_service import TimeService
from .services.weather_service import WeatherService

# JSON schema for every tool the assistant can call.
TOOL_SCHEMAS: list[dict] = [
    {
        "type": "function",
        "function": {
            "name": "get_current_time",
            "description": "Devuelve la fecha y hora actual local. Usar para cualquier "
                           "pregunta sobre la hora o el día de hoy.",
            "parameters": {"type": "object", "properties": {}},
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_weather",
            "description": (
                "Devuelve un panorama completo del clima: condición actual, "
                "pronóstico hora por hora (próximas 18h) y resumen de hoy, "
                "mañana y pasado mañana (máx/mín y probabilidad de lluvia). "
                "Usalo para CUALQUIER consulta de clima (ahora, la hora que "
                "viene, hoy a la noche, mañana, temperatura, lluvia, viento) y "
                "elegí vos del resultado el dato que responde la pregunta."
            ),
            "parameters": {"type": "object", "properties": {}},
        },
    },
    {
        "type": "function",
        "function": {
            "name": "set_lights",
            "description": (
                "Prende o apaga luces. Podés pedir zonas individuales, habitaciones "
                "o toda la casa. 'sala_de_estar' incluye living Y comedor. "
                "'todas' incluye living, comedor y patio."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "areas": {
                        "type": "array",
                        "items": {
                            "type": "string",
                            "enum": [
                                "living",
                                "comedor",
                                "patio",
                                "sala_de_estar",
                                "patio_trasero",
                                "todas",
                            ],
                        },
                        "description": (
                            "Zonas a controlar. sala_de_estar = living + comedor. "
                            "patio_trasero = patio. todas = las 3 luces."
                        ),
                    },
                    "on": {
                        "type": "boolean",
                        "description": "true para prender, false para apagar.",
                    },
                },
                "required": ["areas", "on"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "spotify_play",
            "description": "Busca y reproduce una canción, playlist, álbum o artista en Spotify.",
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "Qué reproducir. Ej: 'Bohemian Rhapsody', "
                                       "'mi playlist de rock', 'Gustavo Cerati'.",
                    },
                    "kind": {
                        "type": "string",
                        "enum": ["track", "playlist", "album", "artist"],
                        "description": "Tipo de contenido. Por defecto 'track'.",
                    },
                },
                "required": ["query"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "spotify_control",
            "description": "Controla la reproducción actual de Spotify.",
            "parameters": {
                "type": "object",
                "properties": {
                    "action": {
                        "type": "string",
                        "enum": ["pause", "resume", "next", "previous"],
                    },
                },
                "required": ["action"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "remember_fact",
            "description": (
                "Guarda un dato o preferencia del usuario para recordarlo en el "
                "futuro (entre sesiones). Ej: 'la playlist para cocinar es X', "
                "'me gusta la casa a 22 grados', 'mi cumpleaños es el 3 de mayo'. "
                "Usalo cuando el usuario pida recordar algo o cuente una "
                "preferencia duradera."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "fact": {
                        "type": "string",
                        "description": "El dato a recordar, redactado de forma clara y autocontenida.",
                    },
                },
                "required": ["fact"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "forget_fact",
            "description": "Olvida datos recordados que coincidan con una búsqueda.",
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "Texto que identifica qué olvidar. Ej: 'playlist para cocinar'.",
                    },
                },
                "required": ["query"],
            },
        },
    },
]


class ToolRunner:
    """Owns the services and dispatches tool calls coming from the model."""

    def __init__(
        self,
        time_service: TimeService,
        weather_service: WeatherService,
        lights_service: LightsService,
        spotify_service: SpotifyService,
        memory_service: MemoryService,
    ) -> None:
        self.time = time_service
        self.weather = weather_service
        self.lights = lights_service
        self.spotify = spotify_service
        self.memory = memory_service

    def run(self, name: str, args: dict, emit: Callable[[dict], None]) -> Any:
        """Execute a tool by name. `emit` pushes UI events to the frontend."""
        if name == "get_current_time":
            return self.time.snapshot()

        if name == "get_weather":
            return self.weather.forecast()

        if name == "set_lights":
            areas = args.get("areas", [])
            on = bool(args.get("on", True))
            result = self.lights.set_many(areas, on)
            emit({
                "type": "action",
                "name": "set_lights",
                "areas": result.get("applied", []),
                "on": on,
                "simulated": result.get("simulated", True),
            })
            return result

        if name == "spotify_play":
            result = self.spotify.play(args.get("query", ""), args.get("kind", "track"))
            emit({"type": "action", "name": "spotify_play", **result})
            return result

        if name == "spotify_control":
            result = self.spotify.control(args.get("action", ""))
            emit({"type": "action", "name": "spotify_control", **result})
            return result

        if name == "remember_fact":
            result = self.memory.add(args.get("fact", ""))
            emit({"type": "action", "name": "remember_fact", **result})
            return result

        if name == "forget_fact":
            result = self.memory.forget(args.get("query", ""))
            emit({"type": "action", "name": "forget_fact", **result})
            return result

        return {"ok": False, "message": f"Herramienta desconocida: {name}"}

    @staticmethod
    def parse_args(raw: str | None) -> dict:
        if not raw:
            return {}
        try:
            return json.loads(raw)
        except json.JSONDecodeError:
            return {}
