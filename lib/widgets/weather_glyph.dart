import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models/weather_model.dart';

const Color _sun = Color(0xFFFFC53A);
const Color _moon = Color(0xFFCFE0F5);
const Color _cloud = Color(0xFFE7EEF8);
const Color _rain = Color(0xFF7FC1FF);
const Color _snow = Color(0xFFEAF3FF);
const Color _bolt = Color(0xFFFFC53A);

/// Renders a layered, colored glyph for the given [kind], adapting to day/night.
class WeatherGlyph extends StatelessWidget {
  const WeatherGlyph({super.key, required this.kind, required this.isDay});

  final WeatherKind kind;
  final bool isDay;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 74,
      child: switch (kind) {
        WeatherKind.clear => _single(
            isDay ? Symbols.sunny : Symbols.bedtime,
            isDay ? _sun : _moon,
            size: 60,
          ),
        WeatherKind.partly => _sunCloud(),
        WeatherKind.cloudy => _single(Symbols.cloud, _cloud, size: 62),
        WeatherKind.fog => _single(Symbols.foggy, _cloud, size: 60),
        WeatherKind.rain => _single(Symbols.rainy, _rain, size: 60),
        WeatherKind.snow => _single(Symbols.weather_snowy, _snow, size: 60),
        WeatherKind.thunder => _single(Symbols.thunderstorm, _bolt, size: 60),
      },
    );
  }

  Widget _single(IconData icon, Color color, {required double size}) {
    return Center(
      child: Icon(
        icon,
        size: size,
        fill: 1,
        weight: 600,
        color: color,
        shadows: [
          Shadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
    );
  }

  /// A warm sun (or cool moon at night) peeking behind a cloud.
  Widget _sunCloud() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: -2,
          left: 2,
          child: Icon(
            isDay ? Symbols.sunny : Symbols.bedtime,
            size: 46,
            fill: 1,
            weight: 600,
            color: isDay ? _sun : _moon,
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Icon(
            Symbols.cloud,
            size: 66,
            fill: 1,
            weight: 500,
            color: _cloud,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
