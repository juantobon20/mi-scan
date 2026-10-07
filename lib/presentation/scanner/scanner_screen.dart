import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/camera_info.dart';
import '../../domain/entities/scan_page.dart';
import '../../domain/entities/scanned_document.dart';
import '../../domain/services/camera_service.dart';
import '../crop/crop_screen.dart';
import '../gallery/gallery_picker_screen.dart';
import '../navigation/screen_factory.dart';
import '../review/review_screen.dart';
import '../widgets/quad_painter.dart';
import '../widgets/save_pdf.dart';
import 'scan_session.dart';
import 'scanner_controller.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key, required this.session, required this.controller, required this.factory});

  final ScanSession session;
  final ScannerController controller;
  final ScreenFactory factory;

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with WidgetsBindingObserver {
  double _zoomAtGestureStart = 1;

  ScanSession get session => widget.session;
  ScannerController get ctrl => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    ctrl.initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    ctrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      ctrl.suspend();
    } else if (state == AppLifecycleState.resumed) {
      ctrl.resume();
    }
  }

  Future<void> _capture() async {
    if (ctrl.capturing || !ctrl.isReady) return;
    try {
      final path = await ctrl.capture();
      if (!mounted) return;
      if (ctrl.mode == ScanMode.batch) {
        await session.autoCropPage(path);
        silentDelete(path);
      } else {
        final result = await _importAndCrop(path);
        silentDelete(path);
        if (result != null && result.save && mounted && await _saveAndClose()) return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.takePhotoError('$e'))));
      }
    } finally {
      await ctrl.finishCapture();
    }
  }

  Future<bool> _saveAndClose() async {
    final doc = await saveSessionAsPdf(context, session);
    if (doc != null && mounted) {
      Navigator.pop(context, doc);
      return true;
    }
    return false;
  }

  Future<CropResult?> _importAndCrop(String sourcePath, {int index = 0, int total = 1}) async {
    final tmp = await session.importSource(sourcePath);
    if (!mounted) return null;
    final result = await Navigator.push<CropResult>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CropScreen(session: session, imagePath: tmp, index: index, total: total),
      ),
    );
    silentDelete(tmp);
    if (result != null) session.add(result.page);
    return result;
  }

  Future<void> _gallery() async {
    await ctrl.pauseFrames();
    if (!mounted) return;
    final paths = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => GalleryPickerScreen(controller: widget.factory.galleryController(session.dir)),
      ),
    );
    for (var i = 0; paths != null && i < paths.length; i++) {
      if (!mounted) return;
      if (ctrl.mode == ScanMode.batch) {
        await session.autoCropPage(paths[i]);
        continue;
      }
      final result = await _importAndCrop(paths[i], index: i, total: paths.length);
      if (result != null && result.save && mounted && await _saveAndClose()) return;
    }
    paths?.forEach(silentDelete);
    await ctrl.resumeFrames();
  }

  Future<void> _review() async {
    await ctrl.pauseFrames();
    if (!mounted) return;
    final result = await Navigator.push<ScannedDocument>(
      context,
      MaterialPageRoute(builder: (_) => ReviewScreen(session: session)),
    );
    if (!mounted) return;
    if (result != null) {
      Navigator.pop(context, result);
    } else {
      await ctrl.resumeFrames();
    }
  }

  Future<void> _close() async {
    if (session.pages.isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(context.l10n.discardScanTitle),
          content: Text(context.l10n.discardScanMessage(session.pages.length)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(context.l10n.actionKeepScanning)),
            TextButton(onPressed: () => Navigator.pop(c, true), child: Text(context.l10n.actionDiscard)),
          ],
        ),
      );
      if (ok != true) return;
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => didPop ? null : _close(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: ListenableBuilder(
            listenable: Listenable.merge([ctrl, session]),
            builder: (context, _) => Column(
              children: [
                _TopBar(controller: ctrl, onClose: _close),
                Expanded(child: Center(child: _preview(context))),
                if (ctrl.isReady && ctrl.zoomRange.isZoomable) _ZoomSlider(controller: ctrl),
                _ModeSelector(controller: ctrl),
                _BottomBar(
                  controller: ctrl,
                  session: session,
                  onGallery: _gallery,
                  onCapture: _capture,
                  onReview: _review,
                  onDone: _saveAndClose,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _preview(BuildContext context) {
    final problem = ctrl.problem;
    if (problem != null) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          _problemMessage(context.l10n, problem),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white),
        ),
      );
    }
    final camera = ctrl.camera;
    if (camera == null) return const CircularProgressIndicator(color: kScanColor);
    return AspectRatio(
      aspectRatio: camera.previewAspectRatio,
      child: GestureDetector(
        onScaleStart: (_) => _zoomAtGestureStart = ctrl.zoom,
        onScaleUpdate: (details) => ctrl.setZoom(_zoomAtGestureStart * details.scale),
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.factory.previewBuilder(camera),
            CustomPaint(painter: QuadPainter(ctrl.quad?.offsets ?? const [])),
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Center(child: _ZoomBadge(zoom: ctrl.zoom)),
            ),
          ],
        ),
      ),
    );
  }

  String _problemMessage(AppLocalizations l10n, CameraAccessException problem) => switch (problem.failure) {
        CameraFailure.permissionDenied => l10n.cameraPermissionDenied,
        CameraFailure.unavailable => l10n.cameraOpenError,
        CameraFailure.failed => l10n.cameraError(problem.details ?? ''),
      };
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.controller, required this.onClose});
  final ScannerController controller;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final flashIcon = switch (controller.flash) {
      FlashSetting.off => Icons.flash_off,
      FlashSetting.auto => Icons.flash_auto,
      FlashSetting.always => Icons.flash_on,
    };
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 28), onPressed: onClose),
          const Spacer(),
          IconButton(
            key: const Key('flash_button'),
            tooltip: context.l10n.flashTooltip,
            icon: Icon(flashIcon, color: Colors.white),
            onPressed: controller.isReady ? controller.cycleFlash : null,
          ),
          IconButton(
            key: const Key('torch_button'),
            tooltip: context.l10n.torchTooltip,
            icon: Icon(
              controller.torch ? Icons.flashlight_on : Icons.flashlight_off,
              color: controller.torch ? kScanColor : Colors.white,
            ),
            onPressed: controller.isReady ? controller.toggleTorch : null,
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _ZoomBadge extends StatelessWidget {
  const _ZoomBadge({required this.zoom});
  final double zoom;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
        child: Text(
          '${zoom.toStringAsFixed(1)}x',
          key: const Key('zoom_label'),
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      );
}

class _ZoomSlider extends StatelessWidget {
  const _ZoomSlider({required this.controller});
  final ScannerController controller;

  @override
  Widget build(BuildContext context) {
    final range = controller.zoomRange;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          const Icon(Icons.zoom_out, color: Colors.white70, size: 20),
          Expanded(
            child: Slider(
              key: const Key('zoom_slider'),
              min: range.min,
              max: range.max,
              value: controller.zoom.clamp(range.min, range.max),
              activeColor: kScanColor,
              semanticFormatterCallback: (_) => context.l10n.zoomTooltip,
              onChanged: controller.setZoom,
            ),
          ),
          const Icon(Icons.zoom_in, color: Colors.white70, size: 20),
        ],
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.controller});
  final ScannerController controller;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ChoiceChip(
              key: const Key('mode_single'),
              label: Text(context.l10n.modeSingle),
              selected: controller.mode == ScanMode.single,
              selectedColor: kScanColor,
              onSelected: (_) => controller.setMode(ScanMode.single),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              key: const Key('mode_batch'),
              label: Text(context.l10n.modeBatch),
              selected: controller.mode == ScanMode.batch,
              selectedColor: kScanColor,
              onSelected: (_) => controller.setMode(ScanMode.batch),
            ),
          ],
        ),
      );
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.controller,
    required this.session,
    required this.onGallery,
    required this.onCapture,
    required this.onReview,
    required this.onDone,
  });

  final ScannerController controller;
  final ScanSession session;
  final VoidCallback onGallery;
  final VoidCallback onCapture;
  final VoidCallback onReview;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final pages = session.pages;
    final batch = controller.mode == ScanMode.batch;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _SideButton(icon: Icons.photo_library_outlined, label: context.l10n.galleryButton, onTap: onGallery),
          GestureDetector(
            key: const Key('shutter'),
            onTap: onCapture,
            child: Container(
              width: 76,
              height: 76,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: kScanColor, width: 5)),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: controller.capturing ? Colors.grey : Colors.white,
                ),
              ),
            ),
          ),
          if (pages.isEmpty)
            const SizedBox(width: 64)
          else if (batch)
            _DoneButton(count: pages.length, onDone: onDone, onReview: onReview, last: pages.last)
          else
            _Thumb(page: pages.last, count: pages.length, onTap: onReview),
        ],
      ),
    );
  }
}

