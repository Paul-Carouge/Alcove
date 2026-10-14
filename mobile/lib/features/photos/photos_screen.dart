import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/session.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../ui/remote_image.dart';
import '../backup/backup_controller.dart';
import 'media.dart';
import 'photo_viewer.dart';

/// The timeline: photos and videos grouped by month (headers stay pinned), newest first.
class PhotosScreen extends StatefulWidget {
  const PhotosScreen({super.key, required this.session, this.backup, this.onOpenBackup});

  final Session session;
  final BackupController? backup;
  final VoidCallback? onOpenBackup;

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

  /// Columns added or removed by pinching the grid.
  int _density = 0;
  final Map<int, Offset> _pointers = {};
  double _pinchStart = 0;

  /// "1 year ago today" groups.
  List<(int, int, List<MediaItem>)> _memories = []; // years ago, year, items

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 1200) _loadMore();
    });
    _reload();
    _loadMemories();
  }

  Future<void> _loadMemories() async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final res = await widget.session.pb.send<Map<String, dynamic>>(
        '/api/v1/photos/memories',
        query: {'date': today},
      );
      final list = [
        for (final g
            in (res['memories'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>())
          (
            (g['yearsAgo'] as num).toInt(),
            (g['year'] as num).toInt(),
            [
              for (final it in (g['items'] as List<dynamic>).cast<Map<String, dynamic>>())
                MediaItem(RecordModel.fromJson(it)),
            ],
          ),
      ];
      if (mounted) setState(() => _memories = list.where((g) => g.$3.isNotEmpty).toList());
    } catch (_) {
      // Memories are a bonus: the timeline works without them.
    }
  }

  // Two fingers apart: bigger photos (fewer columns); together: more columns. A raw Listener does not
  // take part in the gesture arena, so scrolling keeps working.
  void _pointerMove(PointerEvent e) {
    _pointers[e.pointer] = e.position;
    if (_pointers.length != 2) return;
    final pts = _pointers.values.toList();
    final d = (pts[0] - pts[1]).distance;
    if (_pinchStart == 0) {
      _pinchStart = d;
      return;
    }
    final ratio = d / _pinchStart;
    if (ratio > 1.3 || ratio < 0.77) {
      setState(() => _density = (_density + (ratio > 1 ? -1 : 1)).clamp(-2, 4));
      _pinchStart = d;
      HapticFeedback.selectionClick();
    }
  }

  void _pointerUp(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.length < 2) _pinchStart = 0;
  }

  void _openMemory(List<MediaItem> items) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PhotoViewer(
          session: widget.session,
          items: items,
          initial: 0,
          onChanged: () => setState(() {}),
        ),
      ),
    );
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
      _token = await widget.session.fileToken();
      final res = await widget.session.pb
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
          onTrashed: (item) => setState(() {
            _items.remove(item);
            _total -= 1;
          }),
        ),
      ),
    );
  }

  int _columns(double width) =>
      ((width >= 900 ? 6 : (width >= 600 ? 5 : 3)) + _density).clamp(2, 8);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final columns = _columns(MediaQuery.sizeOf(context).width);

    final slivers = <Widget>[
      LargeTitleAppBar(
        title: l.tabPhotos,
        actions: [
          if (widget.backup case final c?)
            ListenableBuilder(
              listenable: c,
              builder: (context, _) => _BackupChip(controller: c, onTap: widget.onOpenBackup),
            ),
        ],
      ),
    ];

    if (_memories.isNotEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: _Memories(
            groups: _memories,
            thumb: (it) => it.thumbUrl(widget.session.pb, _token),
            onOpen: _openMemory,
          ),
        ),
      );
    }

    if (_failed && _items.isEmpty) {
      slivers.add(
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.cloud_off_outlined,
            title: l.loadFailed,
            action: OutlinedButton(onPressed: _reload, child: Text(l.retry)),
          ),
        ),
      );
    } else if (_items.isEmpty && _total == 0) {
      slivers.add(
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.photo_library_outlined,
            title: l.photosEmptyTitle,
            body: l.photosEmpty,
            action: widget.onOpenBackup == null
                ? null
                : FilledButton.icon(
                    onPressed: widget.onOpenBackup,
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: Text(l.backupTitle),
                  ),
          ),
        ),
      );
    } else if (_items.isEmpty) {
      slivers.add(_skeleton(columns));
    }

    for (final (key, items) in groupByMonth(_items)) {
      final parts = key.split('-');
      final date = parts[0] == '0000' ? null : DateTime(int.parse(parts[0]), int.parse(parts[1]));
      slivers.add(
        SliverMainAxisGroup(
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _MonthHeader(
                month: date == null
                    ? ''
                    : toBeginningOfSentenceCase(DateFormat.MMMM(locale).format(date)),
                year: date == null || date.year == DateTime.now().year ? '' : '${date.year}',
                count: items.length,
                background: context.colors.bg,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AlcoveSpace.s2),
              sliver: SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 3,
                  crossAxisSpacing: 3,
                ),
                itemCount: items.length,
                itemBuilder: (_, i) => MediaTile(
                  item: items[i],
                  url: items[i].thumbUrl(widget.session.pb, _token),
                  onTap: () => _open(items[i]),
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (_loading && _items.isNotEmpty) {
      slivers.add(
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(AlcoveSpace.s5),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
          ),
        ),
      );
    }
    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: AlcoveSpace.s7)));

    return Listener(
      onPointerDown: (e) => _pointers[e.pointer] = e.position,
      onPointerMove: _pointerMove,
      onPointerUp: _pointerUp,
      onPointerCancel: _pointerUp,
      child: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([_reload(), _loadMemories()]);
        },
        edgeOffset: 120,
        child: CustomScrollView(controller: _scroll, slivers: slivers),
      ),
    );
  }

  Widget _skeleton(int columns) => SliverPadding(
    padding: const EdgeInsets.fromLTRB(AlcoveSpace.s2, AlcoveSpace.s5, AlcoveSpace.s2, 0),
    sliver: SliverGrid.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 3,
        crossAxisSpacing: 3,
      ),
      itemCount: columns * 6,
      itemBuilder: (_, _) => const Skeleton(),
    ),
  );
}

