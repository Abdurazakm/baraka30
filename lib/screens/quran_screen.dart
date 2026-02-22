import 'dart:async';

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quran_flutter/quran_flutter.dart';
import 'package:flutter/gestures.dart';
import '../services/app_language.dart';
import '../services/offline_quran_service.dart';
import '../services/progress_reset_service.dart';
import 'downloads_screen.dart';

class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  static const String _highlightedVersesKey = 'quran_highlighted_verses';
  static const String _continuousPlayPrefKey = 'quran_continuous_play_pref';
  static const String _audioHintSeenPrefKey = 'quran_audio_hint_seen';
  static const String _bismillahText = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ';

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
  int? _returnReadingPage;
  Timer? _refreshTimer;
  bool _isRefreshing = false;

  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _playingVerseKey;
  bool _isAudioBusy = false;
  bool _isContinuousPlaybackActive = false;
  final Set<String> _highlightedVerses = <String>{};
  final OfflineQuranService _offlineService = OfflineQuranService();
  final Map<int, Map<int, String>> _offlineTranslationCache = {};
  String _offlineTranslationKey = OfflineQuranService.defaultTranslationKey;
  String _offlineReciterKey = OfflineQuranService.defaultReciterKey;
  bool _useDownloadedTranslations = false;
  bool _useDownloadedAudio = false;
  bool _preferContinuousPlayback = false;
  bool _showAudioHint = true;

  @override
  void initState() {
    super.initState();
    _initData();
    _audioPlayer.onPlayerComplete.listen((_) => _handlePlayerComplete());
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _refreshProgressIfNeeded(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _pageController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    _prefs = await SharedPreferences.getInstance();

    _surahList = Quran.getSurahAsList();
    _currentPage = _prefs.getInt('quran_current_page') ?? 1;
    _bookmarkedPage = _prefs.getInt('quran_bookmark') ?? -1;
    _showTranslation = _prefs.getBool('show_translation') ?? false;
    _preferContinuousPlayback = _prefs.getBool(_continuousPlayPrefKey) ?? false;
    _showAudioHint = !(_prefs.getBool(_audioHintSeenPrefKey) ?? false);
    _selectedTranslationLanguage = _getSavedTranslationLanguage();
    _loadHighlightedVerses();
    await _loadDownloadPrefs();

    _loadReadingPlan();
    await _loadDailyProgress();
    await _loadMonthlyProgress();

    _pageController = PageController(
      initialPage: _pageIndexForNumber(_currentPage),
    );
    _prefetchOfflineTranslationsForPage(_currentPage);
    setState(() => _isLoading = false);
  }

  Future<void> _loadDownloadPrefs() async {
    _offlineTranslationKey =
        _prefs.getString(DownloadsScreen.translationKeyPref) ??
        OfflineQuranService.defaultTranslationKey;
    _offlineReciterKey =
        _prefs.getString(DownloadsScreen.reciterKeyPref) ??
        OfflineQuranService.defaultReciterKey;
    _useDownloadedTranslations =
        _prefs.getBool(DownloadsScreen.useDownloadedTranslationPref) ?? false;
    _useDownloadedAudio =
        _prefs.getBool(DownloadsScreen.useDownloadedAudioPref) ?? false;
  }

  Future<void> _reloadDownloadPrefs() async {
    await _loadDownloadPrefs();
    _offlineTranslationCache.clear();
    _prefetchOfflineTranslationsForPage(_currentPage);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _prefetchOfflineTranslationsForPage(int pageNum) async {
    if (!_useDownloadedTranslations) {
      return;
    }
    final dynamic pageData = Quran.getSurahVersesInPageAsList(pageNum);
    if (pageData == null) {
      return;
    }

    final Set<int> surahNumbers = {};
    for (final surahInPage in pageData) {
      final surahNumber = surahInPage!.surahNumber! as int;
      surahNumbers.add(surahNumber);
    }

    for (final surahNumber in surahNumbers) {
      if (_offlineTranslationCache.containsKey(surahNumber)) {
        continue;
      }
      final map = await _offlineService.loadTranslationMap(
        key: _offlineTranslationKey,
        surah: surahNumber,
      );
      if (map.isNotEmpty) {
        _offlineTranslationCache[surahNumber] = map;
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _loadReadingPlan() {
    _rounds = _prefs.getInt('quran_rounds_goal') ?? 1;
    _dailyTargetPages = (_rounds * 604) / 30;
  }

  Future<void> _loadDailyProgress() async {
    final rounds = _prefs.getInt('quran_rounds_goal') ?? _rounds;
    final result = await ProgressResetService.ensureCalendarProgressCurrent(
      prefs: _prefs,
      rounds: rounds,
    );
    final storedPages =
        _prefs.getStringList('quran_pages_read_today') ?? <String>[];
    _progressDateKey = result.todayKey;
    _pagesReadToday = storedPages.length;
  }

  Future<void> _loadMonthlyProgress() async {
    final rounds = _prefs.getInt('quran_rounds_goal') ?? _rounds;
    final result = await ProgressResetService.ensureCalendarProgressCurrent(
      prefs: _prefs,
      rounds: rounds,
    );
    final storedPages =
        _prefs.getStringList('quran_pages_read_month') ?? <String>[];
    _progressMonthKey = result.monthKey;
    _pagesReadMonth = storedPages.length;
  }

  Future<void> _refreshProgressIfNeeded() async {
    if (_isLoading || _isRefreshing) {
      return;
    }

    _isRefreshing = true;
    try {
      final rounds = _prefs.getInt('quran_rounds_goal') ?? _rounds;
      final result = await ProgressResetService.ensureCalendarProgressCurrent(
        prefs: _prefs,
        rounds: rounds,
      );
      final today = result.todayKey;
      final monthKey = result.monthKey;

      final storedPages =
          _prefs.getStringList('quran_pages_read_today') ?? <String>[];
      final storedMonthPages =
          _prefs.getStringList('quran_pages_read_month') ?? <String>[];
      final dailyTarget = (rounds * 604) / 30;

      final bool needsUpdate =
          rounds != _rounds ||
          storedPages.length != _pagesReadToday ||
          storedMonthPages.length != _pagesReadMonth ||
          dailyTarget != _dailyTargetPages ||
          today != _progressDateKey ||
          monthKey != _progressMonthKey;

      if (needsUpdate && mounted) {
        setState(() {
          _rounds = rounds;
          _pagesReadToday = storedPages.length;
          _pagesReadMonth = storedMonthPages.length;
          _dailyTargetPages = dailyTarget;
          _progressDateKey = today;
          _progressMonthKey = monthKey;
        });
      }
    } finally {
      _isRefreshing = false;
    }
  }

  void _onPageChanged(int pageIndex) {
    int pageNum = _pageNumberForIndex(pageIndex);
    setState(() => _currentPage = pageNum);
    _prefs.setInt('quran_current_page', pageNum);
    _trackPageRead(pageNum);
    _prefetchOfflineTranslationsForPage(pageNum);
  }

  Future<void> _trackPageRead(int pageNum) async {
    final rounds = _prefs.getInt('quran_rounds_goal') ?? _rounds;
    final result = await ProgressResetService.ensureCalendarProgressCurrent(
      prefs: _prefs,
      rounds: rounds,
    );
    _progressDateKey = result.todayKey;
    _progressMonthKey = result.monthKey;
    if (result.dailyReset) {
      _pagesReadToday = 0;
    }
    if (result.monthlyReset) {
      _pagesReadMonth = 0;
    }

    final storedPages =
        _prefs.getStringList('quran_pages_read_today') ?? <String>[];
    final pageKey = pageNum.toString();
    if (!storedPages.contains(pageKey)) {
      storedPages.add(pageKey);
      await _prefs.setStringList('quran_pages_read_today', storedPages);
      await _trackMonthlyPageRead(pageKey);
      if (mounted) {
        setState(() => _pagesReadToday = storedPages.length);
      }
    }
  }

  Future<void> _trackMonthlyPageRead(String pageKey) async {
    final storedPages =
        _prefs.getStringList('quran_pages_read_month') ?? <String>[];
    if (!storedPages.contains(pageKey)) {
      storedPages.add(pageKey);
      await _prefs.setStringList('quran_pages_read_month', storedPages);
      if (mounted) {
        setState(() => _pagesReadMonth = storedPages.length);
      }
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
    if (_useDownloadedTranslations) {
      final surahMap = _offlineTranslationCache[surahNumber];
      final offline = surahMap?[verseNumber];
      if (offline != null && offline.isNotEmpty) {
        return offline;
      }
    }
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
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
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
    await _prefs.setStringList(
      _highlightedVersesKey,
      _highlightedVerses.toList(),
    );
  }

  String _buildVerseAudioUrl({
    required int surahNumber,
    required int verseNumber,
  }) {
    final surah = surahNumber.toString().padLeft(3, '0');
    final verse = verseNumber.toString().padLeft(3, '0');
    final reciter = OfflineQuranService.reciterOptions.firstWhere(
      (r) => r.key == _offlineReciterKey,
      orElse: () => OfflineQuranService.reciterOptions.first,
    );
    return '${reciter.baseUrl}/$surah$verse.mp3';
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
            _isContinuousPlaybackActive = false;
          });
        }
        return;
      }

      if (_isContinuousPlaybackActive && mounted) {
        setState(() => _isContinuousPlaybackActive = false);
      }

      await _playVerseAudio(surahNumber: surahNumber, verseNumber: verseNumber);
    } catch (_) {
      if (!mounted) {
        return;
      }
      final strings = AppStrings.of(context);
      setState(() => _playingVerseKey = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.couldNotPlayVerse())),
      );
    } finally {
      if (mounted) {
        setState(() => _isAudioBusy = false);
      }
    }
  }

  Future<void> _handleVerseTap({
    required int surahNumber,
    required int verseNumber,
  }) async {
    if (_preferContinuousPlayback) {
      final selectedKey = _verseKey(surahNumber, verseNumber);
      final isThisVersePlaying = _playingVerseKey == selectedKey;
      if (_isContinuousPlaybackActive && isThisVersePlaying) {
        await _stopContinuousPlayback();
        return;
      }
      await _startContinuousPlayback(
        surahNumber: surahNumber,
        verseNumber: verseNumber,
      );
      return;
    }

    await _toggleVerseAudio(surahNumber: surahNumber, verseNumber: verseNumber);
  }

  Future<void> _toggleContinuousPlayPreference() async {
    final next = !_preferContinuousPlayback;
    setState(() => _preferContinuousPlayback = next);
    await _prefs.setBool(_continuousPlayPrefKey, next);
  }

  Future<void> _startContinuousPlayback({
    required int surahNumber,
    required int verseNumber,
  }) async {
    if (_isAudioBusy) {
      return;
    }

    setState(() {
      _isAudioBusy = true;
      _isContinuousPlaybackActive = true;
    });

    try {
      await _playVerseAudio(surahNumber: surahNumber, verseNumber: verseNumber);
    } catch (_) {
      if (!mounted) {
        return;
      }
      final strings = AppStrings.of(context);
      setState(() {
        _playingVerseKey = null;
        _isContinuousPlaybackActive = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.couldNotStartContinuous())),
      );
    } finally {
      if (mounted) {
        setState(() => _isAudioBusy = false);
      }
    }
  }

  Future<void> _stopContinuousPlayback() async {
    if (_isAudioBusy) {
      return;
    }

    setState(() => _isAudioBusy = true);
    try {
      await _audioPlayer.stop();
      if (mounted) {
        setState(() {
          _playingVerseKey = null;
          _isContinuousPlaybackActive = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isAudioBusy = false);
      }
    }
  }

  Future<void> _playVerseAudio({
    required int surahNumber,
    required int verseNumber,
  }) async {
    final selectedKey = _verseKey(surahNumber, verseNumber);

    if (_isContinuousPlaybackActive) {
      await _syncPageToPlayingVerse(
        surahNumber: surahNumber,
        verseNumber: verseNumber,
      );
    }

    if (_useDownloadedAudio) {
      final file = await _offlineService.getOfflineAudioFile(
        reciterKey: _offlineReciterKey,
        surah: surahNumber,
        ayah: verseNumber,
      );
      if (file != null) {
        await _audioPlayer.stop();
        if (!mounted) {
          return;
        }
        setState(() => _playingVerseKey = selectedKey);
        await _audioPlayer.play(DeviceFileSource(file.path));
        await _markAudioHintSeenOnce();
        return;
      }
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
    await _markAudioHintSeenOnce();
  }

  Future<void> _syncPageToPlayingVerse({
    required int surahNumber,
    required int verseNumber,
  }) async {
    if (!_pageController.hasClients) {
      return;
    }

    final targetPage = Quran.getPageNumber(
      surahNumber: surahNumber,
      verseNumber: verseNumber,
    );

    if (targetPage == _currentPage) {
      return;
    }

    final targetIndex = _pageIndexForNumber(targetPage);
    final currentIndex =
        _pageController.page?.round() ?? _pageIndexForNumber(_currentPage);
    final distance = (currentIndex - targetIndex).abs();
    final durationMs = (180 + (distance * 10)).clamp(180, 900);

    await _pageController.animateToPage(
      targetIndex,
      duration: Duration(milliseconds: durationMs),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _markAudioHintSeenOnce() async {
    if (!_showAudioHint) {
      return;
    }

    await _prefs.setBool(_audioHintSeenPrefKey, true);
    if (mounted) {
      setState(() => _showAudioHint = false);
    }
  }

  Future<void> _handlePlayerComplete() async {
    if (!mounted) {
      return;
    }

    final currentKey = _playingVerseKey;
    if (!_isContinuousPlaybackActive || currentKey == null) {
      setState(() => _playingVerseKey = null);
      return;
    }

    final nextVerse = _getNextVerse(currentKey);
    if (nextVerse == null) {
      final strings = AppStrings.of(context);
      setState(() {
        _playingVerseKey = null;
        _isContinuousPlaybackActive = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.continuousPlaybackFinished())),
      );
      return;
    }

    try {
      await _playVerseAudio(
        surahNumber: nextVerse.$1,
        verseNumber: nextVerse.$2,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      final strings = AppStrings.of(context);
      setState(() {
        _playingVerseKey = null;
        _isContinuousPlaybackActive = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.couldNotContinue())),
      );
    }
  }

  (int, int)? _getNextVerse(String currentKey) {
    final current = _parseVerseKey(currentKey);
    if (current == null) {
      return null;
    }

    final currentSurah = current.$1;
    final currentVerse = current.$2;

    if (_verseExists(currentSurah, currentVerse + 1)) {
      return (currentSurah, currentVerse + 1);
    }

    for (int surah = currentSurah + 1; surah <= 114; surah++) {
      if (_verseExists(surah, 1)) {
        return (surah, 1);
      }
    }

    return null;
  }

  (int, int)? _parseVerseKey(String key) {
    final parts = key.split(':');
    if (parts.length != 2) {
      return null;
    }

    final surah = int.tryParse(parts[0]);
    final verse = int.tryParse(parts[1]);
    if (surah == null || verse == null) {
      return null;
    }

    return (surah, verse);
  }

  bool _verseExists(int surahNumber, int verseNumber) {
    try {
      Quran.getVerse(surahNumber: surahNumber, verseNumber: verseNumber);
      return true;
    } catch (_) {
      return false;
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
          child: Container(
            color: Colors.black87,
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
                        color: Colors.white,
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
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      translation,
                      softWrap: true,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: Colors.white,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
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
    final strings = AppStrings.of(context);
    final key = _verseKey(surahNumber, verseNumber);
    final isHighlighted = _highlightedVerses.contains(key);
    final isPlaying = _playingVerseKey == key;
    final isContinuousPlaying = isPlaying && _isContinuousPlaybackActive;
    final verse = Quran.getVerse(
      surahNumber: surahNumber,
      verseNumber: verseNumber,
    );

    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  isHighlighted ? Icons.highlight_off : Icons.highlight,
                ),
                title: Text(
                  isHighlighted
                      ? strings.removeHighlight()
                      : strings.highlightVerse(),
                ),
                onTap: () => Navigator.pop(context, 'highlight'),
              ),
              ListTile(
                leading: Icon(
                  isPlaying
                      ? Icons.stop_circle_outlined
                      : Icons.play_circle_fill,
                ),
                title: Text(isPlaying ? strings.stopAudio() : strings.playAudio()),
                onTap: () => Navigator.pop(context, 'audio'),
              ),
              ListTile(
                leading: Icon(
                  isContinuousPlaying
                      ? Icons.repeat_one_on
                      : Icons.playlist_play,
                ),
                title: Text(
                  isContinuousPlaying
                      ? strings.stopContinuous()
                      : strings.playContinuously(),
                ),
                subtitle: Text(strings.keepPlayingSubtitle()),
                onTap: () => Navigator.pop(context, 'continuous'),
              ),
              ListTile(
                leading: const Icon(Icons.translate),
                title: Text(strings.showTranslation()),
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
      await _toggleVerseHighlight(
        surahNumber: surahNumber,
        verseNumber: verseNumber,
      );
      return;
    }

    if (selected == 'audio') {
      await _toggleVerseAudio(
        surahNumber: surahNumber,
        verseNumber: verseNumber,
      );
      return;
    }

    if (selected == 'continuous') {
      if (isContinuousPlaying) {
        await _stopContinuousPlayback();
      } else {
        await _startContinuousPlayback(
          surahNumber: surahNumber,
          verseNumber: verseNumber,
        );
      }
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

  Future<void> _showVerseQuickActions({
    required int surahNumber,
    required int verseNumber,
    required String arabicText,
  }) async {
    final strings = AppStrings.of(context);
    final key = _verseKey(surahNumber, verseNumber);
    final isHighlighted = _highlightedVerses.contains(key);
    final isPlaying = _playingVerseKey == key;
    final isContinuousPlaying = isPlaying && _isContinuousPlaybackActive;

    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
            child: Wrap(
              alignment: WrapAlignment.spaceEvenly,
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildQuickAction(
                  icon: isHighlighted ? Icons.highlight_off : Icons.highlight,
                  label: isHighlighted
                      ? strings.unhighlightShort()
                      : strings.highlightShort(),
                  onTap: () => Navigator.pop(context, 'highlight'),
                ),
                _buildQuickAction(
                  icon: isPlaying
                      ? Icons.stop_circle_outlined
                      : Icons.play_circle_fill,
                  label: isPlaying ? strings.stopAudio() : strings.playAudio(),
                  onTap: () => Navigator.pop(context, 'audio'),
                ),
                _buildQuickAction(
                  icon: isContinuousPlaying
                      ? Icons.repeat_one_on
                      : Icons.playlist_play,
                  label: isContinuousPlaying
                      ? strings.stopContinuousShort()
                      : strings.playContinuouslyShort(),
                  onTap: () => Navigator.pop(context, 'continuous'),
                ),
                _buildQuickAction(
                  icon: Icons.translate,
                  label: strings.translationShort(),
                  onTap: () => Navigator.pop(context, 'translation'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selected == null) {
      return;
    }

    if (selected == 'highlight') {
      await _toggleVerseHighlight(
        surahNumber: surahNumber,
        verseNumber: verseNumber,
      );
      return;
    }

    if (selected == 'audio') {
      await _toggleVerseAudio(
        surahNumber: surahNumber,
        verseNumber: verseNumber,
      );
      return;
    }

    if (selected == 'continuous') {
      if (isContinuousPlaying) {
        await _stopContinuousPlayback();
      } else {
        await _startContinuousPlayback(
          surahNumber: surahNumber,
          verseNumber: verseNumber,
        );
      }
      return;
    }

    if (selected == 'translation') {
      await _showVerseTranslation(
        surahNumber: surahNumber,
        verseNumber: verseNumber,
        arabicText: arabicText,
      );
    }
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 120,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
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
        final strings = AppStrings.of(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(strings.noBookmarkSaved())));
      }
      return;
    }

    _jumpToPage(_bookmarkedPage, captureReadingPage: true);
  }

  int _currentVisiblePage() {
    if (!_pageController.hasClients) {
      return _currentPage;
    }
    final index = _pageController.page?.round() ?? _pageIndexForNumber(_currentPage);
    return _pageNumberForIndex(index);
  }

  void _jumpToPage(
    int pageNum, {
    bool captureReadingPage = false,
  }) {
    if (!_pageController.hasClients) {
      return;
    }

    final targetPage = pageNum.clamp(1, 604);
    final previousPage = _currentVisiblePage();
    if (captureReadingPage && previousPage != targetPage) {
      _returnReadingPage = previousPage;
    }
    final targetIndex = _pageIndexForNumber(targetPage);
    final currentIndex = _pageController.page?.round() ?? targetIndex;
    final distance = (currentIndex - targetIndex).abs();
    final durationMs = (200 + (distance * 10)).clamp(200, 1200);

    _pageController.animateToPage(
      targetIndex,
      duration: Duration(milliseconds: durationMs),
      curve: Curves.easeOutCubic,
    );

    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }

  }

  void _jumpToReadingPage() {
    final page = _returnReadingPage;
    if (page == null || page == _currentPage) {
      return;
    }
    _jumpToPage(page, captureReadingPage: false);
    if (mounted) {
      setState(() {
        _returnReadingPage = null;
      });
    } else {
      _returnReadingPage = null;
    }
  }

  int _pageIndexForNumber(int pageNum) {
    final clamped = pageNum.clamp(1, 604);
    return clamped - 1;
  }

  int _pageNumberForIndex(int index) {
    final clamped = index.clamp(0, 603);
    return clamped + 1;
  }

  Future<void> _showPageSearchDialog() async {
    final strings = AppStrings.of(context);
    final selectedPage = await showDialog<int>(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: '$_currentPage');
        String? errorText;

        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: Text(strings.goToPageTitle()),
              content: TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: strings.pageNumberLabel(),
                  hintText: strings.pageNumberHint(),
                  errorText: errorText,
                ),
                onSubmitted: (_) {
                  final page = int.tryParse(controller.text.trim());
                  if (page == null || page < 1 || page > 604) {
                    setLocalState(() {
                      errorText = strings.enterPageError();
                    });
                    return;
                  }
                  Navigator.pop(context, page);
                },
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(strings.cancel()),
                ),
                FilledButton(
                  onPressed: () {
                    final page = int.tryParse(controller.text.trim());
                    if (page == null || page < 1 || page > 604) {
                      setLocalState(() {
                        errorText = strings.enterPageError();
                      });
                      return;
                    }
                    Navigator.pop(context, page);
                  },
                  child: Text(strings.goButton()),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted || selectedPage == null) {
      return;
    }

    _jumpToPage(selectedPage, captureReadingPage: true);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F1),
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.manage_search),
              tooltip: strings.goToPage(),
              onPressed: _showPageSearchDialog,
            ),
            const SizedBox(width: 4),
            Text(
              strings.pageLabel(_currentPage),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _bookmarkedPage == _currentPage
                  ? Icons.bookmark
                  : Icons.bookmark_border,
              color: _bookmarkedPage == _currentPage ? Colors.amber : null,
            ),
            tooltip: _bookmarkedPage == _currentPage
              ? strings.removeBookmark()
              : strings.saveBookmark(),
            onPressed: _toggleBookmark,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              switch (value) {
                case 'go_page':
                  await _showPageSearchDialog();
                  break;
                case 'downloads':
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DownloadsScreen()),
                  );
                  if (result == true) {
                    await _reloadDownloadPrefs();
                  }
                  break;
                case 'bookmark_jump':
                  _jumpToBookmark();
                  break;
                case 'translation_toggle':
                  _toggleTranslation();
                  break;
                case 'continuous_toggle':
                  await _toggleContinuousPlayPreference();
                  break;
                case 'language_picker':
                  await _showTranslationLanguagePicker();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'go_page', child: Text(strings.goToPage())),
              PopupMenuItem(
                value: 'downloads',
                child: Text(strings.offlineDownloads()),
              ),
              PopupMenuItem(
                value: 'bookmark_jump',
                child: Text(strings.goToBookmark()),
              ),
              PopupMenuItem(
                value: 'translation_toggle',
                child: Text(
                  _showTranslation
                      ? strings.hideTranslation()
                      : strings.showTranslation(),
                ),
              ),
              PopupMenuItem(
                value: 'continuous_toggle',
                child: Text(
                  _preferContinuousPlayback
                      ? strings.continuousTapPlayOn()
                      : strings.continuousTapPlayOff(),
                ),
              ),
              PopupMenuItem(
                value: 'language_picker',
                child: Text(strings.translationLanguage()),
              ),
            ],
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
        _bismillahText,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Uthmanic',
          fontSize: 26,
          color: Colors.black87,
        ),
      ),
    );
  }

  String _stripBismillahPrefix(String text) {
    final trimmed = text.trimLeft();
    final normalizedTarget = _normalizeArabic(_bismillahText);
    String normalized = '';
    int cutIndex = 0;

    for (int i = 0; i < trimmed.length; i++) {
      final chunk = _normalizeArabic(trimmed[i]);
      if (chunk.isEmpty) {
        cutIndex = i + 1;
        continue;
      }
      normalized += chunk;
      cutIndex = i + 1;
      if (normalized.length >= normalizedTarget.length) {
        break;
      }
    }

    if (normalized == normalizedTarget) {
      return trimmed.substring(cutIndex).trimLeft();
    }

    return text;
  }

  String _normalizeArabic(String input) {
    final buffer = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      final code = input.codeUnitAt(i);
      if (_isArabicDiacritic(code) || code == 0x0640) {
        continue;
      }
      final mapped = _normalizeArabicChar(code);
      if (mapped != null) {
        buffer.write(String.fromCharCode(mapped));
      }
    }
    return buffer.toString();
  }

  bool _isArabicDiacritic(int code) {
    return (code >= 0x0610 && code <= 0x061A) ||
        (code >= 0x064B && code <= 0x065F) ||
        code == 0x0670 ||
        (code >= 0x06D6 && code <= 0x06ED);
  }

  int? _normalizeArabicChar(int code) {
    switch (code) {
      case 0x0622: // آ
      case 0x0623: // أ
      case 0x0625: // إ
      case 0x0671: // ٱ
        return 0x0627; // ا
      default:
        return code;
    }
  }

  Widget _buildMushafPage(int pageNum) {
    final dynamic pageData = Quran.getSurahVersesInPageAsList(pageNum);

    if (pageData == null) {
      return Center(child: Text(AppStrings.of(context).pageNotFound()));
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
                ? _buildTranslationMode(
                    pageData,
                    mushafFontSize,
                    translationFontSize,
                  )
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

      // Add headers if it's the start of a Surah
      if (versesList.isNotEmpty && versesList.first.verseNumber == 1) {
        pageContent.add(_buildSurahHeader(surahNumber));
        if (surahNumber != 1 && surahNumber != 9) {
          pageContent.add(_buildBismillah());
        }
      }

      // Collect all verses into a single list of text spans
      List<InlineSpan> textSpans = [];

      for (var v in versesList) {
        final verseKey = _verseKey(surahNumber, v.verseNumber);
        final isPlayingVerse = _playingVerseKey == verseKey;
        final isHighlightedVerse = _highlightedVerses.contains(verseKey);

        // Determine background color for highlights/audio
        Color bgColor = Colors.transparent;
        if (isPlayingVerse) {
          bgColor = Colors.green.withValues(alpha: 0.14);
        } else if (isHighlightedVerse) {
          bgColor = Colors.amber.withValues(alpha: 0.18);
        }

        final displayText =
            (v.verseNumber == 1 && surahNumber != 1 && surahNumber != 9)
            ? _stripBismillahPrefix(v.text)
            : v.text;

        if (displayText.trim().isNotEmpty) {
          // Add the actual Arabic verse text
          textSpans.add(
            TextSpan(
              text: '$displayText ',
              style: TextStyle(
                fontFamily: 'Uthmanic',
                fontSize: fontSize,
                height: 1.8,
                color: Colors.black87,
                backgroundColor: bgColor, // Highlight spans across line breaks
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  _showVerseQuickActions(
                    surahNumber: surahNumber,
                    verseNumber: v.verseNumber,
                    arabicText: v.text,
                  );
                },
            ),
          );

          // Add the Ayah end marker (the circle with the number)
          textSpans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: GestureDetector(
                onTap: () => _showVerseQuickActions(
                  surahNumber: surahNumber,
                  verseNumber: v.verseNumber,
                  arabicText: v.text,
                ),
                onLongPress: () => _handleVerseLongPress(
                  surahNumber: surahNumber,
                  verseNumber: v.verseNumber,
                ),
                child: Container(
                  color: bgColor,
                  child: _buildAyahEnd(v.verseNumber),
                ),
              ),
            ),
          );

          // Small space between verses
          textSpans.add(const TextSpan(text: ' '));
        }
      }

      // Wrap the entire Surah section in a single, justified text block
      pageContent.add(
        Directionality(
          textDirection: TextDirection.rtl,
          child: RichText(
            textAlign: TextAlign
                .justify, // <-- This creates the physical Mushaf block look
            text: TextSpan(children: textSpans),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: pageContent,
    );
  }

  Widget _buildTranslationMode(
    List<dynamic> pageData,
    double arabicSize,
    double transSize,
  ) {
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
              final verseKey = _verseKey(
                surahInPage.surahNumber!,
                v.verseNumber,
              );
              final isPlayingVerse = _playingVerseKey == verseKey;
              final isHighlightedVerse = _highlightedVerses.contains(verseKey);
              final translation = _getTranslationText(
                surahNumber: surahInPage.surahNumber!,
                verseNumber: v.verseNumber,
              );
              final displayText =
                  (v.verseNumber == 1 &&
                      surahInPage.surahNumber! != 1 &&
                      surahInPage.surahNumber! != 9)
                  ? _stripBismillahPrefix(v.text)
                  : v.text;

              if (displayText.trim().isEmpty) {
                return const SizedBox.shrink();
              }

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _handleVerseTap(
                  surahNumber: surahInPage.surahNumber!,
                  verseNumber: v.verseNumber,
                ),
                onLongPress: () => _handleVerseLongPress(
                  surahNumber: surahInPage.surahNumber!,
                  verseNumber: v.verseNumber,
                ),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 24.0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
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
                              text: '$displayText ',
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
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _isContinuousPlaybackActive
                                ? 'Continuous playback active... (long-press and choose Stop Continuous Play)'
                                : 'Playing verse audio... (long-press and choose Stop Audio)',
                            style: const TextStyle(
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
    final strings = AppStrings.of(context);
    double overallProgress = _currentPage / 604;
    final dailyTarget = _dailyTargetPages <= 0 ? 1.0 : _dailyTargetPages;
    final dailyProgress = (_pagesReadToday / dailyTarget).clamp(0.0, 1.0);
    final monthlyTarget = _rounds * 604;
    final monthlyProgress = monthlyTarget <= 0
        ? 0.0
        : (_pagesReadMonth / monthlyTarget).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 25),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_showAudioHint) ...[
            const Text(
              'Tip: Tap verse to play • Long-press ayah marker for options',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
          ],
          _buildProgressRow(
            'DAILY',
            dailyProgress,
            '$_pagesReadToday / ${dailyTarget.toStringAsFixed(1)}',
            action: (_returnReadingPage != null &&
                    _returnReadingPage != _currentPage)
                ? TextButton(
                    onPressed: _jumpToReadingPage,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.brown,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(strings.goToReading()),
                  )
                : null,
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

  Widget _buildProgressRow(
    String label,
    double value,
    String trailing, {
    Widget? action,
  }) {
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
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  trailing,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                if (action != null) ...[
                  const SizedBox(width: 6),
                  action,
                ],
              ],
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
    final strings = AppStrings.of(context);
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.brown),
            child: Center(
              child: Text(
                strings.surahIndex(),
                style: const TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.bookmark),
            title: Text(strings.goToBookmark()),
            subtitle: Text(
              _bookmarkedPage > 0
                  ? strings.pageLabel(_bookmarkedPage)
                  : strings.noBookmarkSaved(),
            ),
            onTap: _jumpToBookmark,
          ),
          ListTile(
            leading: const Icon(Icons.manage_search),
            title: Text(strings.goToPage()),
            subtitle: Text(strings.jumpToAnyPage()),
            onTap: _showPageSearchDialog,
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
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  title: Text(surah.name),
                  subtitle: Text(surah.nameEnglish),
                  onTap: () {
                    int startPage = Quran.getPageNumber(
                      surahNumber: index + 1,
                      verseNumber: 1,
                    );
                    _jumpToPage(startPage, captureReadingPage: true);
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
