import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:alcove/core/file_cache.dart';
import 'package:alcove/core/file_sort.dart';
import 'package:alcove/core/prefs.dart';
import 'package:alcove/core/previews.dart';
import 'package:alcove/core/recent_files.dart';
import 'package:alcove/core/share_inbox.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';

RecordModel node(
  String id,
  String name, {
  String kind = 'file',
  int size = 0,
  String updated = '2026-10-01 10:00:00.000Z',
}) => RecordModel.fromJson({
  'id': id,
  'collectionId': 'nodes',
  'name': name,
  'kind': kind,
  'size': size,
  'updated': updated,
});

void main() {
  group('previewKind', () {
    test('picks a viewer from the type, then the name', () {
      expect(previewKind('application/pdf', 'a.pdf'), PreviewKind.pdf);
      expect(previewKind('application/octet-stream', 'scan.PDF'), PreviewKind.pdf);
      expect(previewKind('image/jpeg', 'a.jpg'), PreviewKind.image);
      expect(previewKind('', 'photo.png'), PreviewKind.image);
      expect(previewKind('video/mp4', 'a.mp4'), PreviewKind.video);
      expect(previewKind('text/plain', 'notes.txt'), PreviewKind.text);
      expect(previewKind('text/markdown', 'README.md'), PreviewKind.text);
      expect(previewKind('application/json', 'data'), PreviewKind.code);
      expect(previewKind('text/plain', 'budget.csv'), PreviewKind.code);
      expect(previewKind('application/octet-stream', 'main.dart'), PreviewKind.code);
      expect(previewKind('text/plain; charset=utf-8', 'Makefile'), PreviewKind.code);
      expect(previewKind('application/zip', 'a.zip'), PreviewKind.none);
      expect(previewKind('image/heic', 'a.heic'), PreviewKind.none);
    });
  });

  group('previewText', () {
    test('decodes UTF-8, drops the BOM and CRLF, indents JSON', () {
      final bytes = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode('{"a":[1,2]}\r\n')]);
      expect(
        previewText(bytes, PreviewKind.code, name: 'x.json'),
        '{\n  "a": [\n    1,\n    2\n  ]\n}',
      );
      expect(
        previewText(Uint8List.fromList(utf8.encode('é\r\nb')), PreviewKind.text),
        'é\nb',
      );
    });

    test('leaves invalid JSON as it is and refuses binary files', () {
      expect(
        previewText(Uint8List.fromList(utf8.encode('{nope')), PreviewKind.code, name: 'a.json'),
        '{nope',
      );
      expect(previewText(Uint8List.fromList([0x50, 0x4b, 0, 3]), PreviewKind.code), isNull);
    });

    test('chunks keep every line, in order', () {
      final text = [for (var i = 0; i < 205; i++) 'line $i'].join('\n');
      final chunks = textChunks(text, lines: 80);
      expect(chunks, hasLength(3));
      expect(chunks.join('\n'), text);
    });
  });

  group('PDF layout', () {
    test('pageAt finds the page under the top third of the screen', () {
      final tops = [12.0, 512.0, 1012.0];
      expect(pageAt(tops, 0, 900), 0);
      expect(pageAt(tops, 300, 900), 1);
      expect(pageAt(tops, 5000, 900), 2);
      expect(pageAt(const [], 10, 900), 0);
    });

    test('renderWidth rounds up to steps and caps', () {
      expect(renderWidth(360, 3), 1280);
      expect(renderWidth(361, 3), 1280);
      expect(renderWidth(10, 1), 256);
      expect(renderWidth(5000, 3), 4096);
    });
  });

  group('sort', () {
    final list = [
      node('1', 'beta.txt', size: 30, updated: '2026-10-03 10:00:00.000Z'),
      node('2', 'Zeta', kind: 'folder', updated: '2026-10-05 10:00:00.000Z'),
      node('3', 'alpha.pdf', size: 10, updated: '2026-10-01 10:00:00.000Z'),
      node('4', 'Archives', kind: 'folder', updated: '2026-10-02 10:00:00.000Z'),
      node('5', 'gamma.png', size: 20, updated: '2026-10-04 10:00:00.000Z'),
    ];
    List<String> names(FileSort s) => [
      for (final n in sortNodes(list, s)) n.getStringValue('name'),
    ];

    test('folders first, then by name, date or size, either way', () {
      expect(names(FileSort.byName), ['Archives', 'Zeta', 'alpha.pdf', 'beta.txt', 'gamma.png']);
      expect(
        names(const FileSort(SortField.name, descending: true)),
        ['Zeta', 'Archives', 'gamma.png', 'beta.txt', 'alpha.pdf'],
      );
      expect(
        names(FileSort.initial(SortField.date)),
        ['Zeta', 'Archives', 'gamma.png', 'beta.txt', 'alpha.pdf'],
      );
      // Folders have no size: by name among themselves.
      expect(
        names(FileSort.initial(SortField.size)),
        ['Zeta', 'Archives', 'beta.txt', 'gamma.png', 'alpha.pdf'],
      );
      expect(
        names(const FileSort(SortField.size)),
        ['Archives', 'Zeta', 'alpha.pdf', 'gamma.png', 'beta.txt'],
      );
    });

    test('is saved and read back on the device', () async {
      final prefs = LocalPrefs.memory();
      expect(await FileSort.load(prefs), FileSort.byName);
      await const FileSort(SortField.size, descending: true).save(prefs);
      expect(await FileSort.load(prefs), const FileSort(SortField.size, descending: true));
      expect(FileSort.decode('bogus'), FileSort.byName);
      expect(FileSort.decode('date'), const FileSort(SortField.date));
    });

    test('prefs survive a restart (file)', () async {
      final dir = Directory.systemTemp.createTempSync('prefs');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/prefs.json');
      await const FileSort(SortField.date).save(LocalPrefs(file));
      expect(await FileSort.load(LocalPrefs(file)), const FileSort(SortField.date));
      file.writeAsStringSync('not json');
      expect(await FileSort.load(LocalPrefs(file)), FileSort.byName);
    });
  });

  group('recent files', () {
    test('merge opened and modified files, newest first, each once', () {
      final a = node('a', 'a.pdf', updated: '2026-10-01 10:00:00.000Z');
      final b = node('b', 'b.txt', updated: '2026-10-05 10:00:00.000Z');
      final c = node('c', 'c.csv', updated: '2026-10-03 10:00:00.000Z');
      final merged = mergeRecent(
        [(a, DateTime.utc(2026, 10, 6)), (c, DateTime.utc(2026, 9, 1))],
        [b, c, a],
      );
      expect([for (final n in merged) n.id], ['a', 'b', 'c']);
      expect(mergeRecent(const [], [a, b, c], max: 2).map((n) => n.id), ['b', 'c']);
    });

    test('remembers what was opened, per account, most recent first', () async {
      final prefs = LocalPrefs.memory();
      final r = RecentFiles('u1', prefs: prefs, keep: 2);
      await r.remember(node('a', 'a.pdf'), at: DateTime.utc(2026, 10, 1));
      await r.remember(node('b', 'b.pdf'), at: DateTime.utc(2026, 10, 2));
      await r.remember(node('a', 'a.pdf'), at: DateTime.utc(2026, 10, 3));
      await r.remember(node('c', 'c.pdf'), at: DateTime.utc(2026, 10, 4));
      expect([for (final (n, _) in await r.opened()) n.id], ['c', 'a']);
      expect(await RecentFiles('u2', prefs: prefs).opened(), isEmpty);
      await r.forget('c');
      expect([for (final (n, _) in await r.opened()) n.id], ['a']);
    });
  });

  group('share intent', () {
    test('parses what Android sends and drops what is not a file', () {
      expect(parseSharedFiles(null), isEmpty);
      expect(parseSharedFiles('x'), isEmpty);
      expect(
        parseSharedFiles([
          {'path': '/c/shared/1-a.pdf', 'name': 'a.pdf', 'mime': 'application/pdf', 'size': 12},
          {'path': '/c/shared/2-photo', 'name': ' ', 'mime': '', 'size': 3.0},
          {'name': 'no path'},
          'junk',
        ]),
        const [
          SharedFile(path: '/c/shared/1-a.pdf', name: 'a.pdf', mime: 'application/pdf', size: 12),
          SharedFile(
            path: '/c/shared/2-photo',
            name: '2-photo',
            mime: 'application/octet-stream',
            size: 3,
          ),
        ],
      );
    });

    test('becomes upload items for the chosen folder', () async {
      final items = sharedUploads(
        const [SharedFile(path: '/tmp/x.txt', name: 'x.txt', mime: 'text/plain')],
        'folder1',
      );
      expect(items.single.name, 'x.txt');
      expect(items.single.parent, 'folder1');
      expect((await items.single.open()).path, '/tmp/x.txt');
    });
  });

  group('file cache', () {
    test('names are safe and change with the version', () {
      expect(
        cacheName('ab1', '2026-10-01 10:00:00.000Z', '../evil/x.pdf'),
        'ab1-20261001100000000Z/__evil_x.pdf',
      );
      expect(cacheName('a', '1', ''), 'a-1/file');
      expect(cacheName('a', '1', 'x'), isNot(cacheName('a', '2', 'x')));
    });

    test('prune drops old files, then the oldest above the size limit', () async {
      final dir = Directory.systemTemp.createTempSync('cache');
      addTearDown(() => dir.deleteSync(recursive: true));
      final now = DateTime(2026, 10, 15);
      File write(String name, int size, Duration age) {
        final f = File('${dir.path}/$name')
          ..createSync(recursive: true)
          ..writeAsBytesSync(List.filled(size, 1));
        f.setLastModifiedSync(now.subtract(age));
        return f;
      }

      final old = write('a-1/old.pdf', 10, const Duration(days: 5));
      final older = write('b-1/big.pdf', 60, const Duration(hours: 5));
      final recent = write('c-1/new.pdf', 50, const Duration(hours: 1));
      final part = write('d-1/x.pdf.part', 5, const Duration(hours: 2));
      final downloading = write('e-1/y.pdf.part', 5, const Duration(minutes: 5));
      await FileCache(root: () async => dir, maxBytes: 100).prune(now: now);
      expect(old.existsSync(), isFalse, reason: 'older than three days');
      expect(older.existsSync(), isFalse, reason: 'oldest while above the limit');
      expect(recent.existsSync(), isTrue);
      expect(part.existsSync(), isFalse, reason: 'abandoned download');
      expect(downloading.existsSync(), isTrue, reason: 'may still be downloading');
      expect(Directory('${dir.path}/a-1').existsSync(), isFalse, reason: 'empty folder');
    });
  });
}
