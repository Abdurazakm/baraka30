import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class TranslationOption {
  const TranslationOption({required this.key, required this.label});

  final String key;
  final String label;
}

class ReciterOption {
  const ReciterOption({required this.key, required this.label, required this.baseUrl});

  final String key;
  final String label;
  final String baseUrl;
}

class OfflineQuranService {
  static const String defaultTranslationKey = 'english_saheeh';
  static const String defaultReciterKey = 'alafasy_128kbps';

  static const List<TranslationOption> translationOptions = [
    TranslationOption(key: 'english_saheeh', label: 'English - Saheeh International'),
    TranslationOption(key: 'english_qaribullah', label: 'English - Qaribullah'),
    TranslationOption(key: 'urdu_junagarhi', label: 'Urdu - Junagarhi'),
    TranslationOption(key: 'french_hamidullah', label: 'French - Hamidullah'),
    TranslationOption(key: 'somali_abdallah', label: 'Somali - Abdallah'),
  ];

  static const List<ReciterOption> reciterOptions = [
    ReciterOption(
      key: 'alafasy_128kbps',
      label: 'Alafasy (128 kbps)',
      baseUrl: 'https://everyayah.com/data/Alafasy_128kbps',
    ),
  ];

  static const String _quranEncBaseUrl = 'https://quranenc.com/api/v1/translation/sura';
  static const String _rootFolder = 'offline_quran';

  final http.Client _client;

  OfflineQuranService({http.Client? client}) : _client = client ?? http.Client();

  Future<Directory> _baseDir() async {
    if (kIsWeb) {
      throw UnsupportedError('Offline downloads are not supported on web.');
    }
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/$_rootFolder');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _translationFile(String key, int surah) async {
    final dir = Directory('${(await _baseDir()).path}/translations/$key');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File('${dir.path}/surah_$surah.json');
  }

  Future<File> _audioFile(String reciterKey, int surah, int ayah) async {
    final dir = Directory('${(await _baseDir()).path}/audio/$reciterKey/surah_$surah');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File('${dir.path}/ayah_$ayah.mp3');
  }

  Future<bool> translationExists(String key, int surah) async {
    if (kIsWeb) {
      return false;
    }
    final file = await _translationFile(key, surah);
    return file.exists();
  }

  Future<bool> audioExists(String reciterKey, int surah, int ayah) async {
    if (kIsWeb) {
      return false;
    }
    final file = await _audioFile(reciterKey, surah, ayah);
    return file.exists();
  }

  Future<void> downloadTranslationSurah({
    required String key,
    required int surah,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('Offline downloads are not supported on web.');
    }
    final url = Uri.parse('$_quranEncBaseUrl/$key/$surah');
    final response = await _client.get(url);
    if (response.statusCode != 200) {
      throw HttpException('Translation download failed (${response.statusCode}).');
    }
    final file = await _translationFile(key, surah);
    await file.writeAsBytes(response.bodyBytes, flush: true);
  }

  Future<void> downloadAudioSurah({
    required String reciterKey,
    required int surah,
    required int verseCount,
    ValueChanged<double>? onProgress,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('Offline downloads are not supported on web.');
    }
    final reciter = reciterOptions.firstWhere((r) => r.key == reciterKey);
    final paddedSurah = surah.toString().padLeft(3, '0');

    for (int ayah = 1; ayah <= verseCount; ayah++) {
      final paddedAyah = ayah.toString().padLeft(3, '0');
      final url = Uri.parse('${reciter.baseUrl}/$paddedSurah$paddedAyah.mp3');
      final response = await _client.get(url);
      if (response.statusCode != 200) {
        throw HttpException('Audio download failed (${response.statusCode}) for $surah:$ayah.');
      }
      final file = await _audioFile(reciterKey, surah, ayah);
      await file.writeAsBytes(response.bodyBytes, flush: true);
      if (onProgress != null) {
        onProgress(ayah / verseCount);
      }
    }
  }

  Future<Map<int, String>> loadTranslationMap({
    required String key,
    required int surah,
  }) async {
    if (kIsWeb) {
      return <int, String>{};
    }
    final file = await _translationFile(key, surah);
    if (!await file.exists()) {
      return <int, String>{};
    }

    final raw = await file.readAsString();
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final result = decoded['result'] as List<dynamic>? ?? const [];
    final Map<int, String> map = {};
    for (final entry in result) {
      final row = entry as Map<String, dynamic>;
      final aya = int.tryParse(row['aya'].toString()) ?? 0;
      if (aya <= 0) {
        continue;
      }
      map[aya] = row['translation']?.toString() ?? '';
    }
    return map;
  }

  Future<File?> getOfflineAudioFile({
    required String reciterKey,
    required int surah,
    required int ayah,
  }) async {
    if (kIsWeb) {
      return null;
    }
    final file = await _audioFile(reciterKey, surah, ayah);
    if (!await file.exists()) {
      return null;
    }
    return file;
  }

  Future<void> clearTranslations(String key) async {
    if (kIsWeb) {
      return;
    }
    final dir = Directory('${(await _baseDir()).path}/translations/$key');
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  Future<void> clearAudio(String reciterKey) async {
    if (kIsWeb) {
      return;
    }
    final dir = Directory('${(await _baseDir()).path}/audio/$reciterKey');
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}
