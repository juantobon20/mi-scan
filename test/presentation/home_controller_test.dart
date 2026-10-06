import 'package:flutter_test/flutter_test.dart';
import 'package:mi_scan/domain/repositories/document_repository.dart';
import 'package:mi_scan/domain/usecases/document_usecases.dart';
import 'package:mi_scan/presentation/home/home_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fakes.dart';

class MockRepo extends Mock implements DocumentRepository {}

void main() {
  late MockRepo repo;
  late FakeShareService share;
  late HomeController ctrl;
  final a = sampleDoc('A'), b = sampleDoc('B');

  setUp(() {
    repo = MockRepo();
    share = FakeShareService();
    ctrl = HomeController(
      listDocuments: ListDocuments(repo),
      renameDocument: RenameDocument(repo),
      deleteDocument: DeleteDocument(repo),
      shareService: share,
    );
  });

  test('initial state: documents is null (loading)', () {
    expect(ctrl.documents, isNull);
  });

  test('load publishes the documents and notifies', () async {
    when(() => repo.list()).thenAnswer((_) async => [a, b]);
    var n = 0;
    ctrl.addListener(() => n++);
    await ctrl.load();
    expect(ctrl.documents, [a, b]);
    expect(ctrl.error, isNull);
    expect(n, 1);
  });

  test('load with an error leaves an empty list and exposes the error', () async {
    when(() => repo.list()).thenThrow(Exception('boom'));
    await ctrl.load();
    expect(ctrl.documents, isEmpty);
    expect(ctrl.error, isA<Exception>());
  });

  test('a later failure keeps the previous list', () async {
    when(() => repo.list()).thenAnswer((_) async => [a]);
    await ctrl.load();
    when(() => repo.list()).thenThrow(Exception('boom'));
    await ctrl.load();
    expect(ctrl.documents, [a]);
    expect(ctrl.error, isNotNull);
  });

  test('rename and delete reload the list', () async {
    when(() => repo.list()).thenAnswer((_) async => [a]);
    when(() => repo.rename(a, 'Z')).thenAnswer((_) async => sampleDoc('Z'));
    when(() => repo.delete(a)).thenAnswer((_) async {});
    await ctrl.rename(a, 'Z');
    await ctrl.delete(a);
    verify(() => repo.rename(a, 'Z')).called(1);
    verify(() => repo.delete(a)).called(1);
    verify(() => repo.list()).called(2);
  });

  test('share sends the PDF path', () async {
    await ctrl.share(a);
    expect(share.shared, [a.pdfPath]);
  });

  test('does not notify after dispose', () async {
    when(() => repo.list()).thenAnswer((_) async => [a]);
    final f = ctrl.load();
    ctrl.dispose();
    await f;
  });
}
