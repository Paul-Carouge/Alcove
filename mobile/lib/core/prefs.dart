import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Small, non-secret settings kept on this device only (file sort order, recently opened files).
/// A JSON file in the app's support directory: no extra dependency, written atomically.
/// Secrets never go here (they use SecureStore).
class LocalPrefs {
  LocalPrefs(this._file);

  /// The app-wide instance; tests replace it with one on a temporary file (or [LocalPrefs.memory]).
  static LocalPrefs instance = LocalPrefs(null);

  /// Prefs that are never written to disk (tests, previews).
  LocalPrefs.memory() : _file = null, _memoryOnly = true;

  final File? _file;
  bool _memoryOnly = false;
  Future<Map<String, dynamic>>? _data;

  /// Every change runs after the previous one (read, change, write), so two changes made at the
  /// same time never lose one another.
  Future<void> _queue = Future.value();

  Future<File?> _resolve() async {
    if (_memoryOnly) return null;
    if (_file != null) return _file;
    try {
      return File('${(await getApplicationSupportDirectory()).path}/prefs.json');
    } catch (_) {
      return null; // no platform directory (widget tests): memory only
    }
  }

  /// Read once; every caller shares the same map.
  Future<Map<String, dynamic>> _load() => _data ??= () async {
    try {
      final f = await _resolve();
      if (f != null && await f.exists()) {
        return (jsonDecode(await f.readAsString()) as Map).cast<String, dynamic>();
      }
    } catch (_) {
      // A damaged file is ignored: these are only preferences.
    }
    return <String, dynamic>{};
  }();

  /// The value of [key], once the changes asked before are done.
  Future<T?> get<T>(String key) async {
    await _queue;
    final v = (await _load())[key];
    return v is T ? v : null;
  }

  Future<void> set(String key, Object? value) => update(key, (_) => value);

  /// Replaces [key] with what [change] makes of its current value (null removes it), as one step.
  Future<void> update(String key, Object? Function(Object? current) change) => _serial((data) {
    final next = change(data[key]);
    if (next == null) {
      data.remove(key);
    } else {
      data[key] = next;
    }
  });

  /// Removes every key [test] accepts (e.g. one account's lists at sign-out).
  Future<void> removeWhere(bool Function(String key) test) =>
      _serial((data) => data.removeWhere((k, _) => test(k)));

  Future<void> _serial(void Function(Map<String, dynamic> data) change) {
    final done = _queue.then((_) async {
      final data = await _load();
      change(data);
      await _write(data);
    });
    _queue = done.catchError((Object _) {});
    return done;
  }

  Future<void> _write(Map<String, dynamic> data) async {
    final f = await _resolve();
    if (f == null) return;
    try {
      await f.parent.create(recursive: true);
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(jsonEncode(data), flush: true);
      await tmp.rename(f.path);
    } catch (_) {}
  }
}
