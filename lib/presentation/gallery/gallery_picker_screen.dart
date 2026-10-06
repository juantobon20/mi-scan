import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import '../../core/theme/app_theme.dart';

class GalleryPickerScreen extends StatefulWidget {
  const GalleryPickerScreen({super.key, required this.dir});
  final String dir;

  @override
  State<GalleryPickerScreen> createState() => _GalleryPickerScreenState();
}

class _GalleryPickerScreenState extends State<GalleryPickerScreen> with WidgetsBindingObserver {
  static const _pageSize = 90;

  final _assets = <AssetEntity>[];
  final _selected = <AssetEntity>[];
  final _scroll = ScrollController();
  AssetPathEntity? _album;
  bool _denied = false;
  bool _loading = true;
  bool _more = true;
  bool _working = false;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 600) _loadMore();
    });
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _working) return;
    _selected.clear();
    _assets.clear();
    setState(() {
      _denied = false;
      _loading = true;
      _more = true;
      _page = 0;
      _album = null;
    });
    _init();
  }

  Future<void> _init() async {
    final perm = await PhotoManager.requestPermissionExtend();
    if (!perm.hasAccess) {
      if (mounted) {
        setState(() {
          _denied = true;
          _loading = false;
        });
      }
      return;
    }
    final albums = await PhotoManager.getAssetPathList(
      onlyAll: true,
      type: RequestType.image,
      filterOption: FilterOptionGroup(orders: [const OrderOption(type: OrderOptionType.createDate)]),
    );
    if (albums.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    _album = albums.first;
    await _loadMore();
  }

  Future<void> _loadMore() async {
    final album = _album;
    if (album == null || !_more) return;
    _more = false;
    final list = await album.getAssetListPaged(page: _page, size: _pageSize);
    if (!mounted) return;
    setState(() {
      _assets.addAll(list);
      _loading = false;
      _page++;
      _more = list.length == _pageSize;
    });
  }

  void _toggle(AssetEntity a) => setState(() {
        if (!_selected.remove(a)) _selected.add(a);
      });

  Future<void> _confirm() async {
    setState(() => _working = true);
    final paths = <String>[];
    for (final a in _selected) {
      final bytes = await a.thumbnailDataWithSize(
        const ThumbnailSize(2800, 2800),
        format: ThumbnailFormat.jpeg,
        quality: 92,
      );
      if (bytes == null) continue;
      final f = File(p.join(widget.dir, 'gal_${DateTime.now().microsecondsSinceEpoch}.jpg'));
      await f.writeAsBytes(bytes);
      paths.add(f.path);
    }
    if (mounted) Navigator.pop(context, paths);
  }

  @override
  Widget build(BuildContext context) {
    final n = _selected.length;
    return Scaffold(
      appBar: AppBar(title: Text(n == 0 ? 'Choose images' : '$n selected')),
      body: _denied
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('No permission to access photos.', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: PhotoManager.openSetting, child: const Text('Open settings')),
                ]),
              ),
            )
          : _loading
              ? const Center(child: CircularProgressIndicator(color: kScanColor))
              : _assets.isEmpty
                  ? const Center(child: Text('No images'))
                  : GridView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.only(bottom: 96),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 2,
                        crossAxisSpacing: 2,
                      ),
                      itemCount: _assets.length,
                      itemBuilder: (context, i) {
                        final a = _assets[i];
                        final idx = _selected.indexOf(a);
                        return GestureDetector(
                          onTap: () => _toggle(a),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image(
                                image: AssetEntityImageProvider(
                                  a,
                                  isOriginal: false,
                                  thumbnailSize: const ThumbnailSize.square(300),
                                ),
                                fit: BoxFit.cover,
                              ),
                              if (idx >= 0) Container(color: kScanColor.withValues(alpha: 0.3)),
                              Positioned(
                                left: 6,
                                top: 6,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: idx >= 0 ? kScanColor : Colors.black26,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: idx >= 0
                                      ? Text('${idx + 1}',
                                          style: const TextStyle(
                                              color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: n == 0
          ? null
          : _working
              ? const CircularProgressIndicator(color: kScanColor)
              : FloatingActionButton.extended(
                  backgroundColor: kScanColor,
                  foregroundColor: Colors.white,
                  onPressed: _confirm,
                  icon: const Icon(Icons.add),
                  label: Text('Add ($n)'),
                ),
    );
  }
}
