import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/spotify_model.dart';
import '../services/assistant_service.dart';

/// Spotify state for the music screen. Talks to the Python brain over the
/// shared WebSocket (direct API calls, no LLM).
class SpotifyController extends ChangeNotifier {
  SpotifyController(this._assistant) {
    _assistant.onSpotifyResponse = _onSpotifyResponse;
    _assistant.addListener(_onAssistantChanged);
  }

  final AssistantService _assistant;

  bool configured = true;
  String? error;
  bool loading = false;

  SpotifyPlayback playback = const SpotifyPlayback();
  List<SpotifyItem> searchTracks = [];
  List<SpotifyItem> searchAlbums = [];
  List<SpotifyItem> searchArtists = [];
  List<SpotifyItem> searchPlaylists = [];
  List<SpotifyItem> playlists = [];
  List<SpotifyItem> likedTracks = [];
  List<SpotifyItem> recentTracks = [];
  List<SpotifyItem> recommendedTracks = [];
  List<SpotifyItem> recommendedPlaylists = [];

  SpotifyLibraryTab libraryTab = SpotifyLibraryTab.playlists;
  SpotifySearchKind searchKind = SpotifySearchKind.all;
  String lastSearchQuery = '';

  Timer? _pollTimer;
  Timer? _progressTimer;
  int _requestId = 0;
  final Map<int, void Function(Map<String, dynamic>)> _waiters = {};

  bool get connected => _assistant.connected;

  void start() {
    _pollTimer?.cancel();
    _progressTimer?.cancel();
    refreshPlayback();
    loadLibrary(libraryTab);
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => refreshPlayback());
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 500), (_) => _tickProgress());
  }

  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  void _onAssistantChanged() {
    if (_assistant.connected && _pollTimer == null) start();
  }

  void _tickProgress() {
    if (!playback.playing || playback.durationMs <= 0) return;
    final base = playback.updatedAt;
    if (base == null) return;
    final elapsed = DateTime.now().difference(base).inMilliseconds;
    final next = playback.progressMs + elapsed;
    if (next > playback.durationMs) return;
    playback = playback.copyWith(progressMs: next, updatedAt: DateTime.now());
    notifyListeners();
  }

  void _onSpotifyResponse(Map<String, dynamic> msg) {
    final id = msg['request_id'] as int?;
    if (id != null) {
      _waiters.remove(id)?.call(msg);
    }
    _applyResponse(msg);
  }

  void _applyResponse(Map<String, dynamic> msg) {
    final action = msg['action'] as String?;
    if (msg['ok'] == false) {
      error = msg['message'] as String? ?? 'Error con Spotify';
      loading = false;
      if ((msg['message'] as String?)?.contains('no está configurado') == true) {
        configured = false;
      }
      notifyListeners();
      return;
    }

    error = null;
    configured = true;

    switch (action) {
      case 'state':
        if (msg['playing'] == false && msg['track'] == null) {
          playback = playback.copyWith(playing: false, track: null);
        } else if (msg.containsKey('track')) {
          playback = SpotifyPlayback.fromJson(msg);
        }
        break;
      case 'search':
        searchTracks = _items(msg['tracks']);
        searchAlbums = _items(msg['albums']);
        searchArtists = _items(msg['artists']);
        searchPlaylists = _items(msg['playlists']);
        loading = false;
        break;
      case 'playlists':
        playlists = _items(msg['playlists']);
        loading = false;
        break;
      case 'saved':
        likedTracks = _items(msg['tracks']);
        loading = false;
        break;
      case 'recent':
        recentTracks = _items(msg['tracks']);
        loading = false;
        break;
      case 'recommendations':
        recommendedTracks = _items(msg['tracks']);
        recommendedPlaylists = _items(msg['playlists']);
        loading = false;
        break;
      case 'play':
      case 'control':
      case 'volume':
        Future.delayed(const Duration(milliseconds: 400), refreshPlayback);
        break;
    }
    notifyListeners();
  }

  List<SpotifyItem> _items(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => SpotifyItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Map<String, dynamic>> _send(
    String action, [
    Map<String, dynamic> params = const {},
  ]) async {
    if (!_assistant.connected) {
      error = 'Sin conexión con el asistente';
      notifyListeners();
      return {'ok': false};
    }
    final id = ++_requestId;
    final completer = Completer<Map<String, dynamic>>();
    _waiters[id] = completer.complete;
    _assistant.sendSpotify(action, {...params, 'request_id': id});
    return completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () {
        _waiters.remove(id);
        return {'ok': false, 'message': 'Tiempo de espera agotado'};
      },
    );
  }

  Future<void> refreshPlayback() async {
    await _send('state');
  }

  Future<void> search(String query) async {
    query = query.trim();
    if (query.isEmpty) return;
    lastSearchQuery = query;
    loading = true;
    error = null;
    notifyListeners();
    final kind = switch (searchKind) {
      SpotifySearchKind.all => 'all',
      SpotifySearchKind.track => 'track',
      SpotifySearchKind.album => 'album',
      SpotifySearchKind.artist => 'artist',
      SpotifySearchKind.playlist => 'playlist',
    };
    await _send('search', {'query': query, 'kind': kind});
  }

  void setSearchKind(SpotifySearchKind kind) {
    searchKind = kind;
    notifyListeners();
    if (lastSearchQuery.isNotEmpty) search(lastSearchQuery);
  }

  Future<void> loadLibrary(SpotifyLibraryTab tab) async {
    libraryTab = tab;
    loading = true;
    error = null;
    notifyListeners();
    switch (tab) {
      case SpotifyLibraryTab.playlists:
        await _send('playlists');
      case SpotifyLibraryTab.liked:
        await _send('saved');
      case SpotifyLibraryTab.recent:
        await _send('recent');
      case SpotifyLibraryTab.forYou:
        await _send('recommendations');
    }
  }

  Future<void> play(SpotifyItem item) async {
    if (!item.isPlayable) return;
    error = null;
    await _send('play', {'uri': item.uri});
  }

  Future<void> togglePlayPause() async {
    if (playback.playing) {
      await _send('control', {'command': 'pause'});
    } else {
      await _send('control', {'command': 'resume'});
    }
  }

  Future<void> nextTrack() => _send('control', {'command': 'next'});
  Future<void> previousTrack() => _send('control', {'command': 'previous'});

  Future<void> setVolume(int level) async {
    playback = playback.copyWith(volume: level);
    notifyListeners();
    await _send('volume', {'level': level});
  }

  @override
  void dispose() {
    stop();
    _assistant.onSpotifyResponse = null;
    _assistant.removeListener(_onAssistantChanged);
    super.dispose();
  }
}
