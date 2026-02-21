import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { english, amharic }

class AppLanguageController extends ChangeNotifier {
  static const String prefKey = 'app_language_code';

  AppLanguage _language = AppLanguage.english;
  AppLanguage get language => _language;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(prefKey);
    _language = _languageFromCode(code);
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (_language == language) {
      return;
    }
    _language = language;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefKey, _languageCode(language));
  }

  static AppLanguage _languageFromCode(String? code) {
    switch (code) {
      case 'am':
        return AppLanguage.amharic;
      case 'en':
      default:
        return AppLanguage.english;
    }
  }

  static String _languageCode(AppLanguage language) {
    switch (language) {
      case AppLanguage.amharic:
        return 'am';
      case AppLanguage.english:
      default:
        return 'en';
    }
  }
}

class AppLanguageScope extends InheritedNotifier<AppLanguageController> {
  const AppLanguageScope({
    super.key,
    required AppLanguageController controller,
    required Widget child,
  }) : super(notifier: controller, child: child);

  static AppLanguageController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppLanguageScope>();
    if (scope == null || scope.notifier == null) {
      throw StateError('AppLanguageScope is missing from the widget tree.');
    }
    return scope.notifier!;
  }
}

class AppStrings {
  AppStrings(this.language);

  final AppLanguage language;

  static AppStrings of(BuildContext context) {
    final controller = AppLanguageScope.of(context);
    return AppStrings(controller.language);
  }

  static AppStrings forLanguage(AppLanguage language) {
    return AppStrings(language);
  }

  String t(String key, {Map<String, String> vars = const {}}) {
    final value =
        _strings[language]?[key] ?? _strings[AppLanguage.english]?[key] ?? key;
    var output = value;
    vars.forEach((k, v) {
      output = output.replaceAll('{$k}', v);
    });
    return output;
  }

  String appTitle() => t('app_title');
  String navHome() => t('nav_home');
  String navDhikr() => t('nav_dhikr');
  String navQuran() => t('nav_quran');
  String navPlanner() => t('nav_planner');

  String languageLabel() => t('language');
  String english() => t('english');
  String amharic() => t('amharic');
  String cancel() => t('cancel');
  String ok() => t('ok');
  String yes() => t('yes');
  String no() => t('no');

  String ramadanDay(int day) => t('ramadan_day', vars: {'day': day.toString()});
  String hijriDate(String month, int day, int year) => t(
    'hijri_date',
    vars: {'month': month, 'day': day.toString(), 'year': year.toString()},
  );
  String lastTenNights() => t('last_ten_nights');
  String assalamuAlaikum() => t('assalamu_alaikum');
  String heroRamadanMessage(int day) =>
      t('hero_ramadan_message', vars: {'day': day.toString()});
  String heroMonthMessage(String month) =>
      t('hero_month_message', vars: {'month': month});
  String heroRead() => t('hero_read');
  String heroDhikr() => t('hero_dhikr');
  String heroDua() => t('hero_dua');
  String todaysInspiration() => t('todays_inspiration');
  String dailyChecklist() => t('daily_checklist');
  String dailyNiyyah() => t('daily_niyyah');
  String niyyahText() => t('niyyah_text');
  String fasting() => t('fasting');
  String untilPrayer(String prayer) =>
      t('until_prayer', vars: {'prayer': prayer});
  String localTime() => t('local_time');
  String locationRequiredTitle() => t('location_required_title');
  String locationRequiredMessage() => t('location_required_message');
  String locationServiceOffMessage() => t('location_service_off_message');
  String locationDeniedMessage() => t('location_denied_message');
  String locationDeniedForeverMessage() => t('location_denied_forever_message');
  String locationUnableMessage() => t('location_unable_message');
  String lastLocationUpdated(String value) =>
      t('last_location_updated', vars: {'time': value});
  String retry() => t('retry');
  String locationSettings() => t('location_settings');
  String appSettings() => t('app_settings');
  String sunnahTipMorning() => t('sunnah_tip_morning');
  String sunnahTipEvening() => t('sunnah_tip_evening');

