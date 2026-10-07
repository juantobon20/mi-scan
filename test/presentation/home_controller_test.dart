import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_scan/domain/entities/document_query.dart';
import 'package:mi_scan/domain/entities/folder.dart';
import 'package:mi_scan/domain/entities/scanned_document.dart';
import 'package:mi_scan/presentation/home/home_controller.dart';

import '../helpers/fakes.dart';
import '../helpers/pump_helpers.dart';

class _GatedDocuments extends InMemoryDocumentRepository {
  _GatedDocuments(super.initial);
  final gates = <Completer<void>>[];

  @override
  Future<List<ScannedDocument>> list({DocumentQuery query = const DocumentQuery()}) async {
    final gate = Completer<void>();
    gates.add(gate);
    final result = await super.list(query: query);
    await gate.future;
    return result;
  }
}

void main() {
  late InMemoryDocumentRepository docs;
  late InMemoryFolderRepository folders;
  late FakeShareService share;
  late HomeController ctrl;

  final invoice = sampleDoc('Invoice March');
  final contract = sampleDoc('Contract');
  final receipt = sampleDoc('Receipt');
  final work = Folder(id: 'work', name: 'Work', createdAt: DateTime(2026, 1, 1));

  setUp(() {
    docs = InMemoryDocumentRepository([invoice, contract, receipt]);
    folders = InMemoryFolderRepository(docs, [work]);
    share = FakeShareService();
    ctrl = makeHomeController(documents: docs, folders: folders, share: share);
  });

  tearDown(() => ctrl.dispose());

  test('starts without documents (loading)', () {
    expect(ctrl.documents, isNull);
    expect(ctrl.folders, isEmpty);
  });

  group('load', () {
    test('publishes documents and folders and notifies', () async {
      var notifications = 0;
      ctrl.addListener(() => notifications++);
      await ctrl.load();
      expect(ctrl.documents, [invoice, contract, receipt]);
      expect(ctrl.folders.map((s) => s.folder), [work]);
      expect(ctrl.error, isNull);
      expect(notifications, 1);
    });

    test('an error leaves an empty list and exposes the error', () async {
      docs.listError = Exception('boom');
      await ctrl.load();
      expect(ctrl.documents, isEmpty);
      expect(ctrl.error, isA<Exception>());
    });

    test('a later failure keeps the previous list', () async {
      await ctrl.load();
      docs.listError = Exception('boom');
      await ctrl.load();
      expect(ctrl.documents, hasLength(3));
      expect(ctrl.error, isNotNull);
    });

    test('an older slow response never overwrites a newer one', () async {
      final gated = _GatedDocuments([invoice, contract]);
      ctrl = makeHomeController(documents: gated, folders: InMemoryFolderRepository(gated));
      final first = ctrl.load();
      await Future<void>.delayed(Duration.zero);
      ctrl.setSearchText('contract');
      final second = ctrl.selectFolder(null);
      await Future<void>.delayed(Duration.zero);
      gated.gates.last.complete();
      await second;
      gated.gates.first.complete();
      await first;
      expect(ctrl.documents!.map((d) => d.name), ['Contract']);
    });
  });

  group('search', () {
    test('filters by name once the typing pauses', () async {
      await ctrl.load();
      ctrl.setSearchText('contr');
      expect(ctrl.documents, hasLength(3));
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(ctrl.documents!.map((d) => d.name), ['Contract']);
      expect(ctrl.isSearching, isTrue);
    });

    test('typing quickly triggers a single search', () async {
      await ctrl.load();
      docs.queries.clear();
      for (final text in ['i', 'in', 'inv', 'invo']) {
        ctrl.setSearchText(text);
      }
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(docs.queries, hasLength(1));
      expect(docs.queries.single.text, 'invo');
    });

    test('ignores case and accents', () async {
      docs.docs.add(sampleDoc('Declaraci\u00f3n de renta'));
      await ctrl.load();
      ctrl.setSearchText('DECLARACION');
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(ctrl.documents!.map((d) => d.name), ['Declaraci\u00f3n de renta']);
    });

    test('every word must match', () async {
      await ctrl.load();
      ctrl.setSearchText('invoice march');
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(ctrl.documents, hasLength(1));
      ctrl.setSearchText('invoice april');
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(ctrl.documents, isEmpty);
    });

    test('clearSearch restores the list right away', () async {
      await ctrl.load();
      ctrl.setSearchText('receipt');
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await ctrl.clearSearch();
      expect(ctrl.documents, hasLength(3));
      expect(ctrl.isSearching, isFalse);
      expect(ctrl.searchText, '');
    });

    test('the same text does not search again', () async {
      await ctrl.load();
      ctrl.setSearchText('inv');
      await Future<void>.delayed(const Duration(milliseconds: 60));
      docs.queries.clear();
      ctrl.setSearchText('inv');
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(docs.queries, isEmpty);
    });

    test('a pending search is dropped when the controller is disposed', () async {
      await ctrl.load();
      docs.queries.clear();
      ctrl.setSearchText('inv');
      ctrl.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(docs.queries, isEmpty);
      ctrl = makeHomeController(documents: docs, folders: folders);
    });
  });

  group('folders', () {
    test('selecting a folder shows only its documents', () async {
      docs.docs[0] = invoice.movedTo('work');
      await ctrl.load();
      await ctrl.selectFolder('work');
      expect(ctrl.documents!.map((d) => d.name), ['Invoice March']);
      expect(ctrl.selectedFolder, work);
      await ctrl.selectFolder(null);
      expect(ctrl.documents, hasLength(3));
      expect(ctrl.selectedFolder, isNull);
    });

    test('search is applied inside the selected folder', () async {
      docs.docs[0] = invoice.movedTo('work');
      docs.docs[1] = contract.movedTo('work');
      await ctrl.load();
      await ctrl.selectFolder('work');
      ctrl.setSearchText('contract');
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(ctrl.documents!.map((d) => d.name), ['Contract']);
    });

    test('createFolder returns the folder and refreshes the list of folders', () async {
      await ctrl.load();
      final folder = await ctrl.createFolder('  Taxes ');
      expect(folder.name, 'Taxes');
      expect(ctrl.folders.map((s) => s.folder.name), containsAll(['Taxes', 'Work']));
    });

    test('renameFolder updates the name', () async {
      await ctrl.load();
      await ctrl.renameFolder(work, 'Office');
      expect(ctrl.folders.single.folder.name, 'Office');
    });

    test('deleting the selected folder goes back to All and keeps the documents', () async {
      docs.docs[0] = invoice.movedTo('work');
      await ctrl.load();
      await ctrl.selectFolder('work');
      await ctrl.deleteFolder(work);
      expect(ctrl.selectedFolderId, isNull);
      expect(ctrl.folders, isEmpty);
      expect(ctrl.documents, hasLength(3));
    });

    test('deleting another folder keeps the current selection', () async {
      final other = await folders.create('Other');
      await ctrl.load();
      await ctrl.selectFolder('work');
      await ctrl.deleteFolder(other);
      expect(ctrl.selectedFolderId, 'work');
    });

    test('folder counts follow the documents', () async {
      await ctrl.load();
      expect(ctrl.folders.single.documentCount, 0);
      await ctrl.moveDocument(invoice, 'work');
      expect(ctrl.folders.single.documentCount, 1);
    });

    test('a selected folder that disappeared falls back to All', () async {
      await ctrl.load();
      await ctrl.selectFolder('work');
      folders.folders.clear();
      await ctrl.load();
      expect(ctrl.selectedFolderId, isNull);
      expect(ctrl.documents, hasLength(3));
    });
  });

  group('documents', () {
    test('move changes the folder', () async {
      await ctrl.load();
      await ctrl.moveDocument(contract, 'work');
      expect(docs.docs.firstWhere((d) => d.id == contract.id).folderId, 'work');
    });

    test('moving to the same folder does nothing', () async {
      await ctrl.load();
      await ctrl.moveDocument(contract, null);
      expect(docs.docs.firstWhere((d) => d.id == contract.id).folderId, isNull);
    });

    test('rename and delete reload the list', () async {
      await ctrl.load();
      await ctrl.rename(contract, 'Deal');
      expect(ctrl.documents!.map((d) => d.name), contains('Deal'));
      await ctrl.delete(invoice);
      expect(ctrl.documents!.map((d) => d.name), isNot(contains('Invoice March')));
    });

    test('a scanned document lands in the selected folder', () async {
      await ctrl.load();
      await ctrl.selectFolder('work');
      final scanned = await docs.createFromPages(const [], 'New scan');
      final stored = await ctrl.onDocumentScanned(scanned);
      expect(stored.folderId, 'work');
      expect(ctrl.documents!.map((d) => d.name), ['New scan']);
    });

    test('a scanned document stays unfiled when no folder is selected', () async {
      await ctrl.load();
      final scanned = await docs.createFromPages(const [], 'New scan');
      final stored = await ctrl.onDocumentScanned(scanned);
      expect(stored.folderId, isNull);
      expect(ctrl.documents, hasLength(4));
    });

    test('share sends the PDF path', () async {
      await ctrl.share(contract);
      expect(share.shared, [contract.pdfPath]);
    });
  });

  test('does not notify after dispose', () async {
    final pending = ctrl.load();
    ctrl.dispose();
    await pending;
    ctrl = makeHomeController(documents: docs, folders: folders);
  });
}

