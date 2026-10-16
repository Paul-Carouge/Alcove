import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../core/drive.dart';
import '../../core/file_sort.dart';
import '../../core/recent_files.dart';
import '../../core/session.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../ui/remote_image.dart';
import '../../ui/shell.dart';
import '../viewer/file_viewer.dart';
import 'file_actions.dart';
import 'tags.dart';

/// Browses the drive: folders first, then files, in the order chosen on this device (name, date
/// or size). Files open in the app's viewers. At the root, a strip shows recent files. With an
/// [uploads] queue, files can be added, renamed, moved and moved to the trash.
class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key, required this.session, this.folder, this.uploads});

  final Session session;

  /// null for the root ("My files").
  final RecordModel? folder;

  /// The app's upload queue; null for a read-only browser.
  final UploadQueue? uploads;

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  List<RecordModel>? _nodes;
  bool _failed = false;
  late final Drive _drive = Drive(widget.session);
  late final TagBook _tags = TagBook(widget.session);
  StreamSubscription<String>? _arrivals;
  final _fab = GlobalKey();
  FileSort _sort = FileSort.byName;
  List<RecordModel> _recent = const [];

  String get _here => widget.folder?.id ?? '';
  bool get _root => widget.folder == null;

  @override
  void initState() {
    super.initState();
    FileSort.load().then((s) {
      if (!mounted) return;
      setState(() {
        _sort = s;
        if (_nodes != null) _nodes = sortNodes(_nodes!, s);
      });
    }, onError: (Object _) {});
    _load();
    // A file sent to this folder: show it.
    widget.uploads?.addListener(_uploadsChanged);
    _arrivals = widget.uploads?.completed.listen((parent) {
      if (parent == _here) _load();
    });
  }

  @override
  void dispose() {
    widget.uploads?.removeListener(_uploadsChanged);
    _arrivals?.cancel();
    super.dispose();
  }

  void _snack(String text, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), action: action));
  }

  Future<void> _add() async {
    final l = AppLocalizations.of(context);
    final uploads = widget.uploads!;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final action = await showAddMenu(context, fabKey: _fab, canScan: Platform.isAndroid);
    if (!mounted || action == null) return;
    try {
      switch (action) {
        case AddAction.folder:
          final name = await askName(context, title: l.newFolder, action: l.create);
          if (name == null) return;
          await _drive.createFolder(_here, name);
          await _load();
        case AddAction.upload:
          final items = await pickUploads(_here);
          if (items.isNotEmpty) uploads.add(items);
        case AddAction.scan:
          final item = await scanDocument(_here, locale);
          if (item != null) uploads.add([item]);
      }
    } on PlatformException {
      if (mounted) _snack(action == AddAction.scan ? l.scanUnavailable : l.errorUnexpected);
    } catch (e) {
      if (mounted) _snack(errorMessage(context, e));
    }
  }

  Future<void> _actions(RecordModel node) async {
    final l = AppLocalizations.of(context);
    final action = await showNodeSheet(context, node);
    if (!mounted || action == null) return;
    final name = node.getStringValue('name');
    try {
      switch (action) {
        case NodeAction.rename:
          final next = await askName(context, title: l.rename, action: l.save, initial: name);
          if (next == null || next == name) return;
          await _drive.rename(node.id, next);
          await _load();
        case NodeAction.move:
          final to = await pickFolder(context, _drive, node);
          if (to == null) return;
          await _drive.move(node.id, to);
          final folder = to.isEmpty
              ? l.myFiles
              : (await widget.session.pb.collection('nodes').getOne(to)).getStringValue('name');
          await _load();
          if (mounted) _snack(l.movedTo(folder));
        case NodeAction.tags:
          final ids = await pickTags(context, _tags, node);
          if (ids == null) return;
          await _drive.setTags(node.id, ids);
          await _load();
        case NodeAction.searchable:
          _snack(l.searchableRunning);
          await _drive.makeSearchable(node.id);
          await _load();
          if (mounted) _snack(l.searchableDone);
        case NodeAction.trash:
          await _drive.trash(node.id);
          unawaited(HapticFeedback.mediumImpact());
          if (!mounted) return;
          setState(() {
            _nodes = _nodes?.where((n) => n.id != node.id).toList();
            _recent = _recent.where((n) => n.id != node.id).toList();
          });
          _snack(
            l.trashed(name),
            action: SnackBarAction(
              label: l.undo,
              onPressed: () async {
                try {
                  await _drive.restore(node.id);
                } finally {
                  await _load();
                }
              },
            ),
          );
      }
    } catch (e) {
      if (mounted) _snack(errorMessage(context, e));
    }
  }

  Future<void> _load() async {
    try {
      _token = await widget.session.fileToken();
      // Tags are optional decoration: a failure must not hide the files.
      await _tags.load().catchError((Object _) {});
      final parent = widget.folder?.id ?? '';
      final list = await widget.session.pb
          .collection('nodes')
          .getFullList(
            filter: widget.session.pb.filter('parent = {:p} && trashed_at = ""', {'p': parent}),
            sort: '-kind,name',
          );
      if (_root) unawaited(_loadRecent());
      if (mounted) {
        setState(() {
          _nodes = sortNodes(list, _sort);
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  /// Files opened on this phone and documents changed lately (photos have their own tab).
  Future<void> _loadRecent() async {
    try {
      final user = widget.session.user?.id ?? '';
      final opened = await RecentFiles(user).opened();
      final res = await widget.session.pb
          .collection('nodes')
          .getList(
            perPage: 10,
            filter: 'kind = "file" && trashed_at = "" && mime !~ "image/%" && mime !~ "video/%"',
            sort: '-updated',
          );
      final merged = mergeRecent(opened, res.items);
      if (mounted) setState(() => _recent = merged);
    } catch (_) {
      // A bonus: the folder works without it.
    }
  }

  Future<void> _open(RecordModel node) async {
    await openNode(context, widget.session, node, uploads: widget.uploads);
    // The file opened is now the most recent.
    if (_root && mounted && node.getStringValue('kind') == 'file') unawaited(_loadRecent());
  }

  Future<void> _chooseSort() async {
    final next = await showSortSheet(context, _sort);
    if (next == null || next == _sort || !mounted) return;
    setState(() {
      _sort = next;
      if (_nodes != null) _nodes = sortNodes(_nodes!, next);
    });
    unawaited(next.save());
  }

  String _token = '';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.colors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final title = widget.folder?.getStringValue('name') ?? l.myFiles;
    final nodes = _nodes;

    final List<Widget> content;
    if (_failed && nodes == null) {
      content = [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.cloud_off_outlined,
            title: l.loadFailed,
            action: OutlinedButton(onPressed: _load, child: Text(l.retry)),
          ),
        ),
      ];
    } else if (nodes == null) {
      content = [
        SliverList.builder(
          itemCount: 6,
          itemBuilder: (_, _) => const Padding(
            padding: EdgeInsets.symmetric(horizontal: AlcoveSpace.s4, vertical: AlcoveSpace.s2),
            child: SizedBox(height: 64, child: Skeleton(radius: AlcoveRadius.lg)),
          ),
        ),
      ];
    } else if (nodes.isEmpty) {
      content = [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(icon: Icons.folder_open_outlined, title: l.folderEmpty),
        ),
      ];
    } else {
      final recent = _root ? _recent : const <RecordModel>[];
      content = [
        if (recent.isNotEmpty)
          SliverToBoxAdapter(
            child: RecentStrip(
              nodes: recent,
              locale: locale,
              thumb: _thumb,
              onOpen: _open,
            ),
          ),
        SliverToBoxAdapter(
          child: InsetGroup(
            title: recent.isNotEmpty ? l.filesAll : null,
            children: [
              for (final n in nodes)
                NodeRow(
                  node: n,
                  locale: locale,
                  thumb: _thumb(n),
                  onTap: () => _open(n),
                  onMore: widget.uploads == null ? null : () => _actions(n),
                  tags: _tags.of(n),
                ),
            ],
          ),
        ),
      ];
    }
    final scaffold = Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        edgeOffset: LargeTitleAppBar.edgeOffset(context),
        child: CustomScrollView(
          slivers: [
            LargeTitleAppBar(
              title: title,
              actions: [
                IconButton(
                  key: const Key('sortButton'),
                  tooltip: l.sortTitle,
                  icon: const Icon(Icons.swap_vert),
                  onPressed: _chooseSort,
                ),
                ...shellActions(context, account: _root),
              ],
            ),
            ...content,
            // Room under the last row for the FAB (and the floating navigation bar).
            SliverToBoxAdapter(
              child: SizedBox(
                height: AlcoveSpace.s8 + AlcoveSpace.s5 + MediaQuery.paddingOf(context).bottom,
              ),
            ),
          ],
        ),
      ),
      backgroundColor: colors.bg,
      floatingActionButton: widget.uploads == null
          ? null
          : KeyedSubtree(
              key: _fab,
              child: FloatingActionButton(
                key: const Key('addButton'),
                tooltip: l.addTooltip,
                onPressed: _add,
                child: const Icon(Icons.add),
              ),
            ),
      bottomNavigationBar: _hasUploads ? UploadBanner(queue: widget.uploads!) : null,
    );
    return scaffold;
  }

  /// The banner only takes room while there are uploads to show.
  late bool _hasUploads = widget.uploads?.items.isNotEmpty ?? false;

  void _uploadsChanged() {
    final has = widget.uploads?.items.isNotEmpty ?? false;
    if (has != _hasUploads && mounted) setState(() => _hasUploads = has);
  }

  Uri? _thumb(RecordModel n) => nodeThumb(widget.session, n, _token);
}

