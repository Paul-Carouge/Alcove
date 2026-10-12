import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

import '../../core/session.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import 'media.dart';

/// Full-screen photos and videos, swiped left and right, with details and favorites.
class PhotoViewer extends StatefulWidget {
  const PhotoViewer({
    super.key,
    required this.session,
    required this.items,
    required this.initial,
    this.onChanged,
  });

  final Session session;
  final List<MediaItem> items;
  final int initial;
  final VoidCallback? onChanged;

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late final PageController _pages = PageController(initialPage: widget.initial);
  late int _index = widget.initial;
  String _token = '';

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
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(AlcoveSpace.s5, 0, AlcoveSpace.s5, AlcoveSpace.s5),
          children: [
            Text(l.details, style: Theme.of(context).textTheme.titleMedium),
            for (final (label, value) in rows) ...[
              const SizedBox(height: AlcoveSpace.s3),
              Text(
                label,
                style: TextStyle(color: context.colors.textMuted, fontSize: AlcoveFont.sizeXs),
              ),
              SelectableText(value),
            ],
          ],
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.colors;
    final item = _item;
    return Scaffold(
      backgroundColor: colors.stage,
      appBar: AppBar(
        backgroundColor: colors.stage,
        foregroundColor: colors.onStage,
        title: Text(item.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: item.favorite ? l.favoriteRemove : l.favoriteAdd,
            onPressed: _toggleFavorite,
            icon: Icon(
              item.favorite ? Icons.favorite : Icons.favorite_border,
              color: item.favorite ? colors.favorite : null,
            ),
          ),
          IconButton(tooltip: l.details, onPressed: _details, icon: const Icon(Icons.info_outline)),
        ],
      ),
      body: _token.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : PageView.builder(
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
                return InteractiveViewer(
                  maxScale: 5,
                  child: Center(
                    child: url == null
                        ? Icon(Icons.image_outlined, color: colors.onStageMuted, size: 48)
                        : Image.network(
                            url.toString(),
                            fit: BoxFit.contain,
                            semanticLabel: it.name,
                            loadingBuilder: (_, child, progress) => progress == null
                                ? child
                                : const Center(child: CircularProgressIndicator()),
                          ),
                  ),
                );
              },
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
