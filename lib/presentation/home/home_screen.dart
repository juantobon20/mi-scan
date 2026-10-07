import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/folder.dart';
import '../../domain/entities/scan_page.dart';
import '../../domain/entities/scanned_document.dart';
import '../navigation/screen_factory.dart';
import '../scanner/scan_session.dart';
import '../scanner/scanner_screen.dart';
import '../widgets/name_dialog.dart';
import 'document_text_screen.dart';
import 'home_controller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller, required this.startSession, required this.factory});
  final HomeController controller;
  final ScanSessionFactory startSession;
  final ScreenFactory factory;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _MoveChoice {
  const _MoveChoice(this.folderId);
  final String? folderId;
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  bool _searching = false;

  HomeController get ctrl => widget.controller;

  @override
  void initState() {
    super.initState();
    ctrl.load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.genericError('$e'))));
      }
    }
  }

  Future<void> _scan() async {
    final session = await widget.startSession();
    if (!mounted) return;
    final doc = await Navigator.push<ScannedDocument>(
      context,
      MaterialPageRoute(
        builder: (_) => ScannerScreen(
          session: session,
          controller: widget.factory.scannerController(session),
          factory: widget.factory,
        ),
      ),
    );
    if (doc == null) {
      session.disposeFiles();
      await ctrl.load();
      return;
    }
    final pages = List.of(session.pages);
    final stored = await ctrl.onDocumentScanned(doc);
    unawaited(_recognize(stored, pages).whenComplete(session.disposeFiles));
    await ctrl.share(stored);
  }

  Future<void> _recognize(ScannedDocument doc, List<ScanPage> pages) async {
    final outcome = await ctrl.recognizeText(doc, pages);
    if (!mounted || outcome.hasText || outcome.failedPages == 0) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.ocrFailed(doc.name))));
  }

  Future<void> _viewText(ScannedDocument d) async {
    final text = await ctrl.loadText(d);
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => DocumentTextScreen(title: d.name, text: text)),
    );
  }

  Future<void> _rename(ScannedDocument d) async {
    final name = await showNameDialog(context, title: context.l10n.renameTitle, initial: d.name);
    if (name != null) await _guard(() => ctrl.rename(d, name));
  }

  Future<void> _delete(ScannedDocument d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(context.l10n.deleteDocumentTitle),
        content: Text(d.name),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(context.l10n.actionCancel)),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text(context.l10n.actionDelete)),
        ],
      ),
    );
    if (ok == true) await _guard(() => ctrl.delete(d));
  }

  Future<void> _move(ScannedDocument d) async {
    final choice = await showDialog<_MoveChoice>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text(context.l10n.moveTitle),
        children: [
          SimpleDialogOption(
            key: const Key('move_none'),
            onPressed: () => Navigator.pop(c, const _MoveChoice(null)),
            child: _MoveRow(label: context.l10n.moveNoFolder, selected: d.folderId == null),
          ),
          for (final summary in ctrl.folders)
            SimpleDialogOption(
              key: Key('move_${summary.folder.id}'),
              onPressed: () => Navigator.pop(c, _MoveChoice(summary.folder.id)),
              child: _MoveRow(label: summary.folder.name, selected: d.folderId == summary.folder.id),
            ),
        ],
      ),
    );
    if (choice != null) await _guard(() => ctrl.moveDocument(d, choice.folderId));
  }

  Future<void> _newFolder() async {
    final name = await showNameDialog(context, title: context.l10n.folderNameTitle);
    if (name == null || name.trim().isEmpty) return;
    await _guard(() async {
      final folder = await ctrl.createFolder(name);
      await ctrl.selectFolder(folder.id);
    });
  }

  Future<void> _folderActions(Folder folder) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('folder_rename'),
              leading: const Icon(Icons.edit_outlined),
              title: Text(context.l10n.folderRename),
              onTap: () => Navigator.pop(c, 'rename'),
            ),
            ListTile(
              key: const Key('folder_delete'),
              leading: const Icon(Icons.delete_outline),
              title: Text(context.l10n.folderDelete),
              onTap: () => Navigator.pop(c, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'rename') {
      final name = await showNameDialog(context, title: context.l10n.folderRename, initial: folder.name);
      if (name != null && name.trim().isNotEmpty) await _guard(() => ctrl.renameFolder(folder, name));
    } else {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(context.l10n.folderDeleteTitle),
          content: Text(context.l10n.folderDeleteMessage(folder.name)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(context.l10n.actionCancel)),
            TextButton(onPressed: () => Navigator.pop(c, true), child: Text(context.l10n.actionDelete)),
          ],
        ),
      );
      if (ok == true) await _guard(() => ctrl.deleteFolder(folder));
    }
  }

  void _toggleSearch() {
    if (_searching) {
      _searchController.clear();
      ctrl.clearSearch();
    }
    setState(() => _searching = !_searching);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: _searching
              ? TextField(
                  key: const Key('search_field'),
                  controller: _searchController,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(hintText: context.l10n.searchHint, border: InputBorder.none),
                  onChanged: ctrl.setSearchText,
                )
              : Text(context.l10n.homeTitle),
          actions: [
            IconButton(
              key: const Key('search_button'),
              tooltip: _searching ? context.l10n.searchClearTooltip : context.l10n.searchTooltip,
              icon: Icon(_searching ? Icons.close : Icons.search),
              onPressed: _toggleSearch,
            ),
          ],
        ),
        body: ListenableBuilder(
          listenable: ctrl,
          builder: (context, _) => Column(
            children: [
              _FolderBar(
                controller: ctrl,
                onNewFolder: _newFolder,
                onFolderActions: _folderActions,
              ),
              Expanded(child: _body()),
            ],
          ),
        ),
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
          Text(context.l10n.homeLoadError),
          const SizedBox(height: 12),
          FilledButton(onPressed: ctrl.load, child: Text(context.l10n.actionRetry)),
        ]),
      );
    }
    if (docs.isEmpty) {
      final message = ctrl.isSearching
          ? context.l10n.searchNoResults(ctrl.searchText.trim())
          : ctrl.selectedFolderId != null
              ? context.l10n.folderEmpty
              : context.l10n.homeEmpty;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(message, textAlign: TextAlign.center),
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
        onMove: () => _move(docs[i]),
        onViewText: () => _viewText(docs[i]),
        onDelete: () => _delete(docs[i]),
        recognizing: ctrl.isRecognizing(docs[i]),
      ),
    );
  }
}

