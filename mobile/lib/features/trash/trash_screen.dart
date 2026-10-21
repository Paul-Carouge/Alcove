import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../core/drive.dart';
import '../../core/session.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/expressive.dart';
import '../../ui/kit.dart';
import '../files/file_actions.dart';
import '../files/files_screen.dart';

/// Files and photos in the trash (photos are drive files): restore them or delete them for good.
/// Notes keep their own trash in the Notes tab.
class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key, required this.session});

  final Session session;

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  late final Drive _drive = Drive(widget.session);
  List<RecordModel>? _items;
  bool _failed = false;
  bool _emptying = false;
  String _token = '';

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      _token = await widget.session.fileToken().catchError((Object _) => '');
      final list = await _drive.trashed();
      if (mounted) {
        setState(() {
          _items = list;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _drop(String id) => setState(() => _items = _items?.where((n) => n.id != id).toList());

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<bool> _confirm(String title, String body, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppLocalizations.of(context).cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: context.colors.danger,
                foregroundColor: context.colors.accentContrast,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _actions(RecordModel node) async {
    final l = AppLocalizations.of(context);
    final name = node.getStringValue('name');
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: AlcoveSpace.s2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetHeader(title: name),
              InsetGroup(
                children: [
                  GroupTile(
                    icon: Icons.restore_from_trash_outlined,
                    title: l.notesRestore,
                    chevron: false,
                    onTap: () => Navigator.pop(context, 'restore'),
                  ),
                  GroupTile(
                    icon: Icons.delete_forever_outlined,
                    title: l.notesDeleteForever,
                    danger: true,
                    chevron: false,
                    onTap: () => Navigator.pop(context, 'delete'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    try {
      if (action == 'restore') {
        await _drive.restoreFromTrash(node);
        if (!mounted) return;
        _drop(node.id);
        _snack(l.trashRestored(name));
        return;
      }
      if (!await _confirm(
        l.notesDeleteForeverTitle,
        l.trashDeleteForeverBody(name),
        l.notesDeleteForever,
      )) {
        return;
      }
      await _drive.deleteForever(node.id);
      if (mounted) _drop(node.id);
    } on ClientException catch (e) {
      // The unique-name index refuses a restore next to an item of the same name.
      if (mounted) {
        _snack(
          action == 'restore' && e.statusCode == 400
              ? l.trashRestoreConflict(name)
              : errorMessage(context, e),
        );
      }
    } catch (e) {
      if (mounted) _snack(errorMessage(context, e));
    }
  }

  Future<void> _emptyTrash() async {
    final l = AppLocalizations.of(context);
    final items = _items ?? const <RecordModel>[];
    if (!await _confirm(l.trashEmptyTitle, l.trashEmptyBody(items.length), l.trashEmptyAction)) {
      return;
    }
    setState(() => _emptying = true);
    var failed = 0;
    // Deleting a folder takes its content with it: only top-level items are listed.
    for (final n in items) {
      try {
        await _drive.deleteForever(n.id);
        if (mounted) _drop(n.id);
      } catch (_) {
        failed++;
      }
    }
    if (!mounted) return;
    setState(() => _emptying = false);
    if (failed > 0) _snack(l.trashEmptyFailed(failed));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final items = _items;

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
        SliverList.builder(
          itemCount: 5,
          itemBuilder: (_, _) => const Padding(
            padding: EdgeInsets.symmetric(horizontal: AlcoveSpace.s4, vertical: AlcoveSpace.s2),
            child: SizedBox(height: 64, child: Skeleton(radius: AlcoveRadius.lg)),
          ),
        ),
      ];
    } else if (items.isEmpty) {
      content = [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.delete_outline,
            title: l.trashEmptyState,
            body: l.trashHint,
          ),
        ),
      ];
    } else {
      content = [
        SliverToBoxAdapter(
          child: InsetGroup(
            footer: l.trashHint,
            children: [
              for (final n in items)
                NodeRow(
                  key: ValueKey(n.id),
                  node: n,
                  locale: locale,
                  thumb: nodeThumb(widget.session, n, _token),
                  onTap: () => _actions(n),
                  onMore: () => _actions(n),
                  below: _trashedOn(n, locale, c),
                ),
            ],
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
          slivers: [
            LargeTitleAppBar(
              title: l.trashScreenTitle,
              actions: [
                if (items != null && items.isNotEmpty)
                  _emptying
                      ? const Padding(
                          padding: EdgeInsets.symmetric(horizontal: AlcoveSpace.s4),
                          child: LoadingIndicator(size: 28),
                        )
                      : TextButton(
                          onPressed: _emptyTrash,
                          style: TextButton.styleFrom(foregroundColor: c.danger),
                          child: Text(l.trashEmptyAction),
                        ),
              ],
            ),
            ...content,
            SliverToBoxAdapter(
              child: SizedBox(height: AlcoveSpace.s8 + MediaQuery.paddingOf(context).bottom),
            ),
          ],
        ),
      ),
    );
  }

  /// Size (files) and the day it went to the trash.
  Widget _trashedOn(RecordModel n, String locale, AlcoveColors c) {
    final at = DateTime.tryParse(n.getStringValue('trashed_at').replaceFirst(' ', 'T'));
    return Text(
      [
        if (n.getStringValue('kind') == 'folder')
          AppLocalizations.of(context).kindFolder
        else
          formatSize(n.getIntValue('size'), locale),
        if (at != null) DateFormat.yMMMd(locale).format(at.toLocal()),
      ].join(' · '),
      style: TextStyle(fontSize: AlcoveFont.sizeSm, color: c.textMuted),
    );
  }
}