/// A small thumbnail URL for images the server can resize, or null.
Uri? nodeThumb(Session session, RecordModel n, String token) {
  final mime = n.getStringValue('mime');
  final blob = n.getStringValue('blob');
  if (token.isEmpty || blob.isEmpty) return null;
  if (!['image/jpeg', 'image/png', 'image/webp', 'image/gif'].contains(mime.split(';').first)) {
    return null;
  }
  return session.pb.files.getURL(n, blob, thumb: '96x96', token: token);
}

/// A file size for people: 1.2 MB.
String formatSize(int bytes, String locale) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var v = bytes.toDouble();
  var u = 0;
  while (v >= 1000 && u < units.length - 1) {
    v /= 1000;
    u++;
  }
  return '${NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: u == 0 ? 0 : 1).format(v)} ${units[u]}';
}

/// Opens a folder in a new Files screen (in the current tab), or a file in the app's viewers.
Future<void> openNode(
  BuildContext context,
  Session session,
  RecordModel node, {
  UploadQueue? uploads,
}) async {
  if (node.getStringValue('kind') == 'folder') {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FilesScreen(session: session, folder: node, uploads: uploads),
      ),
    );
    return;
  }
  await openFileNode(context, session, node);
}

/// One file or folder in a grouped list; [below] replaces the size and date line (search snippets).
class NodeRow extends StatelessWidget {
  const NodeRow({
    super.key,
    required this.node,
    required this.locale,
    required this.thumb,
    required this.onTap,
    this.below,
    this.onMore,
    this.tags = const [],
  });

