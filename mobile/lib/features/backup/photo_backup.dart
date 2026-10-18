import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../core/session.dart';
import 'backup_state.dart';
import 'library.dart';
import 'tus_client.dart';

/// The server's root folder for the photo library (drive.PhotosFolder): the same word in English and
/// French, not translated.
const photosFolder = 'Photos';

/// Why a backup run stopped.
enum BackupStop {
  finished,
  disabled,
  noAccess,
  notOnWifi,
  cancelled,
  timeUp,
  serverRefused,
  offline,
}

class BackupProgress {
  int total = 0;
  int processed = 0;
  int uploaded = 0;
  int alreadyThere = 0;
  int failed = 0;
  String current = '';
  double currentFraction = 0;

  int get remaining => total - processed;
}

class BackupReport {
  BackupReport(this.stop, this.progress, [this.error = '']);
  final BackupStop stop;
  final BackupProgress progress;
  final String error;
}

/// Uploads the phone's new photos and videos to a drive folder. Already uploaded assets (kept in
/// [BackupState]) and files the server already has (same SHA-256, POST /api/v1/backup/known) are
/// skipped; interrupted uploads resume.
class PhotoBackup {
  PhotoBackup({
    required this.session,
    required this.library,
    required this.store,
    required this.uploader,
    required this.isOnWifi,
    this.batchSize = 25,
  });

  final Session session;
  final PhotoLibrary library;
  final BackupStore store;
  final TusUploader uploader;
  final Future<bool> Function() isOnWifi;
  final int batchSize;

  Future<BackupReport> run({
    void Function(BackupProgress)? onProgress,
    bool Function()? cancelled,
    Duration? budget,
    String defaultFolderName = 'Phone backup',
  }) async {
    final progress = BackupProgress();
    final state = await store.load();
    if (!state.enabled) return BackupReport(BackupStop.disabled, progress);
    if (!session.isSignedIn) return BackupReport(BackupStop.disabled, progress);
    if (!await library.requestAccess()) return _finish(state, BackupStop.noAccess, progress);
    if (state.wifiOnly && !await isOnWifi()) return _finish(state, BackupStop.notOnWifi, progress);

    // The whole run talks to one server: switching servers stops it (the state belongs to this one).
    final pb = session.pb;
    final deadline = budget == null ? null : DateTime.now().add(budget);
    bool cancelledNow() => (cancelled?.call() ?? false) || !identical(session.pb, pb);
    bool stopNow() => cancelledNow() || (deadline != null && DateTime.now().isAfter(deadline));

    try {
      await _ensureFolder(pb, state, defaultFolderName);
    } on ClientException catch (e) {
      return _finish(
        state,
        e.statusCode == 0 ? BackupStop.offline : BackupStop.serverRefused,
        progress,
        e.response['message']?.toString() ?? '',
      );
    }

    final all = await library.assets(videos: state.videos);
    final todo = all.where((a) => !state.done.containsKey(a.id)).toList();
    progress.total = todo.length;
    onProgress?.call(progress);
    final uploadedThisRun = <String>{};

    for (var i = 0; i < todo.length; i += batchSize) {
      if (stopNow()) {
        return _finish(
          state,
          cancelledNow() ? BackupStop.cancelled : BackupStop.timeUp,
          progress,
        );
      }
      final batch = todo.sublist(i, (i + batchSize).clamp(0, todo.length));
      final files = <LibraryAsset, (File, String)>{};
      for (final asset in batch) {
        final file = await asset.original();
        if (file == null || !await file.exists() || await file.length() == 0) {
          // Not on the phone (e.g. only in iCloud): try again next time.
          progress
            ..failed += 1
            ..processed += 1;
          continue;
        }
        files[asset] = (file, (await sha256.bind(file.openRead()).first).toString());
      }

      final Set<String> known;
      try {
        final res = await pb.send<Map<String, dynamic>>(
          '/api/v1/backup/known',
          method: 'POST',
          body: {'hashes': files.values.map((f) => f.$2).toSet().toList()},
        );
        known = ((res['known'] as List?) ?? const []).cast<String>().toSet();
      } on ClientException catch (e) {
        return _finish(
          state,
          e.statusCode == 0 ? BackupStop.offline : BackupStop.serverRefused,
          progress,
        );
      }

      for (final MapEntry(key: asset, value: (file, hash)) in files.entries) {
        if (stopNow()) {
          return _finish(
            state,
            cancelledNow() ? BackupStop.cancelled : BackupStop.timeUp,
            progress,
          );
        }
        progress
          ..current = await asset.name()
          ..currentFraction = 0;
        onProgress?.call(progress);
        if (known.contains(hash) || uploadedThisRun.contains(hash)) {
          state.done[asset.id] = 'known';
          state.pending.remove(asset.id);
          progress.alreadyThere += 1;
        } else {
          try {
            final node = await uploader.upload(
              endpoint: pb.buildURL('/api/v1/uploads/'),
              token: pb.authStore.token,
              file: file,
              metadata: {'filename': progress.current, 'parent': state.folderId},
              resumeUrl: state.pending[asset.id],
              onCreated: (url) {
                state.pending[asset.id] = url;
                unawaited(store.save(state));
              },
              onProgress: (sent, total) {
                progress.currentFraction = total == 0 ? 1 : sent / total;
                onProgress?.call(progress);
              },
            );
            state.done[asset.id] = node;
            state.pending.remove(asset.id);
            uploadedThisRun.add(hash);
            progress.uploaded += 1;
          } on UploadException catch (e) {
            if (e.permanent) return _finish(state, BackupStop.serverRefused, progress, e.message);
            progress.failed += 1;
          } on SocketException {
            return _finish(state, BackupStop.offline, progress);
          } on Exception {
            progress.failed += 1;
          }
        }
        progress.processed += 1;
        await store.save(state);
        onProgress?.call(progress);
      }
    }
    return _finish(state, BackupStop.finished, progress);
  }

