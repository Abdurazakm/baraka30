import 'package:shared_preferences/shared_preferences.dart';

class ProgressResetResult {
  const ProgressResetResult({
    required this.dailyReset,
    required this.monthlyReset,
    required this.todayKey,
    required this.monthKey,
  });

  final bool dailyReset;
  final bool monthlyReset;
  final String todayKey;
  final String monthKey;
}

class ProgressResetService {
  static String formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static String formatMonth(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$year-$month';
  }

  static Future<ProgressResetResult> ensureCalendarProgressCurrent({
    required SharedPreferences prefs,
    required int rounds,
    int totalQuranPages = 604,
  }) async {
    final now = DateTime.now();
    final today = formatDate(now);
    final monthKey = formatMonth(now);

    final storedDate = prefs.getString('quran_progress_date') ?? '';
    final storedMonth = prefs.getString('quran_progress_month') ?? '';

    bool dailyReset = false;
    bool monthlyReset = false;

    if (storedDate != today) {
      dailyReset = true;
      await prefs.setString('quran_progress_date', today);
      await prefs.setStringList('quran_pages_read_today', <String>[]);
      await _resetDailyChecklist(prefs, rounds, totalQuranPages);
      await prefs.setString('last_reset_date', today);
    }

    if (storedMonth != monthKey) {
      monthlyReset = true;
      await prefs.setString('quran_progress_month', monthKey);
      await prefs.setStringList('quran_pages_read_month', <String>[]);
    }

    return ProgressResetResult(
      dailyReset: dailyReset,
      monthlyReset: monthlyReset,
      todayKey: today,
      monthKey: monthKey,
    );
  }

  static Future<void> _resetDailyChecklist(
    SharedPreferences prefs,
    int rounds,
    int totalQuranPages,
  ) async {
    final pagesPerPrayer = ((rounds * totalQuranPages) / 30 / 5).ceil();
    final List<String> tasks = [
      'Fajr + Read $pagesPerPrayer Pages',
      'Dhuhr + Read $pagesPerPrayer Pages',
      'Asr + Read $pagesPerPrayer Pages',
      'Maghrib + Read $pagesPerPrayer Pages',
      'Isha + Read $pagesPerPrayer Pages',
      'Taraweeh/Tahajjud',
      'Morning/Evening Dhikr',
    ];

    for (final task in tasks) {
      await prefs.setBool('task_$task', false);
    }
  }
}
