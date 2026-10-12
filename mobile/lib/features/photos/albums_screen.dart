import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../core/session.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import 'media.dart';
import 'photo_viewer.dart';
import '../../ui/kit.dart';
import '../../ui/remote_image.dart';
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
    final Widget content;
    if (_failed && albums == null) {
      content = SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyState(
          icon: Icons.cloud_off_outlined,
          title: l.loadFailed,
          action: OutlinedButton(onPressed: _load, child: Text(l.retry)),
        ),
      );
    } else if (albums == null) {
      content = SliverPadding(
        padding: const EdgeInsets.all(AlcoveSpace.s4),
        sliver: SliverGrid.builder(
          gridDelegate: _grid,
          itemCount: 4,
          itemBuilder: (_, _) => const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [AspectRatio(aspectRatio: 1, child: Skeleton(radius: AlcoveRadius.lg))],
          ),
        ),
      );
    } else if (albums.isEmpty) {
      content = SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyState(
          icon: Icons.photo_album_outlined,
          title: l.albumsEmptyTitle,
          body: l.albumsEmpty,
        ),
      );
    } else {
      content = SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          AlcoveSpace.s4,
          AlcoveSpace.s2,
          AlcoveSpace.s4,
          AlcoveSpace.s7,
        ),
        sliver: SliverGrid.builder(
          gridDelegate: _grid,
          itemCount: albums.length,
          itemBuilder: (_, i) {
            final a = albums[i];
            final cover = _cover(a);
            final shared = a['role'] != 'owner'
                ? l.albumSharedBy((a['owner'] as Map)['name'] as String? ?? '')
                : (a['shared'] == true ? l.albumShared : '');
            return Semantics(
              button: true,
              child: GestureDetector(
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
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AlcoveRadius.lg),
                          boxShadow: colors.shadowMD,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AlcoveRadius.lg),
                          child: ColoredBox(
                            color: colors.accentSubtle,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (cover == null)
                                  Icon(Icons.photo_album_outlined, color: colors.accent, size: 36)
                                else
                                  RemoteImage(url: cover, cacheWidth: 480),
                                if (shared.isNotEmpty)
                                  Positioned(
                                    top: AlcoveSpace.s2,
                                    right: AlcoveSpace.s2,
                                    child: Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: colors.stageScrim,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.people_alt_outlined,
                                        size: 14,
                                        color: colors.onStage,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AlcoveSpace.s2 + 2),
                    Text(
                      a['name'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: AlcoveFont.semibold,
                        fontSize: AlcoveFont.sizeMd,
                      ),
                    ),
                    const SizedBox(height: 2),
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
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      edgeOffset: 120,
      child: CustomScrollView(
        slivers: [
          LargeTitleAppBar(title: l.albumsTitle),
          content,
        ],
      ),
    );
  }

  static const _grid = SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 240,
    mainAxisSpacing: AlcoveSpace.s5,
    crossAxisSpacing: AlcoveSpace.s4,
    childAspectRatio: 0.74,
  );
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
    final grid = SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      mainAxisSpacing: 3,
      crossAxisSpacing: 3,
    );
    final List<Widget> content;
    if (_failed && items == null) {
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
    } else if (items == null) {
      content = [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AlcoveSpace.s2),
          sliver: SliverGrid.builder(
            gridDelegate: grid,
            itemCount: columns * 4,
            itemBuilder: (_, _) => const Skeleton(),
          ),
        ),
      ];
    } else {
      content = [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AlcoveSpace.s4, 0, AlcoveSpace.s4, AlcoveSpace.s3),
            child: Text(
              l.albumCount(items.length),
              style: TextStyle(color: context.colors.textMuted),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(AlcoveSpace.s2, 0, AlcoveSpace.s2, AlcoveSpace.s7),
          sliver: SliverGrid.builder(
            gridDelegate: grid,
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
            LargeTitleAppBar(title: widget.name),
            ...content,
          ],
        ),
      ),
    );
  }
}
