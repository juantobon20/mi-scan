import 'dart:io';

class Violation {
  const Violation(this.file, this.line, this.message);
  final String file;
  final int line;
  final String message;

  @override
  String toString() => '$file:$line: $message';
}

bool _isAllowedNonAscii(int rune) {
  if (rune < 128) return true;
  if (rune == 0xA1 || rune == 0xBF || rune == 0xAA || rune == 0xBA) return false;
  if (rune >= 0xA0 && rune <= 0xBF) return true;
  if (rune == 0xD7 || rune == 0xF7) return true;
  if (rune >= 0x2000 && rune <= 0x2BFF) return true;
  if (rune >= 0x2500 && rune <= 0x27BF) return true;
  if (rune >= 0x1F300 && rune <= 0x1FAFF) return true;
  return false;
}

final _wordPattern = RegExp(r'[A-Za-z]+');
final _camelBoundary = RegExp(r'(?<=[a-z])(?=[A-Z])');
final _urlPattern = RegExp(r'https?://\S+');

List<Violation> checkText(String file, String text, Set<String> spanishWords) {
  final violations = <Violation>[];
  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].replaceAll(_urlPattern, '');
    for (final rune in line.runes) {
      if (!_isAllowedNonAscii(rune)) {
        violations.add(Violation(file, i + 1, 'non-English character "${String.fromCharCode(rune)}"'));
        break;
      }
    }
    final seen = <String>{};
    for (final match in _wordPattern.allMatches(line)) {
      for (final part in match.group(0)!.split(_camelBoundary)) {
        final word = part.toLowerCase();
        if (spanishWords.contains(word) && seen.add(word)) {
          violations.add(Violation(file, i + 1, 'Spanish word "$word"'));
        }
      }
    }
  }
  return violations;
}

Set<String> loadSpanishWords(String path) => {
      for (final w in File(path).readAsLinesSync())
        if (w.trim().isNotEmpty) w.trim().toLowerCase(),
    };

List<String> defaultTargets() {
  const roots = ['lib', 'test', 'integration_test'];
  final files = <String>[];
  for (final root in roots) {
    final dir = Directory(root);
    if (!dir.existsSync()) continue;
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) files.add(entity.path);
    }
  }
  for (final doc in ['README.md', 'CHANGELOG.md', 'CLAUDE.md']) {
    if (File(doc).existsSync()) files.add(doc);
  }
  final workflows = Directory('.github');
  if (workflows.existsSync()) {
    for (final entity in workflows.listSync(recursive: true)) {
      if (entity is File && (entity.path.endsWith('.yml') || entity.path.endsWith('.md'))) {
        files.add(entity.path);
      }
    }
  }
  return files.where((f) => !_isExcluded(f)).toList();
}

bool _isExcluded(String path) => path.startsWith('tool/') || path.startsWith('test/tool/');

bool _isChecked(String path) {
  if (_isExcluded(path)) return false;
  return path.endsWith('.dart') || path.endsWith('.md') || path.endsWith('.yml');
}

void main(List<String> args) {
  final scriptDir = File(Platform.script.toFilePath()).parent.path;
  final words = loadSpanishWords('$scriptDir/spanish_words.txt');
  final targets = (args.isEmpty ? defaultTargets() : args.where(_isChecked)).toList();

  final violations = <Violation>[];
  for (final path in targets) {
    final file = File(path);
    if (!file.existsSync()) continue;
    violations.addAll(checkText(path, file.readAsStringSync(), words));
  }

  if (violations.isEmpty) {
    stdout.writeln('English check passed (${targets.length} files).');
    return;
  }
  stderr.writeln('English check failed: code, strings and docs must be in English.');
  violations.forEach(stderr.writeln);
  exit(1);
}
