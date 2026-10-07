import 'package:flutter/material.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/scanned_document.dart';
import '../scanner/scan_session.dart';
import 'name_dialog.dart';

Future<ScannedDocument?> saveSessionAsPdf(BuildContext context, ScanSession session) async {
  final name = await showNameDialog(
    context,
    title: context.l10n.pdfNameTitle,
    initial: context.l10n.scanDefaultName(formatScanTimestamp(DateTime.now())),
  );
  if (name == null || !context.mounted) return null;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(child: CircularProgressIndicator(color: kScanColor)),
    ),
  );
  try {
    return await session.saveAsPdf(name);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.pdfCreateError('$e'))));
    }
    return null;
  } finally {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }
}
