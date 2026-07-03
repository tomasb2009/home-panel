import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// A glowing rounded chip that gives an icon strong-but-elegant presence.
///
/// Tinted by [accent] so it stays cohesive with whatever colour the card uses.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    this.accent = AppColors.blue,
    this.iconColor,
    this.size = 52,
    this.iconSize = 28,
    this.radius = 14,
  });

  final IconData icon;
  final Color accent;

  /// Overrides the icon colour; defaults to a slightly brighter [accent].
  final Color? iconColor;
  final double size;
  final double iconSize;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.22),
            accent.withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.30), width: 1),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.22),
            blurRadius: 16,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Icon(
        icon,
        size: iconSize,
        weight: 600,
        color: iconColor ?? accent,
        shadows: [
          Shadow(color: accent.withValues(alpha: 0.55), blurRadius: 12),
        ],
      ),
    );
  }
}
