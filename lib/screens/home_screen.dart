import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adhan/adhan.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:quran_flutter/quran_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:math';

// Core Data Imports
import '../data/duas.dart';
import '../data/hadith.dart';
import '../data/daily_text.dart';

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

  static const double _defaultLat = 9.03;
  static const double _defaultLng = 38.74;
  double _lat = _defaultLat;
  double _lng = _defaultLng;

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
    _lat = _prefs.getDouble('user_lat') ?? _defaultLat;
    _lng = _prefs.getDouble('user_lng') ?? _defaultLng;
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
        await _prefs.setBool('task_${item.title}', false);
      }
      await _prefs.setString('last_reset_date', today);
    } else {
      for (var item in _checklist) {
        item.checked = _prefs.getBool('task_${item.title}') ?? false;
      }
    }
    await _loadDailyAyah();
    await _loadLocation();
    setState(() => _prefsReady = true);
  }

  Future<void> _loadLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        await _updateLocation(lastKnown);
      }

      final current = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );
      await _updateLocation(current);
    } catch (_) {
      // Keep fallback coordinates when location is unavailable.
    }
  }

  Future<void> _updateLocation(Position position) async {
    _lat = position.latitude;
    _lng = position.longitude;
    await _prefs.setDouble('user_lat', _lat);
    await _prefs.setDouble('user_lng', _lng);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadDailyAyah() async {
    final today = _formatDate(DateTime.now());
    final savedDate = _prefs.getString('daily_ayah_date');
    int surah = _prefs.getInt('daily_ayah_surah') ?? 1;
    int ayah = _prefs.getInt('daily_ayah_ayah') ?? 1;

    if (savedDate != today) {
      final seed = int.tryParse(today.replaceAll('-', '')) ?? DateTime.now().day;
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
      item.checked = _prefs.getBool('task_${item.title}') ?? false;
    }
    setState(() {});
  }

  void _updateChecklistItems() {
    _checklist.clear();
    _checklist.addAll([
      _ChecklistEntry('Fajr + Read $_quranPagesPerPrayer Pages'),
      _ChecklistEntry('Dhuhr + Read $_quranPagesPerPrayer Pages'),
      _ChecklistEntry('Asr + Read $_quranPagesPerPrayer Pages'),
      _ChecklistEntry('Maghrib + Read $_quranPagesPerPrayer Pages'),
      _ChecklistEntry('Isha + Read $_quranPagesPerPrayer Pages'),
      _ChecklistEntry('Taraweeh/Tahajjud'),
      _ChecklistEntry('Morning/Evening Dhikr'),
    ]);
  }

  // --- 1. DYNAMIC BACKGROUND LOGIC ---
  List<Color> _getAdaptiveColors() {
    final hour = DateTime.now().hour;
    if (hour >= 3 && hour < 6)
      return [Colors.indigo.shade900, Colors.deepPurple.shade700]; // Pre-Dawn
    if (hour >= 6 && hour < 17)
      return [const Color(0xFFFFFDE7), Colors.white]; // Mid-Day
    if (hour >= 17 && hour < 19)
      return [Colors.orange.shade300, Colors.deepOrange.shade100]; // Sunset
    return [const Color(0xFF0F2027), const Color(0xFF203A43)]; // Night
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
  PrayerTimes _getPrayerTimes() {
    final myCoordinates = Coordinates(_lat, _lng);
    final params = CalculationMethod.muslim_world_league.getParameters();
    params.madhab = Madhab.shafi;
    return PrayerTimes.today(myCoordinates, params);
  }

  // --- 3. TIMING & NEXT PRAYER LOGIC ---
  Widget _buildTimingSection(ThemeData theme) {
    final times = _getPrayerTimes();
    final now = DateTime.now();
    bool isFasting = now.isAfter(times.fajr) && now.isBefore(times.maghrib);
    final nextPrayer = times.nextPrayer();
    final nextTime = times.timeForPrayer(nextPrayer);
    final String nextName =
        nextPrayer.name[0].toUpperCase() + nextPrayer.name.substring(1);
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${diff.inHours}h ${diff.inMinutes % 60}m",
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text("until $nextName", style: theme.textTheme.bodyMedium),
                ],
              ),
              const Spacer(),
              if (isFasting)
                const Chip(
                  label: Text(
                    "FASTING",
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const Divider(height: 30),
          _buildPrayerTimeline(times, now),
        ],
      ),
    );
  }

  Widget _buildPrayerTimeline(PrayerTimes times, DateTime now) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _miniPrayerItem("Fajr", times.fajr, now),
        _miniPrayerItem("Dhuhr", times.dhuhr, now),
        _miniPrayerItem("Asr", times.asr, now),
        _miniPrayerItem("Maghrib", times.maghrib, now),
        _miniPrayerItem("Isha", times.isha, now),
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
      dailyAyah ??
          const DailyText(
            title: 'Ayah of the Day',
            text: 'Loading today\'s ayah...',
            source: '',
          ),
      duas[inspirationIndex % duas.length],
      hadith[inspirationIndex % hadith.length],
    ];

    _scheduleRoundsSyncIfNeeded();

    if (_prefsReady) {
      for (var item in _checklist) {
        item.checked = _prefs.getBool('task_${item.title}') ?? false;
      }
    }

    return Scaffold(
      body: Stack(
        children: [
          _buildHomeBackground(theme),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                const SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  title: Text(
                    "Baraka30",
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22),
                  ),
                  centerTitle: false,
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
                                ? "Ramadan Day $hijriDay"
                                : "$monthName $hijriDay, $hijriYear AH",
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
                              child: const Text(
                                "LAST 10 NIGHTS",
                                style: TextStyle(
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
                        "Today's Inspiration",
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
                                child: AyahCard(item: inspirationItems[index]),
                              ),
                              builder: (context, child) {
                                double opacity = 1.0;
                                if (_inspirationController.position.hasContentDimensions) {
                                  final page = _inspirationController.page ?? _inspirationPage.toDouble();
                                  final delta = (page - index).abs().clamp(0.0, 1.0);
                                  opacity = 1 - delta;
                                }
                                return Opacity(opacity: opacity, child: child);
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildInspirationDots(theme, inspirationItems.length),
                      const SizedBox(height: 24),
                      Text(
                        "Daily Checklist",
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_prefsReady)
                        ..._checklist.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: ChecklistItem(
                              title: item.title,
                              checked: item.checked,
                              onChanged: (val) {
                                setState(() => item.checked = val ?? false);
                                _prefs.setBool(
                                  'task_${item.title}',
                                  item.checked,
                                );
                              },
                            ),
                          ),
                        ),
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
                  ? "Sunnah: Break your fast with dates and water."
                  : "Sunnah: Use Miswak to keep your breath fresh while fasting.",
              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNiyyahCard(ThemeData theme) {
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
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.white70, size: 16),
              SizedBox(width: 8),
              Text(
                "DAILY NIYYAH",
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            "“I intend to fast this day of Ramadan for the sake of Allah.”",
            style: TextStyle(
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
            'Assalamu Alaikum',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isRamadan
                ? 'Stay steady on Day $hijriDay of Ramadan'
                : 'Keep your Quran rhythm in $monthName',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildHeroChip('Read', Icons.menu_book),
              const SizedBox(width: 8),
              _buildHeroChip('Dhikr', Icons.fingerprint),
              const SizedBox(width: 8),
              _buildHeroChip('Dua', Icons.auto_awesome),
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
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0.0)],
        ),
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

class _ChecklistEntry {
  final String title;
  bool checked = false;
  _ChecklistEntry(this.title);
}
