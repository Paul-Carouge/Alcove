import 'dart:async';
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
  UploadItem({required this.name, required this.parent, required this.open});

  final String name;
  final String parent;

  /// Gives a local file to send (copied from a content URI if needed).
  final Future<File> Function() open;

  UploadStatus status = UploadStatus.waiting;
  int sent = 0;
  int total = 0;
  String error = '';

  double get fraction => total == 0 ? 0 : sent / total;
}

/// Sends files one at a time (tus, resumable within a session) and reports progress.
class UploadQueue extends ChangeNotifier {
  UploadQueue(this.session, {http.Client Function()? httpClient})
    : _httpClient = httpClient ?? http.Client.new;

  final Session session;
  final http.Client Function() _httpClient;
  final List<UploadItem> items = [];
  final _done = StreamController<String>.broadcast();
  bool _running = false;

  /// Parent folder ids whose content changed (a file arrived).
  Stream<String> get completed => _done.stream;

  bool get active =>
      items.any((i) => i.status == UploadStatus.waiting || i.status == UploadStatus.uploading);
  int get finished => items.where((i) => i.status == UploadStatus.done).length;
  int get failedCount => items.where((i) => i.status == UploadStatus.failed).length;

  void add(Iterable<UploadItem> files) {
    items.addAll(files);
    notifyListeners();
    unawaited(_run());
  }

  /// Forgets finished and failed items.
  void clear() {
    items.removeWhere((i) => i.status == UploadStatus.done || i.status == UploadStatus.failed);
    notifyListeners();
  }

  void retryFailed() {
    for (final i in items.where((i) => i.status == UploadStatus.failed)) {
      i
        ..status = UploadStatus.waiting
        ..error = ''
        ..sent = 0;
    }
    notifyListeners();
    unawaited(_run());
  }

  Future<void> _run() async {
    if (_running) return;
    _running = true;
    final client = _httpClient();
    final uploader = TusUploader(client: client);
    try {
      while (true) {
        final next = items.where((i) => i.status == UploadStatus.waiting).firstOrNull;
        if (next == null) break;
        next.status = UploadStatus.uploading;
        notifyListeners();
        try {
          final file = await next.open();
          next.total = await file.length();
          await uploader.upload(
            endpoint: session.pb.buildURL('/api/v1/uploads/'),
            token: session.pb.authStore.token,
            file: file,
            metadata: {'filename': next.name, 'parent': next.parent},
            onProgress: (sent, total) {
              next
                ..sent = sent
                ..total = total;
              notifyListeners();
            },
          );
          next.status = UploadStatus.done;
          _done.add(next.parent);
        } on UploadException catch (e) {
          next
            ..status = UploadStatus.failed
            ..error = e.message;
        } catch (e) {
          next
            ..status = UploadStatus.failed
            ..error = e.toString();
        }
        notifyListeners();
      }
    } finally {
      client.close();
      _running = false;
    }
  }

  @override
  void dispose() {
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
