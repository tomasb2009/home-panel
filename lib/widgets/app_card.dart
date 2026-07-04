import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import 'glow_border.dart';

/// Base surface for every card in the panel.
///
/// Applies the ultra-subtle diagonal gradient, the tenuous 5% border and the
/// imperceptible separating shadow. When [glow] is set the card gains the
/// futuristic "screen-reflection" treatment: a soft floating glow, ambient
/// light from the top-left and a faint glowing rim.
class AppCard extends StatefulWidget {
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
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> with SingleTickerProviderStateMixin {
  AnimationController? _breath;

  @override
  void initState() {
    super.initState();
    if (widget.glow) {
      _breath = AnimationController(vsync: this, duration: AppMotion.breath)
        ..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _breath?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(widget.radius);

    if (!widget.glow) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppGradients.card,
          borderRadius: borderRadius,
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: AppShadows.card,
        ),
        child: widget.clip
            ? ClipRRect(
                borderRadius: borderRadius,
                child: Padding(padding: widget.padding, child: widget.child),
              )
            : Padding(padding: widget.padding, child: widget.child),
      );
    }

    return AnimatedBuilder(
      animation: _breath!,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_breath!.value);
        // Gently pulse the outer reflection so the card feels alive.
        final glowAlpha = 0.06 + (0.16 - 0.06) * t;
        final glowBlur = 20.0 + (32.0 - 20.0) * t;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            boxShadow: [
              ...AppShadows.card,
              BoxShadow(
                color: AppColors.glow.withValues(alpha: glowAlpha),
                blurRadius: glowBlur,
                spreadRadius: -8,
              ),
            ],
          ),
          child: Stack(
            // Let the glowing rim bleed softly outward rather than clipping it
            // to a hard rectangular edge.
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: borderRadius,
                  child: const Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(gradient: AppGradients.card),
                      ),
                      // Ambient light breathing from the top-left corner.
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment(-0.8, -1.1),
                            radius: 1.3,
                            colors: [Color(0x1F42A5FF), Color(0x0042A5FF)],
                          ),
                        ),
                      ),
                      // Glassy specular sheen sliding down from the top edge.
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x12FFFFFF), Color(0x00FFFFFF)],
                            stops: [0.0, 0.4],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(padding: widget.padding, child: widget.child),
              // Faint glowing rim — the weather card's light, dialled down.
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: GlowBorderPainter(
                      radius: widget.radius,
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
      },
    );
  }
}