  Future<BackupReport> _finish(
    BackupState state,
    BackupStop stop,
    BackupProgress progress, [
    String error = '',
  ]) async {
    state
      ..lastRun = DateTime.now()
      ..lastError = error;
    await store.save(state);
    return BackupReport(stop, progress, error);
  }

  /// The destination folder: the saved one if it still exists, else a folder with the same name in the
  /// "Photos" root folder (the photo library, apart from the rest of the drive), else a new one.
  Future<void> _ensureFolder(PocketBase pb, BackupState state, String defaultName) async {
    final nodes = pb.collection('nodes');
    if (state.folderId.isNotEmpty) {
      try {
        final f = await nodes.getOne(state.folderId);
        if (f.getStringValue('trashed_at').isEmpty) return;
      } on ClientException catch (e) {
        if (e.statusCode != 404) rethrow;
      }
    }
    final name = state.folderName.isEmpty ? defaultName : state.folderName;
    final library = await _folderIn(pb, '', photosFolder);
    final folder = await _folderIn(pb, library.id, name);
    state
      ..folderId = folder.id
      ..folderName = name;
  }

  Future<RecordModel> _folderIn(PocketBase pb, String parent, String name) async {
    final nodes = pb.collection('nodes');
    final existing = await nodes.getList(
      perPage: 1,
      filter: pb.filter(
        // Drive names ignore case (unique index): "photos" is the same folder as "Photos".
        'parent = {:parent} && kind = "folder" && trashed_at = "" && name:lower = {:name}',
        {'parent': parent, 'name': name.toLowerCase()},
      ),
    );
    return existing.items.isNotEmpty
        ? existing.items.first
        : await nodes.create(
            body: {
              'owner': pb.authStore.record!.id,
              'parent': parent,
              'name': name,
              'kind': 'folder',
            },
          );
  }
}