/// Month name (and year when not this year), pinned while its photos scroll.
class _MonthHeader extends SliverPersistentHeaderDelegate {
  _MonthHeader({
    required this.month,
    required this.year,
    required this.count,
    required this.background,
  });

  final String month;
  final String year;
  final int count;
  final Color background;

  @override
  double get minExtent => 52;

  @override
  double get maxExtent => 52;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final c = context.colors;
    return Container(
      color: background.withValues(alpha: overlapsContent ? 0.94 : 1),
      padding: const EdgeInsets.fromLTRB(
        AlcoveSpace.s4,
        AlcoveSpace.s3,
        AlcoveSpace.s4,
        AlcoveSpace.s2,
      ),
      alignment: Alignment.bottomLeft,
      child: Semantics(
        header: true,
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: month, style: context.text.titleMedium),
              if (year.isNotEmpty)
                TextSpan(
                  text: '  $year',
                  style: context.text.titleMedium?.copyWith(
                    color: c.textMuted,
                    fontWeight: AlcoveFont.medium,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_MonthHeader old) =>
      old.month != month || old.year != year || old.count != count || old.background != background;
}

/// Backup state at a glance, in the app bar.
class _BackupChip extends StatelessWidget {
  const _BackupChip({required this.controller, this.onTap});

  final BackupController controller;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final on = controller.state.enabled;
    final running = controller.running;
    final p = controller.progress;
    final (icon, color) = !on
        ? (Icons.cloud_off_outlined, c.textMuted)
        : running
        ? (Icons.cloud_sync_outlined, c.accent)
        : (Icons.cloud_done_outlined, c.success);
    return Tooltip(
      message: l.backupTitle,
      child: Material(
        color: c.surface,
        shape: StadiumBorder(side: BorderSide(color: c.border)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AlcoveSpace.s3,
              vertical: AlcoveSpace.s2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: color),
                if (running && p != null && p.total > 0) ...[
                  const SizedBox(width: AlcoveSpace.s2),
                  Text(
                    '${p.processed}/${p.total}',
                    style: TextStyle(
                      fontSize: AlcoveFont.sizeXs,
                      fontWeight: AlcoveFont.semibold,
                      color: c.text,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MediaTile extends StatelessWidget {
  const MediaTile({super.key, required this.item, required this.url, required this.onTap});

  final MediaItem item;
  final Uri? url;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return Semantics(
      button: true,
      label: l.openPhoto(item.name),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AlcoveRadius.sm - 2),
        child: Material(
          color: c.surfaceSunken,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (url != null)
                  RemoteImage(url: url!, cacheWidth: 360)
                else
                  Center(
                    child: item.isReady
                        ? Icon(Icons.image_outlined, color: c.textMuted)
                        : const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                  ),
                if (item.isVideo)
                  Positioned(
                    right: AlcoveSpace.s1 + 2,
                    bottom: AlcoveSpace.s1 + 2,
                    child: _Pill(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_arrow_rounded, size: 14, color: c.onStage),
                          Text(
                            formatDuration(item.duration),
                            style: TextStyle(
                              color: c.onStage,
                              fontSize: 11,
                              fontWeight: AlcoveFont.semibold,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (item.favorite)
                  Positioned(
                    top: AlcoveSpace.s1 + 2,
                    right: AlcoveSpace.s1 + 2,
                    child: Icon(
                      Icons.favorite,
                      size: 18,
                      color: c.favorite,
                      shadows: const [Shadow(blurRadius: 4, color: Color(0x66000000))],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.colors.stageScrim,
      borderRadius: BorderRadius.circular(AlcoveRadius.full),
    ),
    child: Padding(padding: const EdgeInsets.fromLTRB(4, 2, 7, 2), child: child),
  );
}

/// "1 year ago today": one card per year, opening its photos.
class _Memories extends StatelessWidget {
  const _Memories({required this.groups, required this.thumb, required this.onOpen});

  final List<(int, int, List<MediaItem>)> groups;
  final Uri? Function(MediaItem) thumb;
  final void Function(List<MediaItem>) onOpen;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AlcoveSpace.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AlcoveSpace.s4, 0, AlcoveSpace.s4, AlcoveSpace.s2),
            child: Text(l.memories, style: context.text.titleMedium),
          ),
          SizedBox(
            height: 176,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AlcoveSpace.s4),
              itemCount: groups.length,
              separatorBuilder: (_, _) => const SizedBox(width: AlcoveSpace.s3),
              itemBuilder: (context, i) {
                final (ago, year, items) = groups[i];
                final url = thumb(items.first);
                return Semantics(
                  button: true,
                  label: l.yearsAgo(ago),
                  child: GestureDetector(
                    onTap: () => onOpen(items),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AlcoveRadius.lg),
                      child: SizedBox(
                        width: 128,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ColoredBox(color: c.surfaceSunken),
                            if (url != null) RemoteImage(url: url, cacheWidth: 384),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.center,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    c.stage.withValues(alpha: 0),
                                    c.stage.withValues(alpha: 0.75),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              left: AlcoveSpace.s3,
                              right: AlcoveSpace.s3,
                              bottom: AlcoveSpace.s3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l.yearsAgo(ago),
                                    style: TextStyle(
                                      color: c.onStage,
                                      fontWeight: AlcoveFont.semibold,
                                      fontSize: AlcoveFont.sizeMd,
                                    ),
                                  ),
                                  Text(
                                    '$year · ${items.length}',
                                    style: TextStyle(
                                      color: c.onStageMuted,
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
