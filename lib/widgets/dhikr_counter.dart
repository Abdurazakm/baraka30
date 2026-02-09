import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DhikrCounter extends StatefulWidget {
  const DhikrCounter({
    super.key,
    required this.label,
    required this.target,
  });

  final String label;
  final int target;

  @override
  State<DhikrCounter> createState() => _DhikrCounterState();
}

class _DhikrCounterState extends State<DhikrCounter> {
  int _count = 0;
  late SharedPreferences _prefs;
  bool _prefsReady = false;

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  Future<void> _loadCount() async {
    _prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    final lastReset = _prefs.getString(_resetKey()) ?? '';
    int value;
    if (lastReset != today) {
      value = 0;
      await _prefs.setInt(_counterKey(), value);
      await _prefs.setString(_resetKey(), today);
    } else {
      value = _prefs.getInt(_counterKey()) ?? 0;
    }
    if (mounted) {
      setState(() {
        _count = value;
        _prefsReady = true;
      });
    }
  }

  Future<void> _saveCount() async {
    if (!_prefsReady) {
      return;
    }
    await _prefs.setInt(_counterKey(), _count);
  }

  String _counterKey() {
    final normalized = widget.label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return 'dhikr_count_$normalized';
  }

  String _resetKey() {
    final normalized = widget.label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return 'dhikr_last_reset_$normalized';
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = (_count / widget.target).clamp(0, 1).toDouble();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.label,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$_count / ${widget.target}'),
                Row(
                  children: [
                    IconButton(
                      onPressed: _count == 0
                          ? null
                          : () {
                              setState(() {
                                _count = 0;
                              });
                              _saveCount();
                            },
                      icon: const Icon(Icons.refresh),
                    ),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _count += 1;
                        });
                        _saveCount();
                      },
                      child: const Text('+1'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
