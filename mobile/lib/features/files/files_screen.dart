import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/session.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../ui/remote_image.dart';

/// Browses the drive: folders first, then files, by name. Files open in the system browser,
/// which downloads or shows them.
class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key, required this.session, this.folder});

  final Session session;

  /// null for the root ("My files").
  final RecordModel? folder;

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  List<RecordModel>? _nodes;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
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

  Future<void> _open(RecordModel node) async {
    if (node.getStringValue('kind') == 'folder') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => FilesScreen(session: widget.session, folder: node),
        ),
      );
      return;
    }
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final token = await widget.session.fileToken();
      final url = widget.session.pb.buildURL(
        '/api/v1/nodes/${Uri.encodeComponent(node.id)}/download',
        {'token': token, 'inline': '1'},
      );
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) throw StateError('launch');
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.fileCannotOpen)));
    }
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
                _NodeRow(
                  node: n,
                  locale: locale,
                  thumb: _thumb(n),
                  onTap: () => _open(n),
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
            LargeTitleAppBar(title: title),
            ...content,
            const SliverToBoxAdapter(child: SizedBox(height: AlcoveSpace.s6)),
          ],
        ),
      ),
      backgroundColor: colors.bg,
    );
  }

  Uri? _thumb(RecordModel n) {
    final mime = n.getStringValue('mime');
    final blob = n.getStringValue('blob');
    if (_token.isEmpty || blob.isEmpty) return null;
    if (!['image/jpeg', 'image/png', 'image/webp', 'image/gif'].contains(mime.split(';').first)) {
      return null;
    }
    return widget.session.pb.files.getURL(n, blob, thumb: '96x96', token: _token);
  }

  static String _size(int bytes, String locale) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var v = bytes.toDouble();
    var u = 0;
    while (v >= 1000 && u < units.length - 1) {
      v /= 1000;
      u++;
    }
    return '${NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: u == 0 ? 0 : 1).format(v)} ${units[u]}';
  }
}

class _NodeRow extends StatelessWidget {
  const _NodeRow({
    required this.node,
    required this.locale,
    required this.thumb,
    required this.onTap,
  });

  final RecordModel node;
  final String locale;
  final Uri? thumb;
  final VoidCallback onTap;

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
                  if (!folder) ...[
                    const SizedBox(height: 2),
                    Text(
                      [
                        _FilesScreenState._size(node.getIntValue('size'), locale),
                        if (updated != null) DateFormat.yMMMd(locale).format(updated.toLocal()),
                      ].join(' · '),
                      style: TextStyle(fontSize: AlcoveFont.sizeSm, color: c.textMuted),
                    ),
                  ],
                ],
              ),
            ),
            if (folder) Icon(Icons.chevron_right, color: c.textMuted),
          ],
        ),
      ),
    );
  }
}
