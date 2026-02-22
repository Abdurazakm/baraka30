import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:quran_flutter/quran_flutter.dart';

import '../services/offline_quran_service.dart';

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

    if (_isWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Offline downloads are not supported on web.'),
        ),
      );
      return;
    }

    final surahs = _getSelectedSurahs();
    if (surahs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one surah or juz.')),
      );
      return;
    }

    final translations = _selectedTranslations.isEmpty
        ? <String>[_activeTranslationKey]
        : _selectedTranslations.toList();

    setState(() {
      _isBusy = true;
      _status = 'Starting downloads...';
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
              () => _status = 'Downloading translation $key (Surah $surah)...',
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
          setState(() => _status = 'Downloading audio (Surah $surah)...');
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
      ).showSnackBar(const SnackBar(content: Text('Downloads complete.')));
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Download failed: $error')));
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Download Scope',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        SegmentedButton<DownloadScope>(
          segments: const [
            ButtonSegment(value: DownloadScope.surah, label: Text('Surah')),
            ButtonSegment(value: DownloadScope.juz, label: Text('Juz')),
            ButtonSegment(value: DownloadScope.all, label: Text('All')),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Surahs',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select Juz', style: TextStyle(fontWeight: FontWeight.w600)),
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
                title: Text('Juz $juz'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Translations',
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
          decoration: const InputDecoration(labelText: 'Default translation'),
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
          title: const Text('Use downloaded translations'),
          value: _useDownloadedTranslations,
          onChanged: (value) =>
              setState(() => _useDownloadedTranslations = value),
        ),
      ],
    );
  }

  Widget _buildReciterSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Audio', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _activeReciterKey,
          decoration: const InputDecoration(labelText: 'Reciter'),
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
          title: const Text('Use downloaded audio when available'),
          value: _useDownloadedAudio,
          onChanged: (value) => setState(() => _useDownloadedAudio = value),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Offline Downloads')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_isWeb)
              Card(
                color: Colors.orange.withValues(alpha: 0.1),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Offline downloads are not available on Web. '
                    'Use mobile or desktop builds for offline storage.',
                  ),
                ),
              ),
            _buildScopeSelector(),
            const SizedBox(height: 16),
            if (_scope == DownloadScope.surah) _buildSurahList(),
            if (_scope == DownloadScope.juz) _buildJuzList(),
            if (_scope == DownloadScope.all)
              const Text(
                'All surahs will be downloaded.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Download translations'),
              value: _downloadTranslations,
              onChanged: _isWeb
                  ? null
                  : (value) => setState(() => _downloadTranslations = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Download audio'),
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
              label: const Text('Start Download'),
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
