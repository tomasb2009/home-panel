import 'package:flutter/material.dart';

/// Paints a bright, softly glowing gradient rim along a rounded rectangle.
/// Shared by the weather card and the active navbar button for a consistent
/// "screen-reflection" light on the edge.
class GlowBorderPainter extends CustomPainter {
  const GlowBorderPainter({
    required this.radius,
    this.lineWidth = 1.4,
    this.glowWidth = 3.5,
    this.glowBlur = 6,
    this.inset = 1,
    this.colors = const [
      Color(0xFFB3E1FF),
      Color(0xFF5AA6F0),
      Color(0xFF2A5C9E),
      Color(0xFF6FBEFF),
    ],
    this.stops = const [0.0, 0.35, 0.7, 1.0],
  });

  final double radius;
  final double lineWidth;
  final double glowWidth;
  final double glowBlur;
  final double inset;
  final List<Color> colors;
  final List<double> stops;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(inset),
      Radius.circular(radius),
    );

    final shader = LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: colors,
      stops: stops,
    ).createShader(rect);

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = glowWidth
      ..shader = shader
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowBlur);
    canvas.drawRRect(rrect, glow);

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth
      ..shader = shader;
    canvas.drawRRect(rrect, line);
  }

  @override
  bool shouldRepaint(covariant GlowBorderPainter old) =>
      old.radius != radius ||
      old.lineWidth != lineWidth ||
      old.glowWidth != glowWidth ||
      old.glowBlur != glowBlur ||
      old.inset != inset;
}
