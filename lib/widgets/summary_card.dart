import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/tokens.dart';
import 'app_card.dart';
import 'glow_border.dart';
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
            child: Column(
              children: [
                Expanded(
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
                    ],
                  ),
                ),
                SizedBox(height: AppSpacing.miniGap),
                Expanded(
                  child: Row(
                    children: [
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
    final radius = BorderRadius.circular(AppRadius.mini);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        // Soft screen-reflection glow so the card gently floats.
        boxShadow: [
          ...AppShadows.card,
          BoxShadow(
            color: AppColors.glow.withValues(alpha: 0.10),
            blurRadius: 26,
            spreadRadius: -8,
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: radius,
              child: const DecoratedBox(
                decoration: BoxDecoration(gradient: AppGradients.card),
                child: DecoratedBox(
                  // Ambient light breathing from the top-left corner.
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(-0.8, -1.1),
                      radius: 1.3,
                      colors: [Color(0x1F42A5FF), Color(0x0042A5FF)],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _IconBadge(icon: icon),
                const Spacer(),
                Text(
                  name,
                  style: AppText.bodyStrong.copyWith(fontSize: 15),
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
          // Faint glowing rim — the same light as the weather card, dialled down.
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: GlowBorderPainter(
                  radius: AppRadius.mini,
                  lineWidth: 1,
                  glowWidth: 2,
                  glowBlur: 4,
                  colors: [
                    const Color(0xFFB3E1FF).withValues(alpha: 0.45),
                    const Color(0xFF5AA6F0).withValues(alpha: 0.22),
                    const Color(0xFF2A5C9E).withValues(alpha: 0.15),
                    const Color(0xFF6FBEFF).withValues(alpha: 0.40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A glowing rounded chip that gives the icon strong-but-elegant presence.
class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.blue.withValues(alpha: 0.22),
            AppColors.blue.withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(
          color: AppColors.blue.withValues(alpha: 0.30),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.glow.withValues(alpha: 0.22),
            blurRadius: 16,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Icon(
        icon,
        size: 28,
        weight: 600,
        color: AppColors.blueBright,
        shadows: [
          Shadow(
            color: AppColors.glow.withValues(alpha: 0.55),
            blurRadius: 12,
          ),
        ],
      ),
    );
  }
}
