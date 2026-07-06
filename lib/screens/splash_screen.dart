import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/tokens.dart';
import '../widgets/glow_border.dart';

/// Elegant, futuristic boot screen. Plays `intro.mp3` while a glowing emblem,
/// an orbiting HUD ring and a light-sweep title animate in. When the intro
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
    duration: const Duration(milliseconds: 1700),
  );

  // Slow ambient breathing for the glow.
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: AppMotion.breath,
  )..repeat(reverse: true);

  // Continuous rotation for the orbital ring.
  late final AnimationController _orbit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5200),
  )..repeat();

  // Moving highlight that sweeps across the wordmark and the progress fill.
  late final AnimationController _sheen = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
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
          _progress =
              (pos.inMilliseconds / _total.inMilliseconds).clamp(0.0, 1.0);
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

  double _stagger(double start, double end,
      {Curve curve = Curves.easeOutCubic}) {
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
            final emblemFade = _stagger(0.0, 0.4);
            final titleIn = _stagger(0.32, 0.78);
            final subIn = _stagger(0.5, 0.92);
            final footerIn = _stagger(0.62, 1.0);

            return Stack(
              children: [
                // Layered ambient lighting + vignette.
                Positioned.fill(child: _Backdrop(breath: breath)),

                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Opacity(
                        opacity: emblemFade.clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: 0.72 + 0.28 * emblemIn.clamp(0.0, 1.0),
                          child: _Emblem(breath: breath, orbit: _orbit.value),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s40 + 8),
                      Opacity(
                        opacity: titleIn,
                        child: Transform.translate(
                          offset: Offset(0, 18 * (1 - titleIn)),
                          child: _Wordmark(sheen: _sheen.value),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.miniGap),
                      // Thin divider that grows in with the tagline.
                      Opacity(
                        opacity: subIn,
                        child: Container(
                          height: 1,
                          width: 200 * subIn,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                AppColors.glow.withValues(alpha: 0.6),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.miniGap),
                      Opacity(
                        opacity: subIn,
                        child: Text(
                          'TU HOGAR, EN CONTROL',
                          style: AppText.secondary.copyWith(
                            letterSpacing: 6,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Footer: glowing progress bar tied to the intro playback.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 66,
                  child: Opacity(
                    opacity: footerIn,
                    child: Transform.translate(
                      offset: Offset(0, 14 * (1 - footerIn)),
                      child: Column(
                        children: [
                          _ProgressBar(
                            value: _progress,
                            breath: breath,
                            sheen: _sheen.value,
                          ),
                          const SizedBox(height: AppSpacing.s16),
                          _FooterLabel(value: _progress, orbit: _orbit.value),
                        ],
                      ),
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

/// Base lighting: a big breathing glow, a tighter core glow and an edge
/// vignette that focuses attention on the centre.
class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.breath});

  final double breath;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Align(
          alignment: const Alignment(0, -0.30),
          child: Transform.scale(
            scale: 0.92 + 0.10 * breath,
            child: Container(
              width: 680,
              height: 680,
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
          ),
        ),
        Align(
          alignment: const Alignment(0, -0.34),
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF66C0FF).withValues(alpha: 0.10 + 0.05 * breath),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // Vignette: keeps the edges dark and premium.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: 1.1,
              colors: [Colors.transparent, Color(0x66060810)],
              stops: [0.55, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

/// The glowing brand mark: an orbiting HUD ring around a gradient badge.
class _Emblem extends StatelessWidget {
  const _Emblem({required this.breath, required this.orbit});

  final double breath;
  final double orbit;

  @override
  Widget build(BuildContext context) {
    const double ring = 216;
    const double badge = 132;

    return SizedBox(
      width: ring,
      height: ring,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // All ring layers are drawn in one painter so the motion is perfectly
          // consistent (no stacked, independently-rotating transforms).
          CustomPaint(
            size: const Size(ring, ring),
            painter: _OrbitPainter(t: orbit, breath: breath),
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
                  color: AppColors.glow.withValues(alpha: 0.30 + 0.18 * breath),
                  blurRadius: 36 + 16 * breath,
                  spreadRadius: 1,
                ),
                const BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Specular top-left highlight for a glassy feel.
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.main),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.06),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.6],
                      ),
                    ),
                  ),
                ),
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
                  size: 62,
                  weight: 500,
                  fill: 0,
                  color: AppColors.blueBright,
                  shadows: [
                    Shadow(
                      color: AppColors.glow.withValues(alpha: 0.75),
                      blurRadius: 20 + 8 * breath,
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

/// Draws the full HUD ring: a static ticked bezel, a bright rotating comet with
/// a glowing head, a dim inner counter-orbit and a couple of satellites — all
/// from a single rotation phase [t] so nothing ever drifts out of sync.
class _OrbitPainter extends CustomPainter {
  const _OrbitPainter({required this.t, required this.breath});

  final double t; // 0..1 rotation phase
  final double breath;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 4;
    final rBezel = r;
    final rComet = r - 13;
    final rInner = r - 31;
    final a = t * 2 * math.pi;

    // --- Faint full track under the bezel ticks. ---
    canvas.drawCircle(
      c,
      rBezel,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = AppColors.glow.withValues(alpha: 0.06),
    );

    // --- Static ticked bezel (HUD instrument feel). ---
    const ticks = 48;
    for (var i = 0; i < ticks; i++) {
      final ang = i / ticks * 2 * math.pi;
      final major = i % 4 == 0;
      final len = major ? 6.0 : 3.0;
      final cos = math.cos(ang);
      final sin = math.sin(ang);
      final p1 = Offset(c.dx + rBezel * cos, c.dy + rBezel * sin);
      final p2 = Offset(c.dx + (rBezel - len) * cos, c.dy + (rBezel - len) * sin);
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..strokeWidth = major ? 1.4 : 1.0
          ..color = AppColors.glow.withValues(alpha: major ? 0.16 : 0.07),
      );
    }

    // --- Dim inner counter-orbit for depth. ---
    final rectInner = Rect.fromCircle(center: c, radius: rInner);
    final bInner = -a * 1.3 + math.pi;
    const sweepInner = 1.0;
    canvas.drawArc(
      rectInner,
      bInner,
      sweepInner,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: bInner,
          endAngle: bInner + sweepInner,
          colors: [
            Colors.transparent,
            AppColors.blue.withValues(alpha: 0.45),
          ],
          stops: const [0.0, 1.0],
        ).createShader(rectInner)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );

    // --- Main comet arc (blurred glow + crisp core). ---
    final rectComet = Rect.fromCircle(center: c, radius: rComet);
    const sweep = 1.6;
    final cometColors = [
      Colors.transparent,
      AppColors.blue.withValues(alpha: 0.55),
      const Color(0xFFDCF0FF),
    ];
    final cometShader = SweepGradient(
      startAngle: a,
      endAngle: a + sweep,
      colors: cometColors,
      stops: const [0.0, 0.62, 1.0],
    ).createShader(rectComet);

    canvas.drawArc(
      rectComet,
      a,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round
        ..shader = cometShader
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawArc(
      rectComet,
      a,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..shader = cometShader,
    );

    // --- Glowing comet head. ---
    final headAng = a + sweep;
    final head = Offset(
      c.dx + rComet * math.cos(headAng),
      c.dy + rComet * math.sin(headAng),
    );
    canvas.drawCircle(
      head,
      6 + 1.5 * breath,
      Paint()
        ..color = const Color(0xFFDCF0FF).withValues(alpha: 0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(head, 2.6, Paint()..color = Colors.white);

    // --- Two small satellites trailing on the comet ring. ---
    for (final off in const [2.5, 2.9]) {
      final sa = a + off;
      final pos = Offset(
        c.dx + rComet * math.cos(sa),
        c.dy + rComet * math.sin(sa),
      );
      canvas.drawCircle(
        pos,
        3.2,
        Paint()
          ..color = AppColors.blueBright.withValues(alpha: 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(
        pos,
        1.4,
        Paint()..color = Colors.white.withValues(alpha: 0.8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter old) =>
      old.t != t || old.breath != breath;
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
          fontSize: 54,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Footer caption: "Iniciando el panel" plus a live percentage once the intro
/// reports a duration, otherwise animated ellipsis dots.
class _FooterLabel extends StatelessWidget {
  const _FooterLabel({required this.value, required this.orbit});

  final double value;
  final double orbit;

  @override
  Widget build(BuildContext context) {
    final style = AppText.secondary.copyWith(letterSpacing: 1.6);
    if (value > 0) {
      return Text(
        'Iniciando el panel · ${(value * 100).round()}%',
        style: style.copyWith(color: AppColors.textSecondary),
      );
    }
    final dots = '.' * (1 + ((orbit * 3).floor() % 3));
    return Text('Iniciando el panel$dots', style: style);
  }
}

/// Bright, glowing progress bar with a moving sheen and a glowing head cap.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.value,
    required this.breath,
    required this.sheen,
  });

  final double value;
  final double breath;
  final double sheen;

  @override
  Widget build(BuildContext context) {
    const double width = 260;
    const double height = 6;
    final v = value.clamp(0.0, 1.0);

    return Center(
      child: SizedBox(
        width: width,
        height: height + 8, // room for the head-cap glow
        child: Stack(
          alignment: Alignment.centerLeft,
          clipBehavior: Clip.none,
          children: [
            // Track.
            Center(
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(height),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                    width: 1,
                  ),
                ),
              ),
            ),
            // Fill.
            Center(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: v == 0 ? 0.001 : v,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(height),
                    child: Container(
                      height: height,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(height),
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.blue,
                            AppColors.blueBright,
                            Color(0xFFDCF0FF),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.glow
                                .withValues(alpha: 0.65 + 0.2 * breath),
                            blurRadius: 14,
                            spreadRadius: 0,
                          ),
                          BoxShadow(
                            color: const Color(0xFF66C0FF)
                                .withValues(alpha: 0.35),
                            blurRadius: 24,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: _FillSheen(sheen: sheen),
                    ),
                  ),
                ),
              ),
            ),
            // Glowing head cap at the leading edge of the fill.
            if (v > 0.02)
              Positioned(
                left: (width * v).clamp(0.0, width) - 5,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFDCF0FF)
                            .withValues(alpha: 0.9),
                        blurRadius: 12,
                        spreadRadius: 1,
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

/// A soft white band that keeps travelling along the filled portion.
class _FillSheen extends StatelessWidget {
  const _FillSheen({required this.sheen});

  final double sheen;

  @override
  Widget build(BuildContext context) {
    final p = sheen;
    final stops = <double>[
      (p - 0.16).clamp(0.0, 1.0),
      p.clamp(0.0, 1.0),
      (p + 0.16).clamp(0.0, 1.0),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            Colors.white.withValues(alpha: 0.45),
            Colors.transparent,
          ],
          stops: stops,
        ),
      ),
    );
  }
}
