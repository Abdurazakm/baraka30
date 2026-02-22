import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DhikrScreen extends StatefulWidget {
  const DhikrScreen({super.key});

  @override
  State<DhikrScreen> createState() => _DhikrScreenState();
}

class _DhikrScreenState extends State<DhikrScreen> {
  static const String _vibrationPrefKey = 'dhikr_vibration_enabled';

  int _counter = 0;
  String _selectedDhikr = "SubhanAllah";
  bool _vibrationEnabled = true;
  final List<DhikrOption> _options = [
    const DhikrOption(
      label: "SubhanAllah",
      arabic: "سُبْحَانَ اللَّهِ",
      transliteration: "SubhanAllah",
    ),
    const DhikrOption(
      label: "Alhamdulillah",
      arabic: "الْحَمْدُ لِلَّهِ",
      transliteration: "Alhamdulillah",
    ),
    const DhikrOption(
      label: "Allahu Akbar",
      arabic: "اللَّهُ أَكْبَرُ",
      transliteration: "Allahu Akbar",
    ),
    const DhikrOption(
      label: "La ilaha illa Allah",
      arabic: "لَا إِلَٰهَ إِلَّا اللَّهُ",
      transliteration: "La ilaha illa Allah",
    ),
    const DhikrOption(
      label: "Astaghfirullah",
      arabic: "أَسْتَغْفِرُ اللَّهَ",
      transliteration: "Astaghfirullah",
    ),
    const DhikrOption(
      label: "SubhanAllahi wa bihamdihi",
      arabic: "سُبْحَانَ اللَّهِ وَبِحَمْدِهِ",
      transliteration: "SubhanAllahi wa bihamdihi",
    ),
    const DhikrOption(
      label: "SubhanAllahi al-azim",
      arabic: "سُبْحَانَ اللَّهِ الْعَظِيمِ",
      transliteration: "SubhanAllahi al-azim",
    ),
    const DhikrOption(
      label: "La hawla wa la quwwata illa billah",
      arabic: "لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ",
      transliteration: "La hawla wa la quwwata illa billah",
    ),
    const DhikrOption(
      label: "Salawat (Allahumma salli ala Muhammad)",
      arabic: "اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ",
      transliteration: "Allahumma salli ala Muhammad",
    ),
    const DhikrOption(
      label: "Hasbi Allahu wa ni'ma al-wakil",
      arabic: "حَسْبِيَ اللَّهُ وَنِعْمَ الْوَكِيلُ",
      transliteration: "Hasbi Allahu wa ni'ma al-wakil",
    ),
    const DhikrOption(
      label: "La ilaha illa Anta, subhanaka",
      arabic: "لَا إِلَٰهَ إِلَّا أَنْتَ سُبْحَانَكَ",
      transliteration: "La ilaha illa Anta, subhanaka",
    ),
    const DhikrOption(
      label: "Bismillah",
      arabic: "بِسْمِ اللَّهِ",
      transliteration: "Bismillah",
    ),
    const DhikrOption(
      label: "Rabbi zidni ilma",
      arabic: "رَبِّ زِدْنِي عِلْمًا",
      transliteration: "Rabbi zidni ilma",
    ),
    const DhikrOption(
      label: "SubhanAllah wa bihamdihi, SubhanAllah al-azim",
      arabic: "سُبْحَانَ اللَّهِ وَبِحَمْدِهِ سُبْحَانَ اللَّهِ الْعَظِيمِ",
      transliteration: "SubhanAllahi wa bihamdihi, SubhanAllah al-azim",
    ),
    const DhikrOption(
      label: "Astaghfirullah wa atubu ilayh",
      arabic: "أَسْتَغْفِرُ اللَّهَ وَأَتُوبُ إِلَيْهِ",
      transliteration: "Astaghfirullah wa atubu ilayh",
    ),
    const DhikrOption(
      label: "La ilaha illa Allah wahdahu la sharika lah",
      arabic: "لَا إِلَٰهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ",
      transliteration: "La ilaha illa Allah wahdahu la sharika lah",
    ),
    const DhikrOption(
      label: "Lahul mulku wa lahul hamd",
      arabic: "لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ",
      transliteration: "Lahul mulku wa lahul hamd",
    ),
    const DhikrOption(
      label: "Yuhyi wa yumit wa huwa hayy",
      arabic: "يُحْيِي وَيُمِيتُ وَهُوَ حَيٌّ",
      transliteration: "Yuhyi wa yumit wa huwa hayy",
    ),
    const DhikrOption(
      label: "Biyadihi al-khayr wa huwa ala kulli shay'in qadir",
      arabic: "بِيَدِهِ الْخَيْرُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ",
      transliteration: "Biyadihi al-khayr wa huwa ala kulli shay'in qadir",
    ),
    const DhikrOption(
      label: "Allahumma inni as'aluka al-afiyah",
      arabic: "اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَافِيَةَ",
      transliteration: "Allahumma inni as'aluka al-afiyah",
    ),
    const DhikrOption(
      label: "Allahumma inni a'udhu bika min al-hammi",
      arabic: "اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ",
      transliteration: "Allahumma inni a'udhu bika min al-hammi",
    ),
    const DhikrOption(
      label: "Rabbi inni lima anzalta ilayya",
      arabic: "رَبِّ إِنِّي لِمَا أَنْزَلْتَ إِلَيَّ",
      transliteration: "Rabbi inni lima anzalta ilayya",
    ),
    const DhikrOption(
      label: "Allahumma ajirni min an-nar",
      arabic: "اللَّهُمَّ أَجِرْنِي مِنَ النَّارِ",
      transliteration: "Allahumma ajirni min an-nar",
    ),
    const DhikrOption(
      label: "Allahumma inni as'aluka al-jannah",
      arabic: "اللَّهُمَّ إِنِّي أَسْأَلُكَ الْجَنَّةَ",
      transliteration: "Allahumma inni as'aluka al-jannah",
    ),
    const DhikrOption(
      label: "Allahumma inni a'udhu bika min fitnatil qabr",
      arabic: "اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنْ فِتْنَةِ الْقَبْرِ",
      transliteration: "Allahumma inni a'udhu bika min fitnatil qabr",
    ),
    const DhikrOption(
      label: "Allahumma barik lana fi rizqina",
      arabic: "اللَّهُمَّ بَارِكْ لَنَا فِي رِزْقِنَا",
      transliteration: "Allahumma barik lana fi rizqina",
    ),
    const DhikrOption(
      label: "Allahumma ihdina sirata al-mustaqim",
      arabic: "اللَّهُمَّ اهْدِنَا الصِّرَاطَ الْمُسْتَقِيمَ",
      transliteration: "Allahumma ihdina sirata al-mustaqim",
    ),
    const DhikrOption(
      label: "Allahumma salli wa sallim ala nabiyyina",
      arabic: "اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا",
      transliteration: "Allahumma salli wa sallim ala nabiyyina",
    ),
    const DhikrOption(
      label: "Allahumma anta as-salam",
      arabic: "اللَّهُمَّ أَنْتَ السَّلَامُ",
      transliteration: "Allahumma anta as-salam",
    ),
    const DhikrOption(
      label: "Wa minka as-salam tabarakta",
      arabic: "وَمِنْكَ السَّلَامُ تَبَارَكْتَ",
      transliteration: "Wa minka as-salam tabarakta",
    ),
    const DhikrOption(
      label: "Ya Muqallibal qulub thabbit qalbi",
      arabic: "يَا مُقَلِّبَ الْقُلُوبِ ثَبِّتْ قَلْبِي",
      transliteration: "Ya Muqallibal qulub thabbit qalbi",
    ),
    const DhikrOption(
      label: "Rabbi ighfir li",
      arabic: "رَبِّ اغْفِرْ لِي",
      transliteration: "Rabbi ighfir li",
    ),
    const DhikrOption(
      label: "Allahumma ihsini al-khatimah",
      arabic: "اللَّهُمَّ أَحْسِنِ الْخَاتِمَةَ",
      transliteration: "Allahumma ihsini al-khatimah",
    ),
    const DhikrOption(label: "Custom"),
  ];

