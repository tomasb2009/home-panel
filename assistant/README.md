# Home Panel · Asistente de voz (cerebro)

Servicio en Python que entiende lenguaje natural (con OpenAI function-calling) y
ejecuta acciones del hogar. Es el "cerebro" que en el futuro se conecta al panel
Flutter por WebSocket.

## Qué sabe hacer (v1)

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
- **Voz** (Paso B): micrófono → transcripción (Whisper) → cerebro → respuesta hablada
  (TTS de OpenAI). Por ahora con *push-to-talk* (botón en el panel / Enter en CLI).

## API keys que necesitás

| Servicio | Variable(s) | ¿Obligatorio? | Para qué |
|---|---|---|---|
| **OpenAI** | `OPENAI_API_KEY` | **Sí** | Cerebro + voz (STT/TTS) |
| **Spotify** | `SPOTIFY_CLIENT_ID`, `SPOTIFY_CLIENT_SECRET` | Solo para música | Reproducir (requiere Premium) |
| **ElevenLabs** | `ELEVENLABS_API_KEY`, `ELEVENLABS_VOICE_ID` | Solo voz clonada | Reemplaza la voz de OpenAI |
| **Picovoice** | `PICOVOICE_ACCESS_KEY` + `.ppn` | Solo wake word | Escucha manos libres |
| Open-Meteo | — | No | Clima (sin key) |
| MQTT | `MQTT_EMBED_BROKER=true` o `MQTT_HOST` | Solo para luces reales | Broker + control ESP32 |

Con **solo `OPENAI_API_KEY`** ya andan hora, clima, memoria, voz y luces simuladas.

### Voz clonada con ElevenLabs

1. Creá o cloná una voz en https://elevenlabs.io y copiá su **Voice ID**.
2. En `.env`: `TTS_PROVIDER=elevenlabs`, `ELEVENLABS_API_KEY=...`, `ELEVENLABS_VOICE_ID=...`.
3. Listo: la respuesta hablada usa esa voz en vez de la de OpenAI. (La salida PCM
   requiere un plan pago de ElevenLabs; el clonado ya lo requiere igual.)

### Wake word con Porcupine (manos libres)

1. Registrate en https://console.picovoice.ai/ y copiá tu **AccessKey**.
2. Creá tu palabra clave (ej. "Hola Casa"), plataforma **Windows** → descargá el `.ppn`.
   Para español, descargá también el modelo `porcupine_params_es.pv`.
3. En `.env`: `WAKE_WORD_ENABLED=true`, `PICOVOICE_ACCESS_KEY=...`,
   `WAKE_WORD_KEYWORD_PATH=C:\ruta\a\tu_palabra.ppn`,
   `WAKE_WORD_MODEL_PATH=C:\ruta\a\porcupine_params_es.pv`.
4. Corré `python -m assistant --serve`: queda escuchando y al decir la palabra
   dispara un turno de voz y abre el panel automáticamente.

> Nota: para que te escuche con música sonando hace falta un micrófono con
> cancelación de eco (speakerphone USB). Con un micro común, funciona en silencio.

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

Probar por voz en la terminal (push-to-talk con Enter):

```powershell
python -m assistant --voice
```

Levantar el servidor WebSocket para el panel Flutter (incluye voz):

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

Con el servidor corriendo, abrí el panel Flutter (`flutter run -d windows`): el
botón del micrófono abajo a la derecha se pone en verde al conectar. Escribí un
comando o tocá el micrófono para hablar.

## Arquitectura

```
assistant/
  config.py            # configuración desde .env
  brain.py             # loop OpenAI function-calling + personalidad
  tools.py             # schema de herramientas + dispatcher
  ws_server.py         # puente WebSocket con Flutter
  mqtt_broker.py       # broker MQTT embebido (aMQTT, puerto 1883)
  main.py              # entrypoint (CLI / --serve / --mqtt-broker)
  voice.py             # STT (OpenAI) + TTS enchufable (OpenAI / ElevenLabs)
  wake_word.py         # detección de palabra clave (Porcupine)
  audio_io.py          # micrófono (VAD) + reproducción PCM
  services/
    time_service.py
    weather_service.py # Open-Meteo (current + hourly + daily)
    lights_service.py  # MQTT (con modo simulado)
    spotify_service.py # Spotify Web API
    memory_service.py  # memoria persistente (memory.json)
```

Cada herramienta mapea 1:1 a un método de servicio. Con `MQTT_EMBED_BROKER=true` la Pi
corre broker + cliente en un solo proceso; el ESP32 se conecta por WiFi y los botones
físicos actualizan el panel vía WebSocket.

## Protocolo WebSocket

Cliente → servidor:
- `{"type": "text", "text": "..."}` — comando en texto
- `{"type": "listen"}` — grabar y procesar un comando por voz
- `{"type": "reset"}` — limpia la conversación

Servidor → cliente:
- `{"type": "transcript", "text": "..."}`
- `{"type": "state", "value": "listening"|"thinking"|"speaking"|"idle"}`
- `{"type": "action", "name": "set_lights", ...}`
- `{"type": "say", "text": "..."}`
