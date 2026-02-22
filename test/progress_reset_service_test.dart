import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:baraka30/services/progress_reset_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProgressResetService.ensureCalendarProgressCurrent', () {
    test('resets daily and monthly when stored keys are old', () async {
      final now = DateTime.now();
      final today = ProgressResetService.formatDate(now);
      final month = ProgressResetService.formatMonth(now);

      SharedPreferences.setMockInitialValues({
        'quran_progress_date': '2000-01-01',
        'quran_progress_month': '2000-01',
        'quran_pages_read_today': <String>['1', '2'],
        'quran_pages_read_month': <String>['1', '2', '3'],
        'last_reset_date': '2000-01-01',
        'task_Fajr + Read 5 Pages': true,
        'task_Dhuhr + Read 5 Pages': true,
        'task_Asr + Read 5 Pages': true,
        'task_Maghrib + Read 5 Pages': true,
        'task_Isha + Read 5 Pages': true,
        'task_Taraweeh/Tahajjud': true,
        'task_Morning/Evening Dhikr': true,
      });

      final prefs = await SharedPreferences.getInstance();
      final result = await ProgressResetService.ensureCalendarProgressCurrent(
        prefs: prefs,
        rounds: 1,
      );

      expect(result.dailyReset, isTrue);
      expect(result.monthlyReset, isTrue);
      expect(result.todayKey, today);
      expect(result.monthKey, month);
      expect(prefs.getString('quran_progress_date'), today);
      expect(prefs.getString('quran_progress_month'), month);
      expect(prefs.getStringList('quran_pages_read_today'), isEmpty);
      expect(prefs.getStringList('quran_pages_read_month'), isEmpty);
      expect(prefs.getString('last_reset_date'), today);
      expect(prefs.getBool('task_Fajr + Read 5 Pages'), isFalse);
      expect(prefs.getBool('task_Dhuhr + Read 5 Pages'), isFalse);
      expect(prefs.getBool('task_Asr + Read 5 Pages'), isFalse);
      expect(prefs.getBool('task_Maghrib + Read 5 Pages'), isFalse);
      expect(prefs.getBool('task_Isha + Read 5 Pages'), isFalse);
      expect(prefs.getBool('task_Taraweeh/Tahajjud'), isFalse);
      expect(prefs.getBool('task_Morning/Evening Dhikr'), isFalse);
    });

    test('resets monthly only when month changed but same day key', () async {
      final now = DateTime.now();
      final today = ProgressResetService.formatDate(now);
      final month = ProgressResetService.formatMonth(now);

      SharedPreferences.setMockInitialValues({
        'quran_progress_date': today,
        'quran_progress_month': '1999-12',
        'quran_pages_read_today': <String>['1', '2'],
        'quran_pages_read_month': <String>['1', '2', '3'],
      });

      final prefs = await SharedPreferences.getInstance();
      final result = await ProgressResetService.ensureCalendarProgressCurrent(
        prefs: prefs,
        rounds: 1,
      );

      expect(result.dailyReset, isFalse);
      expect(result.monthlyReset, isTrue);
      expect(prefs.getStringList('quran_pages_read_today'), hasLength(2));
      expect(prefs.getStringList('quran_pages_read_month'), isEmpty);
      expect(prefs.getString('quran_progress_month'), month);
    });

    test('does not reset when date and month are current', () async {
      final now = DateTime.now();
      final today = ProgressResetService.formatDate(now);
      final month = ProgressResetService.formatMonth(now);

      SharedPreferences.setMockInitialValues({
        'quran_progress_date': today,
        'quran_progress_month': month,
        'quran_pages_read_today': <String>['1', '2'],
        'quran_pages_read_month': <String>['1', '2', '3'],
      });

      final prefs = await SharedPreferences.getInstance();
      final result = await ProgressResetService.ensureCalendarProgressCurrent(
        prefs: prefs,
        rounds: 1,
      );

      expect(result.dailyReset, isFalse);
      expect(result.monthlyReset, isFalse);
      expect(prefs.getStringList('quran_pages_read_today'), hasLength(2));
      expect(prefs.getStringList('quran_pages_read_month'), hasLength(3));
    });
  });
}
