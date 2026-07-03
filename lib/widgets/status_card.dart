import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import 'app_card.dart';

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 36, weight: 600, color: accent),
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

/// Small solid status indicator dot.
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.color, this.size = 9});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
