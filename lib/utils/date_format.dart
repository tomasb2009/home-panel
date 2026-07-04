/// Lightweight Spanish date formatting helpers (no intl dependency).
class EsDate {
  EsDate._();

  static const List<String> _months = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];

  /// Full weekday names indexed by DateTime.weekday (Mon = 1 ... Sun = 7).
  static const List<String> _weekdays = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo',
  ];

  /// Single-letter weekday headers, Monday first.
  static const List<String> weekdayInitials = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  static String month(int month1to12) => _months[month1to12 - 1];

  static String weekday(DateTime date) => _weekdays[date.weekday - 1];

  static String monthYear(int year, int month) => '${_months[month - 1]} $year';

  /// "Sábado, 5 de Julio".
  static String longDate(DateTime date) =>
      '${weekday(date)}, ${date.day} de ${_months[date.month - 1]}';

  /// "09:00".
  static String time(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Relative day label: "Hoy" / "Mañana", otherwise the long date.
  static String dayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    if (_sameDay(date, today)) return 'Hoy';
    if (_sameDay(date, tomorrow)) return 'Mañana';
    return longDate(date);
  }

  /// Full "when" line: "Sábado, 5 de Julio · 13:00".
  static String whenLine(DateTime date) => '${dayLabel(date)} · ${time(date)}';
}
