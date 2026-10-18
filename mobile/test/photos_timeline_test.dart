import 'dart:convert';

import 'package:alcove/core/secure_store.dart';
import 'package:alcove/core/session.dart';
import 'package:alcove/features/photos/photos_screen.dart';
import 'package:alcove/l10n/gen/app_localizations.dart';
import 'package:alcove/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocketbase/pocketbase.dart';

http.Response _json(int status, Object body) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

Map<String, Object> _photo(int i) => {
  'id': 'm$i',
  'collectionId': 'media1',
  'collectionName': 'media',
  'kind': 'photo',
  'status': 'ready',
  'thumb': '',
  'owner': 'u1',
  'node': 'n$i',
  'taken_at': '2026-01-10 10:00:00.000Z',
};

Future<Session> _signedIn(
  WidgetTester tester,
  http.Client client,
) async => (await tester.runAsync(() async {
  FlutterSecureStorage.setMockInitialValues({});
  final s = Session(
    store: SecureStore(const FlutterSecureStorage()),
    httpClientFactory: () => client,
  );
  await s.useServer(Uri.parse('https://cloud.example.com'));
  s.pb.authStore.save(
    '${base64Url.encode(utf8.encode('{}'))}.${base64Url.encode(utf8.encode('{"exp":4102444800}'))}.s',
    RecordModel.fromJson({'id': 'u1', 'collectionName': 'users'}),
  );
  return s;
}))!;

Widget _app(Session session) => MaterialApp(
  theme: buildTheme(Brightness.light),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: PhotosScreen(session: session)),
);

void main() {
  testWidgets('a failed next page shows Retry and is not refetched on every scroll', (
    tester,
  ) async {
    final pages = <int>[];
    var failPage2 = true;
    final client = MockClient((req) async {
      final path = req.url.path;
      if (path == '/api/files/token') return _json(200, {'token': 'ft'});
      if (path == '/api/collections/media/records') {
        // Keyset paging: the second page continues after the last item of the first.
        final filter = req.url.queryParameters['filter']!;
        final page = filter.contains('id < "m119"') ? 2 : 1;
        pages.add(page);
        expect(req.url.queryParameters['skipTotal'], 'true');
        if (page == 2 && failPage2) return _json(500, {'status': 500});
        return _json(200, {
          'page': 1,
          'perPage': 120,
          'totalItems': -1,
          'totalPages': -1,
          'items': [for (var i = 0; i < (page == 1 ? 120 : 100); i++) _photo((page - 1) * 120 + i)],
        });
      }
      return _json(200, {'memories': []});
    });
    final session = await _signedIn(tester, client);

    Future<void> settle() async {
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
        await tester.pump();
      }
    }

    Future<void> scrollToEnd() async {
      for (var i = 0; i < 4; i++) {
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -6000));
        await settle();
      }
    }

    await tester.pumpWidget(_app(session));
    await settle();
    await scrollToEnd();
    expect(pages, [1, 2]);
    expect(find.text('Retry'), findsOneWidget);

    await scrollToEnd();
    expect(pages, [1, 2], reason: 'scrolling does not retry by itself');

    failPage2 = false;
    await tester.tap(find.text('Retry'));
    await settle();
    expect(pages, [1, 2, 2]);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('long press starts a selection, taps add to it, and trash moves the picked items', (
    tester,
  ) async {
    final trashed = <String>[];
    final client = MockClient((req) async {
      final path = req.url.path;
      if (path == '/api/files/token') return _json(200, {'token': 'ft'});
      if (path == '/api/collections/media/records') {
        return _json(200, {
          'page': 1,
          'perPage': 120,
          'totalItems': -1,
          'totalPages': -1,
          'items': [for (var i = 0; i < 6; i++) _photo(i)],
        });
      }
      if (path.startsWith('/api/collections/nodes/records/') && req.method == 'PATCH') {
        trashed.add(path.split('/').last);
        return _json(200, {'id': path.split('/').last, 'collectionName': 'nodes'});
      }
      return _json(200, {'memories': []});
    });
    final session = await _signedIn(tester, client);
    Future<void> settle() async {
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
        await tester.pump();
      }
    }

    await tester.pumpWidget(_app(session));
    await settle();
    final tiles = find.byType(MediaTile);
    expect(tiles, findsNWidgets(6));

    await tester.longPress(tiles.at(0));
    await tester.pump();
    expect(find.text('1 selected'), findsOneWidget);
    await tester.tap(tiles.at(2));
    await tester.pump();
    expect(find.text('2 selected'), findsOneWidget);
    // A tap on a picked one drops it; the last one dropped ends the selection.
    await tester.tap(tiles.at(2));
    await tester.pump();
    expect(find.text('1 selected'), findsOneWidget);
    await tester.tap(tiles.at(3));
    await tester.pump();

    await tester.tap(find.byTooltip('Move to trash'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Move to trash'));
    await settle();
    expect(trashed..sort(), ['n0', 'n3']);
    expect(find.byType(MediaTile), findsNWidgets(4));
    expect(find.text('Photos'), findsWidgets, reason: 'the selection ended');

    await tester.longPress(find.byType(MediaTile).first);
    await tester.pump();
    await tester.tap(find.byTooltip('Cancel selection'));
    await tester.pump();
    expect(find.textContaining('selected'), findsNothing);
  });
}
