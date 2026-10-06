import 'package:flutter_test/flutter_test.dart';
import 'package:mi_scan/domain/entities/scan_page.dart';
import 'package:mi_scan/domain/repositories/document_repository.dart';
import 'package:mi_scan/domain/usecases/document_usecases.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fakes.dart';

class MockRepo extends Mock implements DocumentRepository {}

void main() {
  late MockRepo repo;
  final doc = sampleDoc('A');

  setUp(() => repo = MockRepo());

  test('ListDocuments delegates to the repository', () async {
    when(() => repo.list()).thenAnswer((_) async => [doc]);
    expect(await ListDocuments(repo)(), [doc]);
  });

  test('RenameDocument delegates with the new name', () async {
    when(() => repo.rename(doc, 'B')).thenAnswer((_) async => sampleDoc('B'));
    expect((await RenameDocument(repo)(doc, 'B')).name, 'B');
    verify(() => repo.rename(doc, 'B')).called(1);
  });

  test('DeleteDocument delegates to the repository', () async {
    when(() => repo.delete(doc)).thenAnswer((_) async {});
    await DeleteDocument(repo)(doc);
    verify(() => repo.delete(doc)).called(1);
  });

  group('CreateDocument', () {
    test('creates the document with the pages', () async {
      const pages = [ScanPage('/a.jpg', 10, 20)];
      when(() => repo.createFromPages(pages, 'N')).thenAnswer((_) async => sampleDoc('N'));
      expect((await CreateDocument(repo)(pages, 'N')).name, 'N');
    });

    test('rejects an empty page list without touching the repository', () {
      expect(() => CreateDocument(repo)([], 'N'), throwsArgumentError);
      verifyZeroInteractions(repo);
    });
  });
}