class _DoneButton extends StatelessWidget {
  const _DoneButton({required this.count, required this.onDone, required this.onReview, required this.last});
  final int count;
  final VoidCallback onDone;
  final VoidCallback onReview;
  final ScanPage last;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Thumb(page: last, count: count, onTap: onReview),
          const SizedBox(height: 6),
          GestureDetector(
            key: const Key('batch_done'),
            onTap: onDone,
            child: Text(context.l10n.batchDone, style: const TextStyle(color: kScanColor, fontWeight: FontWeight.bold)),
          ),
        ],
      );
}

class _SideButton extends StatelessWidget {
  const _SideButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 64,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: Colors.white, size: 30),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ]),
        ),
      );
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.page, required this.count, required this.onTap});
  final ScanPage page;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        key: const Key('page_thumb'),
        onTap: onTap,
        child: SizedBox(
          width: 64,
          height: 64,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(page.path),
                    fit: BoxFit.cover,
                    cacheWidth: 160,
                    errorBuilder: (_, _, _) => const ColoredBox(color: Colors.white24),
                  ),
                ),
              ),
              Positioned(
                right: -6,
                top: -6,
                child: CircleAvatar(
                  radius: 11,
                  backgroundColor: kScanColor,
                  child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ),
            ],
          ),
        ),
      );
}
