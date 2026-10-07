import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_scan/core/l10n/l10n.dart';
import 'package:mi_scan/presentation/home/document_text_screen.dart';

import '../helpers/pump_helpers.dart';

void main() {
  testWidgets('shows the title and the text', (tester) async {
    await pumpApp(tester, const DocumentTextScreen(title: 'Invoice', text: 'Total due 120'));
    expect(find.text('Invoice'), findsOneWidget);
    expect(find.text('Total due 120'), findsOneWidget);
    expect(find.byKey(const Key('copy_text')), findsOneWidget);
  });

  testWidgets('the text can be selected', (tester) async {
    await pumpApp(tester, const DocumentTextScreen(title: 'Invoice', text: 'Select me'));
    expect(find.byType(SelectableText), findsOneWidget);
  });

  testWidgets('long texts scroll', (tester) async {
    usePhoneScreen(tester);
    final text = List.generate(300, (i) => 'Line $i').join('\n');
    await pumpApp(tester, DocumentTextScreen(title: 'Long', text: text));
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -3000));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('copying puts the text on the clipboard and confirms it', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await pumpApp(tester, const DocumentTextScreen(title: 'Invoice', text: 'Total due 120'));
    await tester.tap(find.byKey(const Key('copy_text')));
    await tester.pump();
    expect(copied, 'Total due 120');
    expect(find.text('Text copied'), findsOneWidget);
  });

  for (final text in [null, '', '   \n ']) {
    testWidgets('explains when there is no text (${text == null ? 'null' : "'${text.replaceAll('\n', r'\n')}'"})', (tester) async {
      await pumpApp(tester, DocumentTextScreen(title: 'Empty', text: text));
      expect(find.text('No text was found in this document.'), findsOneWidget);
      expect(find.byKey(const Key('copy_text')), findsNothing);
    });
  }

  testWidgets('texts follow the device language', (tester) async {
    final es = await AppLocalizations.delegate.load(const Locale('es'));
    await pumpApp(tester, const DocumentTextScreen(title: 'Empty', text: null), locale: const Locale('es'));
    expect(find.text(es.textEmpty), findsOneWidget);
  });
}
