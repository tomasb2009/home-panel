import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/tokens.dart';
import 'glow_border.dart';

class NavDestination {
  const NavDestination(this.icon, this.label);
  final IconData icon;
  final String label;
}

/// Fully custom floating navigation bar (never BottomNavigationBar).
///
/// A single glowing "pill" indicator slides across the items to the selected
/// one, passing over the others on the way.
class AppNavBar extends StatefulWidget {
  const AppNavBar({
    super.key,
    required this.currentIndex,
    required this.onChanged,
  });

  final int currentIndex;
  final ValueChanged<int> onChanged;

  static const List<NavDestination> destinations = [
    NavDestination(Symbols.home, 'Inicio'),
    NavDestination(Symbols.lightbulb, 'Luces'),
    NavDestination(Symbols.blinds, 'Cortinas'),
    NavDestination(Symbols.pool, 'Pileta'),
    NavDestination(Symbols.shield, 'Seguridad'),
    NavDestination(Symbols.settings, 'Configuración'),
    NavDestination(Symbols.more_horiz, 'Más'),
  ];

  @override
  State<AppNavBar> createState() => _AppNavBarState();
}

class _AppNavBarState extends State<AppNavBar> {
  final GlobalKey _stackKey = GlobalKey();
  late final List<GlobalKey> _itemKeys = List.generate(
    AppNavBar.destinations.length,
    (_) => GlobalKey(),
  );
  List<Rect> _rects = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null || !stackBox.hasSize) return;
    final rects = <Rect>[];
    for (final key in _itemKeys) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      final offset = box.localToGlobal(Offset.zero, ancestor: stackBox);
      rects.add(offset & box.size);
    }
    if (!mounted) return;
    if (_rects.length != rects.length ||
        !List.generate(rects.length, (i) => _rects[i] == rects[i])
            .every((e) => e)) {
      setState(() => _rects = rects);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Geometry is stable (the whole panel lives in a fixed design canvas), but
    // measure again after each build defensively until the rects settle.
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());

    final hasRects =
        _rects.length == AppNavBar.destinations.length &&
        widget.currentIndex < _rects.length;
    // Inset the pill inside the (equal-width) item so neighbouring pills never
    // touch and the indicator keeps a little breathing room.
    final Rect? active = hasRects
        ? Rect.fromLTRB(
            _rects[widget.currentIndex].left + 6,
            _rects[widget.currentIndex].top + 2,
            _rects[widget.currentIndex].right - 6,
            _rects[widget.currentIndex].bottom - 2,
          )
        : null;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppGradients.card,
        borderRadius: BorderRadius.circular(AppRadius.navbar),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: AppShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.miniGap,
          vertical: AppSpacing.s8,
        ),
        child: Stack(
          key: _stackKey,
          clipBehavior: Clip.none,
          children: [
            if (active != null)
              AnimatedPositioned(
                duration: AppMotion.duration,
                curve: AppMotion.curve,
                left: active.left,
                top: active.top,
                width: active.width,
                height: active.height,
                child: const _SlidingIndicator(),
              ),
            Row(
              children: [
                for (var i = 0; i < AppNavBar.destinations.length; i++)
                  Expanded(
                    child: _NavItem(
                      key: _itemKeys[i],
                      destination: AppNavBar.destinations[i],
                      selected: i == widget.currentIndex,
                      onTap: () => widget.onChanged(i),
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

/// The moving pill: soft blue fill, outer glow and a clean glowing rim.
class _SlidingIndicator extends StatelessWidget {
  const _SlidingIndicator();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.activeButton),
        boxShadow: [
          BoxShadow(
            color: AppColors.glow.withValues(alpha: 0.22),
            blurRadius: 16,
            spreadRadius: -2,
          ),
          BoxShadow(
            color: const Color(0xFF66C0FF).withValues(alpha: 0.10),
            blurRadius: 30,
          ),
        ],
      ),
      child: const CustomPaint(
        painter: GlowBorderPainter(
          radius: AppRadius.activeButton,
          lineWidth: 1.2,
          glowWidth: 3,
          glowBlur: 5,
          inset: 0.8,
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    super.key,
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final Color contentColor = selected
        ? AppColors.blueBright
        : (_hovered ? AppColors.textSecondary : AppColors.textTertiary);

    final double scale = _pressed ? 0.96 : (_hovered && !selected ? 1.03 : 1.0);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        // Each item is stretched to an equal width by Expanded; the content is
        // centered inside so every button reads the same size.
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
          child: AnimatedScale(
            scale: scale,
            duration: AppMotion.duration,
            curve: AppMotion.curve,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<Color?>(
                  duration: AppMotion.duration,
                  curve: AppMotion.curve,
                  tween: ColorTween(end: contentColor),
                  builder: (context, color, _) => Icon(
                    widget.destination.icon,
                    size: 30,
                    weight: 600,
                    fill: selected ? 1 : 0,
                    color: color,
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedDefaultTextStyle(
                  duration: AppMotion.duration,
                  curve: AppMotion.curve,
                  // Weight stays constant so item widths never shift and the
                  // sliding indicator stays perfectly aligned.
                  style: AppText.navLabel.copyWith(color: contentColor),
                  child: Text(widget.destination.label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
