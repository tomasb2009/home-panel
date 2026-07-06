import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../services/click_sound.dart';
import '../../theme/tokens.dart';
import '../../utils/date_format.dart';

/// A compact, themed month calendar. Past days are disabled so only future
/// dates can be scheduled.
class AppCalendar extends StatefulWidget {
  const AppCalendar({
    super.key,
    required this.selected,
    required this.onSelected,
    this.accent = AppColors.blue,
  });

  final DateTime selected;
  final ValueChanged<DateTime> onSelected;
  final Color accent;

  @override
  State<AppCalendar> createState() => _AppCalendarState();
}

class _AppCalendarState extends State<AppCalendar> {
  late DateTime _visible = DateTime(widget.selected.year, widget.selected.month);

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  void _shiftMonth(int delta) {
    setState(() => _visible = DateTime(_visible.year, _visible.month + delta));
  }

  bool _canGoBack() {
    final firstOfThisMonth = DateTime(_today.year, _today.month);
    return _visible.isAfter(firstOfThisMonth);
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(_visible.year, _visible.month + 1, 0).day;
    final firstWeekday = DateTime(_visible.year, _visible.month, 1).weekday; // Mon=1
    final leadingBlanks = firstWeekday - 1;

    final cells = <Widget>[];
    for (var i = 0; i < leadingBlanks; i++) {
      cells.add(const Expanded(child: SizedBox.shrink()));
    }
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_visible.year, _visible.month, day);
      cells.add(Expanded(child: _DayCell(
        date: date,
        selected: _isSameDay(date, widget.selected),
        isToday: _isSameDay(date, _today),
        disabled: date.isBefore(_today),
        accent: widget.accent,
        onTap: () => widget.onSelected(date),
      )));
    }
    while (cells.length % 7 != 0) {
      cells.add(const Expanded(child: SizedBox.shrink()));
    }

    final weeks = <Widget>[];
    for (var i = 0; i < cells.length; i += 7) {
      weeks.add(Row(children: cells.sublist(i, i + 7)));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _NavArrow(
              icon: Symbols.chevron_left,
              enabled: _canGoBack(),
              onTap: () => _shiftMonth(-1),
            ),
            Expanded(
              child: Text(
                EsDate.monthYear(_visible.year, _visible.month),
                textAlign: TextAlign.center,
                style: AppText.bodyStrong.copyWith(fontSize: 15),
              ),
            ),
            _NavArrow(
              icon: Symbols.chevron_right,
              enabled: true,
              onTap: () => _shiftMonth(1),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
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
        const SizedBox(height: 4),
        ...weeks,
      ],
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _NavArrow extends StatelessWidget {
  const _NavArrow({required this.icon, required this.enabled, required this.onTap});

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.3,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? withClick(onTap) : null,
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Icon(icon, size: 20, weight: 600, color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.selected,
    required this.isToday,
    required this.disabled,
    required this.accent,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final bool isToday;
  final bool disabled;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color textColor = disabled
        ? AppColors.textTertiary.withValues(alpha: 0.4)
        : selected
            ? const Color(0xFF0B1524)
            : AppColors.textSecondary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: disabled ? null : withClick(onTap),
      child: MouseRegion(
        cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: AspectRatio(
            aspectRatio: 1,
            child: AnimatedContainer(
              duration: AppMotion.duration,
              curve: AppMotion.curve,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? accent : null,
                border: (isToday && !selected)
                    ? Border.all(color: accent.withValues(alpha: 0.6), width: 1.4)
                    : null,
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.45),
                          blurRadius: 12,
                          spreadRadius: -2,
                        ),
                      ]
                    : null,
              ),
              child: Text(
                '${date.day}',
                style: AppText.body.copyWith(
                  color: textColor,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
