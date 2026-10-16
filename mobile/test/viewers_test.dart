import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:alcove/core/drive.dart';
import 'package:alcove/core/file_cache.dart';
import 'package:alcove/core/native_files.dart';
import 'package:alcove/core/previews.dart';
import 'package:alcove/core/share_inbox.dart';
import 'package:alcove/features/search/search_screen.dart';
import 'package:alcove/features/share/share_screen.dart';
import 'package:alcove/features/viewer/file_viewer.dart';
import 'package:alcove/l10n/gen/app_localizations.dart';
import 'package:alcove/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocketbase/pocketbase.dart';

import 'screenshots/fake_server.dart';

/// A 1×1 PNG.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==',
);

class _FakeNative extends NativeFiles {
  final rendered = <(int, int)>[];
  final calls = <String>[];
  bool closed = false;

  @override
  bool get available => true;
  @override
  Future<PdfInfo> pdfOpen(String path) async =>
      (id: 7, pages: List.filled(12, const Size(595, 842)));
  @override
  Future<Uint8List> pdfRender(int id, int page, int width) async {
    rendered.add((page, width));
    return _png;
  }

  @override
  Future<void> pdfClose(int id) async => closed = true;
  @override
  Future<bool> share(List<String> paths, String mime, String title) async {
    calls.add('share ${paths.single.split('/').last} $mime');
    return true;
  }

  @override
  Future<bool> openWith(String path, String mime, String title) async {
    calls.add('open ${path.split('/').last}');
    return false; // no app on this phone
  }

  @override
  Future<bool> saveToDownloads(String path, String name, String mime) async {
    calls.add('save $name');
    return true;
  }
}

