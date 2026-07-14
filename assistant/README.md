# Home Panel · Asistente (cerebro)

Servicio en Python que entiende lenguaje natural (con OpenAI function-calling) y
ejecuta acciones del hogar. Se conecta al panel Flutter por WebSocket.

## Qué sabe hacer

- **Hora**: "¿qué hora es?", "¿qué día es hoy?"
- **Clima dinámico** (Open-Meteo): "¿cómo está ahora?", "¿va a llover más tarde?",
  "¿qué temperatura a la noche?", "¿cómo está mañana a la mañana?"
- **Luces por MQTT**: living, comedor y patio trasero. "prendé las luces del living",
  "apagá todo". Si no hay broker MQTT configurado, corre en **modo simulado**.
- **Spotify** (requiere Premium): "poné Bohemian Rhapsody", "poné mi playlist de rock",
  "siguiente", "pausá".
- **Memoria**:
  - *Corto plazo* (dentro de la charla): "¿qué hora es?" → "las 17" → "¿y en una hora?"
    → "las 18". Funciona solo, por el historial de conversación.
  - *Largo plazo* (persiste entre reinicios): "acordate que mi playlist para cocinar
    es Cocina Rock" → se guarda en `memory.json` y lo recuerda siempre.

Los comandos se escriben en el panel Flutter (chat de texto).

## API keys que necesitás

| Servicio | Variable(s) | ¿Obligatorio? | Para qué |
|---|---|---|---|
| **OpenAI** | `OPENAI_API_KEY` | **Sí** | Cerebro (NLU + respuestas) |
| **Spotify** | `SPOTIFY_CLIENT_ID`, `SPOTIFY_CLIENT_SECRET` | Solo para música | Reproducir (requiere Premium) |
| Open-Meteo | — | No | Clima (sin key) |
| MQTT | `MQTT_EMBED_BROKER=true` o `MQTT_HOST` | Solo para luces reales | Broker + control ESP32 |

Con **solo `OPENAI_API_KEY`** ya andan hora, clima, memoria y luces simuladas.

## Setup

```powershell
cd assistant
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
copy .env.example .env   # y completá al menos OPENAI_API_KEY
```

## Uso

Probar por texto:

```powershell
python -m assistant
```

Levantar el servidor WebSocket para el panel Flutter:

```powershell
python -m assistant --serve
```

En la Raspberry Pi, con broker MQTT embebido (puerto 1883, 24/7 con `--serve`):

```powershell
# .env
MQTT_EMBED_BROKER=true
MQTT_BROKER_BIND=0.0.0.0
MQTT_LIGHTS_PREFIX=home/switchman3g
```

Solo el broker (útil con systemd):

```powershell
python -m assistant --mqtt-broker
```

El ESP32 apunta `MQTT_SERVER` a la IP de la Pi. Topics: `home/switchman3g/relay1/set|state`
(relay1=living, relay2=comedor, relay3=patio). Al apretar un botón físico, el ESP32
publica el estado y el panel Flutter se sincroniza solo.

Con el servidor corriendo, abrí el panel Flutter: el botón del asistente abajo a la
derecha se pone en verde al conectar. Escribí un comando en el chat.

## Arquitectura

```
assistant/
  config.py            # configuración desde .env
  brain.py             # loop OpenAI function-calling + personalidad
  tools.py             # schema de herramientas + dispatcher
  ws_server.py         # puente WebSocket con Flutter
  mqtt_broker.py       # broker MQTT embebido (aMQTT, puerto 1883)
  main.py              # entrypoint (CLI / --serve / --mqtt-broker)
  services/
    time_service.py
    weather_service.py # Open-Meteo (current + hourly + daily)
    lights_service.py  # MQTT (con modo simulado)
    spotify_service.py # Spotify Web API
    memory_service.py  # memoria persistente (memory.json)
```

Con `MQTT_EMBED_BROKER=true` la Pi corre broker + cliente en un solo proceso; el ESP32
se conecta por WiFi y los botones físicos actualizan el panel vía WebSocket.

## Protocolo WebSocket

Cliente → servidor:
- `{"type": "text", "text": "..."}` — comando en texto
- `{"type": "reset"}` — limpia la conversación
- `{"type": "lights", "id": "living", "on": true}` — toggle manual desde el panel
- `{"type": "spotify", "action": "..."}` — control directo de Spotify

Servidor → cliente:
- `{"type": "transcript", "text": "..."}`
- `{"type": "state", "value": "thinking"|"idle"}`
- `{"type": "action", "name": "set_lights", ...}`
- `{"type": "say", "text": "..."}`
