import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../models/lights_model.dart';
import '../theme/tokens.dart';
import '../widgets/app_card.dart';
import '../widgets/controls/app_toggle.dart';
import '../widgets/icon_badge.dart';

/// Single accent for the whole lighting feature — warm "light on" amber.
const Color _accent = AppColors.amber;

/// Fully interactive lighting control, driven by the simulated [LightsModel].
class LucesScreen extends StatelessWidget {
  const LucesScreen({super.key, required this.model});

  final LightsModel model;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 360, child: _SummaryPanel(model: model)),
            const SizedBox(width: AppSpacing.cardGap),
            Expanded(child: _RoomsView(model: model)),
          ],
        );
      },
    );
  }
}

/// Left control panel: overview count + master scenes.
class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.model});

  final LightsModel model;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      glow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(
                icon: Symbols.lightbulb,
                accent: _accent,
                size: 52,
                iconSize: 28,
              ),
              const SizedBox(width: AppSpacing.iconText),
              Text('Luces', style: AppText.sectionTitle),
            ],
          ),
          const SizedBox(height: AppSpacing.s40),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${model.onCount}', style: AppText.time.copyWith(fontSize: 64)),
              const SizedBox(width: AppSpacing.s8),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '/ ${model.total}',
                  style: AppText.tempMedium.copyWith(color: AppColors.textTertiary),
                ),
              ),
            ],
          ),
          Text('encendidas ahora', style: AppText.secondary),
          const Spacer(),
          _SceneButton(
            icon: Symbols.power_settings_new,
            label: 'Apagar todo',
            accent: AppColors.textTertiary,
            onTap: model.allOff,
          ),
          const SizedBox(height: AppSpacing.miniGap),
          _SceneButton(
            icon: Symbols.light_mode,
            label: 'Encender todo',
            accent: _accent,
            onTap: model.allOn,
          ),
          const SizedBox(height: AppSpacing.miniGap),
          _SceneButton(
            icon: Symbols.bedtime,
            label: 'Modo noche',
            accent: _accent,
            onTap: model.nightMode,
          ),
        ],
      ),
    );
  }
}

class _SceneButton extends StatelessWidget {
  const _SceneButton({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(AppRadius.mini),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: Row(
              children: [
                IconBadge(icon: icon, accent: accent, size: 42, iconSize: 22, radius: 12),
                const SizedBox(width: AppSpacing.iconText),
                Text(label, style: AppText.bodyStrong.copyWith(fontSize: 16)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Right side: every room as a section with its individual lights.
class _RoomsView extends StatelessWidget {
  const _RoomsView({required this.model});

  final LightsModel model;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(right: AppSpacing.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < LightsModel.rooms.length; i++) ...[
            _RoomSection(model: model, room: LightsModel.rooms[i]),
            if (i != LightsModel.rooms.length - 1)
              const SizedBox(height: AppSpacing.cardGap),
          ],
        ],
      ),
    );
  }
}

class _RoomSection extends StatelessWidget {
  const _RoomSection({required this.model, required this.room});

  final LightsModel model;
  final RoomInfo room;

  @override
  Widget build(BuildContext context) {
    final lights = model.byRoom(room.name);
    final onCount = model.roomOnCount(room.name);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(icon: room.icon, accent: _accent, size: 44, iconSize: 24),
              const SizedBox(width: AppSpacing.iconText),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(room.name, style: AppText.bodyStrong),
                    const SizedBox(height: 2),
                    Text('$onCount de ${lights.length} encendidas', style: AppText.secondary),
                  ],
                ),
              ),
              AppToggle(
                value: model.roomAllOn(room.name),
                accent: _accent,
                onChanged: (v) => model.setRoom(room.name, v),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.miniGap),
          _LightGrid(model: model, lights: lights),
        ],
      ),
    );
  }
}

/// Lays lights out two-per-row with equal widths.
class _LightGrid extends StatelessWidget {
  const _LightGrid({required this.model, required this.lights});

  final LightsModel model;
  final List<LightDevice> lights;

  @override
  Widget build(BuildContext context) {
    const columns = 2;
    final rows = <Widget>[];
    for (var i = 0; i < lights.length; i += columns) {
      final rowItems = <Widget>[];
      for (var c = 0; c < columns; c++) {
        final index = i + c;
        if (c > 0) rowItems.add(const SizedBox(width: AppSpacing.miniGap));
        rowItems.add(
          Expanded(
            child: index < lights.length
                ? _LightTile(model: model, light: lights[index])
                : const SizedBox.shrink(),
          ),
        );
      }
      if (rows.isNotEmpty) rows.add(const SizedBox(height: AppSpacing.miniGap));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rowItems,
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

class _LightTile extends StatelessWidget {
  const _LightTile({required this.model, required this.light});

  final LightsModel model;
  final LightDevice light;

  @override
  Widget build(BuildContext context) {
    final badgeAccent = light.isOn ? _accent : AppColors.textTertiary;

    return AnimatedContainer(
      duration: AppMotion.duration,
      curve: AppMotion.curve,
      decoration: BoxDecoration(
        gradient: AppGradients.card,
        borderRadius: BorderRadius.circular(AppRadius.mini),
        border: Border.all(
          color: light.isOn ? _accent.withValues(alpha: 0.28) : AppColors.border,
          width: 1,
        ),
        boxShadow: light.isOn
            ? [
                BoxShadow(
                  color: _accent.withValues(alpha: 0.12),
                  blurRadius: 20,
                  spreadRadius: -6,
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Row(
          children: [
            IconBadge(icon: light.icon, accent: badgeAccent, size: 40, iconSize: 22, radius: 12),
            const SizedBox(width: AppSpacing.iconText),
            Expanded(
              child: Text(
                light.name,
                style: AppText.body.copyWith(
                  color: light.isOn ? AppColors.textPrimary : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            AppToggle(
              value: light.isOn,
              accent: _accent,
              onChanged: (_) => model.toggle(light.id),
            ),
          ],
        ),
      ),
    );
  }
}
