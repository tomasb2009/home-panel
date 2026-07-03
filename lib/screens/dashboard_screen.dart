import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/tokens.dart';
import '../widgets/app_nav_bar.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/events_card.dart';
import '../widgets/status_card.dart';
import '../widgets/summary_card.dart';
import '../widgets/weather_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _navIndex = 0;

  // Fixed design canvas matching the target 14" panel (1920x1200 → 16:10).
  // The whole UI is laid out here and scaled to fill the display, guaranteeing
  // exact proportions, spacing and hierarchy on the device and at any DPI.
  static const Size _canvas = Size(1366, 854);

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
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.outer),
                  child: Column(
                    children: [
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: const [
                            Expanded(flex: 27, child: WeatherCard()),
                            SizedBox(width: AppSpacing.cardGap),
                            Expanded(flex: 73, child: _MainColumn()),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.cardGap),
                      AppNavBar(
                        currentIndex: _navIndex,
                        onChanged: (i) => setState(() => _navIndex = i),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MainColumn extends StatelessWidget {
  const _MainColumn();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DashboardHeader(),
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
                      const StatusDot(color: AppColors.green),
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
        const Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 66, child: SummaryCard()),
              SizedBox(width: AppSpacing.cardGap),
              Expanded(flex: 34, child: EventsCard()),
            ],
          ),
        ),
      ],
    );
  }
}
