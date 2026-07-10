"""The brain: an OpenAI function-calling loop that turns natural language into
tool calls and a spoken-friendly Spanish reply."""
from __future__ import annotations

import logging
from typing import Callable

from openai import OpenAI

from .config import Config
from .services.lights_service import normalize_light_areas
from .tools import TOOL_SCHEMAS, ToolRunner

log = logging.getLogger("brain")

_MAX_TOOL_ROUNDS = 5
# Keep the system message + at most this many recent turns to bound token cost.
_MAX_HISTORY_MESSAGES = 24


def _system_prompt(cfg: Config) -> str:
    name = cfg.assistant_name
    return (
        f"Sos {name}, el asistente de inteligencia artificial de una residencia "
        f"en {cfg.location_name}, Argentina. Tu personalidad es la de un mayordomo "
        "digital: serio, inteligente, calmado y seguro. Hablás en español con tono "
        "formal y preciso, como un asistente de alto nivel. Tus respuestas se leen "
        "en voz alta, así que deben ser BREVES (una o dos frases como máximo), "
        "claras y sin adornos.\n\n"
        "Estilo de comunicación:\n"
        "- Tranquilo y confiado, nunca apurado ni emocional.\n"
        "- Directo: informás el dato o confirmás la acción sin rodeos.\n"
        "- Podés usar 'señor' de vez en cuando, con moderación.\n"
        "- Sin emojis, sin listas largas, sin markdown, sin jerga casual.\n"
        "- Si algo falla, lo informás con compostura, sin dramatizar.\n\n"
        "Capacidades: hora, clima dinámico, luces y música en Spotify.\n\n"
        "Luces (usá set_lights con el área correcta):\n"
        "- living, comedor o patio: una sola zona.\n"
        "- sala_de_estar: SIEMPRE incluye living Y comedor (son dos luces).\n"
        "- patio_trasero: el patio.\n"
        "- todas: las tres luces (living, comedor y patio) de TODA la casa.\n"
        "- 'todas las luces' sin habitación → areas=['todas'].\n"
        "- 'todas las luces de la sala de estar' → areas=['sala_de_estar'], NO todas.\n"
        "- Si piden 'sala de estar' → areas=['sala_de_estar'], NO solo living.\n"
        "- Si el pedido mezcla zonas (ej. apagar sala y prender patio), llamá "
        "set_lights UNA VEZ POR ACCIÓN con el área correcta en cada llamada.\n\n"
        "Reglas:\n"
        "- Para clima, llamá a get_weather y elegí del resultado el dato exacto "
        "que responde la pregunta. Sé concreto y da números.\n"
        "- Para la hora, usá get_current_time.\n"
        "- Confirmá luces y música en una frase corta y segura.\n"
        "- No repitas el pedido del usuario; respondé directo."
    )


class Brain:
    def __init__(self, cfg: Config, runner: ToolRunner) -> None:
        self.cfg = cfg
        self.runner = runner
        self.client = OpenAI(api_key=cfg.openai_api_key)
        self._base_prompt = _system_prompt(cfg)
        self._history: list[dict] = []

    def reset(self) -> None:
        self._history = []

    def _system_message(self) -> dict:
        """System prompt with the current long-term memory injected."""
        facts = self.runner.memory.texts()
        content = self._base_prompt
        if facts:
            bullet = "\n".join(f"- {f}" for f in facts)
            content += (
                "\n\nCosas que recordás de este usuario (usalas cuando vengan al "
                f"caso, sin repetirlas de más):\n{bullet}"
            )
        return {"role": "system", "content": content}

    def _trim(self) -> None:
        if len(self._history) > _MAX_HISTORY_MESSAGES:
            self._history = self._history[-_MAX_HISTORY_MESSAGES:]
        # Never start the trimmed window on an orphan tool result.
        while self._history and self._history[0].get("role") == "tool":
            self._history.pop(0)

    def handle(self, user_text: str, emit: Callable[[dict], None]) -> str:
        """Process one user utterance. Emits state/action events and returns the
        final spoken reply text."""
        self._history.append({"role": "user", "content": user_text})
        self._trim()
        emit({"type": "state", "value": "thinking"})

        for _ in range(_MAX_TOOL_ROUNDS):
            response = self.client.chat.completions.create(
                model=self.cfg.openai_model,
                messages=[self._system_message()] + self._history,
                tools=TOOL_SCHEMAS,
                tool_choice="auto",
                temperature=0.35,
            )
            msg = response.choices[0].message

            if not msg.tool_calls:
                reply = (msg.content or "").strip()
                self._history.append({"role": "assistant", "content": reply})
                emit({"type": "say", "text": reply})
                emit({"type": "state", "value": "idle"})
                return reply

            # Record the assistant's tool-call turn, then run each tool.
            self._history.append({
                "role": "assistant",
                "content": msg.content,
                "tool_calls": [
                    {
                        "id": tc.id,
                        "type": "function",
                        "function": {
                            "name": tc.function.name,
                            "arguments": tc.function.arguments,
                        },
                    }
                    for tc in msg.tool_calls
                ],
            })

            for tc in msg.tool_calls:
                name = tc.function.name
                args = ToolRunner.parse_args(tc.function.arguments)
                if name == "set_lights":
                    original = args.get("areas", [])
                    args["areas"] = normalize_light_areas(user_text, original)
                    if args["areas"] != original:
                        log.info(
                            "set_lights areas %s -> %s (utterance correction)",
                            original,
                            args["areas"],
                        )
                log.info("tool %s(%s)", name, args)
                try:
                    result = self.runner.run(name, args, emit)
                except Exception as e:  # noqa: BLE001
                    result = {"ok": False, "message": f"Error ejecutando {name}: {e}"}
                self._history.append({
                    "role": "tool",
                    "tool_call_id": tc.id,
                    "content": _to_json(result),
                })

        fallback = "Perdón, me trabé procesando eso. ¿Lo intentamos de nuevo?"
        emit({"type": "say", "text": fallback})
        emit({"type": "state", "value": "idle"})
        return fallback


def _to_json(value) -> str:
    import json
    try:
        return json.dumps(value, ensure_ascii=False)
    except (TypeError, ValueError):
        return str(value)
