import 'package:alcove/features/photos/media.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';

MediaItem item(String id, String taken, {Map<String, dynamic> extra = const {}}) => MediaItem(
  RecordModel.fromJson({
    'id': id,
    'collectionId': 'media1',
    'collectionName': 'media',
    'kind': 'image',
    'status': 'ready',
    'taken_at': taken,
    'thumb': 't.jpg',
    'expand': {
      'node': {'id': 'n$id', 'collectionId': 'nodes', 'name': '$id.jpg', 'size': 2048},
    },
    ...extra,
  }),
);

void main() {
  test('groups consecutive items by month', () {
    final groups = groupByMonth([
      item('a', '2025-06-20 12:00:00.000Z'),
      item('b', '2025-06-02 12:00:00.000Z'),
      item('c', '2024-12-24 12:00:00.000Z'),
    ]);
    expect(groups.map((g) => g.$1), ['2025-06', '2024-12']);
    expect(groups.first.$2.map((m) => m.id), ['a', 'b']);
  });

  test('reads fields and builds file URLs', () {
    final pb = PocketBase('https://cloud.example.com');
    final m = item(
      'a',
      '2025-06-20 12:00:00.000Z',
      extra: {
        'camera_make': 'Apple',
        'camera_model': 'iPhone 16',
        'kind': 'video',
        'duration': 75.4,
      },
    );
    expect(m.name, 'a.jpg');
    expect(m.size, 2048);
    expect(m.camera, 'Apple iPhone 16');
    expect(m.isVideo, isTrue);
    expect(
      m.thumbUrl(pb, 'tok').toString(),
      'https://cloud.example.com/api/files/media1/a/t.jpg?token=tok',
    );
    expect(m.previewUrl(pb, 'tok'), isNull);
    expect(
      m.originalUrl(pb, 'tok').toString(),
      'https://cloud.example.com/api/v1/media/a/original?token=tok&inline=1',
    );
  });

  test('formats durations', () {
    expect(formatDuration(3), '0:03');
    expect(formatDuration(75.4), '1:15');
    expect(formatDuration(3725), '1:02:05');
  });
}
