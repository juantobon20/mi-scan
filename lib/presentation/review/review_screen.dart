import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../scanner/scan_session.dart';
import '../widgets/save_pdf.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.session});
  final ScanSession session;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  ScanSession get session => widget.session;

  @override
  void initState() {
    super.initState();
    session.addListener(_refresh);
  }

  void _refresh() => mounted ? setState(() {}) : null;

  @override
  void dispose() {
    session.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _createPdf() async {
    final doc = await saveSessionAsPdf(context, session);
    if (doc != null && mounted) Navigator.pop(context, doc);
  }

  @override
  Widget build(BuildContext context) {
    final pages = session.pages;
    return Scaffold(
      appBar: AppBar(title: Text('${pages.length} page(s)')),
      body: pages.isEmpty
          ? const Center(child: Text('No pages'))
          : ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
              itemCount: pages.length,
              onReorderItem: session.move,
              itemBuilder: (context, i) {
                final page = pages[i];
                return Card(
                  key: ObjectKey(page),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.file(File(page.path),
                          width: 48,
                          height: 64,
                          fit: BoxFit.cover,
                          cacheWidth: 150,
                          errorBuilder: (_, _, _) => const SizedBox(width: 48, height: 64, child: Icon(Icons.image_not_supported))),
                    ),
                    title: Text('Page ${i + 1}'),
                    subtitle: const Text('Long-press to reorder'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        tooltip: 'Rotate',
                        icon: const Icon(Icons.rotate_right),
                        onPressed: () => session.rotate(i),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          session.removeAt(i);
                          if (session.pages.isEmpty) Navigator.pop(context);
                        },
                      ),
                      const SizedBox(width: 24),
                    ]),
                  ),
                );
              },
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'add',
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Add'),
                ),
                const SizedBox(width: 12),
                FloatingActionButton.extended(
                  heroTag: 'pdf',
                  backgroundColor: kScanColor,
                  foregroundColor: Colors.white,
                  onPressed: pages.isEmpty ? null : _createPdf,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Create PDF'),
                ),
              ],
            ),
    );
  }
}
