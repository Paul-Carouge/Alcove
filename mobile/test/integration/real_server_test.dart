// Runs the mobile Session against a real Alcove server (skipped unless configured):
//   ALCOVE_TEST_SERVER=http://127.0.0.1:8096 ALCOVE_TEST_EMAIL=… ALCOVE_TEST_PASSWORD=… flutter test test/integration
import 'dart:io';

import 'package:alcove/core/secure_store.dart';
import 'package:alcove/core/session.dart';
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
}
