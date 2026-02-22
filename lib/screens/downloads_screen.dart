import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:quran_flutter/quran_flutter.dart';

import '../services/offline_quran_service.dart';
import '../services/app_language.dart';

enum DownloadScope { surah, juz, all }

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  static const String translationKeyPref = 'offline_translation_key';
  static const String reciterKeyPref = 'offline_reciter_key';
  static const String useDownloadedTranslationPref =
      'use_downloaded_translation';
  static const String useDownloadedAudioPref = 'use_downloaded_audio';

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  final OfflineQuranService _service = OfflineQuranService();
  late final List<Surah> _surahList;
  final bool _isWeb = kIsWeb;

  final Set<int> _selectedSurahs = <int>{};
  final Set<int> _selectedJuz = <int>{};
  final Set<String> _selectedTranslations = <String>{};

  bool _downloadTranslations = true;
  bool _downloadAudio = false;
  bool _useDownloadedTranslations = false;
  bool _useDownloadedAudio = false;
  bool _isBusy = false;

  String _activeTranslationKey = OfflineQuranService.defaultTranslationKey;
  String _activeReciterKey = OfflineQuranService.defaultReciterKey;
  DownloadScope _scope = DownloadScope.surah;

  String _status = '';
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _surahList = Quran.getSurahAsList();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _activeTranslationKey =
          prefs.getString(DownloadsScreen.translationKeyPref) ??
          OfflineQuranService.defaultTranslationKey;
      _activeReciterKey =
          prefs.getString(DownloadsScreen.reciterKeyPref) ??
          OfflineQuranService.defaultReciterKey;
      _useDownloadedTranslations = _isWeb
          ? false
          : (prefs.getBool(DownloadsScreen.useDownloadedTranslationPref) ??
                false);
      _useDownloadedAudio = _isWeb
          ? false
          : (prefs.getBool(DownloadsScreen.useDownloadedAudioPref) ?? false);
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      DownloadsScreen.translationKeyPref,
      _activeTranslationKey,
    );
    await prefs.setString(DownloadsScreen.reciterKeyPref, _activeReciterKey);
    await prefs.setBool(
      DownloadsScreen.useDownloadedTranslationPref,
      _useDownloadedTranslations,
    );
    await prefs.setBool(
      DownloadsScreen.useDownloadedAudioPref,
      _useDownloadedAudio,
    );
  }

  List<int> _getSelectedSurahs() {
    if (_scope == DownloadScope.all) {
      return _surahList.map((s) => s.number).toList();
    }
    if (_scope == DownloadScope.juz) {
      final Set<int> surahs = <int>{};
      for (final juz in _selectedJuz) {
        final juzSurahs = Quran.getSurahVersesInJuzAsList(juz);
        for (final entry in juzSurahs) {
          surahs.add(entry.surahNumber);
        }
      }
      return surahs.toList()..sort();
    }
    return _selectedSurahs.toList()..sort();
  }

  Future<void> _startDownload() async {
    if (_isBusy) {
      return;
    }

    final strings = AppStrings.of(context);

    if (_isWeb) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.offlineNotSupportedWeb())));
      return;
    }

    final surahs = _getSelectedSurahs();
    if (surahs.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.selectAtLeastOne())));
      return;
    }

    final translations = _selectedTranslations.isEmpty
        ? <String>[_activeTranslationKey]
        : _selectedTranslations.toList();

    setState(() {
      _isBusy = true;
      _status = strings.startingDownloads();
      _progress = 0;
    });

    try {
      int totalSteps = 0;
      if (_downloadTranslations) {
        totalSteps += translations.length * surahs.length;
      }
      if (_downloadAudio) {
        totalSteps += surahs.length;
      }

      int completedSteps = 0;

      if (_downloadTranslations) {
        for (final key in translations) {
          for (final surah in surahs) {
            setState(
              () => _status = strings.downloadingTranslation(key, surah),
            );
            await _service.downloadTranslationSurah(key: key, surah: surah);
            completedSteps++;
            setState(() => _progress = completedSteps / totalSteps);
          }
        }
      }

      if (_downloadAudio) {
        for (final surah in surahs) {
          final verseCount = _surahList
              .firstWhere((s) => s.number == surah)
              .verseCount;
          setState(() => _status = strings.downloadingAudio(surah));
          await _service.downloadAudioSurah(
            reciterKey: _activeReciterKey,
            surah: surah,
            verseCount: verseCount,
            onProgress: (value) {
              setState(() => _progress = (completedSteps + value) / totalSteps);
            },
          );
          completedSteps++;
          setState(() => _progress = completedSteps / totalSteps);
        }
      }

      await _savePrefs();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.downloadsComplete())));
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.downloadFailed('$error'))));
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _status = '';
        });
      }
    }
  }

  Widget _buildScopeSelector() {
    final strings = AppStrings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.downloadScope(),
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        SegmentedButton<DownloadScope>(
          segments: [
            ButtonSegment(
              value: DownloadScope.surah,
              label: Text(strings.scopeSurah()),
            ),
            ButtonSegment(
              value: DownloadScope.juz,
              label: Text(strings.scopeJuz()),
            ),
            ButtonSegment(
              value: DownloadScope.all,
              label: Text(strings.scopeAll()),
            ),
          ],
          selected: {_scope},
          onSelectionChanged: (value) {
            setState(() {
              _scope = value.first;
            });
          },
        ),
      ],
    );
  }

  Widget _buildSurahList() {
    final strings = AppStrings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.selectSurahs(),
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 220,
          child: ListView.builder(
            itemCount: _surahList.length,
            itemBuilder: (context, index) {
              final surah = _surahList[index];
              final selected = _selectedSurahs.contains(surah.number);
              return CheckboxListTile(
                value: selected,
                title: Text('${surah.number}. ${surah.nameEnglish}'),
                subtitle: Text(surah.name),
                dense: true,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedSurahs.add(surah.number);
                    } else {
                      _selectedSurahs.remove(surah.number);
                    }
                  });
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildJuzList() {
    final strings = AppStrings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.selectJuz(),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: ListView.builder(
            itemCount: 30,
            itemBuilder: (context, index) {
              final juz = index + 1;
              final selected = _selectedJuz.contains(juz);
              return CheckboxListTile(
                value: selected,
                title: Text(strings.juzLabel(juz)),
                dense: true,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedJuz.add(juz);
                    } else {
                      _selectedJuz.remove(juz);
                    }
                  });
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTranslationSelector() {
    final strings = AppStrings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.translations(),
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: OfflineQuranService.translationOptions.map((option) {
            final selected = _selectedTranslations.contains(option.key);
            return FilterChip(
              label: Text(option.label),
              selected: selected,
              onSelected: (value) {
                setState(() {
                  if (value) {
                    _selectedTranslations.add(option.key);
                  } else {
                    _selectedTranslations.remove(option.key);
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _activeTranslationKey,
          decoration: InputDecoration(labelText: strings.defaultTranslation()),
          items: OfflineQuranService.translationOptions
              .map(
                (option) => DropdownMenuItem(
                  value: option.key,
                  child: Text(option.label),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) {
              return;
            }
            setState(() => _activeTranslationKey = value);
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(strings.useDownloadedTranslations()),
          value: _useDownloadedTranslations,
          onChanged: (value) =>
              setState(() => _useDownloadedTranslations = value),
        ),
      ],
    );
  }

  Widget _buildReciterSelector() {
    final strings = AppStrings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.audio(),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _activeReciterKey,
          decoration: InputDecoration(labelText: strings.reciter()),
          items: OfflineQuranService.reciterOptions
              .map(
                (option) => DropdownMenuItem(
                  value: option.key,
                  child: Text(option.label),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) {
              return;
            }
            setState(() => _activeReciterKey = value);
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(strings.useDownloadedAudio()),
          value: _useDownloadedAudio,
          onChanged: (value) => setState(() => _useDownloadedAudio = value),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.offlineDownloads())),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_isWeb)
              Card(
                color: Colors.orange.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(strings.offlineNotAvailableWeb()),
                ),
              ),
            _buildScopeSelector(),
            const SizedBox(height: 16),
            if (_scope == DownloadScope.surah) _buildSurahList(),
            if (_scope == DownloadScope.juz) _buildJuzList(),
            if (_scope == DownloadScope.all)
              Text(
                strings.allSurahsDownloaded(),
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(strings.downloadTranslations()),
              value: _downloadTranslations,
              onChanged: _isWeb
                  ? null
                  : (value) => setState(() => _downloadTranslations = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(strings.downloadAudio()),
              value: _downloadAudio,
              onChanged: _isWeb
                  ? null
                  : (value) => setState(() => _downloadAudio = value),
            ),
            const SizedBox(height: 12),
            if (_downloadTranslations) _buildTranslationSelector(),
            const SizedBox(height: 12),
            if (_downloadAudio) _buildReciterSelector(),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isBusy || _isWeb ? null : _startDownload,
              icon: const Icon(Icons.download),
              label: Text(strings.startDownload()),
            ),
            if (_isBusy) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: _progress == 0 ? null : _progress),
              const SizedBox(height: 8),
              Text(_status),
            ],
          ],
        ),
      ),
    );
  }
}
