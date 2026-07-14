import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

/// High-level state of the voice assistant, mirrored from the Python brain.
enum AssistantStatus { offline, idle, listening, thinking, speaking, error }

/// One line of the conversation shown in the assistant panel.
@immutable
class AssistantTurn {
  const AssistantTurn({required this.fromUser, required this.text});
  final bool fromUser;
  final String text;
}

/// Talks to the Python "brain" over a localhost WebSocket.
///
/// Sends text (and later, a "listen" trigger for push-to-talk) and reacts to
/// the events the brain pushes back: transcript, state, action, say.
class AssistantService extends ChangeNotifier {
  AssistantService({this.url = 'ws://127.0.0.1:8765'});

  final String url;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _reconnect;
  bool _disposed = false;

  AssistantStatus _status = AssistantStatus.offline;
  AssistantStatus get status => _status;

  bool get connected =>
      _status != AssistantStatus.offline && _status != AssistantStatus.error;

  final List<AssistantTurn> turns = [];

  /// Light areas the assistant controls, mirrored for the panel UI.
  final Map<String, bool> lights = {'living': false, 'comedor': false, 'patio': false};

  /// Called when voice toggles one or more lights so [LightsModel] stays in sync.
  void Function(List<String> areas, bool on)? onLightCommand;

  /// Called when the wake word is detected, so the panel can pop open.
  VoidCallback? onWake;

  /// Spotify UI responses from the Python brain (direct API, not LLM).
  void Function(Map<String, dynamic> msg)? onSpotifyResponse;

  /// Sync light chips from the dashboard [LightsModel] (manual toggles).
  void syncLightsFrom(Map<String, bool> state) {
    var changed = false;
    for (final entry in state.entries) {
      if (lights[entry.key] != entry.value) {
        lights[entry.key] = entry.value;
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  /// A short human-readable note about the last action taken (for feedback).
  String? lastAction;

  void connect() {
    if (_disposed) return;
    _reconnect?.cancel();
    try {
      _setStatus(AssistantStatus.idle);
      final channel = WebSocketChannel.connect(Uri.parse(url));
      _channel = channel;
      _sub = channel.stream.listen(
        _onMessage,
        onError: (_) => _onDisconnected(),
        onDone: _onDisconnected,
        cancelOnError: true,
      );
    } catch (_) {
      _onDisconnected();
    }
  }

  void _onDisconnected() {
    if (_disposed) return;
    _setStatus(AssistantStatus.offline);
    _sub?.cancel();
    _sub = null;
    _channel = null;
    // Keep trying to reconnect so the panel recovers when the brain starts.
    _reconnect?.cancel();
    _reconnect = Timer(const Duration(seconds: 3), connect);
  }

  void _onMessage(dynamic raw) {
    if (raw is! String) return;
    final Map<String, dynamic> msg;
    try {
      msg = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    switch (msg['type']) {
      case 'wake':
        _setStatus(AssistantStatus.listening);
        onWake?.call();
        break;
      case 'transcript':
        final text = (msg['text'] as String?)?.trim() ?? '';
        if (text.isNotEmpty) turns.add(AssistantTurn(fromUser: true, text: text));
        notifyListeners();
        break;
      case 'state':
        _setStatus(_statusFrom(msg['value'] as String?));
        break;
      case 'say':
        final text = (msg['text'] as String?)?.trim() ?? '';
        if (text.isNotEmpty) {
          turns.add(AssistantTurn(fromUser: false, text: text));
        }
        notifyListeners();
        break;
      case 'action':
        _applyAction(msg);
        break;
      case 'spotify':
        onSpotifyResponse?.call(msg);
        break;
    }
  }

  void _applyAction(Map<String, dynamic> msg) {
    switch (msg['name']) {
      case 'set_lights':
        final areas = (msg['areas'] as List?)?.cast<String>() ?? const [];
        final on = msg['on'] == true;
        for (final a in areas) {
          if (lights.containsKey(a)) lights[a] = on;
        }
        if (areas.isNotEmpty) {
          onLightCommand?.call(areas, on);
          lastAction = '${on ? 'Prendí' : 'Apagué'} ${areas.join(', ')}';
        }
        break;
      case 'spotify_play':
        if (msg['ok'] == true) {
          lastAction = 'Reproduciendo ${msg['playing'] ?? ''}';
          onSpotifyResponse?.call({'type': 'spotify', 'action': 'play', 'ok': true});
        }
        break;
      case 'remember_fact':
        if (msg['ok'] == true) lastAction = 'Lo voy a recordar';
        break;
    }
    notifyListeners();
  }

  AssistantStatus _statusFrom(String? value) {
    switch (value) {
      case 'listening':
        return AssistantStatus.listening;
      case 'thinking':
        return AssistantStatus.thinking;
      case 'speaking':
        return AssistantStatus.speaking;
      case 'idle':
      default:
        return AssistantStatus.idle;
    }
  }

  void _setStatus(AssistantStatus s) {
    if (_status == s) return;
    _status = s;
    notifyListeners();
  }

  /// Sends a typed command to the brain.
  void sendText(String text) {
    text = text.trim();
    if (text.isEmpty || _channel == null) return;
    _channel!.sink.add(jsonEncode({'type': 'text', 'text': text}));
  }

  /// Push-to-talk: asks the brain to capture a voice command (Step B).
  void startListening() {
    if (_channel == null) return;
    _setStatus(AssistantStatus.listening);
    _channel!.sink.add(jsonEncode({'type': 'listen'}));
  }

  /// Direct Spotify API command for the music screen.
  void sendSpotify(String action, [Map<String, dynamic> params = const {}]) {
    if (_channel == null) return;
    _channel!.sink.add(jsonEncode({
      'type': 'spotify',
      'action': action,
      ...params,
    }));
  }

  /// Manual light toggle from the dashboard — forwarded to MQTT via Python.
  void sendLight(String id, bool on) {
    if (_channel == null) return;
    _channel!.sink.add(jsonEncode({'type': 'lights', 'id': id, 'on': on}));
  }

  /// Clears the conversation (short-term memory) on both ends.
  void reset() {
    turns.clear();
    lastAction = null;
    _channel?.sink.add(jsonEncode({'type': 'reset'}));
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _reconnect?.cancel();
    _sub?.cancel();
    _channel?.sink.close(ws_status.goingAway);
    super.dispose();
  }
}
