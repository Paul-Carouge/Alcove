import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../core/session.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import 'media.dart';
import 'photo_viewer.dart';
import 'photos_screen.dart';

/// Albums you own and albums shared with you (GET /api/v1/albums).
class AlbumsScreen extends StatefulWidget {
  const AlbumsScreen({super.key, required this.session});

  final Session session;

  @override
  State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen> {
  List<Map<String, dynamic>>? _albums;
  bool _failed = false;
  String _token = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _token = await widget.session.fileToken();
      final res = await widget.session.pb.send<Map<String, dynamic>>('/api/v1/albums');
      final items = (res['items'] as List).cast<Map<String, dynamic>>();
      if (mounted) {
        setState(() {
          _albums = items;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Uri? _cover(Map<String, dynamic> a) {
    final c = a['cover'];
    if (c is! Map || (c['thumb'] as String? ?? '').isEmpty) return null;
    return widget.session.pb.files.getURL(
      RecordModel.fromJson({'id': c['id'], 'collectionId': c['collectionId']}),
      c['thumb'] as String,
      token: _token,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.colors;
    final albums = _albums;
    Widget body;
    if (_failed && albums == null) {
      body = Center(
        child: TextButton(onPressed: _load, child: Text(l.loadFailed)),
      );
    } else if (albums == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (albums.isEmpty) {
      body = ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(AlcoveSpace.s7),
            child: Text(
              l.albumsEmpty,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textMuted),
            ),
          ),
        ],
      );
    } else {
      body = GridView.builder(
        padding: const EdgeInsets.all(AlcoveSpace.s4),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          mainAxisSpacing: AlcoveSpace.s4,
          crossAxisSpacing: AlcoveSpace.s4,
          childAspectRatio: 0.78,
        ),
        itemCount: albums.length,
        itemBuilder: (_, i) {
          final a = albums[i];
          final cover = _cover(a);
          final shared = a['role'] != 'owner'
              ? l.albumSharedBy((a['owner'] as Map)['name'] as String? ?? '')
              : (a['shared'] == true ? l.albumShared : '');
          return Semantics(
            button: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(AlcoveRadius.lg),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AlbumScreen(
                    session: widget.session,
                    id: a['id'] as String,
                    name: a['name'] as String,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AlcoveRadius.lg),
                      child: ColoredBox(
                        color: colors.accentSubtle,
                        child: cover == null
                            ? Icon(Icons.photo_album_outlined, color: colors.accent, size: 36)
                            : Image.network(cover.toString(), fit: BoxFit.cover, cacheWidth: 400),
                      ),
                    ),
                  ),
                  const SizedBox(height: AlcoveSpace.s2),
                  Text(
                    a['name'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: AlcoveFont.semibold),
                  ),
                  Text(
                    [
                      l.albumCount((a['count'] as num).toInt()),
                      if (shared.isNotEmpty) shared,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.textMuted, fontSize: AlcoveFont.sizeSm),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l.albumsTitle)),
      body: RefreshIndicator(onRefresh: _load, child: body),
    );
  }
}

/// The photos of one album (GET /api/v1/albums/{id}/items).
class AlbumScreen extends StatefulWidget {
  const AlbumScreen({super.key, required this.session, required this.id, required this.name});

  final Session session;
  final String id;
  final String name;

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  List<MediaItem>? _items;
  bool _failed = false;
  String _token = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _token = await widget.session.fileToken();
      final res = await widget.session.pb.send<Map<String, dynamic>>(
        '/api/v1/albums/${Uri.encodeComponent(widget.id)}/items',
        query: {'perPage': 500},
      );
      final items = (res['items'] as List).cast<Map<String, dynamic>>().map((it) {
        return MediaItem(
          RecordModel.fromJson({
            ...it,
            'owner': it['addedBy'],
            'expand': {
              'node': {'id': '', 'collectionId': '', 'name': it['name'], 'size': it['size']},
            },
          }),
        );
      }).toList();
      if (mounted) {
        setState(() {
          _items = items;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final items = _items;
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 900 ? 6 : (width >= 600 ? 5 : 3);
    Widget body;
    if (_failed && items == null) {
      body = Center(
        child: TextButton(onPressed: _load, child: Text(l.loadFailed)),
      );
    } else if (items == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = GridView.builder(
        padding: const EdgeInsets.all(AlcoveSpace.s1),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => MediaTile(
          item: items[i],
          url: items[i].thumbUrl(widget.session.pb, _token),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PhotoViewer(session: widget.session, items: items, initial: i),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: RefreshIndicator(onRefresh: _load, child: body),
    );
  }
}
