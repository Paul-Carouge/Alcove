import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';

import '../../core/session.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/expressive.dart';
import '../../ui/kit.dart';
import '../../ui/remote_image.dart';
import 'media.dart';

/// Full-screen photos and videos, swiped left and right, with details and favorites.
class PhotoViewer extends StatefulWidget {
  const PhotoViewer({
    super.key,
    required this.session,
    required this.items,
    required this.initial,
    this.onChanged,
    this.onTrashed,
  });

  final Session session;
  final List<MediaItem> items;
  final int initial;
  final VoidCallback? onChanged;

  /// Set where items can be moved to the trash (the timeline); called after it succeeded.
  final void Function(MediaItem item)? onTrashed;

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late final PageController _pages = PageController(initialPage: widget.initial);
  late int _index = widget.initial;
  String _token = '';
  bool _chrome = true;
  bool _zoomed = false; // the page cannot be swiped while a photo is zoomed in
  bool _saving = false;

  MediaItem get _item => widget.items[_index];

  @override
  void initState() {
    super.initState();
    widget.session.fileToken().then((t) {
      if (mounted) setState(() => _token = t);
    });
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pages.dispose();
    super.dispose();
  }

  Future<void> _toggleFavorite() async {
    final item = _item;
    final next = !item.favorite;
    setState(() => item.favorite = next);
    try {
      await widget.session.pb.send<dynamic>(
        '/api/v1/media/${Uri.encodeComponent(item.id)}/favorite',
        method: 'PUT',
        body: {'favorite': next},
      );
      widget.onChanged?.call();
    } catch (_) {
      if (mounted) setState(() => item.favorite = !next);
    }
  }

  bool _mine(MediaItem item) => item.record.getStringValue('owner') == widget.session.user?.id;

