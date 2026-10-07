import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_scan/core/l10n/l10n.dart';
import 'package:mi_scan/domain/entities/scan_filter.dart';
import 'package:mi_scan/domain/usecases/document_usecases.dart';
import 'package:mi_scan/presentation/home/home_controller.dart';
import 'package:mi_scan/presentation/home/home_screen.dart';
import 'package:mi_scan/presentation/review/review_screen.dart';
import 'package:mi_scan/presentation/scanner/scan_session.dart';
import 'package:mi_scan/presentation/widgets/scan_filter_label.dart';

import '../helpers/fakes.dart';
import '../helpers/pump_helpers.dart';

Map<String, dynamic> _arb(String locale) =>
    jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync()) as Map<String, dynamic>;

Set<String> _messageKeys(Map<String, dynamic> arb) => arb.keys.where((k) => !k.startsWith('@')).toSet();

Future<AppLocalizations> _load(String code) => AppLocalizations.delegate.load(Locale(code));

HomeController _homeController() {
  final repo = InMemoryDocumentRepository();
  return HomeController(
    listDocuments: ListDocuments(repo),
    renameDocument: RenameDocument(repo),
    deleteDocument: DeleteDocument(repo),
    shareService: FakeShareService(),
  );
}

Future<ScanSession> _noSession() async => throw UnimplementedError();

void main() {
  group('translation files', () {
    test('English and Spanish define exactly the same keys', () {
      expect(_messageKeys(_arb('es')), _messageKeys(_arb('en')));
    });

    test('no translation is empty', () {
      for (final locale in ['en', 'es']) {
        final arb = _arb(locale);
        for (final key in _messageKeys(arb).where((k) => !k.startsWith('@@'))) {
          expect((arb[key] as String).trim(), isNotEmpty, reason: '$locale/$key');
        }
      }
    });

    test('placeholders match between languages', () {
      final placeholder = RegExp(r'\{(\w+)(?:\}|,\s*plural)');
      final en = _arb('en'), es = _arb('es');
      for (final key in _messageKeys(en).where((k) => !k.startsWith('@@'))) {
        Set<String> names(String text) => placeholder.allMatches(text).map((m) => m.group(1)!).toSet();
        expect(names(es[key] as String), names(en[key] as String), reason: key);
      }
    });

    test('supported locales are English first, then Spanish', () {
      expect(AppLocalizations.supportedLocales.map((l) => l.languageCode), ['en', 'es']);
    });
  });

  group('messages', () {
    test('plural forms in English', () async {
      final l10n = await _load('en');
      expect(l10n.reviewTitle(1), '1 page');
      expect(l10n.reviewTitle(3), '3 pages');
      expect(l10n.discardScanMessage(1), '1 unsaved page will be lost.');
      expect(l10n.discardScanMessage(2), '2 unsaved pages will be lost.');
    });

    test('plural forms in Spanish', () async {
      final es = await _load('es');
      final en = await _load('en');
      expect(es.reviewTitle(1), isNot(en.reviewTitle(1)));
      expect(es.reviewTitle(1), contains('1'));
      expect(es.reviewTitle(3), contains('3'));
      expect(es.reviewTitle(1), isNot(es.reviewTitle(3)));
    });

    test('filters have a label in both languages', () async {
      for (final code in ['en', 'es']) {
        final l10n = await _load(code);
        final labels = ScanFilter.values.map((f) => f.label(l10n)).toList();
        expect(labels.toSet(), hasLength(ScanFilter.values.length), reason: code);
        expect(labels.every((l) => l.isNotEmpty), isTrue);
      }
    });
  });

  group('locale resolution', () {
    Future<String> homeTitleFor(WidgetTester tester, Locale device) async {
      tester.platformDispatcher.localesTestValue = [device];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomeScreen(controller: _homeController(), startSession: _noSession),
        ),
      );
      await tester.pumpAndSettle();
      return tester.widget<AppBar>(find.byType(AppBar)).title.toString();
    }

    testWidgets('Spanish device shows Spanish', (tester) async {
      final es = await _load('es');
      expect(await homeTitleFor(tester, const Locale('es')), contains(es.homeTitle));
    });

    testWidgets('Spanish variant (es-MX) shows Spanish', (tester) async {
      final es = await _load('es');
      expect(await homeTitleFor(tester, const Locale('es', 'MX')), contains(es.homeTitle));
    });

    testWidgets('English device shows English', (tester) async {
      final en = await _load('en');
      expect(await homeTitleFor(tester, const Locale('en', 'US')), contains(en.homeTitle));
    });

    for (final code in ['fr', 'pt', 'de', 'ja']) {
      testWidgets('unsupported language "$code" falls back to English', (tester) async {
        final en = await _load('en');
        expect(await homeTitleFor(tester, Locale(code)), contains(en.homeTitle));
      });
    }
  });

  group('screens in Spanish', () {
    testWidgets('home empty state and dialogs use Spanish strings', (tester) async {
      final es = await _load('es');
      await pumpApp(
        tester,
        HomeScreen(controller: _homeController(), startSession: _noSession),
        locale: const Locale('es'),
      );
      await tester.pumpAndSettle();
      expect(find.text(es.homeTitle), findsOneWidget);
      expect(find.text(es.homeEmpty), findsOneWidget);
    });

    testWidgets('review screen uses Spanish strings', (tester) async {
      final es = await _load('es');
      final dir = Directory.systemTemp.createTempSync('l10n_test_');
      addTearDown(() => dir.deleteSync(recursive: true));
      await pumpApp(tester, ReviewScreen(session: buildSession(dir)), locale: const Locale('es'));
      await tester.pump();
      expect(find.text(es.reviewEmpty), findsOneWidget);
      expect(find.text(es.reviewTitle(0)), findsOneWidget);
    });
  });
}
