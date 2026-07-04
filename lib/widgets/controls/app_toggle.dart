import 'package:flutter/material.dart';
import '../../theme/tokens.dart';

/// A custom animated on/off switch that matches the panel's glowing language
/// (never the default Material Switch).
class AppToggle extends StatelessWidget {
  const AppToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.accent = AppColors.blue,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    const double w = 52;
    const double h = 30;
    const double pad = 3;
    const double thumb = h - pad * 2;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: AppMotion.duration,
        curve: AppMotion.curve,
        width: w,
        height: h,
        padding: const EdgeInsets.all(pad),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(h / 2),
          color: value ? null : Colors.white.withValues(alpha: 0.07),
          gradient: value
              ? LinearGradient(
                  colors: [
                    accent.withValues(alpha: 0.95),
                    accent.withValues(alpha: 0.70),
                  ],
                )
              : null,
          border: Border.all(
            color: value ? Colors.transparent : AppColors.border,
            width: 1,
          ),
          boxShadow: value
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.45),
                    blurRadius: 12,
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
        child: AnimatedAlign(
          duration: AppMotion.duration,
          curve: AppMotion.curve,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: thumb,
            height: thumb,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.30),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
