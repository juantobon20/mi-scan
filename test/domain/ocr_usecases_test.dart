import 'package:flutter_test/flutter_test.dart';
import 'package:mi_scan/domain/entities/scan_page.dart';
import 'package:mi_scan/domain/services/text_recognizer.dart';
import 'package:mi_scan/domain/usecases/document_usecases.dart';

import '../helpers/fakes.dart';

void main() {
  late InMemoryDocumentRepository repo;
  late FakeTextRecognizer recognizer;
  late RecognizeDocumentText recognize;
  final doc = sampleDoc('Invoice', id: 'd1');
  const pages = [ScanPage('/p1.jpg', 10, 20), ScanPage('/p2.jpg', 10, 20), ScanPage('/p3.jpg', 10, 20)];

  setUp(() {
    repo = InMemoryDocumentRepository([doc]);
    recognizer = FakeTextRecognizer();
    recognize = RecognizeDocumentText(recognizer, repo);
  });

  group('RecognizeDocumentText', () {
    test('joins the text of every page, in order, separated by a blank line', () async {
      recognizer.texts.addAll({'/p1.jpg': 'Page one', '/p2.jpg': 'Page two', '/p3.jpg': 'Page three'});
      final outcome = await recognize(doc, pages);
      expect(repo.texts['d1'], 'Page one\n\nPage two\n\nPage three');
      expect(outcome.hasText, isTrue);
      expect(outcome.recognizedPages, 3);
      expect(outcome.failedPages, 0);
    });

    test('recognizes the pages one after another', () async {
      await recognize(doc, pages);
      expect(recognizer.recognized, ['/p1.jpg', '/p2.jpg', '/p3.jpg']);
    });

    test('trims each page and skips pages without text', () async {
      recognizer.texts.addAll({'/p1.jpg': '  first  \n', '/p2.jpg': '   ', '/p3.jpg': 'third'});
      await recognize(doc, pages);
      expect(repo.texts['d1'], 'first\n\nthird');
    });

    test('does not save anything when no page has text', () async {
      final outcome = await recognize(doc, pages);
      expect(repo.texts, isEmpty);
      expect(outcome.hasText, isFalse);
      expect(outcome.failedPages, 0);
    });

    test('a page that fails does not stop the others', () async {
      recognizer.texts.addAll({'/p1.jpg': 'one', '/p3.jpg': 'three'});
      recognizer.failing.add('/p2.jpg');
      final outcome = await recognize(doc, pages);
      expect(repo.texts['d1'], 'one\n\nthree');
      expect(outcome.failedPages, 1);
      expect(outcome.recognizedPages, 2);
    });

    test('reports every page as failed when none can be read', () async {
      recognizer.failing.addAll(pages.map((p) => p.path));
      final outcome = await recognize(doc, pages);
      expect(outcome.hasText, isFalse);
      expect(outcome.failedPages, 3);
      expect(repo.texts, isEmpty);
    });

    test('a document without pages has no text and fails nothing', () async {
      final outcome = await recognize(doc, const []);
      expect(outcome.hasText, isFalse);
      expect(outcome.recognizedPages, 0);
    });

    test('recognizing again replaces the previous text', () async {
      recognizer.texts['/p1.jpg'] = 'old';
      await recognize(doc, const [ScanPage('/p1.jpg', 1, 1)]);
      recognizer.texts['/p1.jpg'] = 'new';
      await recognize(doc, const [ScanPage('/p1.jpg', 1, 1)]);
      expect(repo.texts['d1'], 'new');
    });
  });

  group('GetDocumentText', () {
    test('returns the stored text', () async {
      repo.texts['d1'] = 'hello';
      expect(await GetDocumentText(repo)(doc), 'hello');
    });

    test('returns null when the document has no text', () async {
      expect(await GetDocumentText(repo)(doc), isNull);
    });
  });

  test('RecognizedText.isEmpty ignores whitespace', () {
    expect(const RecognizedText('  \n ').isEmpty, isTrue);
    expect(const RecognizedText(' a ').isEmpty, isFalse);
  });

  test('ScannedDocument keeps hasText when moved, renamed or copied', () {
    final withText = sampleDoc('A').withText(hasText: true);
    expect(withText.hasText, isTrue);
    expect(withText.movedTo('f').hasText, isTrue);
    expect(withText.copyWith(name: 'B').hasText, isTrue);
    expect(withText, isNot(sampleDoc('A')));
    expect(withText.withText(hasText: false), sampleDoc('A'));
  });
}
