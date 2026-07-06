import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../models/connectivity_model.dart';
import '../models/events_model.dart';
import '../models/weather_model.dart';
import '../theme/tokens.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/events_card.dart';
import '../widgets/status_card.dart';
import '../widgets/summary_card.dart';
import '../widgets/weather_card.dart';

/// The "Main" tab content. The surrounding canvas, background and navigation
/// bar are provided by the app shell.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.events,
    required this.weather,
    required this.connectivity,
    required this.onNewEvent,
    required this.onOpenCalendar,
  });

  final EventsModel events;
  final WeatherModel weather;
  final ConnectivityModel connectivity;
  final VoidCallback onNewEvent;
  final VoidCallback onOpenCalendar;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 27, child: WeatherCard(model: weather)),
        const SizedBox(width: AppSpacing.cardGap),
        Expanded(
          flex: 73,
          child: _MainColumn(
            events: events,
            connectivity: connectivity,
            onNewEvent: onNewEvent,
            onOpenCalendar: onOpenCalendar,
          ),
        ),
      ],
    );
  }
}

class _MainColumn extends StatelessWidget {
  const _MainColumn({
    required this.events,
    required this.connectivity,
    required this.onNewEvent,
    required this.onOpenCalendar,
  });

  final EventsModel events;
  final ConnectivityModel connectivity;
  final VoidCallback onNewEvent;
  final VoidCallback onOpenCalendar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DashboardHeader(connectivity: connectivity),
        const SizedBox(height: AppSpacing.cardGap),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: StatusCard(
                  icon: Symbols.home,
                  accent: AppColors.blue,
                  title: 'Estado del hogar',
                  value: Row(
                    children: [
                      const StatusDot(color: AppColors.green, glow: true),
                      const SizedBox(width: AppSpacing.s8),
                      Text('Todo normal', style: AppText.bodyStrong),
                    ],
                  ),
                  subtitle: 'No hay alertas activas',
                ),
              ),
              const SizedBox(width: AppSpacing.cardGap),
              Expanded(
                child: StatusCard(
                  icon: Symbols.thermostat,
                  accent: AppColors.amber,
                  title: 'Temperatura interior',
                  value: Text('23.5°', style: AppText.tempMedium),
                  subtitle: 'Confortable',
                ),
              ),
              const SizedBox(width: AppSpacing.cardGap),
              Expanded(
                child: StatusCard(
                  icon: Symbols.devices,
                  accent: AppColors.violet,
                  title: 'Dispositivos conectados',
                  value: Text('23', style: AppText.tempMedium),
                  subtitle: 'Dispositivos en línea',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.cardGap),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Expanded(flex: 66, child: SummaryCard()),
              const SizedBox(width: AppSpacing.cardGap),
              Expanded(
                flex: 34,
                child: EventsCard(
                  model: events,
                  onNewEvent: onNewEvent,
                  onOpenCalendar: onOpenCalendar,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
