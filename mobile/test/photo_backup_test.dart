import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:alcove/core/secure_store.dart';
import 'package:alcove/core/session.dart';
import 'package:alcove/features/backup/photo_backup.dart';
import 'package:alcove/features/backup/backup_state.dart';
import 'package:alcove/features/backup/library.dart';
import 'package:alcove/features/backup/tus_client.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocketbase/pocketbase.dart';

class FakeAsset implements LibraryAsset {
  FakeAsset(this.id, this.file, {this.isVideo = false});
  @override
  final String id;
  final File? file;
  @override
  final bool isVideo;
  @override
  DateTime get created => DateTime(2025);
  @override
  Future<File?> original() async => file;
  @override
  Future<String> name() async => file == null ? '$id.jpg' : file!.uri.pathSegments.last;
}

class FakeLibrary implements PhotoLibrary {
  FakeLibrary(this.items);
  final List<FakeAsset> items;
  bool access = true;
  @override
  Future<bool> requestAccess() async => access;
  @override
  Future<List<LibraryAsset>> assets({required bool videos}) async =>
      items.where((a) => videos || !a.isVideo).toList();
}

http.Response _json(int status, Object body) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

/// The parts of an Alcove server the backup talks to.
class FakeServer {
  final Set<String> hashes = {};
  final List<String> uploadedNames = [];
  final List<String> folders = [];
  int quotaLeft = 1 << 30;
  final Map<String, (int, BytesBuilder, String)> uploads = {};

  Future<http.Response> handle(http.Request req) async {
    final path = req.url.path;
    if (path == '/api/collections/nodes/records' && req.method == 'GET') {
      return _json(200, {'page': 1, 'perPage': 1, 'totalItems': 0, 'totalPages': 0, 'items': []});
    }
    if (path == '/api/collections/nodes/records' && req.method == 'POST') {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      folders.add(body['name'] as String);
      return _json(200, {
        'id': 'folder1',
        'collectionId': 'nodes',
        'name': body['name'],
        'kind': 'folder',
      });
    }
    if (path.startsWith('/api/collections/nodes/records/')) {
      return _json(200, {'id': 'folder1', 'collectionId': 'nodes', 'trashed_at': ''});
    }
    if (path == '/api/v1/backup/known') {
      final asked = ((jsonDecode(req.body) as Map)['hashes'] as List).cast<String>();
      return _json(200, {'known': asked.where(hashes.contains).toList()});
    }
    if (path == '/api/v1/uploads/' && req.method == 'POST') {
      final length = int.parse(req.headers['Upload-Length']!);
      if (length > quotaLeft) return _json(413, {'message': 'Not enough space.'});
      final meta = {
        for (final p in req.headers['Upload-Metadata']!.split(','))
          p.split(' ')[0]: utf8.decode(base64.decode(p.split(' ')[1])),
      };
      expect(meta['parent'], 'folder1');
      final id = 'u${uploads.length}';
      uploads[id] = (length, BytesBuilder(), meta['filename']!);
      return http.Response('', 201, headers: {'location': '/api/v1/uploads/$id'});
    }
    if (path.startsWith('/api/v1/uploads/') && req.method == 'PATCH') {
      final up = uploads[path.split('/').last]!;
      up.$2.add(req.bodyBytes);
      final done = up.$2.length >= up.$1;
      if (done) {
        hashes.add(sha256.convert(up.$2.toBytes()).toString());
        uploadedNames.add(up.$3);
        quotaLeft -= up.$1;
      }
      return http.Response(
        '',
        204,
        headers: {
          'upload-offset': '${up.$2.length}',
          if (done) 'alcove-node-id': 'node-${up.$3}',
        },
      );
    }
    return _json(404, {'status': 404});
  }
}

