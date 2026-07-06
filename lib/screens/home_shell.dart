import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import '../models/connectivity_model.dart';
import '../models/events_model.dart';
import '../models/lights_model.dart';
import '../models/weather_model.dart';
import '../theme/tokens.dart';
import '../widgets/app_nav_bar.dart';
import '../widgets/calendar_view.dart';
import '../widgets/icon_badge.dart';
import '../widgets/new_event_dialog.dart';
import 'dashboard_screen.dart';
import 'luces_screen.dart';

/// Modal overlays that can be shown above the panel content.
enum _Overlay { none, newEvent, calendar }

/// App shell: owns the fixed design canvas, the shared state and the floating
/// navigation bar, swapping the active screen above it.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  // Fixed design canvas matching the target 14" panel (scaled to fill).
  static const Size _canvas = Size(1366, 854);

  static const Duration _transition = Duration(milliseconds: 320);

  int _index = 0;
  // +1 when moving forward through the navbar, -1 when moving back. Drives the
  // direction of the horizontal slide transition.
  double _direction = 1;
  // Only clip the content area while a slide is playing, so card glows can
  // bleed freely at rest and never look cut off at the panel edges.
  bool _animating = false;
  Timer? _clipTimer;
  _Overlay _overlay = _Overlay.none;
  final LightsModel _lights = LightsModel();
  final EventsModel _events = EventsModel();
  final WeatherModel _weather = WeatherModel()..start();
  final ConnectivityModel _connectivity = ConnectivityModel()..start();

  void _closeOverlay() => setState(() => _overlay = _Overlay.none);

  Widget? _overlayContent() {
    switch (_overlay) {
      case _Overlay.newEvent:
        return NewEventDialog(model: _events, onClose: _closeOverlay);
      case _Overlay.calendar:
        return CalendarView(
          model: _events,
          onClose: _closeOverlay,
          onNewEvent: () => setState(() => _overlay = _Overlay.newEvent),
        );
      case _Overlay.none:
        return null;
    }
  }

  void _goTo(int i) {
    if (i == _index) return;
    setState(() {
      _direction = i > _index ? 1 : -1;
      _index = i;
      _animating = true;
    });
    _clipTimer?.cancel();
    _clipTimer = Timer(_transition + const Duration(milliseconds: 40), () {
      if (mounted) setState(() => _animating = false);
    });
  }

  @override
  void dispose() {
    _clipTimer?.cancel();
    _lights.dispose();
    _events.dispose();
    _weather.dispose();
    _connectivity.dispose();
    super.dispose();
  }

  Widget _screenFor(int index) {
    switch (index) {
      case 0:
        return DashboardScreen(
          events: _events,
          weather: _weather,
          connectivity: _connectivity,
          onNewEvent: () => setState(() => _overlay = _Overlay.newEvent),
          onOpenCalendar: () => setState(() => _overlay = _Overlay.calendar),
        );
      case 1:
        return LucesScreen(model: _lights);
      default:
        return _ComingSoon(destination: AppNavBar.destinations[index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: _canvas.width,
                height: _canvas.height,
                child: Stack(
                  children: [
                    // Clip to the panel only while a slide plays, so sliding
                    // screens never spill past the canvas — yet at rest the
                    // card glows bleed freely and never look cut at the edges.
                    ClipRect(
                      clipper: _EdgeClipper(active: _animating),
                      child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.outer,
                      AppSpacing.outer,
                      AppSpacing.outer,
                      AppSpacing.s16,
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: _transition,
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) {
                              final entering = child.key == ValueKey(_index);
                              final begin = Offset(
                                entering ? _direction : -_direction,
                                0,
                              );
                              final slide = Tween<Offset>(
                                begin: begin,
                                end: Offset.zero,
                              ).animate(animation);
                              return SlideTransition(
                                position: slide,
                                child: FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                              );
                            },
                            child: SizedBox.expand(
                              key: ValueKey(_index),
                              child: _screenFor(_index),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.cardGap),
                        AppNavBar(
                          currentIndex: _index,
                          onChanged: _goTo,
                        ),
                      ],
                    ),
                  ),
                    ),
                    if (_overlay != _Overlay.none)
                      Positioned.fill(
                        child: _ModalOverlay(
                          onDismiss: _closeOverlay,
                          child: _overlayContent()!,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-canvas modal backdrop hosting a centred [child].
class _ModalOverlay extends StatelessWidget {
  const _ModalOverlay({required this.child, required this.onDismiss});

  final Widget child;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.45)),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Clips to the canvas only while [active]; otherwise returns a hugely
/// inflated rect so glows can bleed past the panel edges unclipped.
class _EdgeClipper extends CustomClipper<Rect> {
  const _EdgeClipper({required this.active});

  final bool active;

  @override
  Rect getClip(Size size) {
    if (active) return Offset.zero & size;
    return Rect.fromLTRB(-2000, -2000, size.width + 2000, size.height + 2000);
  }

  @override
  bool shouldReclip(_EdgeClipper oldClipper) => oldClipper.active != active;
}

/// Elegant placeholder for screens that are not built yet.
class _ComingSoon extends StatelessWidget {
  const _ComingSoon({required this.destination});

  final NavDestination destination;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconBadge(
            icon: destination.icon,
            accent: AppColors.blue,
            size: 88,
            iconSize: 44,
            radius: 24,
          ),
          const SizedBox(height: AppSpacing.s24),
          Text(destination.label, style: AppText.greeting),
          const SizedBox(height: AppSpacing.s8),
          Text('Próximamente', style: AppText.body),
        ],
      ),
    );
  }
}
