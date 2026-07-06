/// Time-of-day buckets used for the greeting.
///
/// - [morning]   06:00 – 12:59  → "Buenos días"
/// - [afternoon] 13:00 – 19:59  → "Buenas tardes"
/// - [night]     20:00 – 05:59  → "Buenas noches"
enum Daypart {
  morning,
  afternoon,
  night;

  static Daypart of(DateTime time) {
    final h = time.hour;
    if (h >= 6 && h < 13) return Daypart.morning;
    if (h >= 13 && h < 20) return Daypart.afternoon;
    return Daypart.night;
  }

  String get greeting => switch (this) {
        Daypart.morning => 'Buenos días',
        Daypart.afternoon => 'Buenas tardes',
        Daypart.night => 'Buenas noches',
      };
}