Widget _app(Widget home) => MaterialApp(
  theme: buildTheme(Brightness.light),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

(RecordModel, FileCache, Directory) _cached(String name, String mime, List<int> bytes) {
  final dir = Directory.systemTemp.createTempSync('viewer');
  final node = RecordModel.fromJson({
    'id': 'f1',
    'collectionId': 'nodes',
    'name': name,
    'kind': 'file',
    'mime': mime,
    'size': bytes.length,
    'updated': '2026-10-12 10:00:00.000Z',
  });
  File('${dir.path}/${cacheName('f1', node.getStringValue('updated'), name)}')
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes);
  return (node, FileCache(root: () async => dir), dir);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('a PDF renders the pages on screen, shows the page and jumps', (tester) async {
    final session = (await tester.runAsync(fakeSession))!;
    final native = _FakeNative();
    final (node, cache, dir) = _cached('bail.pdf', 'application/pdf', [1, 2, 3]);
    addTearDown(() => dir.deleteSync(recursive: true));
    await tester.pumpWidget(
      _app(
        FileViewerScreen(
          session: session,
          node: node,
          kind: PreviewKind.pdf,
          cache: cache,
          native: native,
        ),
      ),
    );
    await _settle(tester);
    expect(find.text('1 / 12'), findsOneWidget);
    // Lazy: only the pages near the screen were rendered, at the screen's width.
    expect(native.rendered, isNotEmpty);
    expect(native.rendered.map((r) => r.$1).toSet().length, lessThan(6));
    expect(find.bySemanticsLabel('Page 1 of 12'), findsWidgets);

    await tester.tap(find.byKey(const Key('pageChip')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('pageField')), '9');
    await tester.tap(find.text('Go'));
    await _settle(tester);
    expect(find.text('9 / 12'), findsOneWidget);
    expect(native.rendered.any((r) => r.$1 == 8), isTrue);

    // Share, Open with (no app) and Download use the cached file.
    await tester.tap(find.byKey(const Key('viewerShare')));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('viewerOpenWith')));
    await _settle(tester);
    expect(find.text('No app on this phone can open this file.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('viewerDownload')));
    await _settle(tester);
    expect(native.calls, ['share bail.pdf application/pdf', 'open bail.pdf', 'save bail.pdf']);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

    await tester.pumpWidget(const SizedBox());
    expect(native.closed, isTrue);
  });

  testWidgets('text files show as text, code in monospace', (tester) async {
    final session = (await tester.runAsync(fakeSession))!;
    final (node, cache, dir) = _cached(
      'data.json',
      'application/json',
      utf8.encode('{"name":"Alcove","year":2026}'),
    );
    addTearDown(() => dir.deleteSync(recursive: true));
    await tester.pumpWidget(
      _app(
        FileViewerScreen(
          session: session,
          node: node,
          kind: PreviewKind.code,
          cache: cache,
          native: _FakeNative(),
        ),
      ),
    );
    for (var i = 0; i < 20 && find.textContaining('"name"').evaluate().isEmpty; i++) {
      await _settle(tester); // decoded in a background isolate
    }
    final text = tester.widget<Text>(find.textContaining('"name": "Alcove"'));
    expect(text.style?.fontFamily, 'JetBrains Mono');
  });

  testWidgets('a file too large or of another kind gets a calm message', (tester) async {
    final session = (await tester.runAsync(fakeSession))!;
    final (node, cache, dir) = _cached(
      'huge.log',
      'text/plain',
      List.filled(maxTextPreviewBytes + 1, 0x61),
    );
    addTearDown(() => dir.deleteSync(recursive: true));
    await tester.pumpWidget(
      _app(
        FileViewerScreen(
          session: session,
          node: node,
          kind: PreviewKind.text,
          cache: cache,
          native: _FakeNative(),
        ),
      ),
    );
    for (var i = 0; i < 10 && find.text('Too large to preview').evaluate().isEmpty; i++) {
      await _settle(tester);
    }
    expect(find.text('Too large to preview'), findsOneWidget);

    final zip = RecordModel.fromJson({
      'id': 'z',
      'collectionId': 'nodes',
      'name': 'a.zip',
      'mime': 'application/zip',
      'size': 10,
    });
    await tester.pumpWidget(
      _app(
        FileViewerScreen(session: session, node: zip, kind: PreviewKind.none, cache: cache),
      ),
    );
    await _settle(tester);
    expect(find.text('No preview for this file'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Open with…'), findsOneWidget);
  });

  testWidgets('files fetched for the viewer go through the file token and the cache', (
    tester,
  ) async {
    final dir = Directory.systemTemp.createTempSync('cache');
    addTearDown(() => dir.deleteSync(recursive: true));
    final asked = <Uri>[];
    final session = (await tester.runAsync(fakeSession))!;
    final fetched = await tester.runAsync(() async {
      final client = MockClient((r) async {
        asked.add(r.url);
        return http.Response.bytes([1, 2, 3, 4], 200);
      });
      final s = session;
      final cache = FileCache(root: () async => dir);
      final node = RecordModel.fromJson({
        'id': 'n1',
        'collectionId': 'nodes',
        'name': 'a.pdf',
        'size': 4,
        'updated': '2026-10-01',
      });
      Future<File> fetch() => cache.fetch(
        s,
        key: cacheName('n1', '1', 'a.pdf'),
        url: () async => Uri.parse('https://cloud.example.com/x?token=ft'),
        expectedSize: 4,
        client: client,
      );
      final f = await fetch();
      await fetch(); // the second time comes from the cache
      expect(node.id, 'n1');
      return f;
    });
    expect(fetched!.readAsBytesSync(), [1, 2, 3, 4]);
    expect(asked, hasLength(1));
    expect(asked.single.queryParameters['token'], 'ft');
  });

  testWidgets('share to Alcove: browse into a folder, back goes up, send here', (tester) async {
    final session = (await tester.runAsync(fakeSession))!;
    ShareDestination? picked;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  picked = await Navigator.of(context).push<ShareDestination>(
                    MaterialPageRoute(
                      builder: (_) => ShareScreen(
                        session: session,
                        files: const [
                          SharedFile(path: '/x/a.pdf', name: 'a.pdf', mime: 'application/pdf'),
                        ],
                      ),
                    ),
                  );
                },
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await _settle(tester);
    expect(find.text('a.pdf'), findsOneWidget);
    expect(find.text('Send to My files'), findsOneWidget);
    await tester.tap(find.text('Documents'));
    await _settle(tester);
    expect(find.text('Send to Documents'), findsOneWidget);
    await tester.binding.handlePopRoute(); // Android back: up one folder
    await _settle(tester);
    expect(find.text('Send to My files'), findsOneWidget);
    await tester.tap(find.text('Documents'));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('shareHere')));
    await _settle(tester);
    expect(picked, (folderId: 'd2', name: 'Documents'));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  });

  testWidgets('search finds notes and photos too', (tester) async {
    final session = (await tester.runAsync(fakeSession))!;
    await tester.pumpWidget(_app(SearchScreen(session: session, uploads: UploadQueue(session))));
    await tester.enterText(find.byKey(const Key('searchField')), 'facture');
    await tester.pump(const Duration(milliseconds: 350));
    await _settle(tester);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Courses'), findsOneWidget);
    expect(find.text('Files and folders'), findsOneWidget);
  });
}
