import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/session.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';

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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.colors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final title = widget.folder?.getStringValue('name') ?? l.myFiles;
    final nodes = _nodes;

    Widget body;
    if (_failed && nodes == null) {
      body = Center(
        child: TextButton(onPressed: _load, child: Text(l.loadFailed)),
      );
    } else if (nodes == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (nodes.isEmpty) {
      body = ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(AlcoveSpace.s7),
            child: Text(
              l.folderEmpty,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textMuted),
            ),
          ),
        ],
      );
    } else {
      body = ListView.separated(
        itemCount: nodes.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final n = nodes[i];
          final folder = n.getStringValue('kind') == 'folder';
          final updated = DateTime.tryParse(n.getStringValue('updated').replaceFirst(' ', 'T'));
          return ListTile(
            leading: Icon(
              folder ? Icons.folder_outlined : _iconFor(n.getStringValue('mime')),
              color: folder ? colors.accent : colors.textMuted,
            ),
            title: Text(n.getStringValue('name'), overflow: TextOverflow.ellipsis),
            subtitle: folder
                ? null
                : Text(
                    [
                      _size(n.getIntValue('size'), locale),
                      if (updated != null) DateFormat.yMMMd(locale).format(updated.toLocal()),
                    ].join(' · '),
                  ),
            trailing: folder ? const Icon(Icons.chevron_right) : null,
            onTap: () => _open(n),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: RefreshIndicator(onRefresh: _load, child: body),
    );
  }

  static IconData _iconFor(String mime) => switch (mime.split('/').first) {
    'image' => Icons.image_outlined,
    'video' => Icons.movie_outlined,
    'audio' => Icons.audiotrack_outlined,
    'text' => Icons.description_outlined,
    _ => mime.contains('pdf') ? Icons.picture_as_pdf_outlined : Icons.insert_drive_file_outlined,
  };

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
