import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/gallery_image.dart';
import 'gallery_controller.dart';

class GalleryPickerScreen extends StatefulWidget {
  const GalleryPickerScreen({super.key, required this.controller});
  final GalleryController controller;

  @override
  State<GalleryPickerScreen> createState() => _GalleryPickerScreenState();
}

class _GalleryPickerScreenState extends State<GalleryPickerScreen> with WidgetsBindingObserver {
  final _scroll = ScrollController();

  GalleryController get ctrl => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 600) ctrl.loadMore();
    });
    ctrl.initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
    ctrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !ctrl.working) ctrl.initialize();
  }

  Future<void> _confirm() async {
    final paths = await ctrl.confirm();
    if (mounted) Navigator.pop(context, paths);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: ctrl,
        builder: (context, _) {
          final n = ctrl.selectedCount;
          return Scaffold(
            appBar: AppBar(title: Text(n == 0 ? context.l10n.galleryTitle : context.l10n.gallerySelected(n))),
            body: _body(context),
            floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
            floatingActionButton: n == 0
                ? null
                : ctrl.working
                    ? const CircularProgressIndicator(color: kScanColor)
                    : FloatingActionButton.extended(
                        key: const Key('gallery_confirm'),
                        backgroundColor: kScanColor,
                        foregroundColor: Colors.white,
                        onPressed: _confirm,
                        icon: const Icon(Icons.add),
                        label: Text(context.l10n.galleryAdd(n)),
                      ),
          );
        },
      );

  Widget _body(BuildContext context) {
    switch (ctrl.status) {
      case GalleryStatus.denied:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(context.l10n.galleryNoPermission, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: ctrl.openSettings, child: Text(context.l10n.actionOpenSettings)),
            ]),
          ),
        );
      case GalleryStatus.loading:
        return const Center(child: CircularProgressIndicator(color: kScanColor));
      case GalleryStatus.ready:
        if (ctrl.images.isEmpty) return Center(child: Text(context.l10n.galleryEmpty));
        return GridView.builder(
          controller: _scroll,
          padding: const EdgeInsets.only(bottom: 96),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          itemCount: ctrl.images.length,
          itemBuilder: (context, i) {
            final image = ctrl.images[i];
            return _GalleryCell(
              key: Key('gallery_${image.id}'),
              image: image,
              selectionIndex: ctrl.selectionIndex(image),
              thumbnail: ctrl.thumbnail(image),
              onTap: () => ctrl.toggle(image),
            );
          },
        );
    }
  }
}

class _GalleryCell extends StatelessWidget {
  const _GalleryCell({
    super.key,
    required this.image,
    required this.selectionIndex,
    required this.thumbnail,
    required this.onTap,
  });

  final GalleryImage image;
  final int selectionIndex;
  final Future<Uint8List?> thumbnail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = selectionIndex >= 0;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder<Uint8List?>(
            future: thumbnail,
            builder: (context, snapshot) {
              final bytes = snapshot.data;
              if (bytes == null) return const ColoredBox(color: Colors.black12);
              return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
            },
          ),
          if (selected) Container(color: kScanColor.withValues(alpha: 0.3)),
          Positioned(
            left: 6,
            top: 6,
            child: Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? kScanColor : Colors.black26,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: selected
                  ? Text(
                      '${selectionIndex + 1}',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