  String checklistFajr(int pages) =>
      t('checklist_fajr', vars: {'pages': pages.toString()});
  String checklistDhuhr(int pages) =>
      t('checklist_dhuhr', vars: {'pages': pages.toString()});
  String checklistAsr(int pages) =>
      t('checklist_asr', vars: {'pages': pages.toString()});
  String checklistMaghrib(int pages) =>
      t('checklist_maghrib', vars: {'pages': pages.toString()});
  String checklistIsha(int pages) =>
      t('checklist_isha', vars: {'pages': pages.toString()});
  String checklistTaraweeh() => t('checklist_taraweeh');
  String checklistDhikr() => t('checklist_dhikr');

  String ramadanPlanner() => t('ramadan_planner');
  String todaysProgress() => t('todays_progress');
  String monthlyProgress() => t('monthly_progress');
  String quranCompletionGoal() => t('quran_completion_goal');
  String dailyReadingSchedule() => t('daily_reading_schedule');
  String dailyQuranTarget() => t('daily_quran_target');
  String monthlyQuranTarget() => t('monthly_quran_target');
  String goalSetMessage(int value) =>
      t('goal_set_message', vars: {'value': value.toString()});
  String readDailyProgress(int read, String target) => t(
    'read_daily_progress',
    vars: {'read': read.toString(), 'target': target},
  );
  String readMonthlyProgress(int read, String target) => t(
    'read_monthly_progress',
    vars: {'read': read.toString(), 'target': target},
  );
  String roundLabel(int value) => t(
    'round_label',
    vars: {'value': value.toString(), 'plural': value > 1 ? 's' : ''},
  );
  String totalPagesLabel() => t('total_pages');
  String dailyGoalLabel() => t('daily_goal');
  String pagesLabel() => t('pages');

  String tasbih() => t('tasbih');
  String resetCounter() => t('reset_counter');
  String tapCircle() => t('tap_circle');
  String setsCompleted(int count) =>
      t('sets_completed', vars: {'count': count.toString()});
  String customDhikr() => t('custom_dhikr');

  String offlineDownloads() => t('offline_downloads');
  String downloadScope() => t('download_scope');
  String selectSurahs() => t('select_surahs');
  String selectJuz() => t('select_juz');
  String translations() => t('translations');
  String defaultTranslation() => t('default_translation');
  String useDownloadedTranslations() => t('use_downloaded_translations');
  String audio() => t('audio');
  String reciter() => t('reciter');
  String useDownloadedAudio() => t('use_downloaded_audio');
  String offlineNotSupportedWeb() => t('offline_not_supported_web');
  String selectAtLeastOne() => t('select_at_least_one');
  String startingDownloads() => t('starting_downloads');
  String downloadingTranslation(String key, int surah) => t(
    'downloading_translation',
    vars: {'key': key, 'surah': surah.toString()},
  );
  String downloadingAudio(int surah) =>
      t('downloading_audio', vars: {'surah': surah.toString()});
  String downloadsComplete() => t('downloads_complete');
  String downloadFailed(String error) =>
      t('download_failed', vars: {'error': error});
  String downloadTranslations() => t('download_translations');
  String downloadAudio() => t('download_audio');
  String startDownload() => t('start_download');
  String allSurahsDownloaded() => t('all_surahs_downloaded');
  String offlineNotAvailableWeb() => t('offline_not_available_web');

  String pageLabel(int page) =>
      t('page_label', vars: {'page': page.toString()});
  String goToPage() => t('go_to_page');
  String goToPageTitle() => t('go_to_page_title');
  String pageNumberLabel() => t('page_number_label');
  String pageNumberHint() => t('page_number_hint');
  String enterPageError() => t('enter_page_error');
  String goButton() => t('go_button');
  String pageNotFound() => t('page_not_found');
  String surahIndex() => t('surah_index');
  String goToBookmark() => t('go_to_bookmark');
  String noBookmarkSaved() => t('no_bookmark_saved');
  String toggleTranslation() => t('toggle_translation');
  String translationLanguage() => t('translation_language');
  String playAudio() => t('play_audio');
  String stopAudio() => t('stop_audio');
  String highlightVerse() => t('highlight_verse');
  String removeHighlight() => t('remove_highlight');
  String showTranslation() => t('show_translation');
  String playContinuously() => t('play_continuously');
  String stopContinuous() => t('stop_continuous');
  String keepPlayingSubtitle() => t('keep_playing_subtitle');
  String playingVerse() => t('playing_verse');
  String continuousPlaybackActive() => t('continuous_playback_active');
  String continuousPlaybackFinished() => t('continuous_playback_finished');
  String couldNotPlayVerse() => t('could_not_play_verse');
  String couldNotStartContinuous() => t('could_not_start_continuous');
  String couldNotContinue() => t('could_not_continue');
  String tipTapVerse() => t('tip_tap_verse');
  String prayerFajr() => t('prayer_fajr');
  String prayerDhuhr() => t('prayer_dhuhr');
  String prayerAsr() => t('prayer_asr');
  String prayerMaghrib() => t('prayer_maghrib');
  String prayerIsha() => t('prayer_isha');
  String ayahOfDay() => t('ayah_of_day');
  String ayahLoading() => t('ayah_loading');
  String checking() => t('checking');
}

