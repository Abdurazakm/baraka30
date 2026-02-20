import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quran_flutter/quran_flutter.dart';

class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  static const String _highlightedVersesKey = 'quran_highlighted_verses';

  late PageController _pageController;
  int _currentPage = 1;
  int _bookmarkedPage = -1;
  late SharedPreferences _prefs;
  bool _isLoading = true;
  bool _showTranslation = true;
  QuranLanguage _selectedTranslationLanguage = QuranLanguage.english;
  List<Surah> _surahList = [];
  int _rounds = 1;
  double _dailyTargetPages = 0.0;
  int _pagesReadToday = 0;
  String _progressDateKey = '';
  String _progressMonthKey = '';
  int _pagesReadMonth = 0;

  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _playingVerseKey;
  bool _isAudioBusy = false;
  final Set<String> _highlightedVerses = <String>{};

  @override
  void initState() {
    super.initState();
    _initData();
    _audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted) {
        return;
      }
      setState(() => _playingVerseKey = null);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    _prefs = await SharedPreferences.getInstance();

    _surahList = Quran.getSurahAsList();
    _currentPage = _prefs.getInt('quran_current_page') ?? 1;
    _bookmarkedPage = _prefs.getInt('quran_bookmark') ?? -1;
    _showTranslation = _prefs.getBool('show_translation') ?? true;
    _selectedTranslationLanguage = _getSavedTranslationLanguage();
    _loadHighlightedVerses();

    _loadReadingPlan();
    await _loadDailyProgress();
    await _loadMonthlyProgress();

    _pageController = PageController(initialPage: _currentPage - 1);
    setState(() => _isLoading = false);
  }

  void _loadReadingPlan() {
    _rounds = _prefs.getInt('quran_rounds_goal') ?? 1;
    _dailyTargetPages = (_rounds * 604) / 30;
  }

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  String _formatMonth(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}";
  }

  Future<void> _loadDailyProgress() async {
    final today = _formatDate(DateTime.now());
    final storedDate = _prefs.getString('quran_progress_date') ?? '';

    if (storedDate != today) {
      await _prefs.setString('quran_progress_date', today);
      await _prefs.setStringList('quran_pages_read_today', <String>[]);
      await _resetDailyChecklist();
      _progressDateKey = today;
      _pagesReadToday = 0;
      return;
    }

    final storedPages = _prefs.getStringList('quran_pages_read_today') ?? <String>[];
    _progressDateKey = today;
    _pagesReadToday = storedPages.length;
  }

  Future<void> _loadMonthlyProgress() async {
    final monthKey = _formatMonth(DateTime.now());
    final storedMonth = _prefs.getString('quran_progress_month') ?? '';

    if (storedMonth != monthKey) {
      await _prefs.setString('quran_progress_month', monthKey);
      await _prefs.setStringList('quran_pages_read_month', <String>[]);
      _progressMonthKey = monthKey;
      _pagesReadMonth = 0;
      return;
    }

    final storedPages = _prefs.getStringList('quran_pages_read_month') ?? <String>[];
    _progressMonthKey = monthKey;
    _pagesReadMonth = storedPages.length;
  }

  void _onPageChanged(int pageIndex) {
    int pageNum = pageIndex + 1;
    setState(() => _currentPage = pageNum);
    _prefs.setInt('quran_current_page', pageNum);
    _trackPageRead(pageNum);
  }

  Future<void> _trackPageRead(int pageNum) async {
    final today = _formatDate(DateTime.now());
    final monthKey = _formatMonth(DateTime.now());

    if (today != _progressDateKey) {
      _progressDateKey = today;
      _pagesReadToday = 0;
      await _prefs.setString('quran_progress_date', today);
      await _prefs.setStringList('quran_pages_read_today', <String>[]);
      await _resetDailyChecklist();
    }

    if (monthKey != _progressMonthKey) {
      _progressMonthKey = monthKey;
      _pagesReadMonth = 0;
      await _prefs.setString('quran_progress_month', monthKey);
      await _prefs.setStringList('quran_pages_read_month', <String>[]);
    }

    final storedPages = _prefs.getStringList('quran_pages_read_today') ?? <String>[];
    final pageKey = pageNum.toString();
    if (!storedPages.contains(pageKey)) {
      storedPages.add(pageKey);
      await _prefs.setStringList('quran_pages_read_today', storedPages);
      await _syncChecklistWithPagesRead(storedPages.length);
      await _trackMonthlyPageRead(pageKey);
      if (mounted) {
        setState(() => _pagesReadToday = storedPages.length);
      }
    }
  }

  Future<void> _trackMonthlyPageRead(String pageKey) async {
    final storedPages = _prefs.getStringList('quran_pages_read_month') ?? <String>[];
    if (!storedPages.contains(pageKey)) {
      storedPages.add(pageKey);
      await _prefs.setStringList('quran_pages_read_month', storedPages);
      if (mounted) {
        setState(() => _pagesReadMonth = storedPages.length);
      }
    }
  }

  Future<void> _syncChecklistWithPagesRead(int pagesRead) async {
    final pagesPerPrayer = ((_rounds * 604) / 30 / 5).ceil();
    final List<String> prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

    for (int i = 0; i < prayers.length; i++) {
      final requiredPages = pagesPerPrayer * (i + 1);
      if (pagesRead >= requiredPages) {
        final taskTitle = '${prayers[i]} + Read $pagesPerPrayer Pages';
        await _prefs.setBool('task_$taskTitle', true);
      }
    }
  }

  Future<void> _resetDailyChecklist() async {
    final pagesPerPrayer = ((_rounds * 604) / 30 / 5).ceil();
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
      await _prefs.setBool('task_$task', false);
    }
  }

  void _toggleTranslation() {
    setState(() => _showTranslation = !_showTranslation);
    _prefs.setBool('show_translation', _showTranslation);
  }

  QuranLanguage _getSavedTranslationLanguage() {
    final savedName = _prefs.getString('quran_translation_language');
    if (savedName == null || savedName.isEmpty) {
      return QuranLanguage.english;
    }

    for (final language in QuranLanguage.values) {
      if (language.name == savedName) {
        return language;
      }
    }

    return QuranLanguage.english;
  }

  Future<void> _setTranslationLanguage(QuranLanguage language) async {
    if (_selectedTranslationLanguage == language) {
      return;
    }

    setState(() {
      _selectedTranslationLanguage = language;
    });
    await _prefs.setString('quran_translation_language', language.name);
  }

  String _getTranslationText({
    required int surahNumber,
    required int verseNumber,
  }) {
    try {
      return Quran.getVerse(
        surahNumber: surahNumber,
        verseNumber: verseNumber,
        language: _selectedTranslationLanguage,
      ).text;
    } catch (_) {
      return Quran.getVerse(
        surahNumber: surahNumber,
        verseNumber: verseNumber,
        language: QuranLanguage.english,
      ).text;
    }
  }

  Future<void> _showTranslationLanguagePicker() async {
    final selected = await showModalBottomSheet<QuranLanguage>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView.builder(
            itemCount: QuranLanguage.values.length,
            itemBuilder: (context, index) {
              final language = QuranLanguage.values[index];
              final isSelected = language == _selectedTranslationLanguage;
              return ListTile(
                title: Text(language.value),
                trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.green) : null,
                onTap: () => Navigator.pop(context, language),
              );
            },
          ),
        );
      },
    );

    if (selected != null) {
      await _setTranslationLanguage(selected);
    }
  }

  String _verseKey(int surahNumber, int verseNumber) {
    return '$surahNumber:$verseNumber';
  }

  void _loadHighlightedVerses() {
    final saved = _prefs.getStringList(_highlightedVersesKey) ?? <String>[];
    _highlightedVerses
      ..clear()
      ..addAll(saved);
  }

  Future<void> _saveHighlightedVerses() async {
    await _prefs.setStringList(_highlightedVersesKey, _highlightedVerses.toList());
  }

  String _buildVerseAudioUrl({
    required int surahNumber,
    required int verseNumber,
  }) {
    final surah = surahNumber.toString().padLeft(3, '0');
    final verse = verseNumber.toString().padLeft(3, '0');
    return 'https://everyayah.com/data/Alafasy_128kbps/$surah$verse.mp3';
  }

  Future<void> _handleVerseLongPress({
    required int surahNumber,
    required int verseNumber,
  }) async {
    await _showVerseOptions(surahNumber: surahNumber, verseNumber: verseNumber);
  }

  Future<void> _toggleVerseAudio({
    required int surahNumber,
    required int verseNumber,
  }) async {
    if (_isAudioBusy) {
      return;
    }

    final selectedKey = _verseKey(surahNumber, verseNumber);
    setState(() => _isAudioBusy = true);

    try {
      if (_playingVerseKey == selectedKey) {
        await _audioPlayer.stop();
        if (mounted) {
          setState(() {
            _playingVerseKey = null;
          });
        }
        return;
      }

      final url = _buildVerseAudioUrl(
        surahNumber: surahNumber,
        verseNumber: verseNumber,
      );

      await _audioPlayer.stop();
      if (!mounted) {
        return;
      }

      setState(() => _playingVerseKey = selectedKey);
      await _audioPlayer.play(UrlSource(url));
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _playingVerseKey = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not play this verse audio.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isAudioBusy = false);
      }
    }
  }

  Future<void> _toggleVerseHighlight({
    required int surahNumber,
    required int verseNumber,
  }) async {
    final key = _verseKey(surahNumber, verseNumber);
    setState(() {
      if (_highlightedVerses.contains(key)) {
        _highlightedVerses.remove(key);
      } else {
        _highlightedVerses.add(key);
      }
    });
    await _saveHighlightedVerses();
  }

  Future<void> _showVerseTranslation({
    required int surahNumber,
    required int verseNumber,
    required String arabicText,
  }) async {
    final translation = _getTranslationText(
      surahNumber: surahNumber,
      verseNumber: verseNumber,
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Surah $surahNumber • Ayah $verseNumber',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    arabicText,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    softWrap: true,
                    style: const TextStyle(
                      fontFamily: 'Uthmanic',
                      fontSize: 26,
                      height: 1.8,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    translation,
                    softWrap: true,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: Colors.blueGrey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showVerseOptions({
    required int surahNumber,
    required int verseNumber,
  }) async {
    final key = _verseKey(surahNumber, verseNumber);
    final isHighlighted = _highlightedVerses.contains(key);
    final isPlaying = _playingVerseKey == key;
    final verse = Quran.getVerse(surahNumber: surahNumber, verseNumber: verseNumber);

    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(isHighlighted ? Icons.highlight_off : Icons.highlight),
                title: Text(isHighlighted ? 'Remove Highlight' : 'Highlight Verse'),
                onTap: () => Navigator.pop(context, 'highlight'),
              ),
              ListTile(
                leading: Icon(isPlaying ? Icons.stop_circle_outlined : Icons.play_circle_fill),
                title: Text(isPlaying ? 'Stop Audio' : 'Play Audio'),
                onTap: () => Navigator.pop(context, 'audio'),
              ),
              ListTile(
                leading: const Icon(Icons.translate),
                title: const Text('Show Translation'),
                subtitle: Text(_selectedTranslationLanguage.value),
                onTap: () => Navigator.pop(context, 'translation'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || selected == null) {
      return;
    }

    if (selected == 'highlight') {
      await _toggleVerseHighlight(surahNumber: surahNumber, verseNumber: verseNumber);
      return;
    }

    if (selected == 'audio') {
      await _toggleVerseAudio(surahNumber: surahNumber, verseNumber: verseNumber);
      return;
    }

    if (selected == 'translation') {
      await _showVerseTranslation(
        surahNumber: surahNumber,
        verseNumber: verseNumber,
        arabicText: verse.text,
      );
    }
  }

  Future<void> _toggleBookmark() async {
    if (_bookmarkedPage == _currentPage) {
      await _prefs.remove('quran_bookmark');
      setState(() => _bookmarkedPage = -1);
    } else {
      await _prefs.setInt('quran_bookmark', _currentPage);
      setState(() => _bookmarkedPage = _currentPage);
    }
  }

  void _jumpToBookmark() {
    if (_bookmarkedPage <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No bookmark saved yet.')),
        );
      }
      return;
    }

    _pageController.jumpToPage(_bookmarkedPage - 1);
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  void _jumpToPage(int pageNum) {
    _pageController.jumpToPage(pageNum - 1);
    if (Navigator.canPop(context)) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F1),
      appBar: AppBar(
        title: Text(
          'Page $_currentPage',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_added_outlined),
            tooltip: 'Go to Bookmark',
            onPressed: _jumpToBookmark,
          ),
          IconButton(
            icon: Icon(_showTranslation ? Icons.g_translate : Icons.translate_outlined),
            onPressed: _toggleTranslation,
            tooltip: 'Toggle Translation',
          ),
          IconButton(
            icon: const Icon(Icons.language),
            tooltip: 'Translation Language',
            onPressed: _showTranslationLanguagePicker,
          ),
          IconButton(
            icon: Icon(
              _bookmarkedPage == _currentPage ? Icons.bookmark : Icons.bookmark_border,
              color: _bookmarkedPage == _currentPage ? Colors.amber : null,
            ),
            onPressed: _toggleBookmark,
          ),
        ],
      ),
      drawer: _buildIndexDrawer(),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        itemCount: 604,
        reverse: true,
        itemBuilder: (context, index) => _buildMushafPage(index + 1),
      ),
      bottomNavigationBar: _buildStatusBar(),
    );
  }

  Widget _buildBismillah() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 16.0),
      child: const Text(
        'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Uthmanic',
          fontSize: 26,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildMushafPage(int pageNum) {
    final dynamic pageData = Quran.getSurahVersesInPageAsList(pageNum);

    if (pageData == null) {
      return const Center(child: Text('Page not found'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double screenWidth = constraints.maxWidth;
        final double screenHeight = constraints.maxHeight;

        final double mushafFontSize = (screenHeight * 0.75) / 15;
        final double translationFontSize = screenWidth * 0.035;

        return Container(
          width: screenWidth,
          height: screenHeight,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFBF9F1),
            border: Border.all(color: Colors.brown.withValues(alpha: 0.15)),
          ),
          child: SingleChildScrollView(
            child: _showTranslation
                ? _buildTranslationMode(pageData, mushafFontSize, translationFontSize)
                : _buildReadingMode(pageData, mushafFontSize),
          ),
        );
      },
    );
  }

  Widget _buildReadingMode(List<dynamic> pageData, double fontSize) {
    List<Widget> pageContent = [];

    for (var surahInPage in pageData) {
      final surahNumber = surahInPage!.surahNumber!;
      final versesList = surahInPage.verses!.values.toList();

      if (versesList.isNotEmpty && versesList.first.verseNumber == 1) {
        pageContent.add(_buildSurahHeader(surahNumber));
        if (surahNumber != 1 && surahNumber != 9) {
          pageContent.add(_buildBismillah());
        }
      }

      pageContent.add(
        Directionality(
          textDirection: TextDirection.rtl,
          child: Wrap(
            alignment: WrapAlignment.start,
            runSpacing: 2,
            spacing: 6,
            children: versesList.map<Widget>((v) {
              final verseKey = _verseKey(surahNumber, v.verseNumber);
              final isPlayingVerse = _playingVerseKey == verseKey;
              final isHighlightedVerse = _highlightedVerses.contains(verseKey);

              return GestureDetector(
                onLongPress: () => _handleVerseLongPress(
                  surahNumber: surahNumber,
                  verseNumber: v.verseNumber,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                  decoration: BoxDecoration(
                    color: isPlayingVerse
                        ? Colors.green.withValues(alpha: 0.14)
                        : isHighlightedVerse
                            ? Colors.amber.withValues(alpha: 0.18)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${v.text} ',
                          style: TextStyle(
                            fontFamily: 'Uthmanic',
                            fontSize: fontSize,
                            height: 1.8,
                            color: Colors.black87,
                          ),
                        ),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: _buildAyahEnd(v.verseNumber),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: pageContent,
    );
  }

  Widget _buildTranslationMode(List<dynamic> pageData, double arabicSize, double transSize) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: pageData.map<Widget>((surahInPage) {
        final versesList = surahInPage!.verses!.values.toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (versesList.isNotEmpty && versesList.first.verseNumber == 1)
              _buildSurahHeader(surahInPage.surahNumber!),
            ...versesList.map((v) {
              final verseKey = _verseKey(surahInPage.surahNumber!, v.verseNumber);
              final isPlayingVerse = _playingVerseKey == verseKey;
              final isHighlightedVerse = _highlightedVerses.contains(verseKey);
              final translation = _getTranslationText(
                surahNumber: surahInPage.surahNumber!,
                verseNumber: v.verseNumber,
              );

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPress: () => _handleVerseLongPress(
                  surahNumber: surahInPage.surahNumber!,
                  verseNumber: v.verseNumber,
                ),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 24.0),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPlayingVerse
                        ? Colors.green.withValues(alpha: 0.14)
                        : isHighlightedVerse
                            ? Colors.amber.withValues(alpha: 0.18)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      RichText(
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '${v.text} ',
                              style: TextStyle(
                                fontFamily: 'Uthmanic',
                                fontSize: arabicSize * 0.9,
                                height: 1.8,
                                color: Colors.black87,
                              ),
                            ),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: _buildAyahEnd(v.verseNumber),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        translation,
                        style: TextStyle(
                          fontSize: transSize,
                          color: Colors.blueGrey,
                          fontStyle: FontStyle.italic,
                          height: 1.5,
                        ),
                      ),
                      if (isPlayingVerse)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Playing verse audio... (long-press and choose Stop Audio)',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildAyahEnd(int num) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFD4AF37), width: 1),
      ),
      child: Text(
        '$num',
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSurahHeader(int surahNumber) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 20),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.brown.withValues(alpha: 0.05),
        border: Border.symmetric(
          horizontal: BorderSide(color: Colors.brown.withValues(alpha: 0.2)),
        ),
      ),
      child: Text(
        Quran.getSurahName(surahNumber),
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'Uthmanic',
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    double overallProgress = _currentPage / 604;
    final dailyTarget = _dailyTargetPages <= 0 ? 1.0 : _dailyTargetPages;
    final dailyProgress = (_pagesReadToday / dailyTarget).clamp(0.0, 1.0);
    final monthlyTarget = _rounds * 604;
    final monthlyProgress =
        monthlyTarget <= 0 ? 0.0 : (_pagesReadMonth / monthlyTarget).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 25),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildProgressRow(
            'DAILY',
            dailyProgress,
            '$_pagesReadToday / ${dailyTarget.toStringAsFixed(1)}',
          ),
          const SizedBox(height: 8),
          _buildProgressRow(
            'RAMADAN',
            monthlyProgress,
            '$_pagesReadMonth / $monthlyTarget',
          ),
          const SizedBox(height: 8),
          _buildProgressRow('MUSHAF', overallProgress, 'PG $_currentPage/604'),
        ],
      ),
    );
  }

  Widget _buildProgressRow(String label, double value, String trailing) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            Text(
              trailing,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: value,
          minHeight: 4,
          borderRadius: BorderRadius.circular(10),
          backgroundColor: Colors.grey[200],
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.brown),
        ),
      ],
    );
  }

  Widget _buildIndexDrawer() {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.brown),
            child: const Center(
              child: Text(
                'Surah Index',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.bookmark),
            title: const Text('Go to Bookmark'),
            subtitle: Text(
              _bookmarkedPage > 0 ? 'Page $_bookmarkedPage' : 'No bookmark saved',
            ),
            onTap: _jumpToBookmark,
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: _surahList.length,
              itemBuilder: (context, index) {
                final surah = _surahList[index];
                return ListTile(
                  leading: CircleAvatar(
                    child: Text('${index + 1}', style: const TextStyle(fontSize: 12)),
                  ),
                  title: Text(surah.name),
                  subtitle: Text(surah.nameEnglish),
                  onTap: () {
                    int startPage = Quran.getPageNumber(surahNumber: index + 1, verseNumber: 1);
                    _jumpToPage(startPage);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
