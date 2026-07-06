import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Plays a short "click" sound as tactile feedback whenever a button is pressed.
///
/// A small pool of pre-loaded players is cycled so rapid, overlapping taps each
/// get their own crisp click instead of cutting the previous one off.
class ClickSound {
  ClickSound._();

  static final ClickSound instance = ClickSound._();

  static const String _asset = 'sounds/click.mp3';
  static const int _poolSize = 5;
  static const double _volume = 0.55;

  final List<AudioPlayer> _players = [];
  int _next = 0;
  bool _ready = false;

  /// Pre-loads the click into a pool of players. Safe to call once at startup.
  Future<void> init() async {
    if (_ready) return;
    try {
      for (var i = 0; i < _poolSize; i++) {
        final player = AudioPlayer(playerId: 'click_$i')
          ..setPlayerMode(PlayerMode.lowLatency)
          ..setReleaseMode(ReleaseMode.stop);
        await player.setVolume(_volume);
        await player.setSource(AssetSource(_asset));
        _players.add(player);
      }
      _ready = true;
    } catch (e) {
      debugPrint('ClickSound init failed: $e');
    }
  }

  /// Fire-and-forget click. No-op if audio failed to initialise.
  void play() {
    if (!_ready || _players.isEmpty) return;
    final player = _players[_next];
    _next = (_next + 1) % _players.length;
    player.seek(Duration.zero);
    player.resume();
  }

  Future<void> dispose() async {
    for (final p in _players) {
      await p.dispose();
    }
    _players.clear();
    _ready = false;
  }
}

/// Wraps a tap [action] so it plays the click sound first. Returns `null` when
/// [action] is `null`, keeping disabled buttons silent and non-interactive.
VoidCallback? withClick(VoidCallback? action) {
  if (action == null) return null;
  return () {
    ClickSound.instance.play();
    action();
  };
}