class _MoveRow extends StatelessWidget {
  const _MoveRow({required this.label, required this.selected});
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: Text(label)),
          if (selected) const Icon(Icons.check, size: 20, color: kScanColor),
        ],
      );
}

class _FolderBar extends StatelessWidget {
  const _FolderBar({required this.controller, required this.onNewFolder, required this.onFolderActions});
  final HomeController controller;
  final VoidCallback onNewFolder;
  final ValueChanged<Folder> onFolderActions;

  @override
  Widget build(BuildContext context) {
    final folders = controller.folders;
    return SizedBox(
      height: 52,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            ChoiceChip(
              key: const Key('folder_all'),
              label: Text(context.l10n.folderAll),
              selected: controller.selectedFolderId == null,
              selectedColor: kScanColor,
              onSelected: (_) => controller.selectFolder(null),
            ),
            for (final summary in folders)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: GestureDetector(
                  onLongPress: () => onFolderActions(summary.folder),
                  child: ChoiceChip(
                    key: Key('folder_${summary.folder.id}'),
                    avatar: const Icon(Icons.folder_outlined, size: 18),
                    label: Text('${summary.folder.name} (${summary.documentCount})'),
                    selected: controller.selectedFolderId == summary.folder.id,
                    selectedColor: kScanColor,
                    onSelected: (_) => controller.selectFolder(summary.folder.id),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ActionChip(
                key: const Key('folder_new'),
                avatar: const Icon(Icons.create_new_folder_outlined, size: 18),
                label: Text(context.l10n.folderNew),
                onPressed: onNewFolder,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocTile extends StatelessWidget {
  const _DocTile({
    required this.doc,
    required this.onShare,
    required this.onRename,
    required this.onMove,
    required this.onViewText,
    required this.onDelete,
    required this.recognizing,
  });
  final ScannedDocument doc;
  final VoidCallback onShare, onRename, onMove, onViewText, onDelete;
  final bool recognizing;

  @override
  Widget build(BuildContext context) {
    const placeholder = Icon(Icons.picture_as_pdf, color: Colors.red);
    final locale = Localizations.localeOf(context).toString();
    final details = formatDocSubtitle(doc.modified, doc.sizeBytes, locale: locale);
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
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(doc.pageCount > 0 ? '$details · ${context.l10n.reviewTitle(doc.pageCount)}' : details),
          if (recognizing)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                key: const Key('ocr_progress'),
                children: [
                  const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      context.l10n.ocrRecognizing,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            )
          else if (doc.hasText)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                key: const Key('has_text'),
                children: [
                  Icon(Icons.text_snippet_outlined, size: 14, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      context.l10n.searchableText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      onTap: onShare,
      trailing: PopupMenuButton<String>(
        onSelected: (v) => switch (v) {
          'share' => onShare(),
          'rename' => onRename(),
          'move' => onMove(),
          'text' => onViewText(),
          _ => onDelete(),
        },
        itemBuilder: (_) => [
          PopupMenuItem(value: 'share', child: Text(context.l10n.menuShare)),
          PopupMenuItem(value: 'rename', child: Text(context.l10n.menuRename)),
          PopupMenuItem(value: 'move', child: Text(context.l10n.menuMove)),
          if (doc.hasText) PopupMenuItem(value: 'text', child: Text(context.l10n.menuViewText)),
          PopupMenuItem(value: 'delete', child: Text(context.l10n.menuDelete)),
        ],
      ),
    );
  }
}
