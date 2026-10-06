import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/scanned_document.dart';
import '../scanner/scan_session.dart';
import '../scanner/scanner_screen.dart';
import '../widgets/name_dialog.dart';
import 'home_controller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller, required this.startSession});
  final HomeController controller;
  final ScanSessionFactory startSession;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HomeController get ctrl => widget.controller;

  @override
  void initState() {
    super.initState();
    ctrl.load();
  }

  Future<void> _scan() async {
    final session = await widget.startSession();
    if (!mounted) return;
    final doc = await Navigator.push<ScannedDocument>(
      context,
      MaterialPageRoute(builder: (_) => ScannerScreen(session: session)),
    );
    session.disposeFiles();
    await ctrl.load();
    if (doc != null) await ctrl.share(doc);
  }

  Future<void> _rename(ScannedDocument d) async {
    final name = await showNameDialog(context, title: 'Rename', initial: d.name);
    if (name != null) await ctrl.rename(d, name);
  }

  Future<void> _delete(ScannedDocument d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete document?'),
        content: Text(d.name),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await ctrl.delete(d);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Recent')),
        body: ListenableBuilder(listenable: ctrl, builder: (context, _) => _body()),
        floatingActionButton: FloatingActionButton(
          key: const Key('scan_fab'),
          backgroundColor: kScanColor,
          foregroundColor: Colors.white,
          onPressed: _scan,
          child: const Icon(Icons.photo_camera),
        ),
      );

  Widget _body() {
    final docs = ctrl.documents;
    if (docs == null) return const Center(child: CircularProgressIndicator());
    if (ctrl.error != null && docs.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Could not load documents'),
          const SizedBox(height: 12),
          FilledButton(onPressed: ctrl.load, child: const Text('Retry')),
        ]),
      );
    }
    if (docs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('You have no documents yet.\nTap the camera to scan your first one.',
              textAlign: TextAlign.center),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: docs.length,
      itemBuilder: (context, i) => _DocTile(
        doc: docs[i],
        onShare: () => ctrl.share(docs[i]),
        onRename: () => _rename(docs[i]),
        onDelete: () => _delete(docs[i]),
      ),
    );
  }
}

class _DocTile extends StatelessWidget {
  const _DocTile({required this.doc, required this.onShare, required this.onRename, required this.onDelete});
  final ScannedDocument doc;
  final VoidCallback onShare, onRename, onDelete;

  @override
  Widget build(BuildContext context) {
    const placeholder = Icon(Icons.picture_as_pdf, color: Colors.red);
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          width: 48,
          height: 64,
          child: doc.thumbPath == null
              ? placeholder
              : Image.file(File(doc.thumbPath!), fit: BoxFit.cover, errorBuilder: (_, _, _) => placeholder),
        ),
      ),
      title: Text(doc.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(formatDocSubtitle(doc.modified, doc.sizeBytes)),
      onTap: onShare,
      trailing: PopupMenuButton<String>(
        onSelected: (v) => switch (v) {
          'share' => onShare(),
          'rename' => onRename(),
          _ => onDelete(),
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'share', child: Text('Share')),
          PopupMenuItem(value: 'rename', child: Text('Rename')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    );
  }
}