  Future<void> _trash() async {
    final l = AppLocalizations.of(context);
    final item = _item;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.trashTitle),
        content: Text(l.trashBody(item.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.trashConfirm)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.session.pb
          .collection('nodes')
          .update(
            item.record.getStringValue('node'),
            body: {'trashed_at': DateTime.now().toUtc().toIso8601String()},
          );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.errorUnexpected)));
      }
      return;
    }
    widget.onTrashed?.call(item);
    if (!mounted) return;
    if (widget.items.isEmpty) {
      Navigator.of(context).pop();
    } else {
      setState(() => _index = _index.clamp(0, widget.items.length - 1));
    }
  }

  void _details() {
    final l = AppLocalizations.of(context);
    final item = _item;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final taken = item.takenAt;
    final rows = <(String, String)>[
      if (taken != null) (l.detailTaken, DateFormat.yMMMMEEEEd(locale).add_Hm().format(taken)),
      (l.detailFile, item.size > 0 ? '${item.name}\n${_size(item.size, locale)}' : item.name),
      if (item.width > 0) (l.detailDimensions, '${item.width} × ${item.height}'),
      if (item.isVideo && item.duration > 0) (l.detailDuration, formatDuration(item.duration)),
      if (item.camera.isNotEmpty) (l.detailCamera, item.camera),
      if (item.lens.isNotEmpty) (l.detailLens, item.lens),
      if (item.exposure.isNotEmpty) (l.detailSettings, item.exposure),
      if (item.hasLocation)
        (l.detailLocation, '${item.lat.toStringAsFixed(5)}, ${item.lon.toStringAsFixed(5)}'),
    ];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: AlcoveSpace.s2),
            children: [
              SheetHeader(title: l.details),
              InsetGroup(
                children: [
                  for (final (label, value) in rows)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AlcoveSpace.s4,
                        vertical: AlcoveSpace.s3,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              color: context.colors.textMuted,
                              fontSize: AlcoveFont.sizeXs + 1,
                              fontWeight: AlcoveFont.medium,
                            ),
                          ),
                          const SizedBox(height: 2),
                          SelectableText(
                            value,
                            style: const TextStyle(
                              fontSize: AlcoveFont.sizeMd,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _size(int bytes, String locale) {
    const units = ['B', 'KB', 'MB', 'GB'];
    var v = bytes.toDouble();
    var u = 0;
    while (v >= 1000 && u < units.length - 1) {
      v /= 1000;
      u++;
    }
    return '${NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: u == 0 ? 0 : 1).format(v)} ${units[u]}';
  }

  /// Saves the original to the phone's gallery (Pictures/Alcove or Movies/Alcove).
  Future<void> _saveToPhone() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final item = _item;
    setState(() => _saving = true);
    try {
      final perm = await PhotoManager.requestPermissionExtend(
        requestOption: const PermissionRequestOption(
          androidPermission: AndroidPermission(type: RequestType.common, mediaLocation: false),
        ),
      );
      if (!perm.hasAccess) throw StateError('no access');
      final token = await widget.session.fileToken();
      final res = await http.get(item.originalUrl(widget.session.pb, token));
      if (res.statusCode != 200) throw StateError('HTTP ${res.statusCode}');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${item.id}-${item.name.replaceAll('/', '_')}');
      await file.writeAsBytes(res.bodyBytes);
      try {
        if (item.isVideo) {
          await PhotoManager.editor.saveVideo(
            file,
            title: item.name,
            relativePath: 'Movies/Alcove',
          );
        } else {
          await PhotoManager.editor.saveImageWithPath(
            file.path,
            title: item.name,
            relativePath: 'Pictures/Alcove',
          );
        }
      } finally {
        await file.delete().catchError((Object _) => file);
      }
      messenger.showSnackBar(SnackBar(content: Text(l.savedToPhone)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.saveToPhoneFailed)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toggleChrome() {
    setState(() => _chrome = !_chrome);
    SystemChrome.setEnabledSystemUIMode(
      _chrome ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.colors;
    final item = _item;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final taken = item.takenAt;
    const fade = Duration(milliseconds: 180);
    final scrim = [colors.stage.withValues(alpha: 0.85), colors.stage.withValues(alpha: 0)];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: colors.stage,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (_token.isEmpty)
              Center(child: LoadingIndicator(color: colors.onStage))
            else
              PageView.builder(
                controller: _pages,
                physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
                itemCount: widget.items.length,
                onPageChanged: (i) => setState(() {
                  _index = i;
                  _zoomed = false;
                }),
                itemBuilder: (_, i) {
                  final it = widget.items[i];
                  final pb = widget.session.pb;
                  if (it.isVideo) {
                    return _VideoPage(
                      key: ValueKey(it.id),
                      url: it.originalUrl(pb, _token),
                      active: i == _index,
                    );
                  }
                  final url = it.previewUrl(pb, _token);
                  return ZoomablePage(
                    key: ValueKey(it.id),
                    onTap: _toggleChrome,
                    onZoomChanged: (z) => setState(() => _zoomed = z),
                    onDismiss: () => Navigator.of(context).maybePop(),
                    child: url == null
                        ? Icon(Icons.image_outlined, color: colors.onStageMuted, size: 48)
                        : RemoteImage(
                            url: url,
                            fit: BoxFit.contain,
                            semanticLabel: it.name,
                            placeholder: Icon(
                              Icons.broken_image_outlined,
                              color: colors.onStageMuted,
                              size: 48,
                            ),
                          ),
                  );
                },
              ),
            // Top bar: back, date and name over a soft gradient.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: !_chrome,
                child: AnimatedOpacity(
                  opacity: _chrome ? 1 : 0,
                  duration: fade,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: scrim,
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AlcoveSpace.s1,
                          AlcoveSpace.s1,
                          AlcoveSpace.s4,
                          AlcoveSpace.s6,
                        ),
                        child: Row(
                          children: [
                            BackButton(color: colors.onStage),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    taken == null
                                        ? item.name
                                        : DateFormat.yMMMMd(locale).format(taken),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: displayStyle(AlcoveFont.sizeLg + 1, colors.onStage),
                                  ),
                                  if (taken != null || widget.items.length > 1)
                                    Text(
                                      [
                                        if (taken != null)
                                          '${DateFormat.Hm(locale).format(taken)} · ${item.name}',
                                        if (widget.items.length > 1)
                                          '${_index + 1} / ${widget.items.length}',
                                      ].join('  ·  '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: colors.onStageMuted,
                                        fontSize: AlcoveFont.sizeXs,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Floating action bar.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                ignoring: !_chrome,
                child: AnimatedOpacity(
                  opacity: _chrome ? 1 : 0,
                  duration: fade,
                  child: AnimatedSlide(
                    offset: _chrome ? Offset.zero : const Offset(0, 0.6),
                    duration: AlcoveSprings.of(context, AlcoveSprings.medium),
                    curve: AlcoveSprings.spatial,
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AlcoveSpace.s4),
                        child: Center(
                          child: FloatingToolbar(
                            color: colors.stagePanel.withValues(alpha: 0.94),
                            foreground: colors.onStage,
                            border: colors.stageBorder,
                            children: [
                              if (_mine(item))
                                IconButton(
                                  tooltip: item.favorite ? l.favoriteRemove : l.favoriteAdd,
                                  onPressed: _toggleFavorite,
                                  icon: Icon(
                                    item.favorite ? Icons.favorite : Icons.favorite_border,
                                    color: item.favorite ? colors.favorite : null,
                                  ),
                                ),
                              IconButton(
                                tooltip: l.details,
                                onPressed: _details,
                                icon: const Icon(Icons.info_outline),
                              ),
                              IconButton(
                                tooltip: l.saveToPhone,
                                onPressed: _saving ? null : _saveToPhone,
                                icon: _saving
                                    ? LoadingIndicator(size: 24, color: colors.onStage)
                                    : const Icon(Icons.download_outlined),
                              ),
                              if (widget.onTrashed != null && _mine(item))
                                IconButton(
                                  tooltip: l.trashConfirm,
                                  onPressed: _trash,
                                  icon: const Icon(Icons.delete_outline),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A photo that zooms (pinch, double tap) and closes when dragged down while not zoomed.
class ZoomablePage extends StatefulWidget {
  const ZoomablePage({
    super.key,
    required this.child,
    this.onTap,
    this.onZoomChanged,
    this.onDismiss,
  });

  final Widget child;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onZoomChanged;
  final VoidCallback? onDismiss;

  @override
  State<ZoomablePage> createState() => ZoomablePageState();
}

class ZoomablePageState extends State<ZoomablePage> with SingleTickerProviderStateMixin {
  final transform = TransformationController();
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  Animation<Matrix4>? _tween;
  Offset _tapAt = Offset.zero;
  double _drag = 0;
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _anim.addListener(() {
      if (_tween != null) transform.value = _tween!.value;
    });
    transform.addListener(() {
      final z = transform.value.getMaxScaleOnAxis() > 1.01;
      if (z != _zoomed) {
        setState(() => _zoomed = z);
        widget.onZoomChanged?.call(z);
      }
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    transform.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    const scale = 2.5;
    final end = _zoomed
        ? Matrix4.identity()
        : (Matrix4.identity()
            ..translateByDouble(-_tapAt.dx * (scale - 1), -_tapAt.dy * (scale - 1), 0, 1)
            ..scaleByDouble(scale, scale, 1, 1));
    _tween = Matrix4Tween(begin: transform.value, end: end).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic),
    );
    _anim.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_drag.abs() / 400).clamp(0.0, 1.0);
    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTapDown: (d) => _tapAt = d.localPosition,
      onDoubleTap: _toggleZoom,
      onVerticalDragUpdate: _zoomed ? null : (d) => setState(() => _drag += d.delta.dy),
      onVerticalDragEnd: _zoomed
          ? null
          : (d) {
              if (_drag > 120 || (d.primaryVelocity ?? 0) > 900) {
                widget.onDismiss?.call();
              } else {
                setState(() => _drag = 0);
              }
            },
      child: Transform.translate(
        offset: Offset(0, _drag > 0 ? _drag : 0),
        child: Opacity(
          opacity: 1 - progress * 0.6,
          child: InteractiveViewer(
            transformationController: transform,
            maxScale: 5,
            panEnabled: _zoomed,
            child: Center(child: widget.child),
          ),
        ),
      ),
    );
  }
}

class _VideoPage extends StatefulWidget {
  const _VideoPage({super.key, required this.url, required this.active});

  final Uri url;
  final bool active;

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  late final VideoPlayerController _controller = VideoPlayerController.networkUrl(widget.url);
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
      if (widget.active) _controller.play();
    });
  }

  @override
  void didUpdateWidget(_VideoPage old) {
    super.didUpdateWidget(old);
    if (!widget.active) _controller.pause();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (!_ready) return Center(child: LoadingIndicator(color: colors.onStage));
    return GestureDetector(
      onTap: () => setState(() {
        _controller.value.isPlaying ? _controller.pause() : _controller.play();
      }),
      child: Center(
        child: AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              VideoPlayer(_controller),
              VideoProgressIndicator(
                _controller,
                allowScrubbing: true,
                colors: VideoProgressColors(playedColor: colors.accent),
              ),
              if (!_controller.value.isPlaying)
                Center(child: Icon(Icons.play_circle_fill, size: 64, color: colors.onStage)),
            ],
          ),
        ),
      ),
    );
  }
}
