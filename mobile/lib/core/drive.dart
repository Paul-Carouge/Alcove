import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pocketbase/pocketbase.dart';

import '../features/backup/tus_client.dart';
import 'session.dart';

/// Why the server would refuse a name (same rule as server/internal/drive.NamePattern), or null.
String? invalidName(String name) {
  final n = name.trim();
  if (n.isEmpty) return 'empty';
  if (n.runes.length > 255) return 'long';
  if (n.contains('/') ||
      n.runes.any((r) => r < 0x20 || r == 0x7f) ||
      RegExp(r'^\.+$').hasMatch(n)) {
    return 'invalid';
  }
  return null;
}

/// Drive operations not tied to a screen. Access rules on the server scope everything to the user.
class Drive {
  Drive(this.session);

  final Session session;

  RecordService get _nodes => session.pb.collection('nodes');

  Future<RecordModel> createFolder(String parent, String name) => _nodes.create(
    body: {'owner': session.user?.id, 'parent': parent, 'name': name.trim(), 'kind': 'folder'},
  );

  Future<RecordModel> rename(String id, String name) =>
      _nodes.update(id, body: {'name': name.trim()});

  Future<RecordModel> move(String id, String parent) => _nodes.update(id, body: {'parent': parent});

  Future<RecordModel> trash(String id) =>
      _nodes.update(id, body: {'trashed_at': DateTime.now().toUtc().toIso8601String()});

  Future<RecordModel> setTags(String id, List<String> tags) =>
      _nodes.update(id, body: {'tags': tags});

  Future<RecordModel> restore(String id) => _nodes.update(id, body: {'trashed_at': ''});

  /// Makes a searchable copy of a scan (`<name> (OCR).pdf`) and waits for it; returns the new file id.
  /// Throws on refusal or failure.
  Future<String> makeSearchable(String id, {Duration poll = const Duration(seconds: 2)}) async {
    final path = '/api/v1/documents/${Uri.encodeComponent(id)}/searchable';
    var job = await session.pb.send<Map<String, dynamic>>(path, method: 'POST');
    while (job['status'] == 'running') {
      await Future<void>.delayed(poll);
      job = await session.pb.send<Map<String, dynamic>>(path);
    }
    if (job['status'] != 'done') throw StateError(job['error'] as String? ?? 'failed');
    return job['node'] as String;
  }

  /// Sub-folders of a folder ('' = root), by name.
  Future<List<RecordModel>> folders(String parent) async {
    final list = await _nodes.getFullList(
      filter: session.pb.filter('parent = {:p} && kind = "folder" && trashed_at = ""', {
        'p': parent,
      }),
    );
    list.sort(
      (a, b) =>
          a.getStringValue('name').toLowerCase().compareTo(b.getStringValue('name').toLowerCase()),
    );
    return list;
  }
}

enum UploadStatus { waiting, uploading, done, failed }

/// One file sent from the phone.
class UploadItem {
  UploadItem({
    required this.name,
    required this.parent,
    required this.open,
    this.path,
    this.resumeUrl,
    this.moveSource = false,
    this.account = '',
    this.queuedAt,
  });

  final String name;
  final String parent;

  /// The source is a temporary copy of ours (a file shared to the app): moved into the queue's
  /// storage instead of copied, so it doesn't stay behind.
  final bool moveSource;

  /// Whose upload this is (`<server>|<user id>`): only sent while that account is signed in.
  String account;

  /// When it was queued (items of another account are dropped after a week).
  DateTime? queuedAt;

  /// Gives a local file to send (copied from a content URI if needed).
  final Future<File> Function() open;

  /// The queue's own copy of the file, which survives the app being closed.
  String? path;

  /// The tus upload to resume, once created.
  String? resumeUrl;

  UploadStatus status = UploadStatus.waiting;
  int sent = 0;
  int total = 0;
  String error = '';

  double get fraction => total == 0 ? 0 : sent / total;

  Map<String, dynamic> toJson() => {
    'name': name,
    'parent': parent,
    'path': path,
    'resume': resumeUrl,
    'failed': status == UploadStatus.failed,
    'account': account,
    'queuedAt': queuedAt?.toUtc().toIso8601String(),
  };
}

