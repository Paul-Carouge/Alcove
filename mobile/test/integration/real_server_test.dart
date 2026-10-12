// Runs the mobile Session against a real Alcove server (skipped unless configured):
//   ALCOVE_TEST_SERVER=http://127.0.0.1:8096 ALCOVE_TEST_EMAIL=… ALCOVE_TEST_PASSWORD=… flutter test test/integration
import 'dart:io';

import 'package:alcove/core/secure_store.dart';
import 'package:alcove/core/session.dart';
import 'package:alcove/features/backup/backup_state.dart';
import 'package:alcove/features/backup/library.dart';
import 'package:alcove/features/backup/photo_backup.dart';
import 'package:alcove/features/backup/tus_client.dart';
import 'package:alcove/features/photos/media.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  final server = Platform.environment['ALCOVE_TEST_SERVER'];
  final email = Platform.environment['ALCOVE_TEST_EMAIL'] ?? '';
  final password = Platform.environment['ALCOVE_TEST_PASSWORD'] ?? '';

  test(
    'sign in, list photos, fetch a thumbnail',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final session = Session(
        store: SecureStore(const FlutterSecureStorage()),
        httpClientFactory: http.Client.new,
      );
      await session.useServer(Uri.parse(server!));
      expect(await session.signIn(email, 'wrong-password'), isA<SignInFailed>());
      expect(await session.signIn(email, password), isA<SignedIn>());

      final res = await session.pb
          .collection('media')
          .getList(
            perPage: 50,
            filter: 'node.trashed_at = ""',
            sort: '-taken_at,-id',
            expand: 'node',
          );
      expect(res.items, isNotEmpty);
      final item = MediaItem(res.items.first);
      expect(item.name, isNotEmpty);
      final token = await session.fileToken();
      final thumb = await http.get(item.thumbUrl(session.pb, token)!);
      expect(thumb.statusCode, 200);
      expect(thumb.headers['content-type'], contains('image/'));
      final original = await http.get(item.originalUrl(session.pb, token));
      expect(original.statusCode, 200);
    },
    skip: server == null ? 'ALCOVE_TEST_SERVER not set' : false,
  );

  test('backs up phone photos with tus, once', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final session = Session(
      store: SecureStore(const FlutterSecureStorage()),
      httpClientFactory: http.Client.new,
    );
    await session.useServer(Uri.parse(server!));
    expect(await session.signIn(email, password), isA<SignedIn>());
    final dir = await Directory.systemTemp.createTemp('realbackup');
    final fixtures = Platform.environment['ALCOVE_TEST_FIXTURES']!;
    final photo = await File('$fixtures/harbor.jpg').copy('${dir.path}/IMG_9001.jpg');
    final video = await File('$fixtures/clip.mp4').copy('${dir.path}/VID_9001.mp4');
    final store = BackupStore(File('${dir.path}/state.json'));
    await store.save(BackupState(enabled: true, wifiOnly: false, folderName: 'Phone backup'));
    PhotoBackup run() => PhotoBackup(
      session: session,
      library: _Library([_Asset('p1', photo), _Asset('v1', video)]),
      store: store,
      uploader: TusUploader(client: http.Client(), chunkSize: 16 * 1024),
      isOnWifi: () async => true,
    );
    final first = await run().run();
    expect(first.stop, BackupStop.finished);
    expect(first.progress.uploaded, 2);

    // A fresh install (no local state) uploads nothing again: the server knows the files.
    await store.save(BackupState(enabled: true, wifiOnly: false, folderName: 'Phone backup'));
    final again = await run().run();
    expect(again.progress.uploaded, 0);
    expect(again.progress.alreadyThere, 2);

    final folder = await session.pb.collection('nodes').getFirstListItem('name = "Phone backup"');
    final files = await session.pb
        .collection('nodes')
        .getFullList(filter: 'parent = "${folder.id}"');
    expect(files.map((f) => f.getStringValue('name')).toSet(), {'IMG_9001.jpg', 'VID_9001.mp4'});
    await dir.delete(recursive: true);
  }, skip: server == null ? 'ALCOVE_TEST_SERVER not set' : false);
}

class _Asset implements LibraryAsset {
  _Asset(this.id, this.file);
  @override
  final String id;
  final File file;
  @override
  bool get isVideo => file.path.endsWith('.mp4');
  @override
  DateTime get created => DateTime.now();
  @override
  Future<File?> original() async => file;
  @override
  Future<String> name() async => file.uri.pathSegments.last;
}

class _Library implements PhotoLibrary {
  _Library(this.items);
  final List<LibraryAsset> items;
  @override
  Future<bool> requestAccess() async => true;
  @override
  Future<List<LibraryAsset>> assets({required bool videos}) async => items;
}
