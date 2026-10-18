import 'dart:async';
import 'dart:convert';

import 'package:alcove/core/secure_store.dart';
import 'package:alcove/core/session.dart';
import 'package:alcove/ui/remote_image.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  tearDown(() => remoteImageToken = null);

  test('the image cache key ignores the file token', () {
    final a = FreshTokenImage(Uri.parse('https://c.example/api/files/m/1/t.webp?token=old'));
    final b = FreshTokenImage(Uri.parse('https://c.example/api/files/m/1/t.webp?token=new'));
    final c = FreshTokenImage(Uri.parse('https://c.example/api/files/m/2/t.webp?token=old'));
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(c));
  });

  test('a stale token is swapped for a fresh one when the image loads', () async {
    remoteImageToken = () async => 'fresh';
    final img = FreshTokenImage(Uri.parse('https://c.example/f.webp?thumb=1&token=stale'));
    expect((await img.freshUrl()).queryParameters, {'thumb': '1', 'token': 'fresh'});
    final plain = FreshTokenImage(Uri.parse('https://c.example/public.webp'));
    expect(await plain.freshUrl(), plain.url, reason: 'no token, nothing to renew');
  });

  test('concurrent file token calls share one request, and a sign-out drops it', () async {
    var requests = 0;
    final client = MockClient((req) async {
      requests++;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return http.Response(
        jsonEncode({'token': 't$requests'}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    FlutterSecureStorage.setMockInitialValues({});
    final s = Session(
      store: SecureStore(const FlutterSecureStorage()),
      httpClientFactory: () => client,
    );
    await s.useServer(Uri.parse('https://cloud.example.com'));
    final tokens = await Future.wait([for (var i = 0; i < 20; i++) s.fileToken()]);
    expect(tokens.toSet(), {'t1'});
    expect(await s.fileToken(), 't1', reason: 'reused while fresh');
    expect(requests, 1);
    await s.signOut();
    expect(await s.fileToken(), 't2', reason: "the old account's token is not reused");
  });

  testWidgets('a failed image leaves the cache so it is fetched again later', (tester) async {
    // Widget tests answer every HTTP request with 400.
    final img = FreshTokenImage(Uri.parse('https://c.example/f.webp?token=t'));
    final failed = Completer<void>();
    img
        .resolve(ImageConfiguration.empty)
        .addListener(
          ImageStreamListener((_, _) {}, onError: (_, _) => failed.complete()),
        );
    await tester.runAsync(() => failed.future.timeout(const Duration(seconds: 5)));
    await tester.pump();
    expect(PaintingBinding.instance.imageCache.containsKey(img), isFalse);
  });
}
