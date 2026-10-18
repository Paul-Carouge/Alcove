import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/native_files.dart';
import '../../core/session.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/expressive.dart';
import '../../ui/kit.dart';
import '../../ui/remote_image.dart';
import '../../ui/shell.dart';
import '../backup/backup_controller.dart';
import 'media.dart';
import 'photo_viewer.dart';

/// The timeline: photos and videos grouped by month (headers stay pinned), newest first.
class PhotosScreen extends StatefulWidget {
  const PhotosScreen({
    super.key,
    required this.session,
    this.backup,
    this.onOpenBackup,
    this.header,
  });

  final Session session;

  /// Shown under the title (the Photos / Albums switch).
  final Widget? header;
  final BackupController? backup;
  final VoidCallback? onOpenBackup;

  @override
  State<PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends State<PhotosScreen> {
  static const _pageSize = 120;
  final _scroll = ScrollController();
  final List<MediaItem> _items = [];
  bool _done = false;
  bool _loading = false;
  bool _failed = false;
  String _token = '';

  /// Bumped by every reload: a page that arrives afterwards belongs to the old list.
  int _generation = 0;

  /// Ids picked after a long press; null when not selecting.
  Set<String>? _selected;
  bool _busy = false;

  /// [_items] by month, recomputed only when the list changes (not on every pinch or spinner).
  List<(String, List<MediaItem>)>? _groups;
  List<(String, List<MediaItem>)> get _byMonth => _groups ??= groupByMonth(_items);

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
      // After a failed page, only the Retry button asks again (not every scroll event).
      if (!_failed && _scroll.position.extentAfter < 1200) _loadMore();
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
    // Above the navigation bar: the viewer takes the whole screen.
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => PhotoViewer(
          session: widget.session,
          items: items,
          initial: 0,
          onChanged: () => setState(() => _groups = null),
        ),
      ),
    );
  }

  bool _mine(MediaItem item) => item.record.getStringValue('owner') == widget.session.user?.id;

  List<MediaItem> get _picked => [
    for (final it in _items)
      if (_selected?.contains(it.id) ?? false) it,
  ];

  void _toggle(MediaItem item) {
    HapticFeedback.selectionClick();
    setState(() {
      final s = _selected ??= {};
      if (!s.remove(item.id)) s.add(item.id);
      if (s.isEmpty) _selected = null;
    });
  }

  /// Runs [action] on [items] a few at a time (a whole selection at once would queue on a slow
  /// disk) and returns how many failed.
  Future<int> _each(List<MediaItem> items, Future<void> Function(MediaItem) action) async {
    setState(() => _busy = true);
    var failed = 0;
    final queue = items.toList();
    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final it = queue.removeLast();
        try {
          await action(it);
        } catch (_) {
          failed++;
        }
      }
    }

    await Future.wait([for (var i = 0; i < 4; i++) worker()]);
    if (mounted) setState(() => _busy = false);
    return failed;
  }

  /// Favorites every picked photo of the user, or removes them all when they already are.
  Future<void> _favoriteSelection() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final mine = _picked.where(_mine).toList();
    final next = !mine.every((it) => it.favorite);
    final failed = await _each([...mine.where((it) => it.favorite != next)], (it) async {
      await widget.session.pb.send<dynamic>(
        '/api/v1/media/${Uri.encodeComponent(it.id)}/favorite',
        method: 'PUT',
        body: {'favorite': next},
      );
      it.favorite = next;
    });
    if (!mounted) return;
    setState(() {
      _selected = null;
      _groups = null;
    });
    if (failed > 0) messenger.showSnackBar(SnackBar(content: Text(l.photosNotAllDone)));
  }

  Future<void> _trashSelection() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final mine = _picked.where(_mine).toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.trashTitle),
        content: Text(l.photosTrashBody(mine.length)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.trashConfirm)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final now = DateTime.now().toUtc().toIso8601String();
    final gone = <MediaItem>{};
    final failed = await _each(mine, (it) async {
      await widget.session.pb
          .collection('nodes')
          .update(it.record.getStringValue('node'), body: {'trashed_at': now});
      gone.add(it);
    });
    if (!mounted) return;
    unawaited(HapticFeedback.mediumImpact());
    setState(() {
      final ids = {for (final it in gone) it.id};
      _items.removeWhere((it) => ids.contains(it.id));
      _groups = null;
      _selected = null;
    });
    messenger.showSnackBar(
      SnackBar(content: Text(failed > 0 ? l.photosNotAllDone : l.photosTrashed(gone.length))),
    );
  }

  /// Downloads the originals into the viewer cache and hands them to the share sheet.
  Future<void> _shareSelection() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final items = _picked;
    final paths = <String>[];
    final failed = await _each(
      items,
      (it) async => paths.add((await fetchOriginal(widget.session, it)).path),
    );
    if (!mounted) return;
    if (paths.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l.loadFailed)));
      return;
    }
    if (failed > 0) messenger.showSnackBar(SnackBar(content: Text(l.photosNotAllDone)));
    final mime = items.every((it) => it.isVideo)
        ? 'video/*'
        : (items.any((it) => it.isVideo) ? '*/*' : 'image/*');
    if (!await NativeFiles.instance.share(paths, mime, l.tabPhotos)) {
      messenger.showSnackBar(SnackBar(content: Text(l.viewerNoApp)));
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    _generation++;
    _items.clear();
    _groups = null;
    _selected = null;
    _done = false;
    _loading = false;
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || _done) return;
    final generation = _generation;
    setState(() => _loading = true);
    try {
      final token = await widget.session.fileToken();
      // Keyset paging: continue after the last item instead of skipping N rows, so trashed items do
      // not shift the next page and the database does not walk the whole timeline again.
      final last = _items.isEmpty ? null : _items.last;
      final after = last == null
          ? ''
          : widget.session.pb.filter(
              ' && (taken_at < {:t} || (taken_at = {:t} && id < {:id}))',
              {'t': last.record.getStringValue('taken_at'), 'id': last.id},
            );
      final res = await widget.session.pb
          .collection('media')
          .getList(
            perPage: _pageSize,
            skipTotal: true,
            filter: 'node.trashed_at = ""$after',
            sort: '-taken_at,-id',
            expand: 'node',
          );
      if (generation != _generation) return;
      _token = token;
      _items.addAll(res.items.map(MediaItem.new));
      _groups = null;
      _done = res.items.length < _pageSize;
      _failed = false;
    } catch (_) {
      if (generation == _generation) _failed = true;
    } finally {
      if (mounted && generation == _generation) setState(() => _loading = false);
    }
  }

  void _open(MediaItem item) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => PhotoViewer(
          session: widget.session,
          items: _items,
          initial: _items.indexOf(item),
          onChanged: () => setState(() => _groups = null),
          onTrashed: (item) => setState(() {
            _items.remove(item);
            _groups = null;
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

    final selected = _selected;
    final mine = selected == null ? const <MediaItem>[] : _picked.where(_mine).toList();
    final allFavorite = mine.isNotEmpty && mine.every((it) => it.favorite);
    final slivers = <Widget>[
      if (selected != null)
        LargeTitleAppBar(
          title: l.photosSelected(selected.length),
          leading: IconButton(
            tooltip: l.selectionCancel,
            onPressed: () => setState(() => _selected = null),
            icon: const Icon(Icons.close),
          ),
          actions: [
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(AlcoveSpace.s3),
                child: LoadingIndicator(size: 24),
              ),
            IconButton(
              tooltip: allFavorite ? l.favoriteRemove : l.favoriteAdd,
              onPressed: _busy || mine.isEmpty ? null : _favoriteSelection,
              icon: Icon(allFavorite ? Icons.favorite : Icons.favorite_border),
            ),
            if (NativeFiles.instance.available)
              IconButton(
                tooltip: l.viewerShare,
                onPressed: _busy ? null : _shareSelection,
                icon: const Icon(Icons.share_outlined),
              ),
            IconButton(
              tooltip: l.trashConfirm,
              onPressed: _busy || mine.isEmpty ? null : _trashSelection,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        )
      else
        LargeTitleAppBar(
          title: l.tabPhotos,
          actions: [
            if (widget.backup case final c?)
              ListenableBuilder(
                listenable: c,
                builder: (context, _) => _BackupChip(controller: c, onTap: widget.onOpenBackup),
              ),
            ...shellActions(context),
          ],
        ),
      if (widget.header case final h?) SliverToBoxAdapter(child: h),
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
    } else if (_items.isEmpty && _done) {
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

    for (final (key, items) in _byMonth) {
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
                  selected: selected?.contains(items[i].id),
                  onTap: () => selected == null ? _open(items[i]) : _toggle(items[i]),
                  onLongPress: () => _toggle(items[i]),
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (_failed && !_loading && _items.isNotEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AlcoveSpace.s5),
            child: Column(
              children: [
                Text(l.loadFailed, textAlign: TextAlign.center),
                const SizedBox(height: AlcoveSpace.s3),
                OutlinedButton(onPressed: _loadMore, child: Text(l.retry)),
              ],
            ),
          ),
        ),
      );
    }
    if (_loading && _items.isNotEmpty) {
      slivers.add(
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(AlcoveSpace.s5),
            child: Center(child: LoadingIndicator(size: 40)),
          ),
        ),
      );
    }
    // Room for the floating navigation bar.
    slivers.add(
      SliverToBoxAdapter(
        child: SizedBox(height: AlcoveSpace.s5 + MediaQuery.paddingOf(context).bottom),
      ),
    );

    return PopScope(
      // Back leaves the selection first.
      // Hidden behind another tab or the Albums view, a selection must not swallow back.
      canPop: selected == null || !TickerMode.valuesOf(context).enabled,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _selected = null);
      },
      child: Listener(
        onPointerDown: (e) => _pointers[e.pointer] = e.position,
        onPointerMove: _pointerMove,
        onPointerUp: _pointerUp,
        onPointerCancel: _pointerUp,
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([_reload(), _loadMemories()]);
          },
          edgeOffset: LargeTitleAppBar.edgeOffset(context),
          child: CustomScrollView(controller: _scroll, slivers: slivers),
        ),
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
  double get minExtent => 60;

  @override
  double get maxExtent => 60;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final c = context.colors;
    return Container(
      color: background.withValues(alpha: overlapsContent ? 0.94 : 1),
      padding: const EdgeInsets.fromLTRB(
        AlcoveSpace.s4,
        AlcoveSpace.s4,
        AlcoveSpace.s4,
        AlcoveSpace.s3,
      ),
      alignment: AlignmentDirectional.bottomStart,
      child: Semantics(
        header: true,
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: month, style: context.text.titleMedium),
              if (year.isNotEmpty)
                TextSpan(
                  text: '  $year',
                  style: TextStyle(
                    fontFamily: AlcoveFont.sans,
                    color: c.textMuted,
                    fontSize: AlcoveFont.sizeSm + 1,
                    fontWeight: AlcoveFont.medium,
                    fontFeatures: const [FontFeature.tabularFigures()],
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
      child: Semantics(
        button: true,
        label: l.backupTitle,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Center(
              child: AnimatedContainer(
                duration: AlcoveSprings.of(context, AlcoveSprings.medium),
                curve: AlcoveSprings.spatial,
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: AlcoveSpace.s3),
                decoration: ShapeDecoration(
                  color: running ? c.accentSubtle : c.surface,
                  shape: StadiumBorder(
                    side: BorderSide(color: running ? c.accentSubtle : c.border),
                  ),
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
        ),
      ),
    );
  }
}

class MediaTile extends StatelessWidget {
  const MediaTile({
    super.key,
    required this.item,
    required this.url,
    required this.onTap,
    this.onLongPress,
    this.selected,
  });

  final MediaItem item;
  final Uri? url;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// Whether the tile is picked, or null outside selection mode.
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final picked = selected ?? false;
    return Semantics(
      button: true,
      selected: selected,
      label: selected == null ? l.openPhoto(item.name) : item.name,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AlcoveRadius.sm - 2),
        child: Material(
          color: c.surfaceSunken,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (url != null)
                  RemoteImage(url: url!, cacheWidth: 360)
                else
                  Center(
                    child: item.isReady
                        ? Icon(Icons.image_outlined, color: c.textMuted)
                        : const LoadingIndicator(size: 28),
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
                      shadows: [Shadow(blurRadius: 4, color: c.stageScrim)],
                    ),
                  ),
                if (selected != null) ...[
                  if (picked)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: c.accent.withValues(alpha: 0.25),
                        border: Border.all(color: c.accent, width: 3),
                        borderRadius: BorderRadius.circular(AlcoveRadius.sm - 2),
                      ),
                    ),
                  Positioned(
                    top: AlcoveSpace.s1 + 2,
                    left: AlcoveSpace.s1 + 2,
                    // The check mark is a cut-out: a light disc keeps it readable on any photo.
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: picked ? c.onStage : null,
                      ),
                      child: Icon(
                        picked ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 22,
                        color: picked ? c.accent : c.onStage,
                        shadows: [Shadow(blurRadius: 4, color: c.stageScrim)],
                      ),
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

class _Pill extends StatelessWidget {
  const _Pill({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.colors.stageScrim,
      borderRadius: BorderRadius.circular(AlcoveRadius.full),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(AlcoveSpace.s1, 2, AlcoveSpace.s2, 2),
      child: child,
    ),
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
      padding: const EdgeInsets.only(top: AlcoveSpace.s2, bottom: AlcoveSpace.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: l.memories,
            padding: const EdgeInsets.fromLTRB(AlcoveSpace.s4, 0, AlcoveSpace.s4, AlcoveSpace.s3),
          ),
          SizedBox(
            height: 196,
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
                      borderRadius: BorderRadius.circular(AlcoveRadius.xl),
                      child: SizedBox(
                        width: 144,
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
                                    c.stage.withValues(alpha: 0.7),
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
                                    style: displayStyle(AlcoveFont.sizeLg, c.onStage),
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
