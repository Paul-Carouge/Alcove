import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/drive.dart';
import '../../core/session.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../ui/remote_image.dart';
import '../search/search_screen.dart';
import 'file_actions.dart';

/// Browses the drive: folders first, then files, by name. Files open in the system browser,
/// which downloads or shows them. With an [uploads] queue, files can be added, renamed, moved and
/// moved to the trash.
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
  StreamSubscription<String>? _arrivals;

  String get _here => widget.folder?.id ?? '';

  @override
  void initState() {
    super.initState();
    _load();
    // A file sent to this folder: show it.
    _arrivals = widget.uploads?.completed.listen((parent) {
      if (parent == _here) _load();
    });
  }

  @override
  void dispose() {
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
    final action = await showAddSheet(context, canScan: Platform.isAndroid);
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
        case NodeAction.trash:
          await _drive.trash(node.id);
          setState(() => _nodes = _nodes?.where((n) => n.id != node.id).toList());
          if (!mounted) return;
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
      final parent = widget.folder?.id ?? '';
      final list = await widget.session.pb
          .collection('nodes')
          .getFullList(
            filter: widget.session.pb.filter('parent = {:p} && trashed_at = ""', {'p': parent}),
            sort: '-kind,name',
          );
      // Folders first ("folder" > "file" with -kind), then a natural, case-insensitive name order.
      list.sort((a, b) {
        final k = b.getStringValue('kind').compareTo(a.getStringValue('kind'));
        return k != 0
            ? k
            : a
                  .getStringValue('name')
                  .toLowerCase()
                  .compareTo(b.getStringValue('name').toLowerCase());
      });
      if (mounted) {
        setState(() {
          _nodes = list;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _open(RecordModel node) =>
      openNode(context, widget.session, node, uploads: widget.uploads);

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
            child: SizedBox(height: 52, child: Skeleton(radius: AlcoveRadius.md)),
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
      content = [
        SliverToBoxAdapter(
          child: InsetGroup(
            children: [
              for (final n in nodes)
                NodeRow(
                  node: n,
                  locale: locale,
                  thumb: _thumb(n),
                  onTap: () => _open(n),
                  onMore: widget.uploads == null ? null : () => _actions(n),
                ),
            ],
          ),
        ),
      ];
    }
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        edgeOffset: 120,
        child: CustomScrollView(
          slivers: [
            LargeTitleAppBar(
              title: title,
              actions: [
                IconButton(
                  tooltip: AppLocalizations.of(context).searchTitle,
                  icon: const Icon(Icons.search),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => SearchScreen(session: widget.session)),
                  ),
                ),
              ],
            ),
            ...content,
            const SliverToBoxAdapter(child: SizedBox(height: AlcoveSpace.s6)),
          ],
        ),
      ),
      backgroundColor: colors.bg,
      floatingActionButton: widget.uploads == null
          ? null
          : FloatingActionButton(
              key: const Key('addButton'),
              tooltip: l.addTooltip,
              onPressed: _add,
              child: const Icon(Icons.add),
            ),
      bottomNavigationBar: widget.uploads == null ? null : UploadBanner(queue: widget.uploads!),
    );
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

/// Opens a folder in a new Files screen, or a file in the system browser (which shows or downloads it).
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
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final token = await session.fileToken();
    final url = session.pb.buildURL('/api/v1/nodes/${Uri.encodeComponent(node.id)}/download', {
      'token': token,
      'inline': '1',
    });
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) throw StateError('launch');
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l.fileCannotOpen)));
  }
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
  });

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
    final (icon, tint) = folder
        ? (Icons.folder_rounded, c.accent)
        : switch (mime.split('/').first) {
            'image' => (Icons.image_outlined, c.success),
            'video' => (Icons.movie_outlined, c.favorite),
            'audio' => (Icons.graphic_eq, c.warning),
            _ when mime.contains('pdf') => (Icons.picture_as_pdf_outlined, c.danger),
            _ => (Icons.description_outlined, c.textMuted),
          };
    return InkWell(
      onTap: onTap,
      onLongPress: onMore,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AlcoveSpace.s4, vertical: AlcoveSpace.s3),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AlcoveRadius.md),
              child: Container(
                width: 40,
                height: 40,
                color: tint.withValues(alpha: 0.12),
                child: thumb != null
                    ? RemoteImage(url: thumb!, cacheWidth: 120)
                    : Icon(icon, color: tint, size: 22),
              ),
            ),
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
              Icon(Icons.chevron_right, color: c.textMuted),
          ],
        ),
      ),
    );
  }
}
