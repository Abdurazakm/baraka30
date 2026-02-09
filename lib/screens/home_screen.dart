import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adhan/adhan.dart';
import 'dart:async';

// Core Data Imports
import '../data/ayat.dart';
import '../data/duas.dart';
import '../data/hadith.dart';
import '../data/asma.dart'; // Ensure this exists for the Asma'ul Husna card

// Widgets
import '../widgets/ayah_card.dart';
import '../widgets/checklist_item.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late SharedPreferences _prefs;
  bool _prefsReady = false;
  Timer? _timer;
  int _waterGlasses = 0;

  // Placeholder coordinates (Addis Ababa). 
  // In Phase 2, you can use geolocator to update these.
  final double lat = 9.03;
  final double lng = 38.74;

  final List<_ChecklistEntry> _checklist = [
    _ChecklistEntry('Fajr Prayer'),
    _ChecklistEntry('Dhuhr'),
    _ChecklistEntry('Asr'),
    _ChecklistEntry('Maghrib'),
    _ChecklistEntry('Isha'),
    _ChecklistEntry('Quran Reading'),
    _ChecklistEntry('Taraweeh/Tahajjud'),
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    // Refresh every minute to keep countdown and background colors accurate
    _timer = Timer.periodic(const Duration(minutes: 1), (t) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    _prefs = await SharedPreferences.getInstance();
    _waterGlasses = _prefs.getInt('water_count') ?? 0;
    
    final today = _formatDate(DateTime.now());
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
    
    // Check if we are currently fasting
    bool isFasting = now.isAfter(times.fajr) && now.isBefore(times.maghrib);
    
    // Find next prayer
    final nextPrayer = times.nextPrayer();
    final nextTime = times.timeForPrayer(nextPrayer);
    final String nextName = nextPrayer.name[0].toUpperCase() + nextPrayer.name.substring(1);

    // Calculate countdown
    final diff = nextTime?.difference(now) ?? const Duration(hours: 0);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
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
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
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
    final dayIndex = DateTime.now().day; 
    final isLastTen = dayIndex >= 20;

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
                          Text("Ramadan Day $dayIndex", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
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
                      AyahCard(item: ayat[dayIndex % ayat.length]),
                      const SizedBox(height: 12),
                      AyahCard(item: duas[dayIndex % duas.length]),
                      const SizedBox(height: 12),
                      AyahCard(item: hadith[dayIndex % hadith.length]),

                      const SizedBox(height: 24),
                      _buildWaterTracker(theme),

                      const SizedBox(height: 24),
                      Text("Daily Checklist", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
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
                      
                      // SUNNA TIP REMINDER
                      Container(
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
                      ),
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
  bool checked;
  _ChecklistEntry(this.title, {this.checked = false});
}