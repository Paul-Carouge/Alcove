import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';

import 'session.dart';

/// A change to a note made anywhere (this device or another), from the server's realtime stream.
typedef NoteEvent = ({String action, RecordModel record});

/// Notes of the signed-in user (ADR 0027): the `notes` collection, owner-only on the server.
class NotesApi {
  NotesApi(this.session);

  final Session session;

  RecordService get _notes => session.pb.collection('notes');

  Future<List<RecordModel>> list() => _notes.getFullList(sort: '-updated', batch: 500);

  Future<RecordModel> create() =>
      _notes.create(body: {'owner': session.user?.id, 'title': '', 'body': ''});

  Future<RecordModel> update(String id, Map<String, dynamic> body) => _notes.update(id, body: body);

  Future<RecordModel> trash(String id) =>
      update(id, {'trashed_at': DateTime.now().toUtc().toIso8601String()});

  Future<RecordModel> restore(String id) => update(id, {'trashed_at': ''});

  Future<void> delete(String id) => _notes.delete(id);

  /// Follows changes while the app is open; returns the function that stops listening.
  Future<void Function()> watch(void Function(NoteEvent event) onEvent) async {
    final stop = await _notes.subscribe('*', (e) {
      final r = e.record;
      if (r != null) onEvent((action: e.action, record: r));
    });
    return () => unawaited(stop());
  }
}

bool isTrashed(RecordModel n) => n.getStringValue('trashed_at').isNotEmpty;

/// Notes not in the trash (or only those in it): pinned first, then the most recently edited.
List<RecordModel> sortNotes(Iterable<RecordModel> notes, {bool trash = false}) {
  final list = notes.where((n) => isTrashed(n) == trash).toList();
  list.sort((a, b) {
    final p = (b.getBoolValue('pinned') ? 1 : 0) - (a.getBoolValue('pinned') ? 1 : 0);
    return p != 0 ? p : b.getStringValue('updated').compareTo(a.getStringValue('updated'));
  });
  return list;
}

/// Notes whose title or text contains every word of [query] (case ignored).
List<RecordModel> filterNotes(List<RecordModel> notes, String query) {
  final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return notes;
  return notes.where((n) {
    final text = '${n.getStringValue('title')}\n${n.getStringValue('body')}'.toLowerCase();
    return words.every(text.contains);
  }).toList();
}

final _marker = RegExp(r'^\s*(#{1,6}|[-*+]\s+\[[ xX]\]|[-*+]|\d+[.)]|>)\s*');
final _rule = RegExp(r'^\s*([-*_])(\s*\1){2,}\s*$');
final _link = RegExp(r'\[([^\]]+)\]\([^)]*\)');

/// The first line of text of a note, without Markdown markers (same as the web app).
String excerpt(String body, {int max = 140}) {
  for (final line in body.split(RegExp(r'\r?\n'))) {
    if (_rule.hasMatch(line) || line.trimLeft().startsWith('```')) continue;
    final text = line
        .replaceFirst(_marker, '')
        .replaceAll(RegExp(r'[*_`]'), '')
        .replaceAllMapped(_link, (m) => m[1]!)
        .trim();
    if (text.isNotEmpty) return text.length > max ? '${text.substring(0, max - 1)}…' : text;
  }
  return '';
}

/// The title of a note, or its first line, or '' (the screen then says "Untitled").
String noteTitle(RecordModel n) {
  final t = n.getStringValue('title').trim();
  return t.isNotEmpty ? t : excerpt(n.getStringValue('body'), max: 60);
}

enum SaveState { idle, pending, saving, saved, error }

/// Saves edits after a pause in typing, one save at a time; edits made during a save are sent
/// right after it, and failed ones are kept for the next attempt.
class Autosave extends ChangeNotifier {
  Autosave(this._save, {this.delay = const Duration(milliseconds: 800)});

  final Future<void> Function(Map<String, dynamic> changes) _save;
  final Duration delay;

  SaveState state = SaveState.idle;
  Map<String, dynamic> _changes = {};
  Timer? _timer;
  Future<void>? _running;
  bool _cancelled = false;

  /// True while some edits have not reached the server.
  bool get dirty =>
      state == SaveState.pending || state == SaveState.saving || state == SaveState.error;

  void _set(SaveState s) {
    state = s;
    notifyListeners();
  }

  void change(Map<String, dynamic> changes) {
    if (_cancelled) return;
    _changes = {..._changes, ...changes};
    _set(SaveState.pending);
    _timer?.cancel();
    _timer = Timer(delay, () => unawaited(flush()));
  }

  Future<void> flush() async {
    _timer?.cancel();
    if (_running != null) {
      await _running;
      if (_changes.isNotEmpty && state != SaveState.error) return flush();
      return;
    }
    if (_cancelled || _changes.isEmpty) return;
    final changes = _changes;
    _changes = {};
    _set(SaveState.saving);
    _running = _save(changes).then(
      (_) {
        if (!_cancelled && state == SaveState.saving) _set(SaveState.saved);
      },
      onError: (Object _) {
        if (_cancelled) return;
        _changes = {...changes, ..._changes};
        _set(SaveState.error);
      },
    );
    await _running;
    _running = null;
    if (_changes.isNotEmpty && state != SaveState.error) return flush();
  }

  /// Drops pending edits for good (the note was deleted, or the user chose to leave).
  void cancel() {
    _timer?.cancel();
    _cancelled = true;
    _changes = {};
    _set(SaveState.idle);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Whether [incoming] is a newer version than [known]; late echoes of older saves are not.
bool isNewer(RecordModel incoming, RecordModel? known) =>
    known == null ||
    incoming.getStringValue('updated').compareTo(known.getStringValue('updated')) > 0;
