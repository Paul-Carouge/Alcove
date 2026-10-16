import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../core/notes.dart';
import '../../core/session.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../ui/shell.dart';
import '../files/file_actions.dart';
import '../files/tags.dart';

String _date(String iso, String locale) {
  final d = DateTime.tryParse(iso.replaceFirst(' ', 'T'))?.toLocal();
  if (d == null) return '';
  final now = DateTime.now();
  return d.year == now.year && d.month == now.month && d.day == now.day
      ? DateFormat.Hm(locale).format(d)
      : DateFormat.yMMMd(locale).format(d);
}

/// The user's notes, pinned first, kept current by realtime updates while the screen is open.
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key, required this.session, this.api});

  final Session session;

  /// Replaced in tests.
  final NotesApi? api;

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  late final NotesApi _api = widget.api ?? NotesApi(widget.session);
  late final TagBook _tags = TagBook(widget.session);
  List<RecordModel>? _all;
  bool _failed = false;
  String _query = '';
  bool _trash = false;
  void Function()? _stop;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _api.watch(_onEvent).then((stop) => mounted ? _stop = stop : stop()).catchError((Object _) {});
  }

  @override
  void dispose() {
    _stop?.call();
    super.dispose();
  }

  void _onEvent(NoteEvent e) {
    final all = _all;
    if (all == null || !mounted) return;
    final known = all.where((n) => n.id == e.record.id).firstOrNull;
    if (e.action != 'delete' && !isNewer(e.record, known)) return;
    setState(() {
      _all = [
        for (final n in all)
          if (n.id != e.record.id) n,
        if (e.action != 'delete') e.record,
      ];
    });
  }

  Future<void> _load() async {
    try {
      await _tags.load().catchError((Object _) {});
      final list = await _api.list();
      if (mounted) {
        setState(() {
          _all = list;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _put(RecordModel note) {
    if (!mounted) return;
    setState(
      () => _all = [
        for (final n in _all ?? <RecordModel>[])
          if (n.id != note.id) n,
        note,
      ],
    );
  }

  Future<void> _open(RecordModel note, {bool isNew = false}) async {
    // Above the navigation bar: the editor has the whole screen (and the keyboard).
    final result = await Navigator.of(context, rootNavigator: true).push<RecordModel>(
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(
          session: widget.session,
          api: _api,
          tags: _tags,
          note: note,
          autofocus: isNew,
        ),
      ),
    );
    if (!mounted || result == null) return;
    _put(result);
    if (isTrashed(result)) {
      unawaited(HapticFeedback.mediumImpact());
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              l.trashed(noteTitle(result).isEmpty ? l.notesUntitled : noteTitle(result)),
            ),
            action: SnackBarAction(
              label: l.undo,
              onPressed: () => _api.restore(result.id).then(_put).catchError((Object _) {}),
            ),
          ),
        );
    }
  }

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  /// Restore or delete forever, for a note in the trash.
  Future<void> _trashActions(RecordModel note) async {
    final l = AppLocalizations.of(context);
    final title = noteTitle(note).isEmpty ? l.notesUntitled : noteTitle(note);
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
              SheetHeader(title: title),
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
        _put(await _api.restore(note.id));
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l.notesDeleteForeverTitle),
          content: Text(l.notesDeleteForeverBody(title)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.notesDeleteForever),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await _api.delete(note.id);
      if (mounted) setState(() => _all = _all?.where((n) => n.id != note.id).toList());
    } catch (e) {
      if (mounted) _snack(errorMessage(context, e));
    }
  }

  Future<void> _create() async {
    try {
      final note = await _api.create();
      if (!mounted) return;
      _put(note);
      await _open(note, isNew: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage(context, e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final all = _all;
    final notes = all == null ? null : filterNotes(sortNotes(all, trash: _trash), _query);

    final List<Widget> content;
    if (_failed && all == null) {
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
    } else if (notes == null) {
      content = [
        SliverList.builder(
          itemCount: 5,
          itemBuilder: (_, _) => const Padding(
            padding: EdgeInsets.symmetric(horizontal: AlcoveSpace.s4, vertical: AlcoveSpace.s2),
            child: SizedBox(height: 72, child: Skeleton(radius: AlcoveRadius.lg)),
          ),
        ),
      ];
    } else if (notes.isEmpty) {
      content = [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _query.isNotEmpty
              ? EmptyState(icon: Icons.search_off, title: l.notesNone)
              : _trash
              ? EmptyState(
                  icon: Icons.delete_outline,
                  title: l.notesTrashEmpty,
                  body: l.notesTrashHint,
                )
              : EmptyState(
                  icon: Icons.edit_note,
                  title: l.notesEmptyTitle,
                  body: l.notesEmptyBody,
                ),
        ),
      ];
    } else {
      content = [
        SliverToBoxAdapter(
          child: InsetGroup(
            footer: _trash ? l.notesTrashHint : null,
            children: [
              for (final n in notes)
                NoteRow(
                  note: n,
                  locale: locale,
                  tags: _tags.of(n),
                  onTap: () => _trash ? _trashActions(n) : _open(n),
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
              title: _trash ? l.notesTrash : l.tabNotes,
              actions: [
                IconButton(
                  tooltip: l.notesTrash,
                  isSelected: _trash,
                  icon: const Icon(Icons.delete_outline),
                  selectedIcon: Icon(Icons.delete, color: c.accent),
                  onPressed: () => setState(() => _trash = !_trash),
                ),
                ...shellActions(context),
              ],
            ),
            // Filters the notes in place (the top bar's search looks everywhere).
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AlcoveSpace.s4,
                  AlcoveSpace.s1,
                  AlcoveSpace.s4,
                  AlcoveSpace.s4,
                ),
                child: _FilterField(
                  hint: l.notesSearch,
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
            ),
            ...content,
            SliverToBoxAdapter(
              child: SizedBox(
                height: AlcoveSpace.s8 + AlcoveSpace.s5 + MediaQuery.paddingOf(context).bottom,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _trash
          ? null
          : FloatingActionButton.extended(
              key: const Key('newNote'),
              onPressed: _create,
              icon: const Icon(Icons.edit_outlined),
              label: Text(l.notesNew),
            ),
    );
  }
}

/// A quiet search pill that filters a list as you type.
class _FilterField extends StatefulWidget {
  const _FilterField({required this.hint, required this.onChanged});
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  State<_FilterField> createState() => _FilterFieldState();
}

class _FilterFieldState extends State<_FilterField> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    const pill = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(AlcoveRadius.full)),
      borderSide: BorderSide.none,
    );
    return TextField(
      key: const Key('notesFilter'),
      controller: _text,
      textInputAction: TextInputAction.search,
      onChanged: (v) {
        setState(() {});
        widget.onChanged(v);
      },
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _text.text.isEmpty
            ? null
            : IconButton(
                tooltip: l.searchClear,
                icon: const Icon(Icons.close),
                onPressed: () {
                  _text.clear();
                  setState(() {});
                  widget.onChanged('');
                },
              ),
        filled: true,
        fillColor: c.surfaceSunken,
        contentPadding: const EdgeInsets.symmetric(vertical: AlcoveSpace.s3),
        border: pill,
        enabledBorder: pill,
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(AlcoveRadius.full)),
          borderSide: BorderSide(color: c.focus, width: 1.5),
        ),
      ),
    );
  }
}

