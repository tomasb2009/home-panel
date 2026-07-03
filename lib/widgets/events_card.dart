import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/tokens.dart';
import 'app_card.dart';
import 'icon_badge.dart';
import 'section_header.dart';

class _EventData {
  const _EventData(this.title, this.when);
  final String title;
  final String when;
}

/// "Próximos eventos" — each event is an elegant block, not a Flutter list tile.
class EventsCard extends StatelessWidget {
  const EventsCard({super.key});

  static const List<_EventData> _events = [
    _EventData('Cumpleaños de mamá', 'Sábado, 5 de Julio'),
    _EventData('Reunión de trabajo', 'Viernes, 4 de Julio · 09:00'),
    _EventData('Mantenimiento pileta', 'Lunes, 7 de Julio · 10:00'),
  ];

  @override
  Widget build(BuildContext context) {
    return AppCard(
      glow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Próximos eventos', trailing: Symbols.add),
          const SizedBox(height: AppSpacing.titleContent),
          for (var i = 0; i < _events.length; i++) ...[
            _EventRow(event: _events[i]),
            if (i != _events.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.s8),
                child: Divider(height: 1, thickness: 1, color: AppColors.divider),
              ),
          ],
          const Spacer(),
          const Divider(height: 1, thickness: 1, color: AppColors.divider),
          const SizedBox(height: AppSpacing.miniGap),
          Row(
            children: [
              Text(
                'Ver calendario',
                style: AppText.body.copyWith(
                  color: AppColors.blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              const Icon(
                Symbols.chevron_right,
                size: 20,
                weight: 600,
                color: AppColors.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});

  final _EventData event;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const IconBadge(
          icon: Symbols.calendar_month,
          accent: AppColors.violet,
          size: 44,
          iconSize: 24,
        ),
        const SizedBox(width: AppSpacing.iconText),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                event.title,
                style: AppText.statValue,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                event.when,
                style: AppText.secondary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
