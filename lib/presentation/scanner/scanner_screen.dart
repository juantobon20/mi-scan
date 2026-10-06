import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/scan_page.dart';
import '../../domain/entities/scanned_document.dart';
import '../crop/crop_screen.dart';
import '../gallery/gallery_picker_screen.dart';
import '../review/review_screen.dart';
import '../widgets/quad_painter.dart';
import '../widgets/save_pdf.dart';
import 'frame_converter.dart';
import 'scan_session.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key, required this.session});
  final ScanSession session;

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with WidgetsBindingObserver {
  CameraController? _cam;
  String? _error;
  FlashMode _flash = FlashMode.off;

  List<Offset> _quad = const [];
  int _misses = 0;
  bool _detecting = false;
  bool _capturing = false;
  int _lastRun = 0;

  ScanSession get session => widget.session;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    session.addListener(_refresh);
    _initCamera();
  }

  void _refresh() => mounted ? setState(() {}) : null;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    session.removeListener(_refresh);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _cam?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cam = _cam;
    if (cam == null || !cam.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      cam.dispose();
      _cam = null;
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cams = await availableCameras();
      final back = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );
      final cam = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
      );
      await cam.initialize();
      await cam.setFlashMode(_flash);
      if (!mounted) return cam.dispose();
      setState(() {
        _cam = cam;
        _error = null;
      });
      await _startStream();
    } on CameraException catch (e) {
      if (mounted) {
        setState(() => _error = e.code.contains('Denied')
            ? 'Camera permission denied. Enable it in Settings to scan.'
            : 'Camera error: ${e.description ?? e.code}');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not open the camera');
    }
  }

  Future<void> _startStream() async {
    final cam = _cam;
    if (cam == null || cam.value.isStreamingImages) return;
    await cam.startImageStream(_onFrame);
  }

  Future<void> _stopStream() async {
    final cam = _cam;
    if (cam != null && cam.value.isStreamingImages) await cam.stopImageStream();
  }

  void _onFrame(CameraImage img) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_detecting || _capturing || now - _lastRun < 200) return;
    _lastRun = now;
    _detecting = true;

    final plane = img.planes[0];
    final frame = downsampleToGray(
      data: plane.bytes,
      width: img.width,
      height: img.height,
      bytesPerRow: plane.bytesPerRow,
      bgra: Platform.isIOS,
      rotation: _cam?.description.sensorOrientation ?? 90,
    );

    session.detectLive(frame).then((q) {
      _detecting = false;
      if (!mounted) return;
      if (q != null) {
        _misses = 0;
        final next = q.offsets;
        setState(() => _quad = _quad.length == 4 ? _quad.toQuad().smoothedTo(q).offsets : next);
      } else if (++_misses > 3 && _quad.isNotEmpty) {
        setState(() => _quad = const []);
      }
    }).catchError((_) {
      _detecting = false;
    });
  }

  Future<void> _capture() async {
    final cam = _cam;
    if (cam == null || _capturing || !cam.value.isInitialized) return;
    setState(() => _capturing = true);
    try {
      await _stopStream();
      final shot = await cam.takePicture();
      if (!mounted) return;
      final r = await _importAndCrop(shot.path);
      silentDelete(shot.path);
      if (r != null && r.save && mounted) {
        final doc = await saveSessionAsPdf(context, session);
        if (doc != null && mounted) {
          Navigator.pop(context, doc);
          return;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not take the photo: $e')));
      }
    } finally {
      _quad = const [];
      if (mounted) setState(() => _capturing = false);
      await _startStream();
    }
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
    await _stopStream();
    if (!mounted) return;
    final paths = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(builder: (_) => GalleryPickerScreen(dir: session.dir)),
    );
    for (var i = 0; paths != null && i < paths.length; i++) {
      if (!mounted) return;
      final r = await _importAndCrop(paths[i], index: i, total: paths.length);
      if (r != null && r.save && mounted) {
        final doc = await saveSessionAsPdf(context, session);
        if (doc != null && mounted) {
          Navigator.pop(context, doc);
          return;
        }
      }
    }
    paths?.forEach(silentDelete);
    await _startStream();
  }

  Future<void> _toggleFlash() async {
    final next = switch (_flash) {
      FlashMode.off => FlashMode.auto,
      FlashMode.auto => FlashMode.always,
      _ => FlashMode.off,
    };
    await _cam?.setFlashMode(next);
    setState(() => _flash = next);
  }

  Future<void> _review() async {
    await _stopStream();
    if (!mounted) return;
    final result = await Navigator.push<ScannedDocument>(
      context,
      MaterialPageRoute(builder: (_) => ReviewScreen(session: session)),
    );
    if (!mounted) return;
    if (result != null) {
      Navigator.pop(context, result);
    } else {
      await _startStream();
    }
  }

  Future<void> _close() async {
    if (session.pages.isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Discard this scan?'),
          content: Text('${session.pages.length} unsaved page(s) will be lost.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep scanning')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Discard')),
          ],
        ),
      );
      if (ok != true) return;
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cam = _cam;
    final flashIcon = switch (_flash) {
      FlashMode.off => Icons.flash_off,
      FlashMode.auto => Icons.flash_auto,
      _ => Icons.flash_on,
    };
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => didPop ? null : _close(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: 56,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 28),
                      onPressed: _close,
                    ),
                    const Spacer(),
                    IconButton(icon: Icon(flashIcon, color: Colors.white), onPressed: _toggleFlash),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: _error != null
                      ? Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(_error!,
                              textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
                        )
                      : cam == null || !cam.value.isInitialized
                          ? const CircularProgressIndicator(color: kScanColor)
                          : AspectRatio(
                              aspectRatio: 1 / cam.value.aspectRatio,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CameraPreview(cam),
                                  CustomPaint(painter: QuadPainter(_quad)),
                                ],
                              ),
                            ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _SideButton(icon: Icons.photo_library_outlined, label: 'Gallery', onTap: _gallery),
                    GestureDetector(
                      onTap: _capture,
                      child: Container(
                        width: 76,
                        height: 76,
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: kScanColor, width: 5),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _capturing ? Colors.grey : Colors.white,
                          ),
                        ),
                      ),
                    ),
                    session.pages.isEmpty
                        ? const SizedBox(width: 64)
                        : _Thumb(page: session.pages.last, count: session.pages.length, onTap: _review),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
                  child: Image.file(File(page.path), fit: BoxFit.cover, cacheWidth: 160),
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
