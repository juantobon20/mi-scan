import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/quad.dart';
import '../../domain/entities/scan_filter.dart';
import '../../domain/entities/scan_page.dart';
import '../scanner/scan_session.dart';
import '../widgets/quad_painter.dart';
import '../widgets/scan_filter_label.dart';

class CropResult {
  CropResult(this.page, {required this.save});
  final ScanPage page;
  final bool save;
}

class CropScreen extends StatefulWidget {
  const CropScreen({
    super.key,
    required this.session,
    required this.imagePath,
    this.index = 0,
    this.total = 1,
  });
  final ScanSession session;
  final String imagePath;
  final int index;
  final int total;

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  static final _fullQuad = Quad.inset(0.04).offsets;

  List<Offset> _quad = _fullQuad;
  Size? _imageSize;
  ScanFilter _filter = ScanFilter.original;
  bool _busy = false;
  bool _detected = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final bytes = await File(widget.imagePath).readAsBytes();
    final buf = await ui.ImmutableBuffer.fromUint8List(bytes);
    final desc = await ui.ImageDescriptor.encoded(buf);
    final size = Size(desc.width.toDouble(), desc.height.toDouble());
    desc.dispose();
    buf.dispose();
    final q = await widget.session.detectInFile(widget.imagePath);
    if (!mounted) return;
    setState(() {
      _imageSize = size;
      if (q != null) {
        _quad = q.offsets;
        _detected = true;
      }
    });
  }

  Future<void> _accept({required bool save}) async {
    final size = _imageSize;
    if (size == null || _busy) return;
    setState(() => _busy = true);
    try {
      final page = await widget.session.cropPage(widget.imagePath, _quad.toQuad(), _filter);
      if (!mounted) return;
      Navigator.pop(context, CropResult(page, save: save));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.cropError('$e'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = _imageSize;
    final isLast = widget.index >= widget.total - 1;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.total > 1
            ? context.l10n.cropTitleProgress(widget.index + 1, widget.total)
            : context.l10n.cropTitle),
        actions: [
          IconButton(
            tooltip: context.l10n.cropSelectAll,
            icon: const Icon(Icons.crop_free),
            onPressed: () => setState(() => _quad = _fullQuad),
          ),
          IconButton(
            tooltip: context.l10n.cropDetectEdges,
            icon: const Icon(Icons.auto_fix_high),
            onPressed: size == null
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final l10n = context.l10n;
                    final q = await widget.session.detectInFile(widget.imagePath);
                    if (!mounted) return;
                    if (q == null) {
                      messenger.showSnackBar(SnackBar(content: Text(l10n.cropNotDetected)));
                    } else {
                      setState(() => _quad = q.offsets);
                    }
                  },
          ),
        ],
      ),
      body: size == null
          ? const Center(child: CircularProgressIndicator(color: kScanColor))
          : Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: LayoutBuilder(builder: (context, c) {
                      final scale = (c.maxWidth / size.width).clamp(0, c.maxHeight / size.height).toDouble();
                      final box = Size(size.width * scale, size.height * scale);
                      return Center(
                        child: SizedBox.fromSize(
                          size: box,
                          child: _Editor(
                            path: widget.imagePath,
                            quad: _quad,
                            box: box,
                            onChanged: (q) => setState(() => _quad = q),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                if (!_detected)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(context.l10n.cropHint, style: const TextStyle(color: Colors.white70)),
                  ),
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      for (final f in ScanFilter.values)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text(f.label(context.l10n)),
                            selected: _filter == f,
                            selectedColor: kScanColor,
                            onSelected: (_) => setState(() => _filter = f),
                          ),
                        ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: _busy ? null : () => Navigator.pop(context),
                          child: Text(widget.total > 1 ? context.l10n.actionSkip : context.l10n.actionCancel,
                              style: const TextStyle(color: Colors.white)),
                        ),
                        const Spacer(),
                        if (_busy)
                          const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2, color: kScanColor))
                        else if (!isLast)
                          FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: kScanColor),
                            onPressed: () => _accept(save: false),
                            icon: const Icon(Icons.arrow_forward),
                            label: Text(context.l10n.actionNext),
                          )
                        else ...[
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white54),
                            ),
                            onPressed: () => _accept(save: false),
                            icon: const Icon(Icons.add),
                            label: Text(context.l10n.actionAdd),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: kScanColor),
                            onPressed: () => _accept(save: true),
                            icon: const Icon(Icons.picture_as_pdf),
                            label: Text(context.l10n.actionSave),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _Editor extends StatelessWidget {
  const _Editor({required this.path, required this.quad, required this.box, required this.onChanged});
  final String path;
  final List<Offset> quad;
  final Size box;
  final ValueChanged<List<Offset>> onChanged;

  static const _hit = 48.0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: Image.file(File(path), fit: BoxFit.fill, cacheWidth: 1600, gaplessPlayback: true),
          ),
        ),
        Positioned.fill(
          child: RepaintBoundary(child: CustomPaint(painter: QuadPainter(quad, dimOutside: true))),
        ),
        for (var i = 0; i < 4; i++)
          Positioned(
            left: quad[i].dx * box.width - _hit / 2,
            top: quad[i].dy * box.height - _hit / 2,
            width: _hit,
            height: _hit,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerMove: (d) {
                final n = [...quad];
                n[i] = Offset(
                  (quad[i].dx + d.delta.dx / box.width).clamp(0.0, 1.0),
                  (quad[i].dy + d.delta.dy / box.height).clamp(0.0, 1.0),
                );
                onChanged(n);
              },
              child: Center(
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: kScanColor, width: 3),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
