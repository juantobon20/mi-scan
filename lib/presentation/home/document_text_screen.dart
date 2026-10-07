import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/l10n.dart';

class DocumentTextScreen extends StatelessWidget {
  const DocumentTextScreen({super.key, required this.title, required this.text});

  final String title;
  final String? text;

  bool get _hasText => text != null && text!.trim().isNotEmpty;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: text!));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.textCopied)));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(title, overflow: TextOverflow.ellipsis),
          actions: [
            if (_hasText)
              IconButton(
                key: const Key('copy_text'),
                tooltip: context.l10n.textCopy,
                icon: const Icon(Icons.copy_outlined),
                onPressed: () => _copy(context),
              ),
          ],
        ),
        body: _hasText
            ? SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SelectableText(text!, key: const Key('document_text')),
              )
            : Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(context.l10n.textEmpty, textAlign: TextAlign.center),
                ),
              ),
      );
}
