import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:alcove/core/app_update.dart';
import 'package:alcove/core/secure_store.dart';
import 'package:alcove/core/session.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('compares versions', () {
    expect(isNewer('0.19.0', '0.18.1'), isTrue);
    expect(isNewer('1.0.0', '0.99.9'), isTrue);
    expect(isNewer('0.18.1', '0.18.1'), isFalse);
    expect(isNewer('0.18.0', '0.18.1'), isFalse);
    expect(isNewer('v0.20.0', '0.19.9'), isTrue);
    expect(isNewer('0.18.1-3-gabc', '0.1.0'), isFalse); // development builds never offer updates
  });

  test('picks the first device ABI that has its own APK', () {
    expect(pickAbi(['arm64-v8a', 'armeabi-v7a', 'armeabi']), 'arm64-v8a');
    expect(pickAbi(['armeabi-v7a', 'armeabi']), 'armeabi-v7a');
    expect(pickAbi(['x86', 'x86_64']), 'x86_64');
    expect(pickAbi(['riscv64']), isNull); // universal APK
    expect(pickAbi([]), isNull);
  });

  group('download', () {
    const channel = MethodChannel('test/update');
    late Directory cache;
    late List<String> abis;
    late List<MethodCall> calls;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      cache = await Directory.systemTemp.createTemp('alcove-update-test');
      abis = ['arm64-v8a', 'armeabi-v7a'];
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async {
          calls.add(call);
          return switch (call.method) {
            'abis' => abis,
            'canInstall' => true,
            _ => null,
          };
        },
      );
    });

    tearDown(() => cache.delete(recursive: true));

    Future<(AppUpdater, List<Uri>)> updater(
      Future<http.StreamedResponse> Function(http.BaseRequest) apk,
    ) async {
      final urls = <Uri>[];
      final api = MockClient((req) async {
        final body = switch (req.url.path) {
          '/api/files/token' => {'token': 'ft'},
          '/api/v1/app/android' => {'version': '9.0.0', 'available': true},
          _ => <String, Object>{},
        };
        return http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});
      });
      final session = Session(
        store: SecureStore(const FlutterSecureStorage()),
        httpClientFactory: () => api,
      );
      await session.useServer(Uri.parse('https://cloud.example.com'));
      final u = AppUpdater(
        session: session,
        currentVersion: '1.0.0',
        channel: channel,
        httpClient: MockClient.streaming((req, _) {
          urls.add(req.url);
          return apk(req);
        }),
        cacheDir: () async => cache,
        stallTimeout: const Duration(milliseconds: 200),
      );
      u.latest = '9.0.0';
      return (u, urls);
    }

    http.StreamedResponse ok(List<int> bytes) =>
        http.StreamedResponse(Stream.value(bytes), 200, contentLength: bytes.length);

    test('asks for the APK of the device ABI and removes older downloads', () async {
      final old = File('${cache.path}/updates/alcove-8.0.0.apk');
      await old.create(recursive: true);
      final (u, urls) = await updater((_) async => ok(utf8.encode('PK')));
      await u.downloadAndInstall();
      expect(u.phase, UpdatePhase.readyToInstall);
      expect(urls.single.queryParameters, {'token': 'ft', 'abi': 'arm64-v8a'});
      expect(await old.exists(), isFalse);
      expect(await File('${cache.path}/updates/alcove-9.0.0.apk').readAsString(), 'PK');
      expect(calls.map((c) => c.method), containsAllInOrder(['abis', 'canInstall', 'install']));
    });

    test('no ABI with its own APK: the universal one', () async {
      abis = ['riscv64'];
      final (u, urls) = await updater((_) async => ok(utf8.encode('PK')));
      await u.downloadAndInstall();
      expect(urls.single.queryParameters, {'token': 'ft'});
    });

    test('a server slower to answer than the stall timeout is waited for', () async {
      final (u, _) = await updater((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 400)); // > stallTimeout (200 ms)
        return ok(utf8.encode('PK'));
      });
      await u.downloadAndInstall();
      expect(u.phase, UpdatePhase.readyToInstall);
    });

    test('a stalled download fails instead of hanging', () async {
      final (u, _) = await updater(
        (_) async => http.StreamedResponse(StreamController<List<int>>().stream, 200),
      );
      await u.downloadAndInstall();
      expect(u.phase, UpdatePhase.failed);
    });
  });
}
