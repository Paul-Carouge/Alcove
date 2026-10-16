import 'package:pocketbase/pocketbase.dart';

import 'prefs.dart';

/// When a drive record was last modified (its `updated` field), or null.
DateTime? modifiedAt(RecordModel n) =>
    DateTime.tryParse(n.getStringValue('updated').replaceFirst(' ', 'T'));

/// The "Recent" strip of Files: files opened on this phone and files changed lately, newest first,
/// each once (the latest of its two dates wins).
List<RecordModel> mergeRecent(
  List<(RecordModel, DateTime)> opened,
  List<RecordModel> modified, {
  int max = 10,
}) {
  final best = <String, (RecordModel, DateTime)>{};
  void put(RecordModel n, DateTime at) {
    final known = best[n.id];
    if (known == null || at.isAfter(known.$2)) best[n.id] = (n, at);
  }

  for (final (n, at) in opened) {
    put(n, at);
  }
  for (final n in modified) {
    final at = modifiedAt(n);
    if (at != null) put(n, at);
  }
  final list = best.values.toList()..sort((a, b) => b.$2.compareTo(a.$2));
  return [for (final (n, _) in list.take(max)) n];
}

/// Files opened in the app's viewers, remembered on this device per account.
class RecentFiles {
  RecentFiles(this.account, {LocalPrefs? prefs, this.keep = 12})
    : _prefs = prefs ?? LocalPrefs.instance;

  /// The signed-in user's id (each account has its own list).
  final String account;
  final LocalPrefs _prefs;
  final int keep;

  String get _key => 'recent:$account';

  Future<List<(RecordModel, DateTime)>> opened() async =>
      _parse(await _prefs.get<List<dynamic>>(_key));

  static List<(RecordModel, DateTime)> _parse(Object? raw) {
    final out = <(RecordModel, DateTime)>[];
    for (final e in raw is List ? raw : const []) {
      if (e is! Map) continue;
      final at = DateTime.tryParse(e['at'] as String? ?? '');
      final node = e['node'];
      if (at == null || node is! Map) continue;
      out.add((RecordModel.fromJson(node.cast<String, dynamic>()), at));
    }
    return out;
  }

  static Map<String, dynamic> _entry(RecordModel n, DateTime t) => {
    'at': t.toIso8601String(),
    'node': {
      for (final k in ['id', 'collectionId', 'collectionName', 'name', 'kind', 'mime'])
        k: n.getStringValue(k),
      'size': n.getIntValue('size'),
      'parent': n.getStringValue('parent'),
      'blob': n.getStringValue('blob'),
      'updated': n.getStringValue('updated'),
    },
  };

  /// Read, changed and written as one step: files opened in quick succession are all kept.
  Future<void> remember(RecordModel node, {DateTime? at}) => _prefs.update(_key, (raw) {
    final list = _parse(raw).where((e) => e.$1.id != node.id).toList()
      ..insert(0, (node, at ?? DateTime.now().toUtc()));
    return [for (final (n, t) in list.take(keep)) _entry(n, t)];
  });

  /// Forgets a file (it was moved to the trash).
  Future<void> forget(String id) => _prefs.update(_key, (raw) {
    return [
      for (final (n, t) in _parse(raw))
        if (n.id != id) _entry(n, t),
    ];
  });
}
