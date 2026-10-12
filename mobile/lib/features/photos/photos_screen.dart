import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/session.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import 'media.dart';
import 'photo_viewer.dart';

/// The timeline: photos and videos grouped by month, newest first.
class PhotosScreen extends StatefulWidget {
  const PhotosScreen({super.key, required this.session});

  final Session session;

  @override
  State<PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends State<PhotosScreen> {
  static const _pageSize = 120;
  final _scroll = ScrollController();
  final List<MediaItem> _items = [];
  int _page = 0;
  int _total = -1;
  bool _loading = false;
  bool _failed = false;
  String _token = '';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 1200) _loadMore();
    });
    _reload();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    _items.clear();
    _page = 0;
    _total = -1;
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || (_total >= 0 && _items.length >= _total)) return;
    setState(() => _loading = true);
    try {
      final pb = widget.session.pb;
      _token = await widget.session.fileToken();
      final res = await pb
          .collection('media')
          .getList(
            page: _page + 1,
            perPage: _pageSize,
            filter: 'node.trashed_at = ""',
            sort: '-taken_at,-id',
            expand: 'node',
          );
      _items.addAll(res.items.map(MediaItem.new));
      _page = res.page;
      _total = res.totalItems;
      _failed = false;
    } catch (_) {
      _failed = true;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _open(MediaItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PhotoViewer(
          session: widget.session,
          items: _items,
          initial: _items.indexOf(item),
          onChanged: () => setState(() {}),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.colors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 900 ? 6 : (width >= 600 ? 5 : 3);

    final slivers = <Widget>[
      SliverAppBar.large(title: Text(l.tabPhotos)),
      if (_failed && _items.isEmpty)
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: TextButton(onPressed: _reload, child: Text(l.loadFailed)),
          ),
        )
      else if (!_loading && _items.isEmpty && _total == 0)
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.all(AlcoveSpace.s6),
            child: Center(
              child: Text(
                l.photosEmpty,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textMuted),
              ),
            ),
          ),
        ),
    ];
    for (final (key, items) in groupByMonth(_items)) {
      final parts = key.split('-');
      final label = parts[0] == '0000'
          ? ''
          : toBeginningOfSentenceCase(
              DateFormat.yMMMM(locale).format(DateTime(int.parse(parts[0]), int.parse(parts[1]))),
            );
      slivers
        ..add(
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AlcoveSpace.s4,
                AlcoveSpace.s5,
                AlcoveSpace.s4,
                AlcoveSpace.s2,
              ),
              child: Semantics(
                header: true,
                child: Text(label, style: Theme.of(context).textTheme.titleMedium),
              ),
            ),
          ),
        )
        ..add(
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AlcoveSpace.s1),
            sliver: SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
              ),
              itemCount: items.length,
              itemBuilder: (_, i) => _Tile(
                item: items[i],
                url: items[i].thumbUrl(widget.session.pb, _token),
                onTap: () => _open(items[i]),
              ),
            ),
          ),
        );
    }
    if (_loading) {
      slivers.add(
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(AlcoveSpace.s5),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: CustomScrollView(controller: _scroll, slivers: slivers),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.item, required this.url, required this.onTap});

  final MediaItem item;
  final Uri? url;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.colors;
    return Semantics(
      button: true,
      label: l.openPhoto(item.name),
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: colors.surfaceSunken),
            if (url != null)
              Image.network(
                url.toString(),
                fit: BoxFit.cover,
                cacheWidth: 360,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) =>
                    Icon(Icons.broken_image_outlined, color: colors.textMuted),
              )
            else
              Center(
                child: item.isReady
                    ? Icon(Icons.image_outlined, color: colors.textMuted)
                    : const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
              ),
            if (item.isVideo)
              Positioned(
                right: AlcoveSpace.s1,
                bottom: AlcoveSpace.s1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.stageScrim,
                    borderRadius: BorderRadius.circular(AlcoveRadius.full),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AlcoveSpace.s2, vertical: 1),
                    child: Text(
                      formatDuration(item.duration),
                      style: TextStyle(color: colors.onStage, fontSize: AlcoveFont.sizeXs),
                    ),
                  ),
                ),
              ),
            if (item.favorite)
              Positioned(
                top: AlcoveSpace.s1,
                right: AlcoveSpace.s1,
                child: Icon(Icons.favorite, size: 18, color: colors.favorite),
              ),
          ],
        ),
      ),
    );
  }
}
