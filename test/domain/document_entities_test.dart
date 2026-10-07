import 'package:flutter_test/flutter_test.dart';
import 'package:mi_scan/domain/entities/document_query.dart';
import 'package:mi_scan/domain/entities/folder.dart';

import '../helpers/fakes.dart';

void main() {
  group('ScannedDocument', () {
    final doc = sampleDoc('Doc', folderId: 'f1', pageCount: 3);

    test('movedTo changes only the folder', () {
      final moved = doc.movedTo('f2');
      expect(moved.folderId, 'f2');
      expect(moved.id, doc.id);
      expect(moved.name, doc.name);
      expect(moved.pageCount, 3);
    });

    test('movedTo(null) takes the document out of its folder', () {
      expect(doc.movedTo(null).folderId, isNull);
    });

    test('copyWith changes name and paths and keeps the rest', () {
      final copy = doc.copyWith(name: 'New', pdfPath: '/x/New.pdf', thumbPath: '/x/New.pdf.jpg');
      expect(copy.name, 'New');
      expect(copy.pdfPath, '/x/New.pdf');
      expect(copy.folderId, 'f1');
      expect(copy.pageCount, 3);
      expect(copy.id, doc.id);
    });

    test('copyWith keeps the thumbnail unless told to clear it', () {
      final withThumb = doc.copyWith(thumbPath: '/t.jpg');
      expect(withThumb.copyWith(name: 'x').thumbPath, '/t.jpg');
      expect(withThumb.copyWith(clearThumb: true).thumbPath, isNull);
    });

    test('equality compares every field', () {
      expect(sampleDoc('Doc', folderId: 'f1', pageCount: 3), doc);
      expect(sampleDoc('Doc', folderId: 'f2', pageCount: 3), isNot(doc));
      expect(sampleDoc('Doc', folderId: 'f1', pageCount: 4), isNot(doc));
      expect(sampleDoc('Doc', folderId: 'f1', pageCount: 3).hashCode, doc.hashCode);
    });
  });

  group('Folder', () {
    final folder = Folder(id: 'f', name: 'Work', createdAt: DateTime(2026));

    test('copyWith renames', () {
      expect(folder.copyWith(name: 'Home').name, 'Home');
      expect(folder.copyWith(name: 'Home').id, 'f');
    });

    test('equality and hash', () {
      expect(Folder(id: 'f', name: 'Work', createdAt: DateTime(2026)), folder);
      expect(FolderSummary(folder, 2), FolderSummary(folder, 2));
      expect(FolderSummary(folder, 2), isNot(FolderSummary(folder, 3)));
      expect(FolderSummary(folder, 2).hashCode, FolderSummary(folder, 2).hashCode);
    });
  });

  group('DocumentQuery', () {
    test('is empty by default', () {
      const query = DocumentQuery();
      expect(query.folderId, isNull);
      expect(query.hasText, isFalse);
    });

    test('whitespace is not text', () {
      expect(const DocumentQuery(text: '   ').hasText, isFalse);
      expect(const DocumentQuery(text: ' a ').hasText, isTrue);
    });

    test('copyWith can set and clear the folder independently of the text', () {
      const query = DocumentQuery(folderId: 'f', text: 'abc');
      expect(query.copyWith(text: 'x').folderId, 'f');
      expect(query.copyWith(clearFolder: true).folderId, isNull);
      expect(query.copyWith(clearFolder: true).text, 'abc');
      expect(query.copyWith(folderId: 'g').text, 'abc');
    });

    test('equality', () {
      expect(const DocumentQuery(folderId: 'f', text: 'a'), const DocumentQuery(folderId: 'f', text: 'a'));
      expect(const DocumentQuery(folderId: 'f'), isNot(const DocumentQuery()));
    });
  });
}
