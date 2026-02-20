import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key, this.roundsGoalNotifier});

  final ValueNotifier<int>? roundsGoalNotifier;

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  int _rounds = 1; 
  final int _totalQuranPages = 604;
  bool _isLoading = true;
  double _overallProgress = 0.0;
  int _pagesReadToday = 0;
  int _pagesReadMonth = 0;
  double _dailyTargetPages = 0.0;
  double _monthlyTargetPages = 0.0;
  Timer? _refreshTimer;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _refreshProgressIfNeeded();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // Load both the Goal and the Progress (based on checklist)
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Load Goal
    int rounds = prefs.getInt('quran_rounds_goal') ?? 1;
    if (widget.roundsGoalNotifier != null && widget.roundsGoalNotifier!.value != rounds) {
      widget.roundsGoalNotifier!.value = rounds;
    }

    final today = _formatDate(DateTime.now());
    final storedDate = prefs.getString('quran_progress_date') ?? '';
    final monthKey = _formatMonth(DateTime.now());
    final storedMonth = prefs.getString('quran_progress_month') ?? '';
    if (storedDate != today) {
      await prefs.setString('quran_progress_date', today);
      await prefs.setStringList('quran_pages_read_today', <String>[]);
      await _resetDailyChecklist(prefs, rounds);
    }
    if (storedMonth != monthKey) {
      await prefs.setString('quran_progress_month', monthKey);
      await prefs.setStringList('quran_pages_read_month', <String>[]);
    }

    final storedPages = prefs.getStringList('quran_pages_read_today') ?? <String>[];
    final storedMonthPages =
        prefs.getStringList('quran_pages_read_month') ?? <String>[];
    final dailyTarget = (rounds * _totalQuranPages) / 30;
    final monthlyTarget = rounds * _totalQuranPages.toDouble();
    final progress = dailyTarget <= 0 ? 0.0 : (storedPages.length / dailyTarget).clamp(0.0, 1.0);

    setState(() {
      _rounds = rounds;
      _pagesReadToday = storedPages.length;
      _pagesReadMonth = storedMonthPages.length;
      _dailyTargetPages = dailyTarget;
      _monthlyTargetPages = monthlyTarget;
      _overallProgress = progress;
      _isLoading = false;
    });
  }

  Future<void> _refreshProgressIfNeeded() async {
    if (_isLoading || _isRefreshing) {
      return;
    }

    _isRefreshing = true;
    final prefs = await SharedPreferences.getInstance();

    final today = _formatDate(DateTime.now());
    final storedDate = prefs.getString('quran_progress_date') ?? '';
    final monthKey = _formatMonth(DateTime.now());
    final storedMonth = prefs.getString('quran_progress_month') ?? '';
    int rounds = prefs.getInt('quran_rounds_goal') ?? _rounds;

    if (storedDate != today) {
      await prefs.setString('quran_progress_date', today);
      await prefs.setStringList('quran_pages_read_today', <String>[]);
      await _resetDailyChecklist(prefs, rounds);
    }
    if (storedMonth != monthKey) {
      await prefs.setString('quran_progress_month', monthKey);
      await prefs.setStringList('quran_pages_read_month', <String>[]);
    }

    final storedPages = prefs.getStringList('quran_pages_read_today') ?? <String>[];
    final storedMonthPages =
        prefs.getStringList('quran_pages_read_month') ?? <String>[];
    final dailyTarget = (rounds * _totalQuranPages) / 30;
    final monthlyTarget = rounds * _totalQuranPages.toDouble();
    final progress = dailyTarget <= 0 ? 0.0 : (storedPages.length / dailyTarget).clamp(0.0, 1.0);

    final bool needsUpdate = rounds != _rounds ||
        storedPages.length != _pagesReadToday ||
        storedMonthPages.length != _pagesReadMonth ||
        dailyTarget != _dailyTargetPages ||
        monthlyTarget != _monthlyTargetPages ||
        progress != _overallProgress;

    if (needsUpdate && mounted) {
      setState(() {
        _rounds = rounds;
        _pagesReadToday = storedPages.length;
        _pagesReadMonth = storedMonthPages.length;
        _dailyTargetPages = dailyTarget;
        _monthlyTargetPages = monthlyTarget;
        _overallProgress = progress;
      });
    }

    _isRefreshing = false;
  }

  Future<void> _resetDailyChecklist(SharedPreferences prefs, int rounds) async {
    final pagesPerPrayer = ((rounds * _totalQuranPages) / 30 / 5).ceil();
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

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _formatMonth(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$year-$month';
  }

  Future<void> _saveGoal(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('quran_rounds_goal', value);
    widget.roundsGoalNotifier?.value = value;
    setState(() => _rounds = value);
    
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Goal set to $value Round${value > 1 ? 's' : ''}!"),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green.shade800,
      ),
    );
    _loadData(); // Refresh math
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    int totalPages = _totalQuranPages * _rounds;
    double dailyPages = totalPages / 30;
    double perPrayer = dailyPages / 5;

    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text("Ramadan Planner")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- PROGRESS SECTION ---
            Text("Today's Progress", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildProgressBar(theme),

            const SizedBox(height: 20),
            Text("Monthly Progress", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildMonthlyProgressBar(theme),
            
            const SizedBox(height: 32),
            
            // --- GOAL SETTING ---
            Text("Quran Completion Goal", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildGoalSelector(theme),

            const SizedBox(height: 24),
            _buildSummaryCard(theme, totalPages, dailyPages),

            const SizedBox(height: 32),
            Text("Daily Reading Schedule", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildPrayerRow("Fajr", perPrayer, Icons.wb_twilight, Colors.orange),
            _buildPrayerRow("Dhuhr", perPrayer, Icons.wb_sunny, Colors.amber),
            _buildPrayerRow("Asr", perPrayer, Icons.wb_sunny_outlined, Colors.orangeAccent),
            _buildPrayerRow("Maghrib", perPrayer, Icons.nights_stay, Colors.indigo),
            _buildPrayerRow("Isha", perPrayer, Icons.nightlight_round, Colors.deepPurple),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Daily Quran Target", style: TextStyle(fontWeight: FontWeight.w600)),
              Text("${(_overallProgress * 100).toInt()}%", 
                style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _overallProgress,
              minHeight: 12,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            ),
          ),
          const SizedBox(height: 8),
          Text("Read $_pagesReadToday / ${_dailyTargetPages.toStringAsFixed(1)} pages in Quran to fill this bar.", 
            style: const TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _buildMonthlyProgressBar(ThemeData theme) {
    final progress = _monthlyTargetPages <= 0
        ? 0.0
        : (_pagesReadMonth / _monthlyTargetPages).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Monthly Quran Target", style: TextStyle(fontWeight: FontWeight.w600)),
              Text("${(progress * 100).toInt()}%",
                  style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Read $_pagesReadMonth / ${_monthlyTargetPages.toStringAsFixed(0)} pages this month.",
            style: const TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalSelector(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _rounds,
          isExpanded: true,
          items: List.generate(30, (i) => i + 1).map((val) => DropdownMenuItem(
            value: val, child: Text("$val Round${val > 1 ? 's' : ''} (Khatam)"),
          )).toList(),
          onChanged: (v) {
            if (v != null) {
              _saveGoal(v);
            }
          },
        ),
      ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme, int total, double daily) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.tertiary]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _sumItem("Total Pages", "$total"),
          Container(width: 1, height: 40, color: Colors.white24),
              _sumItem("Daily Goal", daily.toStringAsFixed(1)),
        ],
      ),
    );
  }

  Widget _sumItem(String label, String val) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        Text(val, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildPrayerRow(String name, double pages, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey.shade100)),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.1), child: Icon(icon, color: color, size: 20)),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Text("${pages.toStringAsFixed(1)} Pages", style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold)),
      ),
    );
  }
}