import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adhan/adhan.dart';
import 'package:hijri/hijri_calendar.dart';
import 'dart:async';

// Core Data Imports
import '../data/ayat.dart';
import '../data/duas.dart';
import '../data/hadith.dart';

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
  int _waterGlasses = 0;
  int _quranPagesPerPrayer = 4; // Dynamic based on Planner Goal
  int _lastRoundsGoal = 1;

  // Placeholder coordinates (Addis Ababa)
  final double lat = 9.03;
  final double lng = 38.74;

  final List<_ChecklistEntry> _checklist = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    // Refresh every minute to keep countdown and background colors accurate
    _timer = Timer.periodic(const Duration(minutes: 1), (t) => setState(() {}));
    widget.roundsGoalListenable?.addListener(_onRoundsGoalChanged);
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.roundsGoalListenable?.removeListener(_onRoundsGoalChanged);
    super.dispose();
  }

  Future<void> _loadData() async {
    _prefs = await SharedPreferences.getInstance();
    _waterGlasses = _prefs.getInt('water_count') ?? 0;
    
    // 1. Calculate Dynamic Quran Goal
    int rounds = _prefs.getInt('quran_rounds_goal') ?? 1;
    _lastRoundsGoal = rounds;
    // (604 pages * rounds) / 30 days / 5 prayers
    _quranPagesPerPrayer = ((604 * rounds) / 30 / 5).ceil();

    final today = _formatDate(DateTime.now());
    
    // 2. Initialize the dynamic checklist
    _updateChecklistItems();

    if (_prefs.getString('last_reset_date') != today) {
      await _prefs.setInt('water_count', 0);
      _waterGlasses = 0;
      for (var item in _checklist) {
        await _prefs.setBool('task_${item.title}', false);
      }
      await _prefs.setString('last_reset_date', today);
    } else {
      for (var item in _checklist) {
        item.checked = _prefs.getBool('task_${item.title}') ?? false;
      }
    }
    setState(() => _prefsReady = true);
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
    if (hour >= 3 && hour < 6) return [Colors.indigo.shade900, Colors.deepPurple.shade700]; // Pre-Dawn
    if (hour >= 6 && hour < 17) return [const Color(0xFFFFFDE7), Colors.white]; // Mid-Day
    if (hour >= 17 && hour < 19) return [Colors.orange.shade300, Colors.deepOrange.shade100]; // Sunset
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
    final myCoordinates = Coordinates(lat, lng);
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
    final String nextName = nextPrayer.name[0].toUpperCase() + nextPrayer.name.substring(1);
    final diff = nextTime?.difference(now) ?? const Duration(hours: 0);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(isFasting ? Icons.wb_sunny : Icons.nightlight_round, 
                   color: isFasting ? Colors.orange : Colors.amber, size: 40),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${diff.inHours}h ${diff.inMinutes % 60}m",
                    style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text("until $nextName", style: theme.textTheme.bodyMedium),
                ],
              ),
              const Spacer(),
              if (isFasting) 
                const Chip(label: Text("FASTING", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)))
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
        Text(name, style: TextStyle(fontSize: 9, color: isPassed ? Colors.grey : Colors.black54)),
        const SizedBox(height: 4),
        Icon(isPassed ? Icons.check_circle : Icons.radio_button_unchecked, 
             size: 14, color: isPassed ? Colors.green : Colors.grey),
        const SizedBox(height: 4),
        Text(_formatTime(time), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // --- 4. WATER TRACKER ---
  Widget _buildWaterTracker(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Hydration Goal", style: TextStyle(fontWeight: FontWeight.bold)),
              Text("Track water post-Iftar", style: TextStyle(fontSize: 11)),
            ],
          ),
          Row(
            children: [
              IconButton(onPressed: () {
                if (_waterGlasses > 0) {
                  setState(() => _waterGlasses--);
                  _prefs.setInt('water_count', _waterGlasses);
                }
              }, icon: const Icon(Icons.remove_circle_outline, color: Colors.blue, size: 20)),
              Text("$_waterGlasses", style: theme.textTheme.titleLarge?.copyWith(color: Colors.blue, fontWeight: FontWeight.bold)),
              IconButton(onPressed: () {
                setState(() => _waterGlasses++);
                _prefs.setInt('water_count', _waterGlasses);
              }, icon: const Icon(Icons.add_circle, color: Colors.blue, size: 20)),
            ],
          )
        ],
      ),
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

    _scheduleRoundsSyncIfNeeded();

    if (_prefsReady) {
      for (var item in _checklist) {
        item.checked = _prefs.getBool('task_${item.title}') ?? false;
      }
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _getAdaptiveColors(),
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              const SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: Text("Baraka30", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
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
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (isLastTen) 
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(12)),
                              child: const Text("LAST 10 NIGHTS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildTimingSection(theme),
                      const SizedBox(height: 20),
                      _buildNiyyahCard(theme),
                      const SizedBox(height: 24),
                      Text("Today's Inspiration", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      AyahCard(item: ayat[inspirationIndex % ayat.length]),
                      const SizedBox(height: 12),
                      AyahCard(item: duas[inspirationIndex % duas.length]),
                      const SizedBox(height: 12),
                      AyahCard(item: hadith[inspirationIndex % hadith.length]),
                      const SizedBox(height: 24),
                      _buildWaterTracker(theme),
                      const SizedBox(height: 24),
                      Text("Daily Checklist", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      if (_prefsReady)
                        ..._checklist.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: ChecklistItem(
                            title: item.title,
                            checked: item.checked,
                            onChanged: (val) {
                              setState(() => item.checked = val ?? false);
                              _prefs.setBool('task_${item.title}', item.checked);
                            },
                          ),
                        )),
                      _buildSunnahTip(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
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
        border: Border.all(color: Colors.white24)
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
              Text("DAILY NIYYAH", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            ],
          ),
          SizedBox(height: 12),
          Text("“I intend to fast this day of Ramadan for the sake of Allah.”", 
            style: TextStyle(color: Colors.white, fontSize: 16, fontStyle: FontStyle.italic, height: 1.4)),
        ],
      ),
    );
  }
}

class _ChecklistEntry {
  final String title;
  bool checked = false;
  _ChecklistEntry(this.title);
}