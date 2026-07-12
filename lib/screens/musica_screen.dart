import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models/spotify_model.dart';
import '../services/click_sound.dart';
import '../services/spotify_controller.dart';
import '../theme/tokens.dart';
import '../widgets/app_card.dart';
import '../widgets/icon_badge.dart';

const Color _accent = AppColors.green;

/// Spotify-style music screen: now playing + search + library.
class MusicaScreen extends StatefulWidget {
  const MusicaScreen({super.key, required this.controller});

  final SpotifyController controller;

  @override
  State<MusicaScreen> createState() => _MusicaScreenState();
}

class _MusicaScreenState extends State<MusicaScreen> {
  final TextEditingController _search = TextEditingController();
  int _rightTab = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.start();
    widget.controller.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    widget.controller.stop();
    _search.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 360, child: _NowPlayingPanel(controller: c)),
        const SizedBox(width: AppSpacing.cardGap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TopTabs(
                index: _rightTab,
                onChanged: (i) => setState(() => _rightTab = i),
              ),
              const SizedBox(height: AppSpacing.miniGap),
              Expanded(
                child: _rightTab == 0
                    ? _SearchPanel(controller: c, input: _search)
                    : _LibraryPanel(controller: c),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NowPlayingPanel extends StatelessWidget {
  const _NowPlayingPanel({required this.controller});

  final SpotifyController controller;

  @override
  Widget build(BuildContext context) {
    final pb = controller.playback;
    final track = pb.track;

    if (!controller.configured) {
      return AppCard(
        glow: true,
        child: _SetupHint(connected: controller.connected),
      );
    }

    return AppCard(
      glow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const IconBadge(icon: Symbols.music_note, accent: _accent, size: 52, iconSize: 28),
              const SizedBox(width: AppSpacing.iconText),
              Text('Ahora suena', style: AppText.sectionTitle),
            ],
          ),
          const SizedBox(height: AppSpacing.s24),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.mini),
                  child: track?.image != null
                      ? Image.network(track!.image!, fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const _ArtPlaceholder())
                      : const _ArtPlaceholder(),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s24),
          Text(
            track?.name ?? 'Nada reproduciendo',
            style: AppText.bodyStrong,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            track?.artist ?? 'Elegí algo para escuchar',
            style: AppText.secondary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.s16),
          _ProgressBar(controller: controller),
          const SizedBox(height: AppSpacing.s16),
          _TransportControls(controller: controller),
          const SizedBox(height: AppSpacing.s16),
          _VolumeSlider(controller: controller),
          if (controller.error != null) ...[
            const SizedBox(height: AppSpacing.s8),
            Text(controller.error!, style: AppText.secondary.copyWith(color: AppColors.amber)),
          ],
        ],
      ),
    );
  }
}

class _SetupHint extends StatelessWidget {
  const _SetupHint({required this.connected});
  final bool connected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const IconBadge(icon: Symbols.music_note, accent: _accent, size: 52, iconSize: 28),
            const SizedBox(width: AppSpacing.iconText),
            Text('Música', style: AppText.sectionTitle),
          ],
        ),
        const SizedBox(height: AppSpacing.s40),
        Text(
          connected ? 'Spotify sin configurar' : 'Sin conexión',
          style: AppText.bodyStrong,
        ),
        const SizedBox(height: AppSpacing.s8),
        Text(
          connected
              ? 'Completá SPOTIFY_CLIENT_ID y SPOTIFY_CLIENT_SECRET en assistant/.env y reiniciá el asistente.'
              : 'Iniciá el asistente Python con --serve.',
          style: AppText.secondary,
        ),
        const Spacer(),
        Text(
          'También necesitás Spotify Premium y la app abierta en esta PC.',
          style: AppText.secondary,
        ),
      ],
    );
  }
}

class _ArtPlaceholder extends StatelessWidget {
  const _ArtPlaceholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _accent.withValues(alpha: 0.18),
            Colors.white.withValues(alpha: 0.04),
          ],
        ),
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.mini),
      ),
      child: const Center(
        child: Icon(Symbols.album, size: 72, color: AppColors.textTertiary),
      ),
    );
  }
}

String _fmtMs(int ms) {
  final s = (ms / 1000).floor();
  final m = s ~/ 60;
  final r = s % 60;
  return '$m:${r.toString().padLeft(2, '0')}';
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.controller});
  final SpotifyController controller;

  @override
  Widget build(BuildContext context) {
    final pb = controller.playback;
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pb.durationMs > 0 ? pb.progress : 0,
            minHeight: 5,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            color: _accent,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_fmtMs(pb.progressMs), style: AppText.statLabel),
            Text(_fmtMs(pb.durationMs), style: AppText.statLabel),
          ],
        ),
      ],
    );
  }
}

