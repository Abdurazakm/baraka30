import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adhan/adhan.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:quran_flutter/quran_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:math';

// Core Data Imports
import '../data/duas.dart';
import '../data/hadith.dart';
import '../data/daily_text.dart';
import '../services/app_language.dart';

// Widgets
import '../widgets/ayah_card.dart';
import '../widgets/checklist_item.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.roundsGoalListenable});

  final ValueListenable<int>? roundsGoalListenable;

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  static const String _lastLocationUpdatedPrefKey = 'last_location_updated_ms';
  static const List<String> _hijriMonthNames = [
    'Muharram',
    'Safar',
    'Rabi I',
    'Rabi II',
    'Jumada I',
    'Jumada II',
    'Rajab',
    'Sha\'ban',
    'Ramadan',
    'Shawwal',
    'Dhu al-Qi\'dah',
    'Dhu al-Hijjah',
  ];
  late SharedPreferences _prefs;
  bool _prefsReady = false;
  Timer? _timer;
  Timer? _inspirationTimer;
  int _quranPagesPerPrayer = 4; // Dynamic based on Planner Goal
  int _lastRoundsGoal = 1;
  DailyText? _dailyAyah;
  late final PageController _inspirationController;
  int _inspirationPage = 0;

  double? _lat;
  double? _lng;
  bool _isRequestingLocation = false;
  bool _isLocationServiceDisabled = false;
  bool _isPermissionDeniedForever = false;
  DateTime? _lastLocationUpdatedAt;
  String _localTimeZoneLabel = 'Local Time';
  _LocationStatus _locationStatus = _LocationStatus.required;

  final List<_ChecklistEntry> _checklist = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    // Refresh every minute to keep countdown and background colors accurate
    _timer = Timer.periodic(const Duration(minutes: 1), (t) => setState(() {}));
    widget.roundsGoalListenable?.addListener(_onRoundsGoalChanged);
    _inspirationController = PageController();
    _startInspirationTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _inspirationTimer?.cancel();
    widget.roundsGoalListenable?.removeListener(_onRoundsGoalChanged);
    _inspirationController.dispose();
    super.dispose();
  }

  void _startInspirationTimer() {
    _inspirationTimer?.cancel();
    _inspirationTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (!mounted) {
        return;
      }
      final itemCount = 3;
      if (itemCount <= 1 || !_inspirationController.hasClients) {
        return;
      }
      _inspirationPage = (_inspirationPage + 1) % itemCount;
      _inspirationController.animateToPage(
        _inspirationPage,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _loadData() async {
    _prefs = await SharedPreferences.getInstance();
    final lastLocationUpdatedMs = _prefs.getInt(_lastLocationUpdatedPrefKey);
    if (lastLocationUpdatedMs != null) {
      _lastLocationUpdatedAt = DateTime.fromMillisecondsSinceEpoch(
        lastLocationUpdatedMs,
      );
    }
    await _loadLocalTimeZone();
    // 1. Calculate Dynamic Quran Goal
    int rounds = _prefs.getInt('quran_rounds_goal') ?? 1;
    _lastRoundsGoal = rounds;
    // (604 pages * rounds) / 30 days / 5 prayers
    _quranPagesPerPrayer = ((604 * rounds) / 30 / 5).ceil();

    final today = _formatDate(DateTime.now());

    // 2. Initialize the dynamic checklist
    _updateChecklistItems();

    if (_prefs.getString('last_reset_date') != today) {
      for (var item in _checklist) {
        final storageKey = _checklistStorageKey(item.id, _quranPagesPerPrayer);
        await _prefs.setBool('task_$storageKey', false);
      }
      await _prefs.setString('last_reset_date', today);
    } else {
      for (var item in _checklist) {
        final storageKey = _checklistStorageKey(item.id, _quranPagesPerPrayer);
        item.checked = _prefs.getBool('task_$storageKey') ?? false;
      }
    }
    await _loadDailyAyah();
    await _loadLocation();
    setState(() => _prefsReady = true);
  }

  Future<void> _showLanguageSheet() async {
    final controller = AppLanguageScope.of(context);
    final strings = AppStrings.of(context);

    final selected = await showModalBottomSheet<AppLanguage>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(strings.english()),
                trailing: controller.language == AppLanguage.english
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
                onTap: () => Navigator.pop(context, AppLanguage.english),
              ),
              ListTile(
                title: Text(strings.amharic()),
                trailing: controller.language == AppLanguage.amharic
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
                onTap: () => Navigator.pop(context, AppLanguage.amharic),
              ),
            ],
          ),
        );
      },
    );

    if (selected != null) {
      await controller.setLanguage(selected);
    }
  }

  Future<void> _loadLocalTimeZone() async {
    try {
      final tz = await FlutterTimezone.getLocalTimezone();
      if (!mounted) {
        return;
      }
      setState(() => _localTimeZoneLabel = tz);
    } catch (_) {
      // Keep default label when timezone is unavailable.
    }
  }

  Future<void> _loadLocation() async {
    if (_isRequestingLocation) {
      return;
    }

    if (mounted) {
      setState(() => _isRequestingLocation = true);
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _isLocationServiceDisabled = true;
            _isPermissionDeniedForever = false;
            _locationStatus = _LocationStatus.serviceOff;
          });
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _isLocationServiceDisabled = false;
            _isPermissionDeniedForever =
                permission == LocationPermission.deniedForever;
            _locationStatus = _isPermissionDeniedForever
                ? _LocationStatus.deniedForever
                : _LocationStatus.denied;
          });
        }
        return;
      }

      Position current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );

      if (current.accuracy > 100) {
        current = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            timeLimit: Duration(seconds: 20),
          ),
        );
      }

      await _updateLocation(current);
      if (mounted) {
        setState(() {
          _isLocationServiceDisabled = false;
          _isPermissionDeniedForever = false;
          _locationStatus = _LocationStatus.ready;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _locationStatus = _LocationStatus.unable;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isRequestingLocation = false);
      }
    }
  }

  Future<void> _updateLocation(Position position) async {
    final lat = position.latitude;
    final lng = position.longitude;
    _lat = lat;
    _lng = lng;
    final updatedAt = DateTime.now();
    _lastLocationUpdatedAt = updatedAt;
    _locationStatus = _LocationStatus.ready;
    await _prefs.setDouble('user_lat', lat);
    await _prefs.setDouble('user_lng', lng);
    await _prefs.setInt(
      _lastLocationUpdatedPrefKey,
      updatedAt.millisecondsSinceEpoch,
    );
    if (mounted) {
      setState(() {});
    }
  }

  String _formatLocationUpdatedAt(DateTime value) {
    final date = _formatDate(value);
    final time = _formatTime(value);
    return '$date $time';
  }

  Future<void> _loadDailyAyah() async {
    final today = _formatDate(DateTime.now());
    final savedDate = _prefs.getString('daily_ayah_date');
    int surah = _prefs.getInt('daily_ayah_surah') ?? 1;
    int ayah = _prefs.getInt('daily_ayah_ayah') ?? 1;

    if (savedDate != today) {
      final seed =
          int.tryParse(today.replaceAll('-', '')) ?? DateTime.now().day;
      final random = Random(seed);
      final surahs = Quran.getSurahAsList();
      final selectedSurah = surahs[random.nextInt(surahs.length)];
      surah = selectedSurah.number;
      ayah = random.nextInt(selectedSurah.verseCount) + 1;
      await _prefs.setString('daily_ayah_date', today);
      await _prefs.setInt('daily_ayah_surah', surah);
      await _prefs.setInt('daily_ayah_ayah', ayah);
    }

    final verse = Quran.getVerse(
      surahNumber: surah,
      verseNumber: ayah,
      language: QuranLanguage.english,
    ).text;

    _dailyAyah = DailyText(
      title: 'Ayah of the Day',
      text: verse,
      source: 'Quran $surah:$ayah',
    );
  }

  void _onRoundsGoalChanged() {
    if (!_prefsReady) {
      _loadData();
      return;
    }

    final rounds = widget.roundsGoalListenable?.value ?? _lastRoundsGoal;
    if (rounds == _lastRoundsGoal) {
      return;
    }

    _applyRoundsUpdate(rounds);
  }

  void _scheduleRoundsSyncIfNeeded() {
    if (!_prefsReady) {
      return;
    }

    final rounds = _prefs.getInt('quran_rounds_goal') ?? 1;
    if (rounds == _lastRoundsGoal) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _applyRoundsUpdate(rounds);
    });
  }

  void _applyRoundsUpdate(int rounds) {
    _lastRoundsGoal = rounds;
    _quranPagesPerPrayer = ((604 * rounds) / 30 / 5).ceil();
    _updateChecklistItems();
    for (var item in _checklist) {
      final storageKey = _checklistStorageKey(item.id, _quranPagesPerPrayer);
      item.checked = _prefs.getBool('task_$storageKey') ?? false;
    }
    setState(() {});
  }

  void _updateChecklistItems() {
    _checklist.clear();
    _checklist.addAll([
      _ChecklistEntry(id: 'fajr'),
      _ChecklistEntry(id: 'dhuhr'),
      _ChecklistEntry(id: 'asr'),
      _ChecklistEntry(id: 'maghrib'),
      _ChecklistEntry(id: 'isha'),
      _ChecklistEntry(id: 'taraweeh'),
      _ChecklistEntry(id: 'dhikr'),
    ]);
  }

  String _checklistStorageKey(String id, int pagesPerPrayer) {
    final english = AppStrings.forLanguage(AppLanguage.english);
    switch (id) {
      case 'fajr':
        return english.checklistFajr(pagesPerPrayer);
      case 'dhuhr':
        return english.checklistDhuhr(pagesPerPrayer);
      case 'asr':
        return english.checklistAsr(pagesPerPrayer);
      case 'maghrib':
        return english.checklistMaghrib(pagesPerPrayer);
      case 'isha':
        return english.checklistIsha(pagesPerPrayer);
      case 'taraweeh':
        return english.checklistTaraweeh();
      case 'dhikr':
        return english.checklistDhikr();
      default:
        return id;
    }
  }

  String _checklistLabel(String id, AppStrings strings, int pagesPerPrayer) {
    switch (id) {
      case 'fajr':
        return strings.checklistFajr(pagesPerPrayer);
      case 'dhuhr':
        return strings.checklistDhuhr(pagesPerPrayer);
      case 'asr':
        return strings.checklistAsr(pagesPerPrayer);
      case 'maghrib':
        return strings.checklistMaghrib(pagesPerPrayer);
      case 'isha':
        return strings.checklistIsha(pagesPerPrayer);
      case 'taraweeh':
        return strings.checklistTaraweeh();
      case 'dhikr':
        return strings.checklistDhikr();
      default:
        return id;
    }
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  // --- 2. ADHAN OFFLINE CALCULATION ---
  PrayerTimes? _getPrayerTimes() {
    if (_lat == null || _lng == null) {
      return null;
    }
    final myCoordinates = Coordinates(_lat!, _lng!);
    final params = CalculationMethod.muslim_world_league.getParameters();
    params.madhab = Madhab.shafi;
    return PrayerTimes.today(myCoordinates, params);
  }

  // --- 3. TIMING & NEXT PRAYER LOGIC ---
  Widget _buildTimingSection(ThemeData theme) {
    final strings = AppStrings.of(context);
    final times = _getPrayerTimes();
    if (times == null) {
      return _buildLocationRequiredCard(theme);
    }

    final now = DateTime.now().toLocal();
    final fajr = times.fajr.toLocal();
    final dhuhr = times.dhuhr.toLocal();
    final asr = times.asr.toLocal();
    final maghrib = times.maghrib.toLocal();
    final isha = times.isha.toLocal();

    bool isFasting = now.isAfter(fajr) && now.isBefore(maghrib);
    final nextPrayer = times.nextPrayer();
    final nextTime = times.timeForPrayer(nextPrayer)?.toLocal();
    final String nextName = _localizePrayerName(nextPrayer.name, strings);
    final diff = nextTime?.difference(now) ?? const Duration(hours: 0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                isFasting ? Icons.wb_sunny : Icons.nightlight_round,
                color: isFasting ? Colors.orange : Colors.amber,
                size: 40,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${diff.inHours}h ${diff.inMinutes % 60}m",
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      strings.untilPrayer(nextName),
                      style: theme.textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  ],
                ),
              ),
              const Spacer(),
              if (isFasting)
                Chip(
                  label: Text(
                    strings.fasting(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const Divider(height: 30),
          _buildPrayerTimeline(
            fajr: fajr,
            dhuhr: dhuhr,
            asr: asr,
            maghrib: maghrib,
            isha: isha,
            now: now,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRequiredCard(ThemeData theme) {
    final strings = AppStrings.of(context);
    final showOpenSettings = _isPermissionDeniedForever;
    final showOpenLocation = _isLocationServiceDisabled;
    final statusMessage = _locationStatusMessage(strings);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.my_location, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  strings.locationRequiredTitle(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(statusMessage, style: theme.textTheme.bodyMedium),
          if (_lastLocationUpdatedAt != null) ...[
            const SizedBox(height: 8),
            Text(
              strings.lastLocationUpdated(
                _formatLocationUpdatedAt(_lastLocationUpdatedAt!),
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _isRequestingLocation ? null : _loadLocation,
                icon: const Icon(Icons.refresh),
                label: Text(
                  _isRequestingLocation
                      ? strings.t('checking')
                      : strings.retry(),
                ),
              ),
              if (showOpenLocation)
                OutlinedButton.icon(
                  onPressed: Geolocator.openLocationSettings,
                  icon: const Icon(Icons.location_searching),
                  label: Text(strings.locationSettings()),
                ),
              if (showOpenSettings)
                OutlinedButton.icon(
                  onPressed: Geolocator.openAppSettings,
                  icon: const Icon(Icons.settings),
                  label: Text(strings.appSettings()),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _locationStatusMessage(AppStrings strings) {
    switch (_locationStatus) {
      case _LocationStatus.serviceOff:
        return strings.locationServiceOffMessage();
      case _LocationStatus.denied:
        return strings.locationDeniedMessage();
      case _LocationStatus.deniedForever:
        return strings.locationDeniedForeverMessage();
      case _LocationStatus.unable:
        return strings.locationUnableMessage();
      case _LocationStatus.ready:
      case _LocationStatus.required:
        return strings.locationRequiredMessage();
    }
  }

  String _localizePrayerName(String name, AppStrings strings) {
    switch (name.toLowerCase()) {
      case 'fajr':
        return strings.t('prayer_fajr');
      case 'dhuhr':
        return strings.t('prayer_dhuhr');
      case 'asr':
        return strings.t('prayer_asr');
      case 'maghrib':
        return strings.t('prayer_maghrib');
      case 'isha':
        return strings.t('prayer_isha');
      default:
        return name;
    }
  }

  Widget _buildPrayerTimeline({
    required DateTime fajr,
    required DateTime dhuhr,
    required DateTime asr,
    required DateTime maghrib,
    required DateTime isha,
    required DateTime now,
  }) {
    final strings = AppStrings.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _miniPrayerItem(strings.t('prayer_fajr'), fajr, now),
        _miniPrayerItem(strings.t('prayer_dhuhr'), dhuhr, now),
        _miniPrayerItem(strings.t('prayer_asr'), asr, now),
        _miniPrayerItem(strings.t('prayer_maghrib'), maghrib, now),
        _miniPrayerItem(strings.t('prayer_isha'), isha, now),
      ],
    );
  }

  Widget _miniPrayerItem(String name, DateTime time, DateTime now) {
    bool isPassed = now.isAfter(time);
    return Column(
      children: [
        Text(
          name,
          style: TextStyle(
            fontSize: 9,
            color: isPassed ? Colors.grey : Colors.black54,
          ),
        ),
        const SizedBox(height: 4),
        Icon(
          isPassed ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 14,
          color: isPassed ? Colors.green : Colors.grey,
        ),
        const SizedBox(height: 4),
        Text(
          _formatTime(time),
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    final hijri = HijriCalendar.fromDate(DateTime.now());
    final hijriDay = hijri.hDay;
    final hijriMonth = hijri.hMonth;
    final hijriYear = hijri.hYear;
    final isRamadan = hijriMonth == 9;
    final isLastTen = isRamadan && hijriDay >= 21;
    final monthName = _hijriMonthNames[(hijriMonth - 1).clamp(0, 11)];
    final inspirationIndex = hijriDay;
    final dailyAyah = _dailyAyah;
    final inspirationItems = <DailyText>[
      dailyAyah == null
          ? DailyText(
              title: strings.t('ayah_of_day'),
              text: strings.t('ayah_loading'),
              source: '',
            )
          : DailyText(
              title: strings.t('ayah_of_day'),
              text: dailyAyah.text,
              source: dailyAyah.source,
            ),
      duas[inspirationIndex % duas.length],
      hadith[inspirationIndex % hadith.length],
    ];

    _scheduleRoundsSyncIfNeeded();

    if (_prefsReady) {
      for (var item in _checklist) {
        final storageKey = _checklistStorageKey(item.id, _quranPagesPerPrayer);
        item.checked = _prefs.getBool('task_$storageKey') ?? false;
      }
    }

    return Scaffold(
      body: Stack(
        children: [
          _buildHomeBackground(theme),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  title: Text(
                    strings.appTitle(),
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22),
                  ),
                  centerTitle: false,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.language),
                      tooltip: strings.languageLabel(),
                      onPressed: _showLanguageSheet,
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isRamadan
                                  ? strings.ramadanDay(hijriDay)
                                  : strings.hijriDate(
                                      monthName,
                                      hijriDay,
                                      hijriYear,
                                    ),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isLastTen)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  strings.lastTenNights(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildHeroBanner(theme, isRamadan, monthName, hijriDay),
                        const SizedBox(height: 20),
                        _buildTimingSection(theme),
                        const SizedBox(height: 20),
                        _buildNiyyahCard(theme),
                        const SizedBox(height: 24),
                        Text(
                          strings.todaysInspiration(),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 220,
                          child: PageView.builder(
                            controller: _inspirationController,
                            itemCount: inspirationItems.length,
                            onPageChanged: (index) {
                              setState(() => _inspirationPage = index);
                            },
                            itemBuilder: (context, index) {
                              return AnimatedBuilder(
                                animation: _inspirationController,
                                child: SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  child: AyahCard(
                                    item: inspirationItems[index],
                                  ),
                                ),
                                builder: (context, child) {
                                  double opacity = 1.0;
                                  if (_inspirationController
                                      .position
                                      .hasContentDimensions) {
                                    final page =
                                        _inspirationController.page ??
                                        _inspirationPage.toDouble();
                                    final delta = (page - index).abs().clamp(
                                      0.0,
                                      1.0,
                                    );
                                    opacity = 1 - delta;
                                  }
                                  return Opacity(
                                    opacity: opacity,
                                    child: child,
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildInspirationDots(theme, inspirationItems.length),
                        const SizedBox(height: 24),
                        Text(
                          strings.dailyChecklist(),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_prefsReady)
                          ..._checklist.map((item) {
                            final storageKey = _checklistStorageKey(
                              item.id,
                              _quranPagesPerPrayer,
                            );
                            final label = _checklistLabel(
                              item.id,
                              strings,
                              _quranPagesPerPrayer,
                            );
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: ChecklistItem(
                                title: label,
                                checked: item.checked,
                                onChanged: (val) {
                                  setState(() => item.checked = val ?? false);
                                  _prefs.setBool(
                                    'task_$storageKey',
                                    item.checked,
                                  );
                                },
                              ),
                            );
                          }),
                        _buildSunnahTip(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSunnahTip() {
    final strings = AppStrings.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          const Icon(Icons.tips_and_updates, color: Colors.amber),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              DateTime.now().hour > 16
                  ? strings.sunnahTipEvening()
                  : strings.sunnahTipMorning(),
              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNiyyahCard(ThemeData theme) {
    final strings = AppStrings.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Text(
                strings.dailyNiyyah(),
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            strings.niyyahText(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBanner(
    ThemeData theme,
    bool isRamadan,
    String monthName,
    int hijriDay,
  ) {
    final strings = AppStrings.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.tertiary.withValues(alpha: 0.85),
            theme.colorScheme.primary.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.assalamuAlaikum(),
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isRamadan
                ? strings.heroRamadanMessage(hijriDay)
                : strings.heroMonthMessage(monthName),
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildHeroChip(strings.heroRead(), Icons.menu_book),
              const SizedBox(width: 8),
              _buildHeroChip(strings.heroDhikr(), Icons.fingerprint),
              const SizedBox(width: 8),
              _buildHeroChip(strings.heroDua(), Icons.auto_awesome),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeBackground(ThemeData theme) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFFFF3C2),
                theme.colorScheme.surface,
                const Color(0xFFFAD6C4),
              ],
            ),
          ),
        ),
        Positioned(
          top: -60,
          left: -40,
          child: _buildGlowBlob(
            size: 220,
            color: theme.colorScheme.primary.withValues(alpha: 0.18),
          ),
        ),
        Positioned(
          top: 140,
          right: -60,
          child: _buildGlowBlob(
            size: 200,
            color: theme.colorScheme.tertiary.withValues(alpha: 0.16),
          ),
        ),
        Positioned(
          bottom: -80,
          left: 40,
          child: _buildGlowBlob(
            size: 240,
            color: Colors.orange.withValues(alpha: 0.12),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _DotPatternPainter(
              color: Colors.white.withValues(alpha: 0.35),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGlowBlob({required double size, required Color color}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0.0)]),
      ),
    );
  }

  Widget _buildInspirationDots(ThemeData theme, int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == _inspirationPage;
        return GestureDetector(
          onTap: () {
            _inspirationController.animateToPage(
              index,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 18 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive
                  ? theme.colorScheme.primary
                  : theme.colorScheme.primary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }),
    );
  }
}

class _DotPatternPainter extends CustomPainter {
  _DotPatternPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const double gap = 28;
    const double radius = 1.2;
    for (double y = 0; y <= size.height; y += gap) {
      for (double x = 0; x <= size.width; x += gap) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotPatternPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

enum _LocationStatus {
  required,
  serviceOff,
  denied,
  deniedForever,
  unable,
  ready,
}

class _ChecklistEntry {
  _ChecklistEntry({required this.id});

  final String id;
  bool checked = false;
}
