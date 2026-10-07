import 'package:flutter/material.dart';

import '../../core/l10n/l10n.dart';

Future<String?> showNameDialog(BuildContext context, {required String title, String initial = ''}) =>
    showDialog<String>(context: context, builder: (_) => _NameDialog(title: title, initial: initial));

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, required this.initial});
  final String title;
  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _ctrl = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: TextField(controller: _ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.actionCancel)),
          FilledButton(onPressed: () => Navigator.pop(context, _ctrl.text), child: Text(context.l10n.actionSave)),
        ],
      );
}
