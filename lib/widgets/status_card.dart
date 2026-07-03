import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import 'app_card.dart';
import 'icon_badge.dart';

/// One of the three identical status cards (Estado / Temperatura / Dispositivos).
/// Identical size, height, padding and spacing — enforced by the parent Row.
class StatusCard extends StatelessWidget {
  const StatusCard({
    super.key,
    required this.icon,
    required this.accent,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final Widget value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      glow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconBadge(icon: icon, accent: accent, size: 48, iconSize: 26),
              const SizedBox(width: AppSpacing.iconText),
              Expanded(
                child: Text(
                  title,
                  style: AppText.cardTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.titleContent),
          value,
          const SizedBox(height: AppSpacing.s8),
          Text(subtitle, style: AppText.secondary),
        ],
      ),
    );
  }
}

/// Small solid status indicator dot, optionally wrapped in a soft halo that
/// gently pulses so it reads as a live, breathing signal.
class StatusDot extends StatefulWidget {
  const StatusDot({
    super.key,
    required this.color,
    this.size = 9,
    this.glow = false,
  });

  final Color color;
  final double size;
  final bool glow;

  @override
  State<StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<StatusDot>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulse;

  @override
  void initState() {
    super.initState();
    if (widget.glow) {
      _pulse = AnimationController(vsync: this, duration: AppMotion.pulse)
        ..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.glow) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _pulse!,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_pulse!.value);
        final alpha = 0.30 + (0.75 - 0.30) * t;
        final blur = 5.0 + (13.0 - 5.0) * t;
        final spread = 0.5 + (2.5 - 0.5) * t;
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: alpha),
                blurRadius: blur,
                spreadRadius: spread,
              ),
            ],
          ),
        );
      },
    );
  }
}
