import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../models/events_model.dart';
import '../services/click_sound.dart';
import '../theme/tokens.dart';
import 'controls/app_calendar.dart';
import 'glow_border.dart';
import 'icon_badge.dart';

/// Themed, self-contained "new event" form shown as a centred modal overlay
/// inside the design canvas (so it scales with everything else).
class NewEventDialog extends StatefulWidget {
  const NewEventDialog({super.key, required this.model, required this.onClose});

  final EventsModel model;
  final VoidCallback onClose;

  @override
  State<NewEventDialog> createState() => _NewEventDialogState();
}

class _NewEventDialogState extends State<NewEventDialog> {
  final TextEditingController _title = TextEditingController();
  EventCategory _category = EventCategory.general;
  late DateTime _date = _todayDate();
  int _hour = 9;
  int _minute = 0;

  late final FixedExtentScrollController _hourCtrl =
      FixedExtentScrollController(initialItem: _hour);
  late final FixedExtentScrollController _minuteCtrl =
      FixedExtentScrollController(initialItem: _minute ~/ 5);

  static DateTime _todayDate() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  bool get _valid => _title.text.trim().isNotEmpty;

  void _save() {
    if (!_valid) return;
    widget.model.add(
      title: _title.text,
      when: DateTime(_date.year, _date.month, _date.day, _hour, _minute),
      category: _category,
    );
    widget.onClose();
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
          child: Transform.scale(scale: 0.96 + 0.04 * t, child: child),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              ...AppShadows.card,
              BoxShadow(
                color: AppColors.glow.withValues(alpha: 0.20),
                blurRadius: 40,
                spreadRadius: 0,
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
                width: 780,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.cardPadding),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _header(),
                      const SizedBox(height: AppSpacing.titleContent),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _leftForm()),
                            const SizedBox(width: AppSpacing.cardGap),
                            SizedBox(width: 300, child: _rightDate()),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.titleContent),
                      _footer(),
                    ],
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
        const IconBadge(icon: Symbols.event, accent: AppColors.blue, size: 44, iconSize: 24),
        const SizedBox(width: AppSpacing.iconText),
        Expanded(child: Text('Nuevo evento', style: AppText.sectionTitle)),
        _CircleButton(icon: Symbols.close, onTap: widget.onClose),
      ],
    );
  }

  Widget _leftForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Título'),
        const SizedBox(height: AppSpacing.s8),
        _TitleField(controller: _title),
        const SizedBox(height: AppSpacing.miniGap),
        _label('Categoría'),
        const SizedBox(height: AppSpacing.s8),
        Wrap(
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s8,
          children: [
            for (final c in EventCategory.values)
              _CategoryChip(
                category: c,
                selected: c == _category,
                onTap: () => setState(() => _category = c),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.miniGap),
        _label('Hora'),
        const SizedBox(height: AppSpacing.s8),
        _TimePicker(
          hourCtrl: _hourCtrl,
          minuteCtrl: _minuteCtrl,
          onHour: (h) => setState(() => _hour = h),
          onMinute: (m) => setState(() => _minute = m),
        ),
      ],
    );
  }

  Widget _rightDate() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Fecha'),
        const SizedBox(height: AppSpacing.s8),
        AppCalendar(
          selected: _date,
          accent: AppColors.blue,
          onSelected: (d) => setState(() => _date = d),
        ),
      ],
    );
  }

  Widget _footer() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _TextAction(label: 'Cancelar', onTap: widget.onClose),
        const SizedBox(width: AppSpacing.miniGap),
        _PrimaryAction(label: 'Guardar evento', enabled: _valid, onTap: _save),
      ],
    );
  }

  Widget _label(String text) =>
      Text(text.toUpperCase(), style: AppText.statLabel.copyWith(letterSpacing: 0.8));
}

class _TitleField extends StatelessWidget {
  const _TitleField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(AppRadius.mini),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
        child: TextField(
          controller: controller,
          cursorColor: AppColors.blue,
          style: AppText.body.copyWith(color: AppColors.textPrimary),
          decoration: InputDecoration(
            isCollapsed: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            border: InputBorder.none,
            hintText: 'Ej. Cena con amigos',
            hintStyle: AppText.body.copyWith(color: AppColors.textTertiary),
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final EventCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = category.color;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: withClick(onTap),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: AppMotion.duration,
          curve: AppMotion.curve,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(AppRadius.mini),
            border: Border.all(
              color: selected ? color.withValues(alpha: 0.55) : AppColors.border,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                category.icon,
                size: 18,
                weight: 600,
                color: selected ? color : AppColors.textTertiary,
              ),
              const SizedBox(width: 8),
              Text(
                category.label,
                style: AppText.chipLabel.copyWith(
                  color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimePicker extends StatelessWidget {
  const _TimePicker({
    required this.hourCtrl,
    required this.minuteCtrl,
    required this.onHour,
    required this.onMinute,
  });

  final FixedExtentScrollController hourCtrl;
  final FixedExtentScrollController minuteCtrl;
  final ValueChanged<int> onHour;
  final ValueChanged<int> onMinute;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(AppRadius.mini),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: SizedBox(
        height: 118,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Center selection band.
            Center(
              child: Container(
                height: 38,
                margin: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.blue.withValues(alpha: 0.30), width: 1),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _wheel(
                  controller: hourCtrl,
                  count: 24,
                  valueOf: (i) => i,
                  onChanged: onHour,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(':', style: AppText.tempMedium.copyWith(fontSize: 24)),
                ),
                _wheel(
                  controller: minuteCtrl,
                  count: 12,
                  valueOf: (i) => i * 5,
                  onChanged: onMinute,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _wheel({
    required FixedExtentScrollController controller,
    required int count,
    required int Function(int) valueOf,
    required ValueChanged<int> onChanged,
  }) {
    return SizedBox(
      width: 62,
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: 38,
        physics: const FixedExtentScrollPhysics(),
        perspective: 0.004,
        overAndUnderCenterOpacity: 0.35,
        onSelectedItemChanged: (i) => onChanged(valueOf(i)),
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: count,
          builder: (context, i) => Center(
            child: Text(
              valueOf(i).toString().padLeft(2, '0'),
              style: AppText.bodyStrong.copyWith(fontSize: 20),
            ),
          ),
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

class _TextAction extends StatelessWidget {
  const _TextAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: withClick(onTap),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Text(
            label,
            style: AppText.bodyStrong.copyWith(fontSize: 15, color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? withClick(onTap) : null,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: AnimatedOpacity(
          duration: AppMotion.duration,
          opacity: enabled ? 1 : 0.4,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.blue.withValues(alpha: 0.95),
                  AppColors.blue.withValues(alpha: 0.70),
                ],
              ),
              borderRadius: BorderRadius.circular(AppRadius.mini),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: AppColors.glow.withValues(alpha: 0.40),
                        blurRadius: 16,
                        spreadRadius: -2,
                      ),
                    ]
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              child: Text(
                label,
                style: AppText.bodyStrong.copyWith(fontSize: 15, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