/// Sends files one at a time (tus) and reports progress. Each file is first copied into the app's own
/// storage and the queue is saved, so uploads interrupted by closing the app resume at the next start
/// ([restore]), from where they stopped.
///
/// Each upload belongs to the account that queued it (server and user). Only the signed-in
/// account's uploads are sent; another account's stay on disk, resume when it signs in again, and
/// are deleted after [dormantFor]. Entries saved before accounts were recorded go to the first
/// account that signs in.
class UploadQueue extends ChangeNotifier {
  UploadQueue(
    this.session, {
    http.Client Function()? httpClient,
    Future<Directory> Function()? storage,
    DateTime Function()? now,
  }) : _httpClient = httpClient ?? Session.uploadClient,
       _storage = storage ?? _defaultStorage,
       _now = now ?? DateTime.now;

  static const dormantFor = Duration(days: 7);

  final Session session;
  final DateTime Function() _now;

  /// Saved uploads of other accounts, kept as they are in queue.json.
  final List<Map<String, dynamic>> _dormant = [];

  /// The signed-in account, as recorded on its uploads.
  String get account => '${session.server ?? ''}|${session.user?.id ?? ''}';
  final http.Client Function() _httpClient;
  final Future<Directory> Function() _storage;
  final List<UploadItem> items = [];
  final _done = StreamController<String>.broadcast();
  bool _running = false;
  bool _disposed = false;

  static Future<Directory> _defaultStorage() async =>
      Directory('${(await getApplicationSupportDirectory()).path}/uploads');

  /// Parent folder ids whose content changed (a file arrived).
  Stream<String> get completed => _done.stream;

  bool get active =>
      items.any((i) => i.status == UploadStatus.waiting || i.status == UploadStatus.uploading);
  int get finished => items.where((i) => i.status == UploadStatus.done).length;
  int get failedCount => items.where((i) => i.status == UploadStatus.failed).length;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  /// Queues files: they are copied into the app's storage first, then sent.
  void add(Iterable<UploadItem> files) {
    final list = files.toList();
    for (final i in list) {
      i
        ..account = account
        ..queuedAt ??= _now();
    }
    items.addAll(list);
    _changed();
    unawaited(_stage(list));
  }

  Future<void> _stage(List<UploadItem> list) async {
    final Directory dir;
    try {
      dir = await _storage();
      await dir.create(recursive: true);
    } catch (e) {
      for (final item in list) {
        item
          ..status = UploadStatus.failed
          ..error = e.toString();
      }
      _changed();
      return;
    }
    for (final item in list) {
      try {
        final src = await item.open();
        if (!src.path.startsWith(dir.path)) {
          final safe = item.name.replaceAll(RegExp(r'[^\w.\- ]'), '_');
          final target = '${dir.path}/${DateTime.now().microsecondsSinceEpoch}-$safe';
          if (item.moveSource) {
            // Our own temporary copy: moved (or copied, then deleted, across volumes).
            try {
              item.path = (await src.rename(target)).path;
            } on FileSystemException {
              item.path = (await src.copy(target)).path;
              await src.delete().catchError((Object _) => src);
            }
          } else {
            item.path = (await src.copy(target)).path;
          }
        } else {
          item.path = src.path;
        }
      } catch (e) {
        item
          ..status = UploadStatus.failed
          ..error = e.toString();
      }
    }
    await _save();
    _changed();
    unawaited(_run());
  }

  /// Picks up the uploads left by a previous run of the app.
  Future<void> restore() async {
    try {
      final dir = await _storage();
      // Leftovers of a save interrupted before its rename.
      if (await dir.exists()) {
        await for (final f in dir.list()) {
          if (f is File && f.path.endsWith('/queue.json.tmp')) {
            await f.delete();
          }
        }
      }
      final file = File('${dir.path}/queue.json');
      if (!await file.exists()) return;
      final list = jsonDecode(await file.readAsString()) as List<dynamic>;
      final me = account;
      final now = _now();
      for (final raw in list.cast<Map<String, dynamic>>()) {
        final path = raw['path'] as String?;
        if (path == null || !await File(path).exists()) continue;
        // Saved before accounts were recorded: the first account to sign in takes them.
        final owner = (raw['account'] as String?)?.isNotEmpty == true
            ? raw['account'] as String
            : me;
        final queuedAt = DateTime.tryParse(raw['queuedAt'] as String? ?? '') ?? now;
        if (owner != me) {
          if (now.difference(queuedAt) > dormantFor) {
            await File(path).delete().catchError((Object _) => File(path));
          } else {
            _dormant.add({
              ...raw,
              'account': owner,
              'queuedAt': queuedAt.toUtc().toIso8601String(),
            });
          }
          continue;
        }
        final item = UploadItem(
          name: raw['name'] as String,
          parent: raw['parent'] as String? ?? '',
          open: () async => File(path),
          path: path,
          resumeUrl: raw['resume'] as String?,
          account: owner,
          queuedAt: queuedAt,
        );
        if (raw['failed'] == true) item.status = UploadStatus.failed;
        items.add(item);
      }
      await _save(); // records the adopted and dropped entries
    } catch (_) {
      return; // a damaged queue file must not break the app
    }
    _changed();
    unawaited(_run());
  }

