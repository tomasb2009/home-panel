import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Broad weather families used to pick a glyph and a Spanish label.
enum WeatherKind { clear, partly, cloudy, fog, rain, snow, thunder }

/// A snapshot of the current weather plus today's forecast max.
@immutable
class WeatherData {
  const WeatherData({
    required this.temperature,
    required this.humidity,
    required this.windKmh,
    required this.maxTemperature,
    required this.code,
    required this.isDay,
  });

  final double temperature;
  final int humidity;
  final double windKmh;
  final double maxTemperature;
  final int code;
  final bool isDay;

  WeatherKind get kind => _kindFor(code);

  /// Spanish description of the current sky.
  String get condition {
    switch (code) {
      case 0:
        return 'Despejado';
      case 1:
        return 'Mayormente despejado';
      case 2:
        return 'Parcialmente nublado';
      case 3:
        return 'Nublado';
      case 45:
      case 48:
        return 'Niebla';
      case 51:
      case 53:
      case 55:
        return 'Llovizna';
      case 56:
      case 57:
        return 'Llovizna helada';
      case 61:
      case 63:
      case 65:
        return 'Lluvia';
      case 66:
      case 67:
        return 'Lluvia helada';
      case 71:
      case 73:
      case 75:
        return 'Nieve';
      case 77:
        return 'Granos de nieve';
      case 80:
      case 81:
      case 82:
        return 'Chubascos';
      case 85:
      case 86:
        return 'Chubascos de nieve';
      case 95:
        return 'Tormenta';
      case 96:
      case 99:
        return 'Tormenta con granizo';
      default:
        return 'Sin datos';
    }
  }

  static WeatherKind _kindFor(int code) {
    if (code == 0 || code == 1) return WeatherKind.clear;
    if (code == 2) return WeatherKind.partly;
    if (code == 3) return WeatherKind.cloudy;
    if (code == 45 || code == 48) return WeatherKind.fog;
    if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
      return WeatherKind.rain;
    }
    if ((code >= 71 && code <= 77) || code == 85 || code == 86) {
      return WeatherKind.snow;
    }
    if (code >= 95) return WeatherKind.thunder;
    return WeatherKind.cloudy;
  }
}

/// Fetches live weather for a fixed location (Córdoba, Argentina) from the
/// free, key-less Open-Meteo API and refreshes it periodically.
class WeatherModel extends ChangeNotifier {
  WeatherModel();

  // Córdoba, Córdoba, Argentina.
  static const double _lat = -31.4201;
  static const double _lon = -64.1888;
  static const String _timezone = 'America/Argentina/Cordoba';
  static const String city = 'Córdoba';

  static const Duration _refreshEvery = Duration(minutes: 15);

  WeatherData? _data;
  WeatherData? get data => _data;

  bool _loading = false;
  bool get loading => _loading;

  bool _hasError = false;
  bool get hasError => _hasError;

  Timer? _timer;

  /// Kicks off the first fetch and schedules periodic refreshes.
  void start() {
    refresh();
    _timer ??= Timer.periodic(_refreshEvery, (_) => refresh());
  }

  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    if (_data == null) notifyListeners();

    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '$_lat',
      'longitude': '$_lon',
      'current':
          'temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m,is_day',
      'daily': 'temperature_2m_max',
      'timezone': _timezone,
    });

    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) {
        throw HttpException('HTTP ${res.statusCode}');
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final current = json['current'] as Map<String, dynamic>;
      final daily = json['daily'] as Map<String, dynamic>;
      final maxList = (daily['temperature_2m_max'] as List).cast<num>();

      _data = WeatherData(
        temperature: (current['temperature_2m'] as num).toDouble(),
        humidity: (current['relative_humidity_2m'] as num).round(),
        windKmh: (current['wind_speed_10m'] as num).toDouble(),
        maxTemperature: maxList.isNotEmpty
            ? maxList.first.toDouble()
            : (current['temperature_2m'] as num).toDouble(),
        code: (current['weather_code'] as num).toInt(),
        isDay: (current['is_day'] as num) == 1,
      );
      _hasError = false;
    } catch (e) {
      debugPrint('WeatherModel refresh failed: $e');
      _hasError = _data == null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class HttpException implements Exception {
  HttpException(this.message);
  final String message;
  @override
  String toString() => 'HttpException: $message';
}
