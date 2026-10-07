import 'package:flutter_test/flutter_test.dart';
import 'package:mi_scan/domain/entities/document_query.dart';
import 'package:mi_scan/domain/entities/folder.dart';
import 'package:mi_scan/domain/entities/scan_page.dart';
import 'package:mi_scan/domain/repositories/document_repository.dart';
import 'package:mi_scan/domain/repositories/folder_repository.dart';
import 'package:mi_scan/domain/usecases/document_usecases.dart';
import 'package:mi_scan/domain/usecases/folder_usecases.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fakes.dart';

class MockDocuments extends Mock implements DocumentRepository {}

class MockFolders extends Mock implements FolderRepository {}

void main() {
  late MockDocuments repo;
  late MockFolders folderRepo;
  final doc = sampleDoc('A');
  final folder = Folder(id: 'f1', name: 'Work', createdAt: DateTime(2026, 1, 1));

  setUpAll(() => registerFallbackValue(const DocumentQuery()));

  setUp(() {
    repo = MockDocuments();
    folderRepo = MockFolders();
  });

  group('documents', () {
    test('ListDocuments passes the query to the repository', () async {
      const query = DocumentQuery(folderId: 'f1', text: 'inv');
      when(() => repo.list(query: query)).thenAnswer((_) async => [doc]);
      expect(await ListDocuments(repo)(query: query), [doc]);
    });

    test('ListDocuments defaults to every document', () async {
      when(() => repo.list(query: const DocumentQuery())).thenAnswer((_) async => [doc]);
      expect(await ListDocuments(repo)(), [doc]);
    });

    test('RenameDocument delegates with the new name', () async {
      when(() => repo.rename(doc, 'B')).thenAnswer((_) async => sampleDoc('B'));
      expect((await RenameDocument(repo)(doc, 'B')).name, 'B');
    });

    test('DeleteDocument delegates to the repository', () async {
      when(() => repo.delete(doc)).thenAnswer((_) async {});
      await DeleteDocument(repo)(doc);
      verify(() => repo.delete(doc)).called(1);
    });

    group('MoveDocument', () {
      test('moves the document to the folder', () async {
        when(() => repo.move(doc, 'f1')).thenAnswer((_) async => doc.movedTo('f1'));
        expect((await MoveDocument(repo)(doc, 'f1')).folderId, 'f1');
      });

      test('does not touch the repository when the folder does not change', () async {
        expect(await MoveDocument(repo)(doc, null), doc);
        verifyZeroInteractions(repo);
      });

      test('can take a document out of its folder', () async {
        final filed = doc.movedTo('f1');
        when(() => repo.move(filed, null)).thenAnswer((_) async => doc);
        expect((await MoveDocument(repo)(filed, null)).folderId, isNull);
      });
    });

    group('CreateDocument', () {
      const pages = [ScanPage('/a.jpg', 10, 20)];

      test('creates the document with the pages', () async {
        when(() => repo.createFromPages(pages, 'N', folderId: null)).thenAnswer((_) async => sampleDoc('N'));
        expect((await CreateDocument(repo)(pages, 'N')).name, 'N');
      });

      test('forwards the folder', () async {
        when(() => repo.createFromPages(pages, 'N', folderId: 'f1')).thenAnswer((_) async => sampleDoc('N'));
        await CreateDocument(repo)(pages, 'N', folderId: 'f1');
        verify(() => repo.createFromPages(pages, 'N', folderId: 'f1')).called(1);
      });

      test('rejects an empty page list without touching the repository', () {
        expect(() => CreateDocument(repo)([], 'N'), throwsArgumentError);
        verifyZeroInteractions(repo);
      });
    });
  });

  group('folders', () {
    test('ListFolders delegates to the repository', () async {
      when(() => folderRepo.list()).thenAnswer((_) async => [FolderSummary(folder, 2)]);
      expect((await ListFolders(folderRepo)()).single.documentCount, 2);
    });

    test('CreateFolder creates it', () async {
      when(() => folderRepo.create('Work')).thenAnswer((_) async => folder);
      expect(await CreateFolder(folderRepo)('Work'), folder);
    });

    test('CreateFolder rejects blank names', () {
      for (final name in ['', '   ', '\n']) {
        expect(() => CreateFolder(folderRepo)(name), throwsArgumentError);
      }
      verifyZeroInteractions(folderRepo);
    });

    test('RenameFolder renames it', () async {
      when(() => folderRepo.rename(folder, 'Office')).thenAnswer((_) async => folder.copyWith(name: 'Office'));
      expect((await RenameFolder(folderRepo)(folder, 'Office')).name, 'Office');
    });

    test('RenameFolder rejects blank names', () {
      expect(() => RenameFolder(folderRepo)(folder, '  '), throwsArgumentError);
      verifyZeroInteractions(folderRepo);
    });

    test('DeleteFolder delegates to the repository', () async {
      when(() => folderRepo.delete(folder)).thenAnswer((_) async {});
      await DeleteFolder(folderRepo)(folder);
      verify(() => folderRepo.delete(folder)).called(1);
    });
  });
}
