import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/tokens.dart';
import 'app_card.dart';
import 'section_header.dart';
import 'status_card.dart';

/// "Resumen del hogar" — a section card holding four spacious mini cards.
class SummaryCard extends StatelessWidget {
  const SummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Resumen del hogar',
            trailing: Symbols.chevron_right,
          ),
          const SizedBox(height: AppSpacing.titleContent),
          const Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _MiniCard(
                    icon: Symbols.grid_view,
                    name: 'Planta Baja',
                    status: 'Todo normal',
                  ),
                ),
                SizedBox(width: AppSpacing.miniGap),
                Expanded(
                  child: _MiniCard(
                    icon: Symbols.stairs,
                    name: 'Planta Alta',
                    status: 'Todo normal',
                  ),
                ),
                SizedBox(width: AppSpacing.miniGap),
                Expanded(
                  child: _MiniCard(
                    icon: Symbols.park,
                    name: 'Exterior',
                    status: 'Todo normal',
                  ),
                ),
                SizedBox(width: AppSpacing.miniGap),
                Expanded(
                  child: _MiniCard(
                    icon: Symbols.garage,
                    name: 'Garage',
                    status: 'Todo normal',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.icon,
    required this.name,
    required this.status,
  });

  final IconData icon;
  final String name;
  final String status;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppGradients.card,
        borderRadius: BorderRadius.circular(AppRadius.mini),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 34, weight: 500, color: AppColors.textSecondary),
            const Spacer(),
            Text(
              name,
              style: AppText.body.copyWith(fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.s8),
            Row(
              children: [
                const StatusDot(color: AppColors.green, size: 7),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    status,
                    style: AppText.secondary.copyWith(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
