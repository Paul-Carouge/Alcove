import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:alcove/core/drive.dart';
import 'package:alcove/core/file_cache.dart';
import 'package:alcove/core/prefs.dart';
import 'package:alcove/core/recent_files.dart';
import 'package:alcove/core/secure_store.dart';
import 'package:alcove/core/session.dart';
import 'package:alcove/core/share_inbox.dart';
import 'package:alcove/features/viewer/pdf_view.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocketbase/pocketbase.dart';

import 'screenshots/fake_server.dart';

/// A signed-in session of [user] on [server]; every request answers 404 (nothing is sent).
Future<Session> _session(String server, String user) async {
  FlutterSecureStorage.setMockInitialValues({});
  final client = MockClient((_) async => http.Response('{}', 404));
  final s = Session(
    store: SecureStore(const FlutterSecureStorage()),
    httpClientFactory: () => client,
  );
  await s.useServer(Uri.parse(server));
  s.pb.authStore.save(
    fakeToken,
    RecordModel.fromJson({'id': user, 'collectionId': '_pb_users_auth_', 'email': '$user@x'}),
  );
  return s;
}

Uint8List _bytes(int n) => Uint8List(n);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PDF page bitmaps', () {
    test('two large visible pages never push each other out', () {
      final cache = PageBitmaps(maxBytes: 100);
      cache.put(0, 512, _bytes(80), current: 0);
      cache.put(1, 512, _bytes(80), current: 0);
      expect(cache.has(0, 512), isTrue);
      expect(cache.has(1, 512), isTrue);
      // Reading further on: the oldest page off screen goes, just enough to fit.
      cache.put(5, 512, _bytes(10), current: 5);
      expect(cache.has(0, 512), isFalse);
      expect(cache.has(1, 512), isTrue);
      expect(cache.has(5, 512), isTrue);
      expect(cache.bytes, 90);
    });

    test('overwriting a page counts its size once', () {
      final cache = PageBitmaps(maxBytes: 1000);
      cache.put(0, 512, _bytes(100), current: 0);
      cache.put(0, 512, _bytes(100), current: 0);
      expect(cache.bytes, 100);
    });

    test('least recently used goes first; another width stands in meanwhile', () {
      final cache = PageBitmaps(maxBytes: 30);
      cache.put(10, 256, _bytes(10), current: 0);
      cache.put(20, 256, _bytes(10), current: 0);
      cache.best(10, 256); // used again
      cache.put(30, 256, _bytes(15), current: 0);
      expect(cache.has(20, 256), isFalse);
      expect(cache.has(10, 256), isTrue);
      expect(cache.best(10, 1024), isNotNull, reason: 'the 256 px bitmap while 1024 renders');
    });
  });

  group('upload queue per account', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('accounts'));
    tearDown(() => dir.deleteSync(recursive: true));

    File copy(String name, {Duration age = Duration.zero}) =>
        File('${dir.path}/$name')..writeAsStringSync('data $name');

    test('only the signed-in account sends; others wait, then expire after a week', () async {
      final now = DateTime.utc(2026, 10, 16, 12);
      final legacy = copy('1-legacy.pdf');
      final bFresh = copy('2-b.pdf');
      final bOld = copy('3-b-old.pdf');
      final aMine = copy('4-a.pdf');
      final queueFile = File('${dir.path}/queue.json')
        ..writeAsStringSync(
          jsonEncode([
            {'name': 'legacy.pdf', 'parent': '', 'path': legacy.path},
            {
              'name': 'b.pdf',
              'parent': '',
              'path': bFresh.path,
              'account': 'https://b.example|ub',
              'queuedAt': now.subtract(const Duration(days: 2)).toIso8601String(),
            },
            {
              'name': 'b-old.pdf',
              'parent': '',
              'path': bOld.path,
              'account': 'https://b.example|ub',
              'queuedAt': now.subtract(const Duration(days: 8)).toIso8601String(),
            },
            {
              'name': 'a.pdf',
              'parent': '',
              'path': aMine.path,
              'account': 'https://a.example|ua',
              'queuedAt': now.toIso8601String(),
            },
          ]),
        );

      final a = await _session('https://a.example', 'ua');
      final qa = UploadQueue(a, storage: () async => dir, now: () => now);
      await qa.restore();
      // The untagged entry is adopted by the first account to sign in.
      expect(qa.items.map((i) => i.name).toSet(), {'legacy.pdf', 'a.pdf'});
      expect(qa.items.every((i) => i.account == 'https://a.example|ua'), isTrue);
      expect(bOld.existsSync(), isFalse, reason: 'another account, older than a week');
      expect(bFresh.existsSync(), isTrue, reason: 'kept for its account');
      final saved = (jsonDecode(queueFile.readAsStringSync()) as List).cast<Map<String, dynamic>>();
      expect(saved.map((e) => e['name']).toSet(), containsAll(['b.pdf', 'legacy.pdf', 'a.pdf']));
      expect(saved.firstWhere((e) => e['name'] == 'legacy.pdf')['account'], 'https://a.example|ua');
      qa.dispose();

      // Let A's (refused) uploads settle so the file is stable, then B signs in.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final b = await _session('https://b.example', 'ub');
      final qb = UploadQueue(b, storage: () async => dir, now: () => now);
      await qb.restore();
      expect(qb.items.map((i) => i.name), ['b.pdf']);
      qb.dispose();
    });

    test('new uploads carry the account, and shared copies are moved, not copied', () async {
      final a = await _session('https://a.example', 'ua');
      final shared = Directory.systemTemp.createTempSync('shared');
      addTearDown(() => shared.deleteSync(recursive: true));
      final src = File('${shared.path}/1-photo.jpg')..writeAsStringSync('jpeg');
      final q = UploadQueue(a, storage: () async => dir);
      q.add(sharedUploads([SharedFile(path: src.path, name: 'photo.jpg', mime: 'image/jpeg')], ''));
      for (var i = 0; i < 100 && q.items.single.path == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(q.items.single.account, 'https://a.example|ua');
      expect(q.items.single.path, startsWith(dir.path));
      expect(src.existsSync(), isFalse, reason: 'the shared copy does not stay behind');
      q.dispose();
    });
  });

  test('the same file asked twice while downloading is downloaded once', () async {
    final dir = Directory.systemTemp.createTempSync('dedupe');
    addTearDown(() => dir.deleteSync(recursive: true));
    final session = await fakeSession();
    var requests = 0;
    final gate = Completer<void>();
    final client = MockClient.streaming((req, _) async {
      requests++;
      await gate.future;
      return http.StreamedResponse(Stream.value([1, 2, 3]), 200, contentLength: 3);
    });
    final cache = FileCache(root: () async => dir);
    final progress = <int>[];
    Future<File> fetch() => cache.fetch(
      session,
      key: 'n-1/a.bin',
      url: () async => Uri.parse('https://cloud.example.com/a'),
      expectedSize: 3,
      client: client,
      onProgress: (got, _) => progress.add(got),
    );
    final first = fetch();
    final second = fetch();
    gate.complete();
    final files = await Future.wait([first, second]);
    expect(requests, 1);
    expect(files[0].path, files[1].path);
    expect(progress, [3, 3], reason: 'both callers hear about the progress');
  });

  test('preferences changed at the same time all stick', () async {
    final dir = Directory.systemTemp.createTempSync('prefs');
    addTearDown(() => dir.deleteSync(recursive: true));
    final prefs = LocalPrefs(File('${dir.path}/prefs.json'));
    final recent = RecentFiles('u1', prefs: prefs);
    await Future.wait([
      for (var i = 0; i < 6; i++)
        recent.remember(
          RecordModel.fromJson({'id': 'f$i', 'collectionId': 'nodes', 'name': '$i.pdf'}),
          at: DateTime.utc(2026, 10, 1, i),
        ),
      prefs.set('filesSort', 'date:desc'),
    ]);
    expect((await recent.opened()).length, 6);
    // And on disk, read back by a fresh instance.
    final again = LocalPrefs(File('${dir.path}/prefs.json'));
    expect((await RecentFiles('u1', prefs: again).opened()).length, 6);
    expect(await again.get<String>('filesSort'), 'date:desc');
  });

  test('a signed-out shell tells Android to keep later shares', () async {
    const channel = MethodChannel('test/share');
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async {
        calls.add(call.method);
        return call.method == 'ready' ? <Object?>[] : null;
      },
    );
    final inbox = ShareInbox(channel, true);
    await inbox.start();
    inbox.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(calls, ['ready', 'unready']);
  });
}
