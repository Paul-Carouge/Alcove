import 'package:pocketbase/pocketbase.dart';

import 'prefs.dart';

enum SortField { name, date, size }

/// How Files lists a folder. Folders always come first.
class FileSort {
  const FileSort(this.field, {this.descending = false});

  final SortField field;
  final bool descending;

  static const byName = FileSort(SortField.name);

  /// The order a field starts with when chosen: A to Z, newest first, largest first.
  static FileSort initial(SortField field) => FileSort(field, descending: field != SortField.name);

  String encode() => '${field.name}:${descending ? 'desc' : 'asc'}';

  static FileSort decode(String? raw) {
    final parts = (raw ?? '').split(':');
    final field = SortField.values.where((f) => f.name == parts.first).firstOrNull;
    if (field == null) return byName;
    return FileSort(field, descending: parts.length > 1 && parts[1] == 'desc');
  }

  @override
  bool operator ==(Object other) =>
      other is FileSort && other.field == field && other.descending == descending;

  @override
  int get hashCode => Object.hash(field, descending);

  static const _key = 'filesSort';

  /// The order chosen on this device.
  static Future<FileSort> load([LocalPrefs? prefs]) async =>
      decode(await (prefs ?? LocalPrefs.instance).get<String>(_key));

  Future<void> save([LocalPrefs? prefs]) => (prefs ?? LocalPrefs.instance).set(_key, encode());
}

int _byName(RecordModel a, RecordModel b) {
  final n = a
      .getStringValue('name')
      .toLowerCase()
      .compareTo(b.getStringValue('name').toLowerCase());
  return n != 0 ? n : a.id.compareTo(b.id);
}

/// Folders first (by name, or by date when sorting by date), then files in [sort] order;
/// ties broken by name.
List<RecordModel> sortNodes(Iterable<RecordModel> nodes, FileSort sort) {
  int cmp(RecordModel a, RecordModel b) {
    final fa = a.getStringValue('kind') == 'folder';
    final fb = b.getStringValue('kind') == 'folder';
    if (fa != fb) return fa ? -1 : 1;
    final field = fa && sort.field == SortField.size ? SortField.name : sort.field;
    final int c = switch (field) {
      SortField.name => _byName(a, b),
      SortField.date => a.getStringValue('updated').compareTo(b.getStringValue('updated')),
      SortField.size => a.getIntValue('size').compareTo(b.getIntValue('size')),
    };
    final ordered = sort.descending ? -c : c;
    return ordered != 0 ? ordered : _byName(a, b);
  }

  return nodes.toList()..sort(cmp);
}
