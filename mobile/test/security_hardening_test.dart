import 'dart:convert';
import 'dart:io';

import 'package:alcove/core/file_cache.dart';
import 'package:alcove/core/file_names.dart';
import 'package:alcove/core/prefs.dart';
import 'package:alcove/core/recent_files.dart';
import 'package:alcove/core/share_inbox.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocketbase/pocketbase.dart';

import 'screenshots/fake_server.dart';

void main() {
  group('safeFileName', () {
    test('drops bidi and zero-width controls (no disguised extensions)', () {
      expect(safeFileName('invoice\u202Efdp.exe'), 'invoicefdp.exe');
      expect(safeFileName('a\u200Bb\u2066c\u2069\uFEFF.txt'), 'abc.txt');
    });

    test('no separators, control characters or leading dots', () {
      expect(safeFileName('../../etc/passwd'), '__.._etc_passwd');
      expect(safeFileName('a\nb\\c'), 'a_b_c');
      expect(safeFileName('.hidden'), '_hidden');
      expect(safeFileName('   '), 'file');
      expect(safeFileName('...'), 'file');
    });

    test('at most 200 UTF-8 bytes, keeping the extension and whole characters', () {
      final long = '${'é' * 300}.pdf';
      final safe = safeFileName(long);
      expect(utf8.encode(safe).length, lessThanOrEqualTo(200));
      expect(safe, endsWith('é.pdf'));
      expect(safeFileName('${'a' * 250}.averyveryverylongextension').length, 200);
      expect(safeFileName('short.txt'), 'short.txt');
    });

    test('shared files and cache entries use it', () {
      final parsed = parseSharedFiles([
        {'path': '/c/shared/1', 'name': 'photo\u202Egnp.apk', 'mime': 'image/png'},
      ]);
      expect(parsed.single.name, 'photognp.apk');
      expect(cacheName('n1', '2026', 'x\u200F/y.pdf'), 'n1-2026/x_y.pdf');
    });
  });

  group('handOutMime', () {
    test('never announces an installable package', () {
      expect(
        handOutMime('app.apk', 'application/vnd.android.package-archive'),
        'application/octet-stream',
      );
      expect(handOutMime('notes.txt', 'application/vnd.android.package-archive'), 'text/plain');
      expect(
        handOutMime('x.bin', 'application/vnd.android.package-archive'),
        'application/octet-stream',
      );
      expect(handOutMime('photo.apk', 'image/png'), 'application/octet-stream');
    });

    test('the extension wins when it disagrees with the server', () {
      expect(handOutMime('report.pdf', 'text/html'), 'application/pdf');
      expect(
        handOutMime('data.unknownext', 'application/x-thing; charset=x'),
        'application/x-thing',
      );
      expect(handOutMime('noext', ''), 'application/octet-stream');
      expect(handOutMime('noext', 'image/*'), 'application/octet-stream');
    });
  });

  group('bounded downloads', () {
    test('the limit is the larger announced size, or a hard maximum', () {
      expect(downloadLimit(100, 120), 120);
      expect(downloadLimit(100, null), 100);
      expect(downloadLimit(0, 50), 50);
      expect(downloadLimit(0, null), maxDownloadBytes);
    });

    test('a server sending more than announced is cut off and leaves nothing', () async {
      final dir = Directory.systemTemp.createTempSync('bounded');
      addTearDown(() => dir.deleteSync(recursive: true));
      final session = await fakeSession();
      final client = MockClient.streaming((req, _) async {
        // No Content-Length, endless-looking body of 10 × 1 KB.
        final body = Stream.fromIterable(List.generate(10, (_) => List.filled(1024, 7)));
        return http.StreamedResponse(body, 200);
      });
      final cache = FileCache(root: () async => dir);
      await expectLater(
        cache.fetch(
          session,
          key: cacheName('n', '1', 'x.bin'),
          url: () async => Uri.parse('https://cloud.example.com/x'),
          expectedSize: 2048,
          client: client,
        ),
        throwsA(isA<HttpException>()),
      );
      final left = dir.listSync(recursive: true).whereType<File>();
      expect(left, isEmpty, reason: 'the partial file is deleted');
    });
  });

  test('sign-out purges the viewer cache, shared files and recent lists', () async {
    final dir = Directory.systemTemp.createTempSync('purge');
    addTearDown(() => dir.deleteSync(recursive: true));
    for (final name in ['viewer/a-1/x.pdf', 'shared/1-y.jpg', 'outgoing/2-z.txt', 'other/keep']) {
      File('${dir.path}/$name')
        ..createSync(recursive: true)
        ..writeAsStringSync('x');
    }
    final prefs = LocalPrefs.memory();
    await RecentFiles('u1', prefs: prefs).remember(
      RecordModel.fromJson({'id': 'f', 'collectionId': 'nodes', 'name': 'a.pdf'}),
    );
    await prefs.set('filesSort', 'size:desc');
    await purgeDeviceFiles(cache: () async => dir, prefs: prefs);
    expect(Directory('${dir.path}/viewer').existsSync(), isFalse);
    expect(Directory('${dir.path}/shared').existsSync(), isFalse);
    expect(Directory('${dir.path}/outgoing').existsSync(), isFalse);
    expect(File('${dir.path}/other/keep').existsSync(), isTrue);
    expect(await RecentFiles('u1', prefs: prefs).opened(), isEmpty);
    expect(await prefs.get<String>('filesSort'), 'size:desc', reason: 'a device setting stays');
  });
}
