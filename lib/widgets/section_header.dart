import 'package:flutter/material.dart';
import '../services/click_sound.dart';
import '../theme/tokens.dart';

/// Section title with an optional trailing action rendered as a subtle
/// rounded control (chevron for "Resumen", plus for "Eventos").
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.onTrailingTap,
  });

  final String title;
  final IconData? trailing;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: AppText.sectionTitle)),
        if (trailing != null)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: withClick(onTrailingTap),
            child: MouseRegion(
              cursor: onTrailingTap != null
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.basic,
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(AppRadius.mini),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: Icon(
                  trailing,
                  size: 22,
                  weight: 600,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
