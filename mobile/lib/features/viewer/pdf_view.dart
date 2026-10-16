import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/native_files.dart';
import '../../core/previews.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/expressive.dart';
import '../../ui/kit.dart';

/// Rendered PDF pages by page and width, least recently used first, within [maxBytes]. The pages
/// next to the one being read (±1) are never evicted, so two large visible pages can't keep
/// pushing each other out (and being rendered again forever).
class PageBitmaps {
  PageBitmaps({this.maxBytes = 48 * 1000 * 1000});

  final int maxBytes;
  final _map = <(int, int), Uint8List>{};
  int _bytes = 0;

  /// Renders in progress, so a page is never asked twice at once.
  final rendering = <(int, int)>{};

  int get bytes => _bytes;
  Iterable<(int, int)> get keys => _map.keys;

  bool has(int page, int width) => _map.containsKey((page, width));

  /// The bitmap at [width], or any other width of the page while the right one renders.
  Uint8List? best(int page, int width) {
    final exact = _map.remove((page, width));
    if (exact != null) {
      _map[(page, width)] = exact; // now the most recent
      return exact;
    }
    for (final e in _map.entries) {
      if (e.key.$1 == page) return e.value;
    }
    return null;
  }

  void put(int page, int width, Uint8List png, {required int current}) {
    final old = _map.remove((page, width));
    if (old != null) _bytes -= old.length;
    _map[(page, width)] = png;
    _bytes += png.length;
    if (_bytes <= maxBytes) return;
    for (final key in _map.keys.toList()) {
      if (_bytes <= maxBytes) break;
      if ((key.$1 - current).abs() <= 1) continue; // on screen: kept
      _bytes -= _map.remove(key)!.length;
    }
  }
}

/// The visible page of a [PdfView], and a way to jump to another one.
class PdfController extends ChangeNotifier {
  int _page = 0;
  int _count = 0;
  void Function(int page)? _jump;

  /// 0-based.
  int get page => _page;
  int get count => _count;

  void _set(int page, int count) {
    if (page == _page && count == _count) return;
    _page = page;
    _count = count;
    notifyListeners();
  }

  void jumpTo(int page) => _jump?.call(page.clamp(0, math.max(0, _count - 1)));
}

/// A PDF drawn by the system's PdfRenderer (Android), page by page as you scroll: each visible
/// page is rendered at the width it is shown (sharper when zoomed), cached, and dropped when far.
/// Pinch or double tap to zoom; zoomed pages pan sideways.
class PdfView extends StatefulWidget {
  const PdfView({super.key, required this.file, required this.controller, this.native});

  final File file;
  final PdfController controller;
  final NativeFiles? native;

  @override
  State<PdfView> createState() => _PdfViewState();
}

class _PdfViewState extends State<PdfView> {
  static const _gap = AlcoveSpace.s3;
  static const _pad = AlcoveSpace.s3;
  static const _maxScale = 5.0;

  NativeFiles get _native => widget.native ?? NativeFiles.instance;
  PdfInfo? _info;
  bool _failed = false;
  final _v = ScrollController();
  final _h = ScrollController();

  /// Committed zoom (layout), and the live factor on top of it while pinching.
  double _scale = 1;
  double _live = 1;
  Offset _focal = Offset.zero;
  final Map<int, Offset> _pointers = {};
  double _pinchStart = 0;
  double _viewport = 0;
  double _viewportH = 0;
  Offset _tapAt = Offset.zero;

  final _bitmaps = PageBitmaps();

