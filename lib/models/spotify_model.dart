import 'package:flutter/foundation.dart';

/// A track, album, artist or playlist row from Spotify.
@immutable
class SpotifyItem {
  const SpotifyItem({
    required this.uri,
    required this.name,
    this.id,
    this.artist = '',
    this.album = '',
    this.image,
    this.durationMs = 0,
    this.tracks = 0,
    this.owner = '',
    this.itemType = 'track',
  });

  final String? uri;
  final String? id;
  final String name;
  final String artist;
  final String album;
  final String? image;
  final int durationMs;
  final int tracks;
  final String owner;
  final String itemType;

  factory SpotifyItem.fromJson(Map<String, dynamic> json) {
    return SpotifyItem(
      uri: json['uri'] as String?,
      id: json['id'] as String?,
      name: (json['name'] as String?) ?? '',
      artist: (json['artist'] as String?) ?? '',
      album: (json['album'] as String?) ?? '',
      image: json['image'] as String?,
      durationMs: (json['duration_ms'] as num?)?.toInt() ?? 0,
      tracks: (json['tracks'] as num?)?.toInt() ?? 0,
      owner: (json['owner'] as String?) ?? '',
      itemType: (json['type'] as String?) ?? 'track',
    );
  }

  bool get isPlayable => uri != null && uri!.isNotEmpty;
}

/// Current playback snapshot.
@immutable
class SpotifyPlayback {
  const SpotifyPlayback({
    this.playing = false,
    this.progressMs = 0,
    this.volume = 50,
    this.track,
    this.updatedAt,
  });

  final bool playing;
  final int progressMs;
  final int volume;
  final SpotifyItem? track;
  final DateTime? updatedAt;

  int get durationMs => track?.durationMs ?? 0;

  double get progress {
    if (durationMs <= 0) return 0;
    return (progressMs / durationMs).clamp(0.0, 1.0);
  }

  SpotifyPlayback copyWith({
    bool? playing,
    int? progressMs,
    int? volume,
    SpotifyItem? track,
    DateTime? updatedAt,
  }) {
    return SpotifyPlayback(
      playing: playing ?? this.playing,
      progressMs: progressMs ?? this.progressMs,
      volume: volume ?? this.volume,
      track: track ?? this.track,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory SpotifyPlayback.fromJson(Map<String, dynamic> json) {
    final trackJson = json['track'] as Map<String, dynamic>?;
    return SpotifyPlayback(
      playing: json['playing'] == true,
      progressMs: (json['progress_ms'] as num?)?.toInt() ?? 0,
      volume: (json['volume'] as num?)?.toInt() ?? 50,
      track: trackJson != null ? SpotifyItem.fromJson(trackJson) : null,
      updatedAt: DateTime.now(),
    );
  }
}

enum SpotifyLibraryTab { playlists, liked, recent, forYou }

enum SpotifySearchKind { all, track, album, artist, playlist }