const Map<AppLanguage, Map<String, String>> _strings = {
  AppLanguage.english: {
    'app_title': 'Baraka30',
    'nav_home': 'Home',
    'nav_dhikr': 'Dhikr',
    'nav_quran': 'Quran',
    'nav_planner': 'Planner',
    'language': 'Language',
    'english': 'English',
    'amharic': 'Amharic',
    'cancel': 'Cancel',
    'ok': 'OK',
    'yes': 'Yes',
    'no': 'No',
    'ramadan_day': 'Ramadan Day {day}',
    'hijri_date': '{month} {day}, {year} AH',
    'last_ten_nights': 'LAST 10 NIGHTS',
    'assalamu_alaikum': 'Assalamu Alaikum',
    'hero_ramadan_message': 'Stay steady on Day {day} of Ramadan',
    'hero_month_message': 'Keep your Quran rhythm in {month}',
    'hero_read': 'Read',
    'hero_dhikr': 'Dhikr',
    'hero_dua': 'Dua',
    'todays_inspiration': "Today's Inspiration",
    'daily_checklist': 'Daily Checklist',
    'daily_niyyah': 'DAILY NIYYAH',
    'niyyah_text':
        '“I intend to fast this day of Ramadan for the sake of Allah.”',
    'fasting': 'FASTING',
    'until_prayer': 'until {prayer}',
    'local_time': 'Local Time',
    'location_required_title': 'Accurate Prayer Times Need Location',
    'location_required_message':
        'Location is required for accurate prayer times.',
    'location_service_off_message':
        'Enable location services to calculate prayer times accurately.',
    'location_denied_message':
        'Location permission is required for accurate prayer times.',
    'location_denied_forever_message':
        'Location permission is permanently denied. Open settings to allow it for accurate prayer times.',
    'location_unable_message':
        'Unable to get accurate location right now. Please retry.',
    'last_location_updated': 'Last updated location: {time}',
    'retry': 'Retry',
    'location_settings': 'Location Settings',
    'app_settings': 'App Settings',
    'sunnah_tip_morning':
        'Sunnah: Use Miswak to keep your breath fresh while fasting.',
    'sunnah_tip_evening': 'Sunnah: Break your fast with dates and water.',
    'checklist_fajr': 'Fajr + Read {pages} Pages',
    'checklist_dhuhr': 'Dhuhr + Read {pages} Pages',
    'checklist_asr': 'Asr + Read {pages} Pages',
    'checklist_maghrib': 'Maghrib + Read {pages} Pages',
    'checklist_isha': 'Isha + Read {pages} Pages',
    'checklist_taraweeh': 'Taraweeh/Tahajjud',
    'checklist_dhikr': 'Morning/Evening Dhikr',
    'ramadan_planner': 'Ramadan Planner',
    'todays_progress': "Today's Progress",
    'monthly_progress': 'Monthly Progress',
    'quran_completion_goal': 'Quran Completion Goal',
    'daily_reading_schedule': 'Daily Reading Schedule',
    'daily_quran_target': 'Daily Quran Target',
    'monthly_quran_target': 'Monthly Quran Target',
    'goal_set_message': 'Goal set to {value} Round{s}!',
    'read_daily_progress':
        'Read {read} / {target} pages in Quran to fill this bar.',
    'read_monthly_progress': 'Read {read} / {target} pages this month.',
    'round_label': '{value} Round{s} (Khatam)',
    'total_pages': 'Total Pages',
    'daily_goal': 'Daily Goal',
    'pages': 'Pages',
    'tasbih': 'Tasbih',
    'reset_counter': 'Reset Counter?',
    'tap_circle': 'Tap anywhere on the circle',
    'sets_completed': '{count} Sets of 33 Completed',
    'custom_dhikr': 'Custom',
    'offline_downloads': 'Offline Downloads',
    'download_scope': 'Download Scope',
    'select_surahs': 'Select Surahs',
    'select_juz': 'Select Juz',
    'translations': 'Translations',
    'default_translation': 'Default translation',
    'use_downloaded_translations': 'Use downloaded translations',
    'audio': 'Audio',
    'reciter': 'Reciter',
    'use_downloaded_audio': 'Use downloaded audio when available',
    'offline_not_supported_web': 'Offline downloads are not supported on web.',
    'select_at_least_one': 'Select at least one surah or juz.',
    'starting_downloads': 'Starting downloads...',
    'downloading_translation':
        'Downloading translation {key} (Surah {surah})...',
    'downloading_audio': 'Downloading audio (Surah {surah})...',
    'downloads_complete': 'Downloads complete.',
    'download_failed': 'Download failed: {error}',
    'download_translations': 'Download translations',
    'download_audio': 'Download audio',
    'start_download': 'Start Download',
    'all_surahs_downloaded': 'All surahs will be downloaded.',
    'offline_not_available_web':
        'Offline downloads are not available on Web. Use mobile or desktop builds for offline storage.',
    'page_label': 'Page {page}',
    'go_to_page': 'Go to Page',
    'go_to_page_title': 'Go to Page',
    'page_number_label': 'Page number',
    'page_number_hint': '1 - 604',
    'enter_page_error': 'Enter a number from 1 to 604',
    'go_button': 'Go',
    'page_not_found': 'Page not found',
    'surah_index': 'Surah Index',
    'go_to_bookmark': 'Go to Bookmark',
    'no_bookmark_saved': 'No bookmark saved',
    'toggle_translation': 'Toggle Translation',
    'translation_language': 'Translation Language',
    'play_audio': 'Play Audio',
    'stop_audio': 'Stop Audio',
    'highlight_verse': 'Highlight Verse',
    'remove_highlight': 'Remove Highlight',
    'show_translation': 'Show Translation',
    'play_continuously': 'Play Continuously from Here',
    'stop_continuous': 'Stop Continuous Play',
    'keep_playing_subtitle': 'Keeps playing next verses automatically',
    'playing_verse':
        'Playing verse audio... (long-press and choose Stop Audio)',
    'continuous_playback_active':
        'Continuous playback active... (long-press and choose Stop Continuous Play)',
    'continuous_playback_finished': 'Continuous playback finished.',
    'could_not_play_verse': 'Could not play this verse audio.',
    'could_not_start_continuous': 'Could not start continuous audio.',
    'could_not_continue': 'Could not continue playback.',
    'tip_tap_verse':
        'Tip: Tap verse to play • Long-press ayah marker for options',
    'prayer_fajr': 'Fajr',
    'prayer_dhuhr': 'Dhuhr',
    'prayer_asr': 'Asr',
    'prayer_maghrib': 'Maghrib',
    'prayer_isha': 'Isha',
    'ayah_of_day': 'Ayah of the Day',
    'ayah_loading': "Loading today's ayah...",
    'checking': 'Checking...',
  },
  AppLanguage.amharic: {
    'app_title': 'Baraka30',
    'nav_home': 'ቤት',
    'nav_dhikr': 'ዝክር',
    'nav_quran': 'ቁርአን',
    'nav_planner': 'እቅድ',
    'language': 'ቋንቋ',
    'english': 'እንግሊዝኛ',
    'amharic': 'አማርኛ',
    'cancel': 'ተው',
    'ok': 'እሺ',
    'yes': 'አዎ',
    'no': 'አይ',
    'ramadan_day': 'የረመዳን ቀን {day}',
    'hijri_date': '{month} {day}, {year} አህ',
    'last_ten_nights': 'የመጨረሻ 10 ሌሊቶች',
    'assalamu_alaikum': 'ሰላም እንዴት ነው',
    'hero_ramadan_message': 'በረመዳን {day} ቀን በጽናት ቆዩ',
    'hero_month_message': 'በ{month} የቁርአን ልምድዎን ይጠብቁ',
    'hero_read': 'ንባብ',
    'hero_dhikr': 'ዝክር',
    'hero_dua': 'ዱዓ',
    'todays_inspiration': 'ዛሬ መነሳሳት',
    'daily_checklist': 'የዕለት ተዕለት ዝርዝር',
    'daily_niyyah': 'የዕለት ነድያህ',
    'niyyah_text': '“ይህን የረመዳን ቀን ለአላህ ስለማድረግ ለመጾም እቆማለሁ።”',
    'fasting': 'ጾም',
    'until_prayer': 'እስከ {prayer}',
    'local_time': 'አካባቢ ሰዓት',
    'location_required_title': 'ትክክለኛ የሶላት ጊዜ ለመሆን አካባቢ ያስፈልጋል',
    'location_required_message': 'ትክክለኛ የሶላት ጊዜ ለማስረጃ አካባቢ ያስፈልጋል።',
    'location_service_off_message': 'ትክክለኛ የሶላት ጊዜ ለማስረጃ የአካባቢ አገልግሎት አብራሩ።',
    'location_denied_message': 'ትክክለኛ የሶላት ጊዜ ለማስረጃ የአካባቢ ፍቃድ ያስፈልጋል።',
    'location_denied_forever_message':
        'የአካባቢ ፍቃድ ለዘላቂ ተከልክሏል። ትክክለኛ የሶላት ጊዜ ለማግኘት ቅንብሮች ይክፈቱ።',
    'location_unable_message': 'አሁን ትክክለኛ አካባቢ ማግኘት አልተቻለም። እባክዎ ደግመው ይሞክሩ።',
    'last_location_updated': 'የመጨረሻ የአካባቢ ዝመና: {time}',
    'retry': 'ደግመው ይሞክሩ',
    'location_settings': 'የአካባቢ ቅንብሮች',
    'app_settings': 'የመተግበሪያ ቅንብሮች',
    'sunnah_tip_morning': 'ሱና፡ በጾም ጊዜ የስር ንፁህነትን ለመጠበቅ ሚስዋክ ይጠቀሙ።',
    'sunnah_tip_evening': 'ሱና፡ ጾምዎን በዘንባባ እና በውሃ ያፍቱ።',
    'checklist_fajr': 'ፈጅር + {pages} ገጾች አንብብ',
    'checklist_dhuhr': 'ዙህር + {pages} ገጾች አንብብ',
    'checklist_asr': 'አስር + {pages} ገጾች አንብብ',
    'checklist_maghrib': 'መግሪብ + {pages} ገጾች አንብብ',
    'checklist_isha': 'ኢሻ + {pages} ገጾች አንብብ',
    'checklist_taraweeh': 'ተራዊህ/ተሐጅዱ',
    'checklist_dhikr': 'የጠዋት/የማታ ዝክር',
    'ramadan_planner': 'የረመዳን እቅድ',
    'todays_progress': 'የዛሬ እድገት',
    'monthly_progress': 'ወርሃዊ እድገት',
    'quran_completion_goal': 'የቁርአን ማጠናቀቂያ ግብ',
    'daily_reading_schedule': 'የዕለት ንባብ ሰሌዳ',
    'daily_quran_target': 'የዕለት ቁርአን ግብ',
    'monthly_quran_target': 'ወርሃዊ ቁርአን ግብ',
    'goal_set_message': 'ግብ ተዘጋጅቷል፦ {value} ዙር{plural}!',
    'read_daily_progress': 'ይህን መደርደሪያ ለመሙላት {read} / {target} ገጾች አንብብ።',
    'read_monthly_progress': 'በዚህ ወር {read} / {target} ገጾች አንብብ።',
    'round_label': '{value} ዙር{plural} (ከተም)',
    'total_pages': 'ጠቅላላ ገጾች',
    'daily_goal': 'ዕለታዊ ግብ',
    'pages': 'ገጾች',
    'tasbih': 'ጠስብህ',
    'reset_counter': 'ቆጣሪውን ይጀምሩ?',
    'tap_circle': 'በክብ ላይ ይንኩ',
    'sets_completed': '{count} የ33 ስብስቦች ተጠናቀቁ',
    'custom_dhikr': 'ራስህ ምርጫ',
    'offline_downloads': 'የመስመር ውጭ ማውረድ',
    'download_scope': 'የማውረድ ወሰን',
    'select_surahs': 'ሱራዎችን ይምረጡ',
    'select_juz': 'ጁዝ ይምረጡ',
    'translations': 'ትርጉሞች',
    'default_translation': 'ነባሪ ትርጉም',
    'use_downloaded_translations': 'የወረዱ ትርጉሞችን ተጠቀም',
    'audio': 'ድምጽ',
    'reciter': 'ቃርኢ',
    'use_downloaded_audio': 'የወረደ ድምጽ ሲኖር ተጠቀም',
    'offline_not_supported_web': 'በድር ላይ የመስመር ውጭ ማውረድ አይቻልም።',
    'select_at_least_one': 'ቢያንስ አንድ ሱራ ወይም ጁዝ ይምረጡ።',
    'starting_downloads': 'ማውረድ ተጀምሯል...',
    'downloading_translation': 'ትርጉም {key} በማውረድ ላይ (ሱራ {surah})...',
    'downloading_audio': 'ድምጽ በማውረድ ላይ (ሱራ {surah})...',
    'downloads_complete': 'ማውረድ ተጠናቀቀ።',
    'download_failed': 'ማውረድ አልተሳካም፦ {error}',
    'download_translations': 'ትርጉሞችን አውርድ',
    'download_audio': 'ድምጽ አውርድ',
    'start_download': 'ማውረድ ጀምር',
    'all_surahs_downloaded': 'ሁሉም ሱራዎች ይወረዳሉ።',
    'offline_not_available_web':
        'በድር ላይ የመስመር ውጭ ማውረድ አይቻልም። ለመስመር ውጭ ማከማቻ የሞባይል ወይም ዴስክቶፕ ግንባታ ይጠቀሙ።',
    'page_label': 'ገጽ {page}',
    'go_to_page': 'ወደ ገጽ ሂድ',
    'go_to_page_title': 'ወደ ገጽ ሂድ',
    'page_number_label': 'የገጽ ቁጥር',
    'page_number_hint': '1 - 604',
    'enter_page_error': '1 እስከ 604 ያለ ቁጥር ያስገቡ',
    'go_button': 'ሂድ',
    'page_not_found': 'ገጽ አልተገኘም',
    'surah_index': 'የሱራ ማውጫ',
    'go_to_bookmark': 'ወደ ምልክት ሂድ',
    'no_bookmark_saved': 'ምንም ምልክት የለም',
    'toggle_translation': 'ትርጉም አሳይ/ደብቅ',
    'translation_language': 'የትርጉም ቋንቋ',
    'play_audio': 'ድምጽ አጫውት',
    'stop_audio': 'ድምጽ አቁም',
    'highlight_verse': 'አድምቅ',
    'remove_highlight': 'አድምቅን አንሳ',
    'show_translation': 'ትርጉም አሳይ',
    'play_continuously': 'ከዚህ ጀምሮ ቀጥታ አጫውት',
    'stop_continuous': 'ቀጥታ አቁም',
    'keep_playing_subtitle': 'ቀጣይ አያቶችን በራሱ ይቀጥላል',
    'playing_verse': 'የአያት ድምጽ በመጫወት ላይ... (ረዥም ጫን እና አቁም ምረጥ)',
    'continuous_playback_active':
        'ቀጥታ መቀጠል በመጫወት ላይ... (ረዥም ጫን እና ቀጥታ አቁም ምረጥ)',
    'continuous_playback_finished': 'ቀጥታ መጫወት ተጠናቀቀ።',
    'could_not_play_verse': 'የዚህ አያት ድምጽ ማጫወት አልተቻለም።',
    'could_not_start_continuous': 'ቀጥታ ድምጽ መጀመር አልተቻለም።',
    'could_not_continue': 'መቀጠል አልተቻለም።',
    'tip_tap_verse': 'ጠቅ በማድረግ ድምጽ አጫውት • ለአማራጮች የአያት ምልክትን ረዥም ጫን',
    'prayer_fajr': 'ፈጅር',
    'prayer_dhuhr': 'ዙህር',
    'prayer_asr': 'አስር',
    'prayer_maghrib': 'መግሪብ',
    'prayer_isha': 'ኢሻ',
    'ayah_of_day': 'የዛሬ አያት',
    'ayah_loading': 'የዛሬን አያት በመጫን ላይ...',
    'checking': 'በመመርመር ላይ...',
  },
};