  /// Pages on screen (and their neighbours) with the width they want.
  final Map<int, int> _wanted = {};
  bool _rendering = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    widget.controller._jump = _jumpTo;
    _v.addListener(_track);
    _open();
  }

  Future<void> _open() async {
    try {
      final info = await _native.pdfOpen(widget.file.path);
      if (_disposed) {
        unawaited(_native.pdfClose(info.id).catchError((Object _) {}));
        return;
      }
      setState(() => _info = info);
      widget.controller._set(0, info.pages.length);
    } catch (_) {
      if (!_disposed) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    widget.controller._jump = null;
    final info = _info;
    if (info != null) unawaited(_native.pdfClose(info.id).catchError((Object _) {}));
    _v.dispose();
    _h.dispose();
    super.dispose();
  }

  double get _pageWidth => math.max(0, _viewport - 2 * _pad) * _scale;

  List<double> _heights(double width) => [
    for (final s in _info!.pages) s.width <= 0 ? width : width * s.height / s.width,
  ];

  List<double> _tops(List<double> heights) {
    final out = <double>[];
    var y = _pad;
    for (final h in heights) {
      out.add(y);
      y += h + _gap;
    }
    return out;
  }

  void _track() {
    final info = _info;
    if (info == null || !_v.hasClients) return;
    final tops = _tops(_heights(_pageWidth));
    widget.controller._set(pageAt(tops, _v.offset, _viewportH), info.pages.length);
  }

  void _jumpTo(int page) {
    if (_info == null || !_v.hasClients) return;
    final tops = _tops(_heights(_pageWidth));
    _v.jumpTo((tops[page] - _pad).clamp(0, _v.position.maxScrollExtent));
  }

  // -- Zoom ----------------------------------------------------------------------------------

  void _pointerDown(PointerDownEvent e) {
    _pointers[e.pointer] = e.localPosition;
    if (_pointers.length == 2) {
      final p = _pointers.values.toList();
      _pinchStart = (p[0] - p[1]).distance;
      _focal = (p[0] + p[1]) / 2;
      setState(() {}); // stops the list scrolling while pinching
    }
  }

  void _pointerMove(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.localPosition;
    if (_pointers.length != 2 || _pinchStart <= 0) return;
    final p = _pointers.values.toList();
    final d = (p[0] - p[1]).distance;
    final target = (_scale * d / _pinchStart).clamp(1.0, _maxScale);
    setState(() => _live = target / _scale);
  }

  void _pointerUp(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.length < 2 && _pinchStart > 0) {
      _pinchStart = 0;
      _commit(_scale * _live, _focal);
    }
  }

  /// Applies a new zoom to the layout, keeping the point under [focal] where it was.
  void _commit(double next, Offset focal) {
    final info = _info;
    if (info == null || !_v.hasClients) {
      setState(() => _live = 1);
      return;
    }
    next = next.clamp(1.0, _maxScale);
    final oldHeights = _heights(_pageWidth);
    final oldTops = _tops(oldHeights);
    final y = _v.offset + focal.dy;
    final i = pageAt(oldTops, y - _viewportH / 3, _viewportH);
    final within = oldHeights[i] <= 0 ? 0.0 : ((y - oldTops[i]) / oldHeights[i]);
    final x = (_h.hasClients ? _h.offset : 0) + focal.dx;
    final old = _scale;
    setState(() {
      _scale = next;
      _live = 1;
    });
    final newHeights = _heights(_pageWidth);
    final newTops = _tops(newHeights);
    final ny = newTops[i] + within * newHeights[i] - focal.dy;
    final nx = x / old * next - focal.dx;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) return;
      if (_v.hasClients) _v.jumpTo(ny.clamp(0, _v.position.maxScrollExtent));
      if (_h.hasClients) _h.jumpTo(nx.clamp(0, _h.position.maxScrollExtent));
    });
  }

  void _doubleTap() {
    HapticFeedback.selectionClick();
    _commit(_scale > 1.05 ? 1 : 2.5, _tapAt);
  }

  // -- Rendering -----------------------------------------------------------------------------

  void _want(int page, int width) {
    if (_bitmaps.has(page, width) || _bitmaps.rendering.contains((page, width))) return;
    _wanted[page] = width;
    if (!_rendering) unawaited(_pump());
  }

  Future<void> _pump() async {
    _rendering = true;
    try {
      while (!_disposed && _wanted.isNotEmpty) {
        final info = _info!;
        // Closest to the page being read first; the rest may have scrolled away by then.
        final current = widget.controller.page;
        final page = _wanted.keys.reduce(
          (a, b) => (a - current).abs() <= (b - current).abs() ? a : b,
        );
        final width = _wanted.remove(page)!;
        if ((page - current).abs() > 3 || _bitmaps.has(page, width)) continue;
        _bitmaps.rendering.add((page, width));
        try {
          final png = await _native.pdfRender(info.id, page, width);
          if (_disposed) return;
          _bitmaps.put(page, width, png, current: widget.controller.page);
          setState(() {});
        } catch (_) {
          // A page that fails stays blank; the others go on.
        } finally {
          _bitmaps.rendering.remove((page, width));
        }
      }
    } finally {
      _rendering = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final info = _info;
    if (_failed) {
      return EmptyState(
        icon: Icons.picture_as_pdf_outlined,
        title: l.pdfCannotShow,
        body: l.viewerNoPreviewBody,
      );
    }
    if (info == null) return const Center(child: LoadingIndicator());
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final pinching = _pointers.length >= 2;
    return LayoutBuilder(
      builder: (context, box) {
        _viewport = box.maxWidth;
        _viewportH = box.maxHeight;
        final width = _pageWidth;
        final heights = _heights(width);
        final bitmapWidth = renderWidth(width, ratio);
        final bottom = MediaQuery.paddingOf(context).bottom;
        final list = ListView.builder(
          controller: _v,
          physics: pinching ? const NeverScrollableScrollPhysics() : null,
          padding: EdgeInsets.fromLTRB(_pad * _scale, _pad, _pad * _scale, _pad + bottom),
          itemCount: info.pages.length,
          itemExtentBuilder: (i, _) => heights[i] + _gap,
          itemBuilder: (context, i) {
            _want(i, bitmapWidth);
            final png = _bitmaps.best(i, bitmapWidth);
            return Padding(
              padding: const EdgeInsets.only(bottom: _gap),
              child: Semantics(
                label: l.pdfPage(i + 1, info.pages.length),
                image: true,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.surface,
                    boxShadow: c.shadowSM,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: png == null
                      ? Center(
                          child: Text(
                            '${i + 1}',
                            style: displayStyle(AlcoveFont.sizeXl, c.border),
                          ),
                        )
                      : Image.memory(
                          png,
                          fit: BoxFit.fill,
                          gaplessPlayback: true,
                          filterQuality: FilterQuality.medium,
                        ),
                ),
              ),
            );
          },
        );
        return Listener(
          onPointerDown: _pointerDown,
          onPointerMove: _pointerMove,
          onPointerUp: _pointerUp,
          onPointerCancel: _pointerUp,
          child: GestureDetector(
            onDoubleTapDown: (d) => _tapAt = d.localPosition,
            onDoubleTap: _doubleTap,
            child: ClipRect(
              child: Transform.scale(
                scale: _live,
                origin: _focal - Offset(box.maxWidth / 2, box.maxHeight / 2),
                child: Scrollbar(
                  controller: _v,
                  notificationPredicate: (n) => n.metrics.axis == Axis.vertical,
                  child: SingleChildScrollView(
                    controller: _h,
                    scrollDirection: Axis.horizontal,
                    physics: _scale <= 1 || pinching ? const NeverScrollableScrollPhysics() : null,
                    child: SizedBox(width: box.maxWidth * _scale, child: list),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