class _TransportControls extends StatelessWidget {
  const _TransportControls({required this.controller});
  final SpotifyController controller;

  @override
  Widget build(BuildContext context) {
    final playing = controller.playback.playing;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _RoundControl(
          icon: Symbols.skip_previous,
          onTap: () => controller.previousTrack(),
        ),
        const SizedBox(width: AppSpacing.s16),
        _RoundControl(
          icon: playing ? Symbols.pause : Symbols.play_arrow,
          large: true,
          accent: _accent,
          onTap: () => controller.togglePlayPause(),
        ),
        const SizedBox(width: AppSpacing.s16),
        _RoundControl(
          icon: Symbols.skip_next,
          onTap: () => controller.nextTrack(),
        ),
      ],
    );
  }
}

class _RoundControl extends StatelessWidget {
  const _RoundControl({
    required this.icon,
    required this.onTap,
    this.large = false,
    this.accent = AppColors.textSecondary,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool large;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final size = large ? 56.0 : 44.0;
    return GestureDetector(
      onTap: withClick(onTap),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: large ? _accent.withValues(alpha: 0.14) : Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: large ? _accent.withValues(alpha: 0.35) : AppColors.border,
          ),
        ),
        child: Icon(icon, size: large ? 32 : 26, color: large ? _accent : accent, fill: 1),
      ),
    );
  }
}

class _VolumeSlider extends StatelessWidget {
  const _VolumeSlider({required this.controller});
  final SpotifyController controller;

  @override
  Widget build(BuildContext context) {
    final vol = controller.playback.volume.toDouble();
    return Row(
      children: [
        const Icon(Symbols.volume_down, size: 20, color: AppColors.textTertiary),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: SliderComponentShape.noOverlay,
              activeTrackColor: _accent,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
              thumbColor: _accent,
            ),
            child: Slider(
              value: vol,
              min: 0,
              max: 100,
              onChanged: (v) => controller.setVolume(v.round()),
            ),
          ),
        ),
        const Icon(Symbols.volume_up, size: 20, color: AppColors.textTertiary),
      ],
    );
  }
}

class _TopTabs extends StatelessWidget {
  const _TopTabs({required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TabChip(label: 'Buscar', selected: index == 0, onTap: () => onChanged(0)),
        const SizedBox(width: AppSpacing.s8),
        _TabChip(label: 'Tu biblioteca', selected: index == 1, onTap: () => onChanged(1)),
      ],
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: withClick(onTap),
      child: AnimatedContainer(
        duration: AppMotion.duration,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.mini),
          color: selected ? _accent.withValues(alpha: 0.12) : Colors.transparent,
          border: Border.all(
            color: selected ? _accent.withValues(alpha: 0.35) : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppText.chipLabel.copyWith(
            color: selected ? _accent : AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({required this.controller, required this.input});
  final SpotifyController controller;
  final TextEditingController input;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SearchBar(
            controller: input,
            onSearch: () => controller.search(input.text),
          ),
          const SizedBox(height: AppSpacing.miniGap),
          _SearchKindRow(controller: controller),
          const SizedBox(height: AppSpacing.miniGap),
          Expanded(
            child: controller.loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: _accent))
                : _SearchResults(controller: controller),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onSearch});
  final TextEditingController controller;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.mini),
              color: Colors.white.withValues(alpha: 0.03),
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: TextField(
              controller: controller,
              style: AppText.body,
              cursorColor: _accent,
              decoration: InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                hintText: 'Canciones, artistas, álbumes, playlists…',
                hintStyle: AppText.secondary,
                prefixIcon: const Icon(Symbols.search, size: 22, color: AppColors.textTertiary),
                prefixIconConstraints: const BoxConstraints(minWidth: 40),
              ),
              onSubmitted: (_) => onSearch(),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s8),
        GestureDetector(
          onTap: withClick(onSearch),
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.mini),
              color: _accent.withValues(alpha: 0.14),
              border: Border.all(color: _accent.withValues(alpha: 0.35)),
            ),
            child: const Icon(Symbols.search, color: _accent, size: 22),
          ),
        ),
      ],
    );
  }
}

class _SearchKindRow extends StatelessWidget {
  const _SearchKindRow({required this.controller});
  final SpotifyController controller;