  Future<void> _saving = Future.value();

  /// Completes when every save requested so far is on disk.
  @visibleForTesting
  Future<void> get saved => _saving;

  /// Saves run one after another, each writing the state at its turn: two overlapping saves could
  /// otherwise finish out of order and leave the older queue on disk.
  Future<void> _save() => _saving = _saving.then((_) => _write());

  Future<void> _write() async {
    try {
      final dir = await _storage();
      await dir.create(recursive: true);
      final pending = items.where((i) => i.status != UploadStatus.done && i.path != null);
      // Other accounts' uploads are kept for when they sign in again. Written to a temporary file then
      // renamed, so an app killed mid-write never leaves a truncated queue (which restore would drop).
      final tmp = File('${dir.path}/queue.json.tmp');
      await tmp.writeAsString(
        jsonEncode([for (final i in pending) i.toJson(), ..._dormant]),
        flush: true,
      );
      await tmp.rename('${dir.path}/queue.json');
    } catch (_) {
      // Saving is best effort: the upload itself goes on.
    }
  }

  Future<void> _discard(UploadItem item) async {
    final path = item.path;
    if (path == null) return;
    try {
      if (path.startsWith((await _storage()).path)) await File(path).delete();
    } catch (_) {}
  }

  /// Forgets finished and failed items (and their copies).
  void clear() {
    final gone = items
        .where((i) => i.status == UploadStatus.done || i.status == UploadStatus.failed)
        .toList();
    items.removeWhere(gone.contains);
    _changed();
    unawaited(() async {
      for (final i in gone.where((i) => i.status == UploadStatus.failed)) {
        await _discard(i);
      }
      await _save();
    }());
  }

  void retryFailed() {
    for (final i in items.where((i) => i.status == UploadStatus.failed && i.path != null)) {
      i
        ..status = UploadStatus.waiting
        ..error = ''
        ..sent = 0;
    }
    _changed();
    unawaited(_run());
  }

  Future<void> _run() async {
    if (_running) return;
    _running = true;
    final client = _httpClient();
    final uploader = TusUploader(client: client);
    try {
      while (!_disposed) {
        final next = items
            .where((i) => i.status == UploadStatus.waiting && i.path != null)
            .firstOrNull;
        if (next == null) break;
        next.status = UploadStatus.uploading;
        _changed();
        try {
          final file = File(next.path!);
          next.total = await file.length();
          await uploader.upload(
            endpoint: session.pb.buildURL('/api/v1/uploads/'),
            token: session.pb.authStore.token,
            file: file,
            metadata: {'filename': next.name, 'parent': next.parent},
            resumeUrl: next.resumeUrl,
            onCreated: (url) {
              next.resumeUrl = url;
              unawaited(_save());
            },
            onProgress: (sent, total) {
              next
                ..sent = sent
                ..total = total;
              _changed();
            },
          );
          next.status = UploadStatus.done;
          await _discard(next);
          if (!_done.isClosed) _done.add(next.parent);
        } on UploadException catch (e) {
          next
            ..status = UploadStatus.failed
            ..error = e.message;
          // The server refused for good: start from scratch if retried.
          if (e.permanent) next.resumeUrl = null;
        } catch (e) {
          next
            ..status = UploadStatus.failed
            ..error = e.toString();
        }
        await _save();
        _changed();
      }
    } finally {
      client.close();
      _running = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_done.close());
    super.dispose();
  }
}

/// Writes a byte stream to a temporary file (picked files that only have a content URI).
Future<File> spool(Stream<List<int>> bytes, String name) async {
  final dir = Directory('${(await getTemporaryDirectory()).path}/outgoing');
  await dir.create(recursive: true);
  final safe = name.replaceAll(RegExp(r'[^\w.\- ]'), '_');
  final file = File('${dir.path}/${DateTime.now().microsecondsSinceEpoch}-$safe');
  final sink = file.openWrite();
  await sink.addStream(bytes);
  await sink.close();
  return file;
}
