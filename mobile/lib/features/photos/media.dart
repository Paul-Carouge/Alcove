import 'package:pocketbase/pocketbase.dart';

/// A photo or video (a record of the `media` collection, with its drive node expanded).
class MediaItem {
  MediaItem(this.record);

  final RecordModel record;

  String get id => record.id;
  bool get isVideo => record.getStringValue('kind') == 'video';
  bool get isReady => record.getStringValue('status') == 'ready';
  bool get favorite => record.getBoolValue('favorite');
  set favorite(bool v) => record.set('favorite', v);
  String get thumb => record.getStringValue('thumb');
  String get preview => record.getStringValue('preview');
  int get width => record.getIntValue('width');
  int get height => record.getIntValue('height');
  double get duration => record.getDoubleValue('duration');
  String get camera => [
    record.getStringValue('camera_make'),
    record.getStringValue('camera_model'),
  ].where((s) => s.isNotEmpty).join(' ');
  String get lens => record.getStringValue('lens');
  String get exposure => record.getStringValue('exposure');
  bool get hasLocation => record.getBoolValue('has_location');
  double get lat => record.getDoubleValue('lat');
  double get lon => record.getDoubleValue('lon');
  String get name => record.getStringValue('expand.node.name');
  int get size => record.getIntValue('expand.node.size');

  /// Local time of capture (upload date when the file has none).
  DateTime? get takenAt {
    final raw = record.getStringValue('taken_at');
    return raw.isEmpty ? null : DateTime.tryParse(raw.replaceFirst(' ', 'T'))?.toLocal();
  }

  /// "YYYY-MM" in local time, for month sections.
  String get monthKey {
    final t = takenAt;
    return t == null ? '0000-00' : '${t.year}-${t.month.toString().padLeft(2, '0')}';
  }

  Uri? thumbUrl(PocketBase pb, String token) =>
      thumb.isEmpty ? null : pb.files.getURL(record, thumb, token: token);

  Uri? previewUrl(PocketBase pb, String token) =>
      preview.isEmpty ? null : pb.files.getURL(record, preview, token: token);

  /// The original file, for its owner and album participants (ADR 0018).
  Uri originalUrl(PocketBase pb, String token) => pb.buildURL(
    '/api/v1/media/${Uri.encodeComponent(id)}/original',
    {'token': token, 'inline': '1'},
  );
}

/// Consecutive items grouped by month (items are sorted newest first).
List<(String, List<MediaItem>)> groupByMonth(List<MediaItem> items) {
  final out = <(String, List<MediaItem>)>[];
  for (final it in items) {
    if (out.isEmpty || out.last.$1 != it.monthKey) out.add((it.monthKey, []));
    out.last.$2.add(it);
  }
  return out;
}

String formatDuration(double seconds) {
  final s = seconds.round();
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final ss = (s % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$ss' : '$m:$ss';
}
