import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../core/drive.dart';
import '../../core/notes.dart';
import '../../core/session.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/expressive.dart';
import '../../ui/kit.dart';
import '../files/file_actions.dart';
import '../files/files_screen.dart';
import '../notes/notes_screen.dart';

enum _TrashAction { restore, deleteForever }

/// Everything in the trash: files and photos (photos are drive files), then notes. Each item can be
/// restored or deleted for good, or the whole trash emptied.
class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key, required this.session, this.notes});

  final Session session;

  /// Replaced in tests.
  final NotesApi? notes;

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  late final Drive _drive = Drive(widget.session);
  late final NotesApi _notesApi = widget.notes ?? NotesApi(widget.session);
  List<RecordModel>? _files;
  List<RecordModel>? _notes;
  bool _failed = false;
  bool _emptying = false;
  String _token = '';

  bool get _isEmpty => (_files?.isEmpty ?? true) && (_notes?.isEmpty ?? true);

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      _token = await widget.session.fileToken().catchError((Object _) => '');
      final (files, notes) = await (_drive.trashed(), _notesApi.list()).wait;
      if (mounted) {
        setState(() {
          _files = files;
          _notes = sortNotes(notes, trash: true);
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _dropFile(String id) => setState(() => _files = _files?.where((n) => n.id != id).toList());

  void _dropNote(String id) => setState(() => _notes = _notes?.where((n) => n.id != id).toList());

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

  /// Asks what to do with one item; null when dismissed.
  Future<_TrashAction?> _ask(String name) {
    final l = AppLocalizations.of(context);
    return showModalBottomSheet<_TrashAction>(
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
                    onTap: () => Navigator.pop(context, _TrashAction.restore),
                  ),
                  GroupTile(
                    icon: Icons.delete_forever_outlined,
                    title: l.notesDeleteForever,
                    danger: true,
                    chevron: false,
                    onTap: () => Navigator.pop(context, _TrashAction.deleteForever),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmDeleteForever(String name) {
    final l = AppLocalizations.of(context);
    return _confirm(
      l.notesDeleteForeverTitle,
      l.trashDeleteForeverBody(name),
      l.notesDeleteForever,
    );
  }

  Future<void> _fileActions(RecordModel node) async {
    final l = AppLocalizations.of(context);
    final name = node.getStringValue('name');
    final action = await _ask(name);
    if (!mounted || action == null) return;
    try {
      switch (action) {
        case _TrashAction.restore:
          await _drive.restoreFromTrash(node);
          if (!mounted) return;
          _dropFile(node.id);
          _snack(l.trashRestored(name));
        case _TrashAction.deleteForever:
          if (!await _confirmDeleteForever(name)) return;
          await _drive.deleteForever(node.id);
          if (!mounted) return;
          // A folder takes its content with it, and trashed children are listed on their own.
          node.getStringValue('kind') == 'folder' ? await _load() : _dropFile(node.id);
      }
    } on ClientException catch (e) {
      // The unique-name index refuses a restore next to an item of the same name.
      if (mounted) {
        _snack(
          action == _TrashAction.restore && e.statusCode == 400
              ? l.trashRestoreConflict(name)
              : errorMessage(context, e),
        );
      }
    } catch (e) {
      if (mounted) _snack(errorMessage(context, e));
    }
  }

  Future<void> _noteActions(RecordModel note) async {
    final l = AppLocalizations.of(context);
    final title = noteTitle(note).isEmpty ? l.notesUntitled : noteTitle(note);
    final action = await _ask(title);
    if (!mounted || action == null) return;
    try {
      switch (action) {
        case _TrashAction.restore:
          await _notesApi.restore(note.id);
          if (!mounted) return;
          _dropNote(note.id);
          _snack(l.trashRestored(title));
        case _TrashAction.deleteForever:
          if (!await _confirmDeleteForever(title)) return;
          await _notesApi.delete(note.id);
          if (mounted) _dropNote(note.id);
      }
    } catch (e) {
      if (mounted) _snack(errorMessage(context, e));
    }
  }

  Future<void> _emptyTrash() async {
    final l = AppLocalizations.of(context);
    final files = _files ?? const <RecordModel>[];
    final notes = _notes ?? const <RecordModel>[];
    if (!await _confirm(
      l.trashEmptyTitle,
      l.trashEmptyBody(files.length + notes.length),
      l.trashEmptyAction,
    )) {
      return;
    }
    // Rows stay untouchable until the end: nothing restored meanwhile gets deleted by the loop.
    setState(() => _emptying = true);
    var failed = 0;
    for (final n in files) {
      try {
        await _drive.deleteForever(n.id);
      } catch (_) {
        failed++;
      }
    }
    for (final n in notes) {
      try {
        await _notesApi.delete(n.id);
      } catch (_) {
        failed++;
      }
    }
    if (!mounted) return;
    await _load();
    if (!mounted) return;
    setState(() => _emptying = false);
    if (failed > 0) _snack(l.trashEmptyFailed(failed));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final files = _files;
    final notes = _notes;

    final List<Widget> content;
    if (_failed && (files == null || notes == null)) {
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
    } else if (files == null || notes == null) {
      content = [
        SliverList.builder(
          itemCount: 5,
          itemBuilder: (_, _) => const Padding(
            padding: EdgeInsets.symmetric(horizontal: AlcoveSpace.s4, vertical: AlcoveSpace.s2),
            child: SizedBox(height: 64, child: Skeleton(radius: AlcoveRadius.lg)),
          ),
        ),
      ];
    } else if (_isEmpty) {
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
        if (files.isNotEmpty)
          SliverToBoxAdapter(
            child: InsetGroup(
              title: l.trashFilesSection,
              children: [
                for (final n in files)
                  NodeRow(
                    key: ValueKey(n.id),
                    node: n,
                    locale: locale,
                    thumb: nodeThumb(widget.session, n, _token),
                    onTap: () => _fileActions(n),
                    onMore: () => _fileActions(n),
                    below: _trashedOn(n, locale, c),
                  ),
              ],
            ),
          ),
        if (notes.isNotEmpty)
          SliverToBoxAdapter(
            child: InsetGroup(
              title: l.notesTrashSection,
              children: [
                for (final n in notes)
                  NoteRow(
                    key: ValueKey(n.id),
                    note: n,
                    locale: locale,
                    onTap: () => _noteActions(n),
                  ),
              ],
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AlcoveSpace.s6),
            child: Text(
              l.trashHint,
              style: TextStyle(
                color: c.textMuted,
                fontSize: AlcoveFont.sizeXs + 1,
                height: AlcoveFont.leadingNormal,
              ),
            ),
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
                if (_emptying)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: AlcoveSpace.s4),
                    child: LoadingIndicator(size: 28),
                  )
                else if (!_isEmpty)
                  TextButton(
                    onPressed: _emptyTrash,
                    style: TextButton.styleFrom(foregroundColor: c.danger),
                    child: Text(l.trashEmptyAction),
                  ),
              ],
            ),
            for (final sliver in content) SliverIgnorePointer(ignoring: _emptying, sliver: sliver),
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
