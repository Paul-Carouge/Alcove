import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../core/session.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../files/files_screen.dart';

/// One search result: a file or folder found by name, or a document found by its text.
class SearchHit {
  SearchHit(this.node, this.match, this.snippet, {this.tag = ''});

  final RecordModel node;

  /// name, tag or content.
  final String match;
  final List<(String, bool)> snippet; // text, matched

  /// The matching tag's name (tag matches).
  final String tag;

  bool get inText => match == 'content';

  factory SearchHit.fromJson(Map<String, dynamic> j) => SearchHit(
    RecordModel.fromJson(j['node'] as Map<String, dynamic>),
    j['match'] as String? ?? 'name',
    [
      for (final s in (j['snippet'] as List<dynamic>? ?? const []))
        ((s as Map<String, dynamic>)['text'] as String? ?? '', s['hit'] == true),
    ],
    tag: j['tag'] as String? ?? '',
  );
}

/// Finds files and folders by name and documents by their text (GET /api/v1/search, ADR 0025).
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.session});

  final Session session;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<SearchHit>? _hits;
  bool _loading = false;
  bool _failed = false;
  String _token = '';
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    widget.session.fileToken().then((t) {
      if (mounted) setState(() => _token = t);
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _changed(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _search);
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    final seq = ++_seq;
    if (q.isEmpty) {
      setState(() {
        _hits = null;
        _loading = false;
        _failed = false;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await widget.session.pb.send<Map<String, dynamic>>(
        '/api/v1/search',
        query: {'q': q.length > 200 ? q.substring(0, 200) : q},
      );
      if (!mounted || seq != _seq) return;
      setState(() {
        _hits = [
          for (final h in (res['items'] as List<dynamic>? ?? const []))
            SearchHit.fromJson(h as Map<String, dynamic>),
        ];
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final hits = _hits;
    final byName = hits?.where((h) => h.match == 'name').toList() ?? const [];
    final byTag = hits?.where((h) => h.match == 'tag').toList() ?? const [];
    final inText = hits?.where((h) => h.inText).toList() ?? const [];

    Widget row(SearchHit h) => NodeRow(
      node: h.node,
      locale: locale,
      thumb: nodeThumb(widget.session, h.node, _token),
      onTap: () => openNode(context, widget.session, h.node),
      below: h.inText && h.snippet.isNotEmpty
          ? _Snippet(segments: h.snippet)
          : h.match == 'tag'
          ? Text(
              l.searchTagged(h.tag),
              style: TextStyle(fontSize: AlcoveFont.sizeSm, color: c.textMuted),
            )
          : null,
    );

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        titleSpacing: Navigator.of(context).canPop() ? 0 : AlcoveSpace.s4,
        toolbarHeight: 72,
        title: TextField(
          key: const Key('searchField'),
          controller: _query,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: _changed,
          onSubmitted: (_) => _search(),
          decoration: InputDecoration(
            hintText: l.searchHint,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _query.text.isEmpty
                ? null
                : IconButton(
                    tooltip: l.searchClear,
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _query.clear();
                      _search();
                    },
                  ),
            filled: true,
            fillColor: c.surface,
            contentPadding: const EdgeInsets.symmetric(vertical: AlcoveSpace.s4),
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(AlcoveRadius.full)),
              borderSide: BorderSide.none,
            ),
            enabledBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(AlcoveRadius.full)),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(AlcoveRadius.full)),
              borderSide: BorderSide(color: c.focus, width: 1.5),
            ),
          ),
        ),
        actions: const [SizedBox(width: AlcoveSpace.s4)],
        bottom: _loading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: switch (hits) {
        _ when _failed => EmptyState(
          icon: Icons.cloud_off_outlined,
          title: l.loadFailed,
          action: OutlinedButton(onPressed: _search, child: Text(l.retry)),
        ),
        null => EmptyState(icon: Icons.manage_search, title: l.searchTitle, body: l.searchPrompt),
        [] => EmptyState(icon: Icons.search_off, title: l.searchNone(_query.text.trim())),
        _ => ListView(
          padding: const EdgeInsets.only(top: AlcoveSpace.s4, bottom: AlcoveSpace.s6),
          children: [
            if (byName.isNotEmpty)
              InsetGroup(title: l.searchByName, children: [for (final h in byName) row(h)]),
            if (byTag.isNotEmpty)
              InsetGroup(title: l.searchByTag, children: [for (final h in byTag) row(h)]),
            if (inText.isNotEmpty)
              InsetGroup(title: l.searchInText, children: [for (final h in inText) row(h)]),
          ],
        ),
      },
    );
  }
}

/// Text around the words that matched; matches are highlighted.
class _Snippet extends StatelessWidget {
  const _Snippet({required this.segments});
  final List<(String, bool)> segments;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Text.rich(
      TextSpan(
        children: [
          for (final (text, hit) in segments)
            TextSpan(
              text: text,
              style: hit
                  ? TextStyle(
                      color: c.text,
                      fontWeight: AlcoveFont.semibold,
                      backgroundColor: c.accentSubtle,
                    )
                  : null,
            ),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: AlcoveFont.sizeSm, color: c.textMuted),
    );
  }
}
