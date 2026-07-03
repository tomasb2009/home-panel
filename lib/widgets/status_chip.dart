import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import 'app_card.dart';

/// Compact status pill used in the header (Internet / Energía).
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    this.width,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: AppCard(
        radius: AppRadius.mini,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s16,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, weight: 600, color: accent),
            const SizedBox(width: AppSpacing.iconText),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: AppText.chipLabel),
                const SizedBox(height: 2),
                Text(value, style: AppText.chipValue),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
