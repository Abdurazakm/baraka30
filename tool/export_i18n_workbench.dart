import 'dart:convert';
import 'dart:io';

void main() {
  final projectRoot = Directory.current.path;
  final sourcePath = '$projectRoot/lib/services/app_language.dart';
  final sourceFile = File(sourcePath);

  if (!sourceFile.existsSync()) {
    stderr.writeln('Could not find app language source at: $sourcePath');
    exitCode = 1;
    return;
  }

  final source = sourceFile.readAsStringSync();
  final englishBlock = _extractLanguageBlock(source, 'english');
  final amharicBlock = _extractLanguageBlock(source, 'amharic');

  if (englishBlock == null || amharicBlock == null) {
    stderr.writeln(
      'Could not parse AppLanguage string maps from app_language.dart',
    );
    exitCode = 1;
    return;
  }

  final english = _parsePairs(englishBlock);
  final amharic = _parsePairs(amharicBlock);

  final keys = <String>{...english.keys, ...amharic.keys}.toList()..sort();

  final outDir = Directory('$projectRoot/assets/i18n');
  outDir.createSync(recursive: true);

  final rows = <Map<String, String>>[];
  for (final key in keys) {
    rows.add({
      'key': key,
      'english': english[key] ?? '',
      'amharic': amharic[key] ?? '',
      'translator_draft': '',
      'manual_review': '',
      'notes': '',
    });
  }

  final csvPath = '${outDir.path}/translation_workbench.csv';
  final jsonPath = '${outDir.path}/translation_workbench.json';

  File(csvPath).writeAsStringSync(_toCsv(rows));
  File(jsonPath).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({'rows': rows}),
  );

  stdout.writeln('Generated: $csvPath');
  stdout.writeln('Generated: $jsonPath');
  stdout.writeln('Total keys: ${keys.length}');
}

String? _extractLanguageBlock(String source, String languageName) {
  final marker = 'AppLanguage.$languageName: {';
  final start = source.indexOf(marker);
  if (start == -1) {
    return null;
  }

  var index = start + marker.length;
  var depth = 1;
  while (index < source.length) {
    final char = source[index];
    if (char == '{') {
      depth++;
    } else if (char == '}') {
      depth--;
      if (depth == 0) {
        return source.substring(start + marker.length, index);
      }
    }
    index++;
  }

  return null;
}

Map<String, String> _parsePairs(String block) {
  final result = <String, String>{};
  final pair = RegExp(
    r"'((?:\\.|[^'])*)'\s*:\s*'((?:\\.|[^'])*)'",
    multiLine: true,
  );

  for (final match in pair.allMatches(block)) {
    final key = _unescape(match.group(1) ?? '');
    final value = _unescape(match.group(2) ?? '');
    result[key] = value;
  }

  return result;
}

String _unescape(String value) {
  return value
      .replaceAll(r"\'", "'")
      .replaceAll(r'\\n', '\n')
      .replaceAll(r'\\t', '\t')
      .replaceAll(r'\\r', '\r')
      .replaceAll(r'\\\\', r'\\');
}

String _escapeCsv(String value) {
  final normalized = value.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final escaped = normalized.replaceAll('"', '""');
  return '"$escaped"';
}

String _toCsv(List<Map<String, String>> rows) {
  const headers = [
    'key',
    'english',
    'amharic',
    'translator_draft',
    'manual_review',
    'notes',
  ];

  final buffer = StringBuffer();
  buffer.writeln(headers.map(_escapeCsv).join(','));

  for (final row in rows) {
    final fields = headers.map((h) => _escapeCsv(row[h] ?? '')).join(',');
    buffer.writeln(fields);
  }

  return buffer.toString();
}
