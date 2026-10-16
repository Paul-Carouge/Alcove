import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pocketbase/pocketbase.dart';

import 'file_names.dart';
import 'prefs.dart';
import 'session.dart';

/// A cache file name for a drive file: its id and version (so an edited file is fetched again)
/// and a safe copy of its name (other apps see it in "Open with" and "Share").
String cacheName(String id, String version, String name) {
  final v = version.replaceAll(RegExp(r'[^0-9A-Za-z]'), '');
  final id_ = id.replaceAll(RegExp(r'[^0-9A-Za-z]'), '');
  return '$id_-$v/${safeFileName(name)}';
}

/// The most bytes accepted for a download: the larger of the drive's size and the announced
/// length, or [maxDownloadBytes] when neither is known.
int downloadLimit(int expectedSize, int? contentLength) {
  final known = [expectedSize, contentLength ?? 0].where((n) => n > 0);
  return known.isEmpty ? maxDownloadBytes : known.reduce((a, b) => a > b ? a : b);
}

const maxDownloadBytes = 4 * 1000 * 1000 * 1000;

/// Forgets the files of the signed-in account kept on this phone: the viewer cache, files shared
/// to the app, picked files waiting to be copied, and the recent files lists. Called on sign-out
/// and when another server is chosen. Best effort: the system may also clear the cache.
Future<void> purgeDeviceFiles({Future<Directory> Function()? cache, LocalPrefs? prefs}) async {
  try {
    final base = await (cache ?? getTemporaryDirectory)();
    for (final name in ['viewer', 'shared', 'outgoing']) {
      final d = Directory('${base.path}/$name');
      if (await d.exists()) await d.delete(recursive: true);
    }
  } catch (_) {}
  try {
    await (prefs ?? LocalPrefs.instance).removeWhere((k) => k.startsWith('recent:'));
  } catch (_) {}
}

/// Files downloaded for the in-app viewers, kept in the app cache (`viewer/`, the only folder
/// shared with other apps through the FileProvider) and pruned: oldest first above [maxBytes],
/// and anything older than [maxAge]. Downloads use the short-lived file token, like thumbnails.
class FileCache {
  FileCache({Future<Directory> Function()? root, this.maxBytes = 300 * 1000 * 1000})
    : _root = root ?? _defaultRoot;

  static FileCache instance = FileCache();

  final Future<Directory> Function() _root;
  final int maxBytes;
  static const maxAge = Duration(days: 3);

  static Future<Directory> _defaultRoot() async =>
      Directory('${(await getTemporaryDirectory()).path}/viewer');

  Future<Directory> get root => _root();

  /// The URL of a drive file's content (attachment), with a file token.
  static Future<Uri> nodeUrl(Session session, RecordModel node) async {
    final token = await session.fileToken();
    return session.pb.buildURL('/api/v1/nodes/${Uri.encodeComponent(node.id)}/download', {
      'token': token,
    });
  }

  /// A drive file, downloaded once (or again when it changed).
  Future<File> node(
    Session session,
    RecordModel node, {
    void Function(int received, int total)? onProgress,
  }) async {
    return fetch(
      session,
      key: cacheName(node.id, node.getStringValue('updated'), node.getStringValue('name')),
      url: () => nodeUrl(session, node),
      expectedSize: node.getIntValue('size'),
      onProgress: onProgress,
    );
  }

  /// Downloads [url] into the cache under [key] (`<folder>/<name>`) unless already there.
  Future<File> fetch(
    Session session, {
    required String key,
    required Future<Uri> Function() url,
    int expectedSize = 0,
    void Function(int received, int total)? onProgress,
    http.Client? client,
  }) async {
    final dir = await root;
    final file = File('${dir.path}/$key');
    if (await file.exists()) {
      final len = await file.length();
      if (expectedSize <= 0 || len == expectedSize) {
        // Touched, so pruning keeps what was opened recently.
        unawaited(file.setLastModified(DateTime.now()).catchError((Object _) {}));
        return file;
      }
    }
    // The same file asked again while it downloads (the viewer reopened): one download, one
    // writer on the .part file, every caller told about the progress.
    final running = _running[file.path];
    if (running != null) {
      if (onProgress != null) running.listeners.add(onProgress);
      return running.future;
    }
    final download = _Download();
    if (onProgress != null) download.listeners.add(onProgress);
    _running[file.path] = download;
    download.future = _download(
      session,
      file,
      url,
      expectedSize,
      download,
      client,
    ).whenComplete(() => _running.remove(file.path));
    return download.future;
  }

  /// Downloads in progress, by destination path (shared by every cache on the same folder).
  static final _running = <String, _Download>{};

  Future<File> _download(
    Session session,
    File file,
    Future<Uri> Function() url,
    int expectedSize,
    _Download download,
    http.Client? client,
  ) async {
    await file.parent.create(recursive: true);
    final part = File('${file.path}.part');
    final http_ = client ?? session.httpClientFactory?.call() ?? http.Client();
    try {
      final res = await http_.send(http.Request('GET', await url()));
      if (res.statusCode != 200) {
        throw HttpException('HTTP ${res.statusCode}', uri: res.request?.url);
      }
      final total = res.contentLength ?? expectedSize;
      final limit = downloadLimit(expectedSize, res.contentLength);
      var received = 0;
      final sink = part.openWrite();
      try {
        await for (final chunk in res.stream) {
          received += chunk.length;
          // A server (or proxy) sending more than announced must not fill the phone.
          if (received > limit) throw const HttpException('larger than announced');
          sink.add(chunk);
          for (final l in download.listeners) {
            l(received, total);
          }
        }
      } finally {
        await sink.close();
      }
      return await part.rename(file.path);
    } catch (_) {
      await part.delete().catchError((Object _) => part);
      rethrow;
    } finally {
      if (client == null) http_.close();
    }
  }

  /// Removes old files, then the oldest ones while the cache is above [maxBytes]. Shared-in copies
  /// ("Share to Alcove") older than a day go too.
  Future<void> prune({DateTime? now}) async {
    final at = now ?? DateTime.now();
    try {
      final dir = await root;
      if (await dir.exists()) {
        final files = <(File, int, DateTime)>[];
        await for (final e in dir.list(recursive: true, followLinks: false)) {
          if (e is! File) continue;
          final st = await e.stat();
          files.add((e, st.size, st.modified));
        }
        files.sort((a, b) => a.$3.compareTo(b.$3));
        var total = files.fold<int>(0, (s, f) => s + f.$2);
        for (final (f, size, modified) in files) {
          // A .part file may be a download in progress: only an hour-old one is abandoned.
          final old = f.path.endsWith('.part')
              ? at.difference(modified) > const Duration(hours: 1)
              : at.difference(modified) > maxAge;
          if (!old && total <= maxBytes) continue;
          await f.delete().catchError((Object _) => f);
          total -= size;
        }
        // Empty version folders.
        await for (final e in dir.list(followLinks: false)) {
          if (e is Directory && await e.list().isEmpty) {
            await e.delete().catchError((Object _) => e);
          }
        }
      }
      final shared = Directory('${dir.parent.path}/shared');
      if (await shared.exists()) {
        await for (final e in shared.list(followLinks: false)) {
          if (e is File && at.difference((await e.stat()).modified) > const Duration(days: 1)) {
            await e.delete().catchError((Object _) => e);
          }
        }
      }
    } catch (_) {
      // Best effort: the system may also clear the cache.
    }
  }
}

class _Download {
  late Future<File> future;
  final listeners = <void Function(int received, int total)>[];
}
