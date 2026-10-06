import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_scan/domain/usecases/document_usecases.dart';
import 'package:mi_scan/presentation/scanner/scan_session.dart';

import 'fakes.dart';

Future<void> pumpApp(WidgetTester tester, Widget home) =>
    tester.pumpWidget(MaterialApp(home: home));

ScanSession buildSession(Directory dir, {FakeImageProcessor? processor, InMemoryDocumentRepository? repo}) =>
    ScanSession(
      dir: dir.path,
      imageProcessor: processor ?? FakeImageProcessor(),
      createDocument: CreateDocument(repo ?? InMemoryDocumentRepository()),
    );
