import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'drive.dart';
import 'file_names.dart';

/// A file another app shared with Alcove, already copied into the app's cache.
@immutable
class SharedFile {
  const SharedFile({required this.path, required this.name, required this.mime, this.size = 0});

  final String path;
  final String name;
  final String mime;
  final int size;

  @override
  bool operator ==(Object other) =>
      other is SharedFile &&
      other.path == path &&
      other.name == name &&
      other.mime == mime &&
      other.size == size;

  @override
  int get hashCode => Object.hash(path, name, mime, size);
}

/// Reads what ShareChannel.kt sends: a list of `{path, name, mime, size}` maps. Entries without a
/// path are dropped; a missing name falls back to the last part of the path; names are made safe
/// ([safeFileName]).
List<SharedFile> parseSharedFiles(Object? raw) {
  if (raw is! List) return const [];
  final out = <SharedFile>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final path = item['path'];
    if (path is! String || path.isEmpty) continue;
    final name = item['name'];
    final mime = item['mime'];
    final size = item['size'];
    out.add(
      SharedFile(
        path: path,
        // Names come from another app: shown and uploaded only once made safe.
        name: safeFileName(name is String && name.trim().isNotEmpty ? name : path.split('/').last),
        mime: mime is String && mime.isNotEmpty ? mime : 'application/octet-stream',
        size: size is num ? size.toInt() : 0,
      ),
    );
  }
  return out;
}

/// Upload queue items for shared files going to [parent] ('' = My files).
List<UploadItem> sharedUploads(List<SharedFile> files, String parent) => [
  // The shared copies are ours: the queue moves them instead of copying them again.
  for (final f in files)
    UploadItem(name: f.name, parent: parent, open: () async => File(f.path), moveSource: true),
];

/// Files shared to the app ("Share to Alcove", Android). Each share is one batch on [incoming].
class ShareInbox {
  ShareInbox([MethodChannel? channel, bool? android])
    : _channel = channel ?? const MethodChannel('alcove/share'),
      _android = android ?? (!kIsWeb && Platform.isAndroid);

  final MethodChannel _channel;

  /// Shares only exist on Android (tests can say otherwise).
  final bool _android;
  final _incoming = StreamController<List<SharedFile>>.broadcast();

  Stream<List<SharedFile>> get incoming => _incoming.stream;

  /// Starts listening and delivers the shares that opened the app.
  Future<void> start() async {
    if (!_android) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'shared') _emit(parseSharedFiles(call.arguments));
    });
    try {
      final batches = await _channel.invokeListMethod<Object?>('ready') ?? const [];
      for (final b in batches) {
        _emit(parseSharedFiles(b));
      }
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  void _emit(List<SharedFile> files) {
    if (files.isNotEmpty && !_incoming.isClosed) _incoming.add(files);
  }

  /// Deletes the copies of a share the user cancelled (queued ones are copied by the queue).
  Future<void> discard(List<SharedFile> files) async {
    try {
      await _channel.invokeMethod<void>('discard', {
        'paths': [for (final f in files) f.path],
      });
    } catch (_) {}
  }

  void dispose() {
    if (_android) {
      _channel.setMethodCallHandler(null);
      // Signed out: Android keeps later shares until the next sign-in listens again.
      unawaited(
        _channel.invokeMethod<void>('unready').catchError((Object _) {}),
      );
    }
    unawaited(_incoming.close());
  }
}