void main() {
  late Directory dir;
  late FakeServer server;
  late Session session;
  late BackupStore store;

  File photo(String name, String content) => File('${dir.path}/$name')..writeAsStringSync(content);

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    dir = await Directory.systemTemp.createTemp('backup');
    server = FakeServer();
    final client = MockClient(server.handle);
    session = Session(
      store: SecureStore(const FlutterSecureStorage()),
      httpClientFactory: () => client,
    );
    await session.useServer(Uri.parse('https://cloud.example.com'));
    session.pb.authStore.save(
      '${base64Url.encode(utf8.encode('{}'))}.${base64Url.encode(utf8.encode('{"exp":4102444800}'))}.s',
      RecordModel.fromJson({'id': 'u1', 'collectionName': 'users'}),
    );
    store = BackupStore(File('${dir.path}/state/backup.json'));
  });
  tearDown(() => dir.delete(recursive: true));

  PhotoBackup service(FakeLibrary library, {bool wifi = true}) => PhotoBackup(
    session: session,
    library: library,
    store: store,
    uploader: TusUploader(client: MockClient(server.handle), chunkSize: 4),
    isOnWifi: () async => wifi,
  );

  test('does nothing until enabled', () async {
    final r = await service(FakeLibrary([FakeAsset('a', photo('a.jpg', 'aaaa'))])).run();
    expect(r.stop, BackupStop.disabled);
    expect(server.uploadedNames, isEmpty);
  });

  test('uploads new photos once, skips what the server has, resumes next time', () async {
    await store.save(BackupState(enabled: true, wifiOnly: false));
    server.hashes.add(sha256.convert(utf8.encode('from the web')).toString());
    final library = FakeLibrary([
      FakeAsset('a', photo('IMG_1.HEIC', 'first photo')),
      FakeAsset('b', photo('IMG_2.jpg', 'from the web')), // already on the server
      FakeAsset('c', photo('IMG_1 copy.HEIC', 'first photo')), // duplicate in the library
      FakeAsset('d', null), // only in the cloud: retried later
      FakeAsset('v', photo('VID_1.mp4', 'a video'), isVideo: true),
    ]);
    final r = await service(library).run(defaultFolderName: 'Phone backup');
    expect(r.stop, BackupStop.finished);
    expect(server.folders, ['Phone backup']);
    expect(server.uploadedNames, ['IMG_1.HEIC', 'VID_1.mp4']);
    expect(r.progress.uploaded, 2);
    expect(r.progress.alreadyThere, 2);
    expect(r.progress.failed, 1);

    final saved = await store.load();
    expect(saved.done, {'a': 'node-IMG_1.HEIC', 'b': 'known', 'c': 'known', 'v': 'node-VID_1.mp4'});
    expect(saved.folderId, 'folder1');

    // A new photo later: only it is uploaded; the missing one is tried again.
    library.items.add(FakeAsset('e', photo('IMG_3.jpg', 'new one')));
    final again = await service(library).run();
    expect(again.progress.total, 2);
    expect(server.uploadedNames, ['IMG_1.HEIC', 'VID_1.mp4', 'IMG_3.jpg']);
  });

  test('respects Wi-Fi only and videos off', () async {
    await store.save(BackupState(enabled: true, wifiOnly: true, videos: false));
    final library = FakeLibrary([
      FakeAsset('a', photo('a.jpg', 'aaaa')),
      FakeAsset('v', photo('v.mp4', 'vvvv'), isVideo: true),
    ]);
    expect((await service(library, wifi: false).run()).stop, BackupStop.notOnWifi);
    expect(server.uploadedNames, isEmpty);
    await service(library).run();
    expect(server.uploadedNames, ['a.jpg']);
  });

  test('stops when the server refuses (quota) and says why', () async {
    await store.save(BackupState(enabled: true, wifiOnly: false));
    server.quotaLeft = 5;
    final r = await service(
      FakeLibrary([FakeAsset('a', photo('big.jpg', 'too big for the quota'))]),
    ).run();
    expect(r.stop, BackupStop.serverRefused);
    expect(r.error, 'Not enough space.');
    expect((await store.load()).lastError, 'Not enough space.');
  });

  test('without access to the library, nothing happens', () async {
    await store.save(BackupState(enabled: true, wifiOnly: false));
    final library = FakeLibrary([FakeAsset('a', photo('a.jpg', 'aaaa'))])..access = false;
    expect((await service(library).run()).stop, BackupStop.noAccess);
  });
}
