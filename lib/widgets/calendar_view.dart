import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../models/events_model.dart';
import '../services/click_sound.dart';
import '../theme/tokens.dart';
import '../utils/date_format.dart';
import 'controls/confirm_delete_button.dart';
import 'glow_border.dart';
import 'icon_badge.dart';

/// Full month calendar overlay: month grid with per-day event markers on the
/// left, and the selected day's events on the right.
class CalendarView extends StatefulWidget {
  const CalendarView({
    super.key,
    required this.model,
    required this.onClose,
    required this.onNewEvent,
  });

  final EventsModel model;
  final VoidCallback onClose;
  final VoidCallback onNewEvent;

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  late DateTime _visible;
  late DateTime _selected;

  static const Color _accent = AppColors.blue;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _selected = DateTime(n.year, n.month, n.day);
    _visible = DateTime(n.year, n.month);
  }

  void _shiftMonth(int delta) {
    setState(() => _visible = DateTime(_visible.year, _visible.month + delta));
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.main);
    return Center(
      child: TweenAnimationBuilder<double>(
        duration: AppMotion.duration,
        curve: AppMotion.curve,
        tween: Tween(begin: 0, end: 1),
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.scale(scale: 0.97 + 0.03 * t, child: child),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              ...AppShadows.card,
              BoxShadow(
                color: AppColors.glow.withValues(alpha: 0.20),
                blurRadius: 40,
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: radius,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(gradient: AppGradients.card),
                  ),
                ),
              ),
              SizedBox(
                width: 1040,
                height: 660,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.cardPadding),
                  child: ListenableBuilder(
                    listenable: widget.model,
                    builder: (context, _) {
                      return Column(
                        children: [
                          _header(),
                          const SizedBox(height: AppSpacing.titleContent),
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(child: _monthGrid()),
                                const SizedBox(width: AppSpacing.cardGap),
                                SizedBox(width: 320, child: _dayPanel()),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: GlowBorderPainter(
                      radius: AppRadius.main,
                      lineWidth: 1,
                      glowWidth: 2.5,
                      glowBlur: 5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        const IconBadge(icon: Symbols.calendar_month, accent: _accent, size: 46, iconSize: 26),
        const SizedBox(width: AppSpacing.iconText),
        Text('Calendario', style: AppText.sectionTitle),
        const SizedBox(width: AppSpacing.s24),
        _NavArrow(icon: Symbols.chevron_left, onTap: () => _shiftMonth(-1)),
        SizedBox(
          width: 190,
          child: Text(
            EsDate.monthYear(_visible.year, _visible.month),
            textAlign: TextAlign.center,
            style: AppText.bodyStrong.copyWith(fontSize: 18),
          ),
        ),
        _NavArrow(icon: Symbols.chevron_right, onTap: () => _shiftMonth(1)),
        const Spacer(),
        _NewButton(onTap: widget.onNewEvent),
        const SizedBox(width: AppSpacing.s8),
        _CircleButton(icon: Symbols.close, onTap: widget.onClose),
      ],
    );
  }

  Widget _monthGrid() {
    final daysInMonth = DateTime(_visible.year, _visible.month + 1, 0).day;
    final firstWeekday = DateTime(_visible.year, _visible.month, 1).weekday;
    final leadingBlanks = firstWeekday - 1;

    final cells = <Widget>[];
    for (var i = 0; i < leadingBlanks; i++) {
      cells.add(const Expanded(child: SizedBox.shrink()));
    }
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_visible.year, _visible.month, day);
      cells.add(Expanded(
        child: _DayCell(
          date: date,
          events: widget.model.onDay(date),
          selected: _sameDay(date, _selected),
          isToday: _sameDay(date, _todayDate()),
          accent: _accent,
          onTap: () => setState(() => _selected = date),
        ),
      ));
    }
    while (cells.length % 7 != 0) {
      cells.add(const Expanded(child: SizedBox.shrink()));
    }

    final weekRows = <Widget>[];
    for (var i = 0; i < cells.length; i += 7) {
      weekRows.add(Expanded(child: Row(children: cells.sublist(i, i + 7))));
    }

    return Column(
      children: [
        Row(
          children: [
            for (final d in EsDate.weekdayInitials)
              Expanded(
                child: Text(
                  d,
                  textAlign: TextAlign.center,
                  style: AppText.statLabel.copyWith(color: AppColors.textTertiary),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        ...weekRows,
      ],
    );
  }

  Widget _dayPanel() {
    final events = widget.model.onDay(_selected);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(EsDate.weekday(_selected), style: AppText.secondary),
            const SizedBox(height: 2),
            Text(
              '${_selected.day} de ${EsDate.month(_selected.month)}',
              style: AppText.bodyStrong.copyWith(fontSize: 20),
            ),
            const SizedBox(height: AppSpacing.miniGap),
            Expanded(
              child: events.isEmpty
                  ? _emptyDay()
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: events.length,
                      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s8),
                      itemBuilder: (context, i) => _DayEventRow(
                        event: events[i],
                        onDelete: () => widget.model.remove(events[i].id),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyDay() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Symbols.event_busy, size: 34, weight: 500,
              color: AppColors.textTertiary.withValues(alpha: 0.6)),
          const SizedBox(height: AppSpacing.s8),
          Text('Sin eventos este día', style: AppText.secondary, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  static DateTime _todayDate() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.events,
    required this.selected,
    required this.isToday,
    required this.accent,
    required this.onTap,
  });

  final DateTime date;
  final List<CalendarEvent> events;
  final bool selected;
  final bool isToday;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: withClick(onTap),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.14) : null,
            borderRadius: BorderRadius.circular(AppRadius.mini),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.55)
                  : (isToday ? accent.withValues(alpha: 0.35) : Colors.transparent),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${date.day}',
                style: AppText.body.copyWith(
                  color: (selected || isToday) ? AppColors.textPrimary : AppColors.textSecondary,
                  fontWeight: (selected || isToday) ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (events.isNotEmpty)
                Row(
                  children: [
                    for (final e in events.take(3))
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: e.category.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    if (events.length > 3)
                      Text('+${events.length - 3}',
                          style: AppText.statLabel.copyWith(fontSize: 10)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayEventRow extends StatelessWidget {
  const _DayEventRow({required this.event, required this.onDelete});

  final CalendarEvent event;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(AppRadius.mini),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s8 + 2),
        child: Row(
          children: [
            IconBadge(icon: event.category.icon, accent: event.category.color, size: 38, iconSize: 20, radius: 11),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(event.title, style: AppText.body.copyWith(
                    color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(EsDate.time(event.when), style: AppText.secondary),
                ],
              ),
            ),
            const SizedBox(width: 6),
            ConfirmDeleteButton(onConfirm: onDelete, size: 30),
          ],
        ),
      ),
    );
  }
}

class _NavArrow extends StatelessWidget {
  const _NavArrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: withClick(onTap),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Icon(icon, size: 20, weight: 600, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: withClick(onTap),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(AppRadius.mini),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Icon(icon, size: 22, weight: 600, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _NewButton extends StatelessWidget {
  const _NewButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: withClick(onTap),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.blue.withValues(alpha: 0.95),
                AppColors.blue.withValues(alpha: 0.70),
              ],
            ),
            borderRadius: BorderRadius.circular(AppRadius.mini),
            boxShadow: [
              BoxShadow(
                color: AppColors.glow.withValues(alpha: 0.35),
                blurRadius: 14,
                spreadRadius: -2,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Symbols.add, size: 20, weight: 700, color: Colors.white),
                const SizedBox(width: 6),
                Text('Nuevo evento',
                    style: AppText.chipLabel.copyWith(color: Colors.white, fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