  /// Tags shown under the name.
  final List<RecordModel> tags;

  final RecordModel node;
  final String locale;
  final Uri? thumb;
  final VoidCallback onTap;
  final Widget? below;

  /// Opens the actions of this file or folder (also on long press).
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final folder = node.getStringValue('kind') == 'folder';
    final mime = node.getStringValue('mime');
    final updated = DateTime.tryParse(node.getStringValue('updated').replaceFirst(' ', 'T'));
    final (icon, tint) = folder ? (Icons.folder_rounded, c.accent) : fileIcon(c, mime);
    return InkWell(
      onTap: onTap,
      onLongPress: onMore,
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(
          AlcoveSpace.s4,
          AlcoveSpace.s3,
          onMore != null ? AlcoveSpace.s1 : AlcoveSpace.s4,
          AlcoveSpace.s3,
        ),
        child: Row(
          children: [
            if (thumb != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(AlcoveRadius.md),
                child: SizedBox.square(
                  dimension: 40,
                  child: ColoredBox(
                    color: c.surfaceSunken,
                    child: RemoteImage(url: thumb!, cacheWidth: 120),
                  ),
                ),
              )
            else
              TintedIcon(icon: icon, color: tint),
            const SizedBox(width: AlcoveSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    node.getStringValue('name'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: AlcoveFont.sizeMd,
                      fontWeight: AlcoveFont.medium,
                    ),
                  ),
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [for (final t in tags) TagChip(tag: t)],
                    ),
                  ],
                  if (below != null) ...[
                    const SizedBox(height: 2),
                    below!,
                  ] else if (!folder) ...[
                    const SizedBox(height: 2),
                    Text(
                      [
                        formatSize(node.getIntValue('size'), locale),
                        if (updated != null) DateFormat.yMMMd(locale).format(updated.toLocal()),
                      ].join(' · '),
                      style: TextStyle(fontSize: AlcoveFont.sizeSm, color: c.textMuted),
                    ),
                  ],
                ],
              ),
            ),
            if (onMore != null)
              IconButton(
                tooltip: AppLocalizations.of(context).moreActions(node.getStringValue('name')),
                icon: Icon(Icons.more_vert, color: c.textMuted),
                onPressed: onMore,
              )
            else if (folder)
              Icon(Icons.chevron_right, color: c.borderStrong),
          ],
        ),
      ),
    );
  }
}

