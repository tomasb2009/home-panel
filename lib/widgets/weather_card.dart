import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../models/weather_model.dart';
import '../theme/tokens.dart';
import '../utils/date_format.dart';
import 'glow_border.dart';
import 'ticking_builder.dart';
import 'weather_glyph.dart';

/// The most prominent element of the panel: full-height, background image,
/// centered content, layered lighting and a bright glowing rim. Time and date
/// are live; the weather is fetched from [WeatherModel].
class WeatherCard extends StatelessWidget {
  const WeatherCard({super.key, required this.model});

  final WeatherModel model;

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
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.cardPadding,
                    vertical: AppSpacing.s40,
                  ),
                  child: _WeatherContent(model: model),
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
  const _WeatherContent({required this.model});

  final WeatherModel model;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        TickingBuilder(
          builder: (context, now) => FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              EsDate.time(now),
              style: AppText.time,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s16),
        TickingBuilder(
          interval: const Duration(seconds: 30),
          builder: (context, now) => Text(
            EsDate.longDate(now),
            textAlign: TextAlign.center,
            style: AppText.date.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s40),
        Expanded(
          child: ListenableBuilder(
            listenable: model,
            builder: (context, _) => _WeatherBody(model: model),
          ),
        ),
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
              WeatherModel.city,
              style: AppText.secondary.copyWith(fontSize: 15),
            ),
          ],
        ),
      ],
    );
  }
}

class _WeatherBody extends StatelessWidget {
  const _WeatherBody({required this.model});

  final WeatherModel model;

  @override
  Widget build(BuildContext context) {
    final data = model.data;

    if (data == null) {
      return Center(
        child: Text(
          model.hasError ? 'Clima no disponible' : 'Cargando clima…',
          style: AppText.body.copyWith(color: AppColors.textTertiary),
        ),
      );
    }

    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              WeatherGlyph(kind: data.kind, isDay: data.isDay),
              const SizedBox(width: AppSpacing.s16),
              Text('${data.temperature.round()}°', style: AppText.tempHero),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.iconText),
        Text(
          data.condition,
          textAlign: TextAlign.center,
          style: AppText.body.copyWith(fontSize: 16, color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.s40),
        _WeatherStatsRow(data: data),
        const Spacer(),
      ],
    );
  }
}

class _WeatherStatsRow extends StatelessWidget {
  const _WeatherStatsRow({required this.data});

  final WeatherData data;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _WeatherStat(
            icon: Symbols.thermostat,
            value: '${data.maxTemperature.round()}°',
            label: 'Máx.',
            accent: AppColors.blueBright,
          ),
          const SizedBox(width: AppSpacing.s24),
          _WeatherStat(
            icon: Symbols.humidity_percentage,
            value: '${data.humidity}%',
            label: 'Humedad',
            accent: AppColors.blueBright,
          ),
          const SizedBox(width: AppSpacing.s24),
          _WeatherStat(
            icon: Symbols.air,
            value: '${data.windKmh.round()} km/h',
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