  @override
  Widget build(BuildContext context) {
    const labels = {
      SpotifySearchKind.all: 'Todo',
      SpotifySearchKind.track: 'Canciones',
      SpotifySearchKind.album: 'Álbumes',
      SpotifySearchKind.artist: 'Artistas',
      SpotifySearchKind.playlist: 'Playlists',
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final kind in SpotifySearchKind.values) ...[
            _TabChip(
              label: labels[kind]!,
              selected: controller.searchKind == kind,
              onTap: () => controller.setSearchKind(kind),
            ),
            const SizedBox(width: AppSpacing.s8),
          ],
        ],
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.controller});
  final SpotifyController controller;

  @override
  Widget build(BuildContext context) {
    final items = <SpotifyItem>[
      ...controller.searchTracks,
      ...controller.searchAlbums,
      ...controller.searchArtists,
      ...controller.searchPlaylists,
    ];
    if (controller.lastSearchQuery.isEmpty) {
      return Center(
        child: Text('Buscá música en tu cuenta de Spotify', style: AppText.secondary),
      );
    }
    if (items.isEmpty) {
      return Center(
        child: Text('Sin resultados para "${controller.lastSearchQuery}"', style: AppText.secondary),
      );
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.s8),
      itemBuilder: (context, i) => _ItemTile(item: items[i], onPlay: () => controller.play(items[i])),
    );
  }
}

class _LibraryPanel extends StatelessWidget {
  const _LibraryPanel({required this.controller});
  final SpotifyController controller;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _TabChip(
                  label: 'Playlists',
                  selected: controller.libraryTab == SpotifyLibraryTab.playlists,
                  onTap: () => controller.loadLibrary(SpotifyLibraryTab.playlists),
                ),
                const SizedBox(width: AppSpacing.s8),
                _TabChip(
                  label: 'Favoritos',
                  selected: controller.libraryTab == SpotifyLibraryTab.liked,
                  onTap: () => controller.loadLibrary(SpotifyLibraryTab.liked),
                ),
                const SizedBox(width: AppSpacing.s8),
                _TabChip(
                  label: 'Recientes',
                  selected: controller.libraryTab == SpotifyLibraryTab.recent,
                  onTap: () => controller.loadLibrary(SpotifyLibraryTab.recent),
                ),
                const SizedBox(width: AppSpacing.s8),
                _TabChip(
                  label: 'Para vos',
                  selected: controller.libraryTab == SpotifyLibraryTab.forYou,
                  onTap: () => controller.loadLibrary(SpotifyLibraryTab.forYou),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.miniGap),
          Expanded(
            child: controller.loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: _accent))
                : _LibraryList(controller: controller),
          ),
        ],
      ),
    );
  }
}

class _LibraryList extends StatelessWidget {
  const _LibraryList({required this.controller});
  final SpotifyController controller;

  @override
  Widget build(BuildContext context) {
    final List<SpotifyItem> items;
    switch (controller.libraryTab) {
      case SpotifyLibraryTab.playlists:
        items = controller.playlists;
      case SpotifyLibraryTab.liked:
        items = controller.likedTracks;
      case SpotifyLibraryTab.recent:
        items = controller.recentTracks;
      case SpotifyLibraryTab.forYou:
        items = [
          ...controller.recommendedPlaylists,
          ...controller.recommendedTracks,
        ];
    }
    if (items.isEmpty) {
      return Center(child: Text('Nada para mostrar todavía', style: AppText.secondary));
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.s8),
      itemBuilder: (context, i) => _ItemTile(item: items[i], onPlay: () => controller.play(items[i])),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item, required this.onPlay});
  final SpotifyItem item;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final subtitle = switch (item.itemType) {
      'playlist' => '${item.tracks} canciones · ${item.owner}',
      'album' => item.artist,
      'artist' => 'Artista',
      _ => item.artist,
    };
    return GestureDetector(
      onTap: withClick(onPlay),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(AppRadius.mini),
            border: Border.all(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: item.image != null
                        ? Image.network(item.image!, fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const _ThumbFallback())
                        : const _ThumbFallback(),
                  ),
                ),
                const SizedBox(width: AppSpacing.iconText),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, style: AppText.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(subtitle, style: AppText.secondary, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const Icon(Symbols.play_circle, color: _accent, size: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThumbFallback extends StatelessWidget {
  const _ThumbFallback();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05)),
      child: const Icon(Symbols.music_note, color: AppColors.textTertiary),
    );
  }
}