  @override
  void initState() {
    super.initState();
    _loadVibrationPreference();
  }

  Future<void> _loadVibrationPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_vibrationPrefKey) ?? true;
    if (mounted) {
      setState(() => _vibrationEnabled = enabled);
    }
  }

  Future<void> _toggleVibration() async {
    final next = !_vibrationEnabled;
    setState(() => _vibrationEnabled = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_vibrationPrefKey, next);
  }

  void _incrementCounter() {
    if (_vibrationEnabled) {
      HapticFeedback.mediumImpact();
      HapticFeedback.vibrate();
    }
    setState(() {
      _counter++;
    });
  }

  void _resetCounter() {
    setState(() {
      _counter = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = _options.firstWhere(
      (item) => item.label == _selectedDhikr,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("Tasbih"),
        actions: [
          IconButton(
            icon: Icon(
              _vibrationEnabled ? Icons.vibration : Icons.vibration_outlined,
            ),
            tooltip: _vibrationEnabled
                ? 'Vibration: On'
                : 'Vibration: Off',
            onPressed: _toggleVibration,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Show confirmation to avoid accidental resets
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Reset Counter?"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("No"),
                    ),
                    TextButton(
                      onPressed: () {
                        _resetCounter();
                        Navigator.pop(context);
                      },
                      child: const Text("Yes"),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Dhikr Selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButton<String>(
              value: _selectedDhikr,
              isExpanded: true,
              underline: Container(),
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
              items: _options.map((DhikrOption value) {
                return DropdownMenuItem<String>(
                  value: value.label,
                  child: Text(
                    value.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _selectedDhikr = newValue!;
                  _counter = 0; // Reset on change
                });
              },
            ),
          ),

          if (selected.arabic != null) ...[
            const SizedBox(height: 8),
            Text(
              selected.arabic!,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              softWrap: true,
              style: theme.textTheme.titleLarge?.copyWith(
                fontFamily: 'Uthmanic',
                height: 1.6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              selected.transliteration ?? '',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                letterSpacing: 0.4,
              ),
            ),
          ],

          const Spacer(),

          // The "Physical Bead" Tap Area
          GestureDetector(
            onTap: _incrementCounter,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer Glow/Ring
                Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                ),
                // The Bead
                AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primaryContainer,
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                    gradient: RadialGradient(
                      colors: [
                        theme.colorScheme.primaryContainer,
                        theme.colorScheme.primary.withOpacity(0.8),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$_counter',
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
          Text(
            "Tap anywhere on the circle",
            style: theme.textTheme.bodySmall?.copyWith(letterSpacing: 1.2),
          ),

          const Spacer(),

          // Target Indicator (Small Progress Bar)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: (_counter % 33) / 33,
                minHeight: 10,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text("${(_counter / 33).floor()} Sets of 33 Completed"),
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}

class DhikrOption {
  const DhikrOption({required this.label, this.arabic, this.transliteration});

  final String label;
  final String? arabic;
  final String? transliteration;
}
