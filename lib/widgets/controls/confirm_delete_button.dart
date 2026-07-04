import 'dart:async';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../theme/tokens.dart';

/// A trash button that requires a second confirming tap. First tap reveals
/// a cancel/confirm pair inline; it auto-reverts after a few seconds.
class ConfirmDeleteButton extends StatefulWidget {
  const ConfirmDeleteButton({super.key, required this.onConfirm, this.size = 32});

  final VoidCallback onConfirm;
  final double size;

  @override
  State<ConfirmDeleteButton> createState() => _ConfirmDeleteButtonState();
}

class _ConfirmDeleteButtonState extends State<ConfirmDeleteButton> {
  bool _confirming = false;
  Timer? _revert;

  @override
  void dispose() {
    _revert?.cancel();
    super.dispose();
  }

  void _arm() {
    setState(() => _confirming = true);
    _revert?.cancel();
    _revert = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _confirming = false);
    });
  }

  void _cancel() {
    _revert?.cancel();
    setState(() => _confirming = false);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: AppMotion.duration,
      curve: AppMotion.curve,
      alignment: Alignment.centerRight,
      child: _confirming
          ? Row(
              key: const ValueKey('confirm'),
              mainAxisSize: MainAxisSize.min,
              children: [
                _MiniButton(
                  icon: Symbols.close,
                  color: AppColors.textSecondary,
                  size: widget.size,
                  onTap: _cancel,
                ),
                const SizedBox(width: 6),
                _MiniButton(
                  icon: Symbols.check,
                  color: AppColors.red,
                  filled: true,
                  size: widget.size,
                  onTap: widget.onConfirm,
                ),
              ],
            )
          : _MiniButton(
              key: const ValueKey('trash'),
              icon: Symbols.delete,
              color: AppColors.textTertiary,
              size: widget.size,
              onTap: _arm,
            ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  const _MiniButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.size,
    this.filled = false,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled
                ? color.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: filled ? color.withValues(alpha: 0.5) : AppColors.border,
              width: 1,
            ),
          ),
          child: Icon(icon, size: 18, weight: 600, color: color),
        ),
      ),
    );
  }
}
