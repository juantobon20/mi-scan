import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_scan/core/l10n/l10n.dart';
import 'package:mi_scan/domain/usecases/document_usecases.dart';
import 'package:mi_scan/presentation/scanner/scan_session.dart';

import 'fakes.dart';

Widget localizedApp(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

Future<void> pumpApp(WidgetTester tester, Widget home, {Locale locale = const Locale('en')}) =>
    tester.pumpWidget(localizedApp(home, locale: locale));

ScanSession buildSession(Directory dir, {FakeImageProcessor? processor, InMemoryDocumentRepository? repo}) =>
    ScanSession(
      dir: dir.path,
      imageProcessor: processor ?? FakeImageProcessor(),
      createDocument: CreateDocument(repo ?? InMemoryDocumentRepository()),
    );
