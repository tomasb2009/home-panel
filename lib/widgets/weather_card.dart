import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/tokens.dart';
import 'glow_border.dart';

/// The most prominent element of the panel: full-height, background image,
/// centered content, layered lighting and a bright glowing rim.
class WeatherCard extends StatelessWidget {
  const WeatherCard({super.key});

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(AppRadius.main);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          ...AppShadows.card,
          // Bright screen-reflection glow around the whole card.
          BoxShadow(
            color: AppColors.glow.withValues(alpha: 0.28),
            blurRadius: 34,
            spreadRadius: -2,
          ),
          BoxShadow(
            color: const Color(0xFF66C0FF).withValues(alpha: 0.14),
            blurRadius: 60,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        // Let the glowing rim bleed softly outward instead of being clipped
        // to a hard rectangular edge.
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: borderRadius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/house_night.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.bottomCenter,
                ),
                // Deep-blue readability overlay (house breathes at the bottom).
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xF00B1524),
                        Color(0xCF0B1524),
                        Color(0x800B1524),
                        Color(0x4D0B1524),
                      ],
                      stops: [0.0, 0.42, 0.66, 1.0],
                    ),
                  ),
                ),
                // Soft ambient light glowing from the top of the card.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0, -1.15),
                      radius: 1.1,
                      colors: [Color(0x3342A5FF), Color(0x0042A5FF)],
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.cardPadding,
                    vertical: AppSpacing.s40,
                  ),
                  child: _WeatherContent(),
                ),
              ],
            ),
          ),
          // Bright gradient rim drawn on top so it is never clipped away.
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: const GlowBorderPainter(radius: AppRadius.main),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherContent extends StatelessWidget {
  const _WeatherContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('20:45', style: AppText.time, textAlign: TextAlign.center),
        ),
        const SizedBox(height: AppSpacing.s16),
        Text(
          'Jueves, 3 de Julio',
          textAlign: TextAlign.center,
          style: AppText.date.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.s40),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const _WeatherGlyph(),
              const SizedBox(width: AppSpacing.s16),
              Text('22°', style: AppText.tempHero),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.iconText),
        Text(
          'Parcialmente nublado',
          textAlign: TextAlign.center,
          style: AppText.body.copyWith(fontSize: 16, color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.s40),
        const _WeatherStatsRow(),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Symbols.location_on,
              size: 20,
              weight: 600,
              fill: 1,
              color: AppColors.textTertiary,
            ),
            const SizedBox(width: AppSpacing.s8),
            Text(
              'Buenos Aires',
              style: AppText.secondary.copyWith(fontSize: 15),
            ),
          ],
        ),
      ],
    );
  }
}

/// Colored partly-cloudy glyph: a warm sun peeking behind a cool cloud.
class _WeatherGlyph extends StatelessWidget {
  const _WeatherGlyph();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 74,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            top: -2,
            left: 2,
            child: Icon(
              Symbols.sunny,
              size: 46,
              fill: 1,
              weight: 600,
              color: Color(0xFFFFC53A),
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
              color: const Color(0xFFE7EEF8),
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
      ),
    );
  }
}

class _WeatherStatsRow extends StatelessWidget {
  const _WeatherStatsRow();

  @override
  Widget build(BuildContext context) {
    return const FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _WeatherStat(
            icon: Symbols.thermostat,
            value: '24°',
            label: 'Máx.',
            accent: AppColors.blueBright,
          ),
          SizedBox(width: AppSpacing.s24),
          _WeatherStat(
            icon: Symbols.humidity_percentage,
            value: '60%',
            label: 'Humedad',
            accent: AppColors.blueBright,
          ),
          SizedBox(width: AppSpacing.s24),
          _WeatherStat(
            icon: Symbols.air,
            value: '12 km/h',
            label: 'Viento',
            accent: AppColors.textTertiary,
          ),
        ],
      ),
    );
  }
}

class _WeatherStat extends StatelessWidget {
  const _WeatherStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 26, weight: 600, color: accent),
        const SizedBox(width: AppSpacing.s8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: AppText.statValue.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(label, style: AppText.statLabel.copyWith(fontSize: 13)),
          ],
        ),
      ],
    );
  }
}

