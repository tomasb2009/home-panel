import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/tokens.dart';
import 'status_chip.dart';

/// Lightweight greeting header. No box, no background — just text.
/// The focus stays on the clock, not the greeting.
class DashboardHeader extends StatelessWidget {
  const DashboardHeader({super.key});

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
              Text('Buenas noches, Tomás 👋', style: AppText.greeting),
              const SizedBox(height: AppSpacing.s8),
              Text('Todo en orden en tu hogar', style: AppText.greetingSub),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.cardGap),
        const StatusChip(
          icon: Symbols.wifi,
          label: 'Internet',
          value: 'Conectado',
          accent: AppColors.blue,
          width: 150,
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