/// Recent files at the top of My files: opened on this phone or changed lately.
class RecentStrip extends StatelessWidget {
  const RecentStrip({
    super.key,
    required this.nodes,
    required this.locale,
    required this.thumb,
    required this.onOpen,
  });

  final List<RecordModel> nodes;
  final String locale;
  final Uri? Function(RecordModel) thumb;
  final void Function(RecordModel) onOpen;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: AlcoveSpace.s1, bottom: AlcoveSpace.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: l.filesRecent,
            padding: const EdgeInsetsDirectional.fromSTEB(
              AlcoveSpace.s4 + AlcoveSpace.s1,
              0,
              AlcoveSpace.s4 + AlcoveSpace.s1,
              AlcoveSpace.s3,
            ),
          ),
          SizedBox(
            height: 148,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AlcoveSpace.s4),
              itemCount: nodes.length,
              separatorBuilder: (_, _) => const SizedBox(width: AlcoveSpace.s3),
              itemBuilder: (context, i) {
                final n = nodes[i];
                final url = thumb(n);
                final updated = modifiedAt(n);
                final (icon, tint) = fileIcon(c, n.getStringValue('mime'));
                return SizedBox(
                  width: 128,
                  child: Material(
                    color: c.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AlcoveRadius.lg),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => onOpen(n),
                      child: Padding(
                        padding: const EdgeInsets.all(AlcoveSpace.s3),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (url != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(AlcoveRadius.md),
                                child: SizedBox.square(
                                  dimension: 44,
                                  child: RemoteImage(url: url, cacheWidth: 132),
                                ),
                              )
                            else
                              TintedIcon(icon: icon, color: tint, size: 44),
                            const Spacer(),
                            Text(
                              n.getStringValue('name'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: sansStyle(
                                AlcoveFont.sizeSm,
                                c.text,
                                AlcoveFont.medium,
                              ).copyWith(height: 1.3),
                            ),
                            if (updated != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                DateFormat.MMMd(locale).format(updated.toLocal()),
                                maxLines: 1,
                                style: sansStyle(AlcoveFont.sizeXs, c.textMuted),
                              ),
                            ],
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

/// The icon and tint of a file type, as in the lists.
(IconData, Color) fileIcon(AlcoveColors c, String mime) => switch (mime.split('/').first) {
  'image' => (Icons.image_outlined, c.success),
  'video' => (Icons.movie_outlined, c.favorite),
  'audio' => (Icons.graphic_eq, c.warning),
  _ when mime.contains('pdf') => (Icons.picture_as_pdf_outlined, c.danger),
  'text' => (Icons.notes, c.accent),
  _ => (Icons.description_outlined, c.textMuted),
};
