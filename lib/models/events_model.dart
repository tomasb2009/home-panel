import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/tokens.dart';

/// The kind of an event, carrying its own icon and accent colour.
enum EventCategory { cumple, trabajo, hogar, salud, general }

extension EventCategoryData on EventCategory {
  String get label => switch (this) {
        EventCategory.cumple => 'Cumpleaños',
        EventCategory.trabajo => 'Trabajo',
        EventCategory.hogar => 'Hogar',
        EventCategory.salud => 'Salud',
        EventCategory.general => 'General',
      };

  IconData get icon => switch (this) {
        EventCategory.cumple => Symbols.cake,
        EventCategory.trabajo => Symbols.work,
        EventCategory.hogar => Symbols.home,
        EventCategory.salud => Symbols.favorite,
        EventCategory.general => Symbols.event,
      };

  Color get color => switch (this) {
        EventCategory.cumple => AppColors.amber,
        EventCategory.trabajo => AppColors.blue,
        EventCategory.hogar => AppColors.green,
        EventCategory.salud => AppColors.violet,
        EventCategory.general => AppColors.red,
      };
}

/// A single scheduled event. Pure in-memory mock.
class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.when,
    required this.category,
  });

  final String id;
  final String title;
  final DateTime when;
  final EventCategory category;
}

/// Simulated store of upcoming events.
class EventsModel extends ChangeNotifier {
  final List<CalendarEvent> _events = [
    CalendarEvent(id: 'e1', title: 'Reunión de trabajo', when: DateTime(2026, 7, 4, 9, 0), category: EventCategory.trabajo),
    CalendarEvent(id: 'e2', title: 'Cumpleaños de mamá', when: DateTime(2026, 7, 5, 13, 0), category: EventCategory.cumple),
    CalendarEvent(id: 'e3', title: 'Mantenimiento pileta', when: DateTime(2026, 7, 7, 10, 0), category: EventCategory.hogar),
  ];

  int _seq = 100;

  /// Upcoming events (from the start of today onward), sorted chronologically.
  List<CalendarEvent> get upcoming {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final list = _events
        .where((e) => !e.when.isBefore(startOfToday))
        .toList()
      ..sort((a, b) => a.when.compareTo(b.when));
    return list;
  }

  /// All events on a given calendar day, sorted by time.
  List<CalendarEvent> onDay(DateTime day) {
    final list = _events
        .where((e) =>
            e.when.year == day.year &&
            e.when.month == day.month &&
            e.when.day == day.day)
        .toList()
      ..sort((a, b) => a.when.compareTo(b.when));
    return list;
  }

  void add({
    required String title,
    required DateTime when,
    required EventCategory category,
  }) {
    _events.add(
      CalendarEvent(
        id: 'e${_seq++}',
        title: title.trim(),
        when: when,
        category: category,
      ),
    );
    notifyListeners();
  }

  void remove(String id) {
    _events.removeWhere((e) => e.id == id);
    notifyListeners();
  }
}
