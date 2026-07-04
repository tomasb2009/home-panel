import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../models/events_model.dart';
import '../theme/tokens.dart';
import '../utils/date_format.dart';
import 'app_card.dart';
import 'controls/confirm_delete_button.dart';
import 'icon_badge.dart';
import 'section_header.dart';

/// "Próximos eventos" — reactive list backed by [EventsModel]. The header "+"
/// opens the new-event flow; each row can be removed.
class EventsCard extends StatelessWidget {
  const EventsCard({
    super.key,
    required this.model,
    required this.onNewEvent,
    required this.onOpenCalendar,
  });

  final EventsModel model;
  final VoidCallback onNewEvent;
  final VoidCallback onOpenCalendar;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) {
        final events = model.upcoming;
        return AppCard(
          glow: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: 'Próximos eventos',
                trailing: Symbols.add,
                onTrailingTap: onNewEvent,
              ),
              const SizedBox(height: AppSpacing.titleContent),
              Expanded(
                child: events.isEmpty
                    ? const _EmptyState()
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: events.length,
                        separatorBuilder: (_, _) => const Padding(
                          padding: EdgeInsets.symmetric(vertical: AppSpacing.s8),
                          child: Divider(height: 1, thickness: 1, color: AppColors.divider),
                        ),
                        itemBuilder: (context, i) => _EventRow(
                          event: events[i],
                          onDelete: () => model.remove(events[i].id),
                        ),
                      ),
              ),
              const SizedBox(height: AppSpacing.s8),
              const Divider(height: 1, thickness: 1, color: AppColors.divider),
              const SizedBox(height: AppSpacing.miniGap),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onOpenCalendar,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Row(
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
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Symbols.event_available,
            size: 40,
            weight: 500,
            color: AppColors.textTertiary.withValues(alpha: 0.6),
          ),
          const SizedBox(height: AppSpacing.s8),
          Text('Sin eventos próximos', style: AppText.secondary),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, required this.onDelete});

  final CalendarEvent event;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IconBadge(icon: event.category.icon, accent: event.category.color, size: 42, iconSize: 22, radius: 12),
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
                EsDate.whenLine(event.when),
                style: AppText.secondary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.s8),
        ConfirmDeleteButton(onConfirm: onDelete),
      ],
    );
  }
}