/// One note in the list: title, first line, tags and date.
class NoteRow extends StatelessWidget {
  const NoteRow({
    super.key,
    required this.note,
    required this.locale,
    required this.onTap,
    this.tags = const [],
  });

  final RecordModel note;
  final String locale;
  final VoidCallback onTap;
  final List<RecordModel> tags;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final title = noteTitle(note);
    final body = excerpt(note.getStringValue('body'));
    final showBody = note.getStringValue('title').trim().isNotEmpty && body.isNotEmpty;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AlcoveSpace.s4, vertical: AlcoveSpace.s3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (note.getBoolValue('pinned')) ...[
                    Icon(Icons.push_pin, size: 16, color: c.accent, semanticLabel: l.notesPinned),
                    const SizedBox(width: AlcoveSpace.s1),
                  ],
                  Expanded(
                    child: Text(
                      title.isEmpty ? l.notesUntitled : title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: displayStyle(AlcoveFont.sizeLg, c.text),
                    ),
                  ),
                ],
              ),
              if (showBody) ...[
                const SizedBox(height: 2),
                Text(
                  body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.textMuted, fontSize: AlcoveFont.sizeSm),
                ),
              ],
              const SizedBox(height: AlcoveSpace.s1),
              Wrap(
                spacing: AlcoveSpace.s1,
                runSpacing: AlcoveSpace.s1,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final t in tags) TagChip(tag: t),
                  Text(
                    _date(note.getStringValue('updated'), locale),
                    style: TextStyle(color: c.textMuted, fontSize: AlcoveFont.sizeXs),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Edits one note; changes are saved as you type. Pops with the latest version of the note.
class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({
    super.key,
    required this.session,
    required this.api,
    required this.note,
    this.tags,
    this.autofocus = false,
    this.saveDelay = const Duration(milliseconds: 800),
  });

  final Session session;
  final NotesApi api;
  final RecordModel note;
  final TagBook? tags;
  final bool autofocus;
  final Duration saveDelay;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late RecordModel _note = widget.note;
  late final _title = TextEditingController(text: _note.getStringValue('title'));
  late final _body = TextEditingController(text: _note.getStringValue('body'));
  late final Autosave _saver = Autosave((changes) async {
    final saved = await widget.api.update(_note.id, changes);
    if (mounted) setState(() => _note = saved);
  }, delay: widget.saveDelay);
  void Function()? _stop;
  bool _closing = false;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Leaving the app (home button, app switcher): save now.
    _lifecycle = AppLifecycleListener(onHide: () => unawaited(_saver.flush()));
    _saver.addListener(_redraw);
    widget.api
        .watch(_onEvent)
        .then((stop) => mounted ? _stop = stop : stop())
        .catchError((Object _) {});
  }

  void _redraw() {
    if (mounted) setState(() {});
  }

  // Another device edited this note: show it, unless edits made here are not saved yet.
  void _onEvent(NoteEvent e) {
    if (e.record.id != _note.id || !mounted) return;
    if (e.action == 'delete') {
      _saver.cancel();
      _closing = true;
      Navigator.of(context).pop();
      return;
    }
    if (!isNewer(e.record, _note)) return;
    setState(() => _note = e.record);
    if (_saver.dirty) return;
    final title = e.record.getStringValue('title');
    final body = e.record.getStringValue('body');
    if (_title.text != title) _title.text = title;
    if (_body.text != body) _body.text = body;
  }

  @override
  void dispose() {
    _stop?.call();
    _lifecycle.dispose();
    unawaited(_saver.flush());
    _saver.removeListener(_redraw);
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _changed() => _saver.change({'title': _title.text, 'body': _body.text});

  /// Sends pending edits; false when they could not be saved (offline): waits at most a few seconds.
  Future<bool> _saved() async {
    await _saver.flush().timeout(const Duration(seconds: 5), onTimeout: () {});
    return !_saver.dirty;
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    if (!await _saved() && mounted) {
      final l = AppLocalizations.of(context);
      final leave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l.notesLeaveTitle),
          content: Text(l.notesLeaveBody),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l.notesLeave)),
            FilledButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.notesKeepEditing),
            ),
          ],
        ),
      );
      if (leave != true) {
        _closing = false;
        return;
      }
      _saver.cancel();
    }
    if (mounted) Navigator.of(context).pop(_note);
  }

  Future<void> _run(Future<RecordModel> Function() action) async {
    try {
      final saved = await action();
      if (mounted) setState(() => _note = saved);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage(context, e))));
      }
    }
  }

  Future<void> _editTags() async {
    final book = widget.tags;
    if (book == null) return;
    await book.load().catchError((Object _) {});
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    final named = RecordModel.fromJson({
      ..._note.toJson(),
      'name': _title.text.trim().isEmpty ? l.notesUntitled : _title.text.trim(),
    });
    final ids = await pickTags(context, book, named);
    if (ids != null) await _run(() => widget.api.update(_note.id, {'tags': ids}));
  }

  Future<void> _trash() async {
    if (_closing) return;
    _closing = true;
    if (!await _saved()) {
      _closing = false;
      if (mounted) {
        final l = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.notesSaveFailed)));
      }
      return;
    }
    try {
      final saved = await widget.api.trash(_note.id);
      if (mounted) Navigator.of(context).pop(saved);
    } catch (e) {
      _closing = false;
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage(context, e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final pinned = _note.getBoolValue('pinned');
    final tags = widget.tags?.of(_note) ?? const <RecordModel>[];
    final status = switch (_saver.state) {
      SaveState.pending || SaveState.saving => l.notesSaving,
      SaveState.saved => l.notesSaved,
      SaveState.error => l.notesSaveFailed,
      SaveState.idle => '',
    };
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_close());
      },
      child: Scaffold(
        backgroundColor: c.surface,
        appBar: AppBar(
          backgroundColor: c.surface,
          leading: BackButton(onPressed: _close),
          titleSpacing: 0,
          title: Semantics(
            liveRegion: true,
            child: GestureDetector(
              onTap: _saver.state == SaveState.error ? _saver.flush : null,
              child: Text(
                status,
                style: TextStyle(
                  color: _saver.state == SaveState.error ? c.danger : c.textMuted,
                  fontSize: AlcoveFont.sizeSm,
                ),
              ),
            ),
          ),
          actions: [
            IconButton(
              tooltip: pinned ? l.notesUnpin : l.notesPin,
              isSelected: pinned,
              icon: const Icon(Icons.push_pin_outlined),
              selectedIcon: Icon(Icons.push_pin, color: c.accent),
              onPressed: () => _run(() => widget.api.update(_note.id, {'pinned': !pinned})),
            ),
            if (widget.tags != null)
              IconButton(
                tooltip: l.tags,
                icon: const Icon(Icons.sell_outlined),
                onPressed: _editTags,
              ),
            IconButton(
              tooltip: l.trashConfirm,
              icon: const Icon(Icons.delete_outline),
              onPressed: _trash,
            ),
            const SizedBox(width: AlcoveSpace.s1),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            AlcoveSpace.s5,
            AlcoveSpace.s2,
            AlcoveSpace.s5,
            AlcoveSpace.s8,
          ),
          children: [
            Semantics(
              label: l.notesTitleLabel,
              child: TextField(
                key: const Key('noteTitle'),
                controller: _title,
                autofocus: widget.autofocus,
                maxLength: 200,
                textCapitalization: TextCapitalization.sentences,
                style: displayStyle(AlcoveFont.sizeXxl, c.text),
                decoration: InputDecoration(
                  hintText: l.notesUntitled,
                  semanticCounterText: '',
                  counterText: '',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (_) => _changed(),
              ),
            ),
            if (tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AlcoveSpace.s3),
                child: Wrap(
                  spacing: AlcoveSpace.s1,
                  runSpacing: AlcoveSpace.s1,
                  children: [for (final t in tags) TagChip(tag: t)],
                ),
              ),
            Semantics(
              label: l.notesBodyLabel,
              child: TextField(
                key: const Key('noteBody'),
                controller: _body,
                maxLines: null,
                minLines: 12,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(
                  color: c.text,
                  fontSize: AlcoveFont.sizeMd,
                  height: AlcoveFont.leadingNormal,
                ),
                decoration: InputDecoration(
                  hintText: l.notesBodyHint,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (_) => _changed(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
