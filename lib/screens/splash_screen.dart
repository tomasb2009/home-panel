import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/tokens.dart';
import '../widgets/glow_border.dart';

/// Elegant, futuristic boot screen. Plays `intro.mp3` while a glowing emblem,
/// an orbiting light ring and a light-sweep title animate in. When the intro
/// finishes (or a safety timeout elapses) it calls [onFinish] to enter the app.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onFinish});

  final VoidCallback onFinish;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Staggered entrance of the emblem, title and footer.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  // Slow ambient breathing for the glow.
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: AppMotion.breath,
  )..repeat(reverse: true);

  // Continuous rotation for the orbital ring.
  late final AnimationController _orbit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  )..repeat();

  // Moving highlight that sweeps across the wordmark.
  late final AnimationController _sheen = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..repeat();

  final AudioPlayer _player = AudioPlayer();
  final List<StreamSubscription<dynamic>> _subs = [];

  double _progress = 0;
  Duration _total = Duration.zero;
  bool _finished = false;
  Timer? _minTimer;
  Timer? _fallbackTimer;
  bool _minElapsed = false;

  @override
  void initState() {
    super.initState();
    _intro.forward();
    _startAudio();

    // Always show the splash for at least a beat, and never hang forever if the
    // audio's completion event never arrives.
    _minTimer = Timer(const Duration(milliseconds: 2600), () {
      _minElapsed = true;
    });
    _fallbackTimer = Timer(const Duration(seconds: 12), _finish);
  }

  Future<void> _startAudio() async {
    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setVolume(0.8);
      _subs.add(_player.onDurationChanged.listen((d) {
        if (mounted) setState(() => _total = d);
      }));
      _subs.add(_player.onPositionChanged.listen((pos) {
        if (!mounted || _total.inMilliseconds == 0) return;
        setState(() {
          _progress = (pos.inMilliseconds / _total.inMilliseconds).clamp(0.0, 1.0);
        });
      }));
      _subs.add(_player.onPlayerComplete.listen((_) {
        _progress = 1;
        _finish();
      }));
      await _player.play(AssetSource('sounds/intro.mp3'));
    } catch (_) {
      // No audio available — fall back to a timed splash.
      _fallbackTimer?.cancel();
      _fallbackTimer = Timer(const Duration(milliseconds: 3200), _finish);
    }
  }

  void _finish() {
    if (_finished) return;
    // Respect a minimum on-screen time so a very short/failed intro still reads.
    if (!_minElapsed) {
      Timer(const Duration(milliseconds: 600), _finish);
      return;
    }
    _finished = true;
    widget.onFinish();
  }

  @override
  void dispose() {
    _minTimer?.cancel();
    _fallbackTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    _intro.dispose();
    _ambient.dispose();
    _orbit.dispose();
    _sheen.dispose();
    super.dispose();
  }

  double _stagger(double start, double end, {Curve curve = Curves.easeOutCubic}) {
    return CurvedAnimation(
      parent: _intro,
      curve: Interval(start, end, curve: curve),
    ).value;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: AnimatedBuilder(
          animation: Listenable.merge([_intro, _ambient, _orbit, _sheen]),
          builder: (context, _) {
            final breath = Curves.easeInOut.transform(_ambient.value);
            final emblemIn = Curves.easeOutBack.transform(_stagger(0.0, 0.55));
            final titleIn = _stagger(0.35, 0.8);
            final subIn = _stagger(0.5, 0.9);
            final footerIn = _stagger(0.65, 1.0);

            return Stack(
              children: [
                // Ambient radial glow behind everything, breathing softly.
                Positioned.fill(
                  child: Align(
                    alignment: const Alignment(0, -0.28),
                    child: _AmbientGlow(breath: breath),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Opacity(
                        opacity: emblemIn.clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: 0.7 + 0.3 * emblemIn.clamp(0.0, 1.0),
                          child: _Emblem(breath: breath, orbit: _orbit.value),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s40),
                      Opacity(
                        opacity: titleIn,
                        child: Transform.translate(
                          offset: Offset(0, 16 * (1 - titleIn)),
                          child: _Wordmark(sheen: _sheen.value),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      Opacity(
                        opacity: subIn,
                        child: Text(
                          'TU HOGAR, EN CONTROL',
                          style: AppText.secondary.copyWith(
                            letterSpacing: 5,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Footer: slim progress bar tied to the intro playback.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 64,
                  child: Opacity(
                    opacity: footerIn,
                    child: Column(
                      children: [
                        _ProgressBar(value: _progress, breath: breath),
                        const SizedBox(height: AppSpacing.s16),
                        Text(
                          'Iniciando el panel',
                          style: AppText.secondary.copyWith(letterSpacing: 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Big, soft blue radial glow that gently breathes.
class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({required this.breath});

  final double breath;

  @override
  Widget build(BuildContext context) {
    final scale = 0.92 + 0.10 * breath;
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 620,
        height: 620,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              AppColors.glow.withValues(alpha: 0.16 + 0.06 * breath),
              AppColors.glow.withValues(alpha: 0.05),
              Colors.transparent,
            ],
            stops: const [0.0, 0.45, 1.0],
          ),
        ),
      ),
    );
  }
}

/// The glowing brand mark: an orbiting light ring around a gradient badge.
class _Emblem extends StatelessWidget {
  const _Emblem({required this.breath, required this.orbit});

  final double breath;
  final double orbit;

  @override
  Widget build(BuildContext context) {
    const double ring = 208;
    const double badge = 132;

    return SizedBox(
      width: ring,
      height: ring,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Orbiting light ring.
          Transform.rotate(
            angle: orbit * 2 * math.pi,
            child: CustomPaint(
              size: const Size(ring, ring),
              painter: _OrbitPainter(),
            ),
          ),
          // Second, slower counter-orbit for depth.
          Transform.rotate(
            angle: -orbit * 2 * math.pi * 0.6 + math.pi,
            child: CustomPaint(
              size: const Size(ring - 26, ring - 26),
              painter: _OrbitPainter(sweep: 0.7, opacity: 0.5),
            ),
          ),
          // The badge itself.
          Container(
            width: badge,
            height: badge,
            decoration: BoxDecoration(
              gradient: AppGradients.card,
              borderRadius: BorderRadius.circular(AppRadius.main),
              boxShadow: [
                BoxShadow(
                  color: AppColors.glow.withValues(alpha: 0.28 + 0.18 * breath),
                  blurRadius: 34 + 14 * breath,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: GlowBorderPainter(
                      radius: AppRadius.main,
                      lineWidth: 1.2,
                      glowWidth: 3,
                      glowBlur: 6,
                    ),
                  ),
                ),
                Icon(
                  Symbols.cottage,
                  size: 64,
                  weight: 500,
                  fill: 0,
                  color: AppColors.blueBright,
                  shadows: [
                    Shadow(
                      color: AppColors.glow.withValues(alpha: 0.7),
                      blurRadius: 18 + 8 * breath,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws a faint track plus a bright, blurred sweeping arc with a leading dot.
class _OrbitPainter extends CustomPainter {
  const _OrbitPainter({this.sweep = 1.5, this.opacity = 1});

  final double sweep;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 3;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const start = -math.pi / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = AppColors.glow.withValues(alpha: 0.07 * opacity);
    canvas.drawCircle(center, radius, track);

    final shader = SweepGradient(
      startAngle: start,
      endAngle: start + sweep,
      colors: [
        Colors.transparent,
        AppColors.blue.withValues(alpha: 0.5 * opacity),
        const Color(0xFFB3E1FF).withValues(alpha: opacity),
      ],
      stops: const [0.0, 0.65, 1.0],
    ).createShader(rect);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..shader = shader
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    canvas.drawArc(rect, start, sweep, false, arc);

    // Leading glowing dot.
    final end = start + sweep;
    final dot = Offset(
      center.dx + radius * math.cos(end),
      center.dy + radius * math.sin(end),
    );
    canvas.drawCircle(
      dot,
      3.4,
      Paint()
        ..color = const Color(0xFFDCF0FF).withValues(alpha: opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(
      dot,
      2.2,
      Paint()..color = Colors.white.withValues(alpha: opacity),
    );
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter old) =>
      old.sweep != sweep || old.opacity != opacity;
}

/// "Home Panel" wordmark with a moving specular sheen sweeping across it.
class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.sheen});

  final double sheen;

  @override
  Widget build(BuildContext context) {
    final p = -0.35 + sheen * 1.7;
    final stops = <double>[
      (p - 0.18).clamp(0.0, 1.0),
      p.clamp(0.0, 1.0),
      (p + 0.18).clamp(0.0, 1.0),
    ];

    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => LinearGradient(
        colors: const [
          AppColors.textSecondary,
          Colors.white,
          AppColors.textSecondary,
        ],
        stops: stops,
      ).createShader(bounds),
      child: Text(
        'Home Panel',
        style: AppText.time.copyWith(
          fontSize: 52,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Slim, glowing progress bar. Falls back to an indeterminate shimmer until the
/// audio reports a real duration.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value, required this.breath});

  final double value;
  final double breath;

  @override
  Widget build(BuildContext context) {
    const double width = 240;
    return Center(
      child: SizedBox(
        width: width,
        height: 4,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0.0, 1.0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: const LinearGradient(
                    colors: [AppColors.blue, AppColors.blueBright],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.glow.withValues(alpha: 0.4 + 0.2 * breath),
                      blurRadius: 10,
                      spreadRadius: -1,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
