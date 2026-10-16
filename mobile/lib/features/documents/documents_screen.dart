import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../core/drive.dart';
import '../../core/session.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/expressive.dart';
import '../../ui/kit.dart';
import '../../ui/shell.dart';
import '../files/files_screen.dart';

/// Which documents the list shows (same filters as the web app's Documents page).
enum DocumentFilter { all, pdf, image, text }

/// The PocketBase filter of the Documents list: PDFs, text files, and images in which text was
/// found (ADR 0025), not in the trash.
String documentsFilter(DocumentFilter kind) {
  var f = 'node.trashed_at = "" && (kind != "image" || (status = "ready" && text != ""))';
  if (kind != DocumentFilter.all) f += ' && kind = "${kind.name}"';
  return f;
}

/// PDFs, scans and text files from the whole drive, most recently changed first, with a line of
/// their text. Tapping one opens it in the app.
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key, required this.session, this.uploads});

  final Session session;
  final UploadQueue? uploads;

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  static const _perPage = 50;
  DocumentFilter _filter = DocumentFilter.all;
  List<RecordModel>? _docs;
  int _total = 0;
  int _page = 0;
  bool _failed = false;
  bool _loadingMore = false;
  String _token = '';
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 600) unawaited(_more());
    });
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final kind = _filter;
    try {
      _token = await widget.session.fileToken().catchError((Object _) => '');
      final res = await _fetch(kind, 1);
      if (!mounted || kind != _filter) return;
      setState(() {
        _docs = res.items;
        _total = res.totalItems;
        _page = 1;
        _failed = false;
      });
    } catch (_) {
      if (mounted && kind == _filter) setState(() => _failed = true);
    }
  }

  Future<ResultList<RecordModel>> _fetch(DocumentFilter kind, int page) => widget.session.pb
      .collection('documents')
      .getList(
        page: page,
        perPage: _perPage,
        filter: documentsFilter(kind),
        sort: '-updated',
        expand: 'node',
        // The full text can be long: only an excerpt in lists.
        fields: '*,text:excerpt(220,true),expand.node',
      );

  Future<void> _more() async {
    final docs = _docs;
    if (_loadingMore || docs == null || docs.length >= _total) return;
    final kind = _filter;
    setState(() => _loadingMore = true);
    try {
      final res = await _fetch(kind, _page + 1);
      if (!mounted || kind != _filter) return;
      setState(() {
        _docs = [...docs, ...res.items];
        _page = res.page;
      });
    } catch (_) {
      // The next scroll tries again.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _choose(DocumentFilter f) {
    if (f == _filter) return;
    setState(() {
      _filter = f;
      _docs = null;
      _failed = false;
    });
    _load();
  }

  Widget _filters(AppLocalizations l) => SizedBox(
    height: 56,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(AlcoveSpace.s4, AlcoveSpace.s1, AlcoveSpace.s4, 0),
      children: [
        for (final (f, label) in [
          (DocumentFilter.all, l.documentsAll),
          (DocumentFilter.pdf, l.documentsPdf),
          (DocumentFilter.image, l.documentsScans),
          (DocumentFilter.text, l.documentsText),
        ])
          Padding(
            padding: const EdgeInsetsDirectional.only(end: AlcoveSpace.s2),
            child: ChoiceChip(
              key: Key('docFilter-${f.name}'),
              label: Text(label),
              selected: _filter == f,
              showCheckmark: false,
              materialTapTargetSize: MaterialTapTargetSize.padded,
              onSelected: (_) => _choose(f),
            ),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final docs = _docs;
    final List<Widget> content;
    if (_failed && docs == null) {
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
    } else if (docs == null) {
      content = [
        SliverList.builder(
          itemCount: 6,
          itemBuilder: (_, _) => const Padding(
            padding: EdgeInsets.symmetric(horizontal: AlcoveSpace.s4, vertical: AlcoveSpace.s2),
            child: SizedBox(height: 72, child: Skeleton(radius: AlcoveRadius.lg)),
          ),
        ),
      ];
    } else if (docs.isEmpty) {
      content = [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.article_outlined,
            title: l.documentsEmptyTitle,
            body: l.documentsEmpty,
          ),
        ),
      ];
    } else {
      content = [
        SliverToBoxAdapter(
          child: InsetGroup(
            children: [
              for (final d in docs)
                if (d.get<RecordModel>('expand.node') case final node when node.id.isNotEmpty)
                  NodeRow(
                    node: node,
                    locale: locale,
                    thumb: nodeThumb(widget.session, node, _token),
                    onTap: () => openNode(context, widget.session, node, uploads: widget.uploads),
                    below: d.getStringValue('text').trim().isEmpty
                        ? null
                        : Text(
                            d.getStringValue('text').trim(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: AlcoveFont.sizeSm,
                              color: c.textMuted,
                              height: 1.4,
                            ),
                          ),
                  ),
            ],
          ),
        ),
        if (_loadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(AlcoveSpace.s4),
              child: Center(child: LoadingIndicator(size: 36)),
            ),
          ),
      ];
    }
    return Scaffold(
      backgroundColor: c.bg,
      body: RefreshIndicator(
        onRefresh: _load,
        edgeOffset: LargeTitleAppBar.edgeOffset(context),
        child: CustomScrollView(
          controller: _scroll,
          slivers: [
            LargeTitleAppBar(title: l.tabDocuments, actions: shellActions(context)),
            SliverToBoxAdapter(child: _filters(l)),
            const SliverToBoxAdapter(child: SizedBox(height: AlcoveSpace.s3)),
            ...content,
            SliverToBoxAdapter(
              child: SizedBox(height: AlcoveSpace.s5 + MediaQuery.paddingOf(context).bottom),
            ),
          ],
        ),
      ),
    );
  }
}
