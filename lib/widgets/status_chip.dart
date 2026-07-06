import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import 'app_card.dart';
import 'icon_badge.dart';

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
        glow: true,
        radius: AppRadius.mini,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s16,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconBadge(icon: icon, accent: accent, size: 38, iconSize: 20, radius: 11),
            const SizedBox(width: AppSpacing.iconText),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: AppText.chipLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value, style: AppText.chipValue, maxLines: 1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
