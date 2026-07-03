import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// Base surface for every card in the panel.
///
/// Applies the ultra-subtle diagonal gradient, the tenuous 5% border and the
/// imperceptible separating shadow. Glow is opt-in (weather card only).
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.radius = AppRadius.card,
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
    this.glow = false,
    this.clip = false,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final bool glow;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppGradients.card,
        borderRadius: borderRadius,
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          ...AppShadows.card,
          if (glow) ...AppShadows.glow,
        ],
      ),
      child: clip
          ? ClipRRect(
              borderRadius: borderRadius,
              child: Padding(padding: padding, child: child),
            )
          : Padding(padding: padding, child: child),
    );
  }
}
