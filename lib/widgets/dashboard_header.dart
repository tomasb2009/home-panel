import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../models/connectivity_model.dart';
import '../theme/tokens.dart';
import '../utils/day_period.dart';
import 'status_chip.dart';
import 'ticking_builder.dart';

/// Lightweight greeting header. No box, no background — just text.
/// The focus stays on the clock, not the greeting.
class DashboardHeader extends StatelessWidget {
  const DashboardHeader({super.key, required this.connectivity});

  final ConnectivityModel connectivity;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              TickingBuilder(
                interval: const Duration(seconds: 30),
                builder: (context, now) => Text(
                  '${Daypart.of(now).greeting}, Tomás 👋',
                  style: AppText.greeting,
                ),
              ),
              const SizedBox(height: AppSpacing.s8),
              Text('Todo en orden en tu hogar', style: AppText.greetingSub),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.cardGap),
        ListenableBuilder(
          listenable: connectivity,
          builder: (context, _) {
            final online = connectivity.online;
            final (icon, value, accent) = !connectivity.checked
                ? (Symbols.wifi_find, 'Comprobando…', AppColors.textTertiary)
                : online
                    ? (Symbols.wifi, 'Conectado', AppColors.green)
                    : (Symbols.wifi_off, 'Sin conexión', AppColors.red);
            return StatusChip(
              icon: icon,
              label: 'Internet',
              value: value,
              accent: accent,
              width: 150,
            );
          },
        ),
        const SizedBox(width: AppSpacing.miniGap),
        const StatusChip(
          icon: Symbols.power_settings_new,
          label: 'Energía',
          value: 'Normal',
          accent: AppColors.green,
          width: 150,
        ),
      ],
    );
  }
}
