import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

import '../../core/session.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
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
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(AlcoveSpace.s5, 0, AlcoveSpace.s5, AlcoveSpace.s5),
            children: [
              Text(l.details, style: context.text.titleLarge),
              const SizedBox(height: AlcoveSpace.s3),
              for (final (label, value) in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AlcoveSpace.s2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 112,
                        child: Text(
                          label,
                          style: TextStyle(
                            color: context.colors.textMuted,
                            fontSize: AlcoveFont.sizeSm,
                          ),
                        ),
                      ),
                      Expanded(
                        child: SelectableText(
                          value,
                          style: const TextStyle(fontWeight: AlcoveFont.medium),
                        ),
                      ),
                    ],
                  ),
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
              const Center(child: CircularProgressIndicator())
            else
              PageView.builder(
                controller: _pages,
                itemCount: widget.items.length,
                onPageChanged: (i) => setState(() => _index = i),
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
                  return GestureDetector(
                    onTap: _toggleChrome,
                    child: InteractiveViewer(
                      maxScale: 5,
                      child: Center(
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
                                    style: TextStyle(
                                      color: colors.onStage,
                                      fontWeight: AlcoveFont.semibold,
                                      fontSize: AlcoveFont.sizeMd,
                                    ),
                                  ),
                                  if (taken != null)
                                    Text(
                                      '${DateFormat.Hm(locale).format(taken)} · ${item.name}',
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
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: AlcoveSpace.s4),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: AlcoveSpace.s2),
                          decoration: BoxDecoration(
                            color: colors.stagePanel.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(AlcoveRadius.full),
                            border: Border.all(color: colors.stageBorder),
                          ),
                          child: IconTheme(
                            data: IconThemeData(color: colors.onStage),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
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
            ),
          ],
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
    if (!_ready) return const Center(child: CircularProgressIndicator());
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
