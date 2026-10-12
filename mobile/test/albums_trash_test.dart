import 'dart:convert';

import 'package:alcove/core/secure_store.dart';
import 'package:alcove/core/session.dart';
import 'package:alcove/features/photos/albums_screen.dart';
import 'package:alcove/features/photos/media.dart';
import 'package:alcove/features/photos/photo_viewer.dart';
import 'package:alcove/l10n/gen/app_localizations.dart';
import 'package:alcove/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocketbase/pocketbase.dart';

http.Response _json(Object body) =>
    http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});

Widget _app(Widget home) => MaterialApp(
  theme: buildTheme(Brightness.light),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

void main() {
  late List<http.Request> requests;
  late Session session;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    requests = [];
    final client = MockClient((req) async {
      requests.add(req);
      final path = req.url.path;
      if (path == '/api/files/token') return _json({'token': 'ft'});
      if (path == '/api/v1/albums') {
        return _json({
          'items': [
            {
              'id': 'al1',
              'name': 'Summer',
              'role': 'owner',
              'owner': {'id': 'u1', 'name': 'Paul'},
              'count': 2,
              'shared': true,
              'cover': null,
              'updated': '',
            },
            {
              'id': 'al2',
              'name': 'Family',
              'role': 'viewer',
              'owner': {'id': 'u2', 'name': 'Camille'},
              'count': 1,
              'shared': true,
              'cover': null,
              'updated': '',
            },
          ],
        });
      }
      if (path == '/api/v1/albums/al1/items') {
        return _json({
          'page': 1,
          'perPage': 500,
          'totalItems': 1,
          'items': [
            {
              'id': 'm1',
              'collectionId': 'media1',
              'thumb': '',
              'preview': '',
              'itemId': 'i1',
              'addedBy': 'u1',
              'kind': 'image',
              'status': 'ready',
              'taken_at': '2025-07-01 10:00:00.000Z',
              'width': 4,
              'height': 3,
              'duration': 0,
              'favorite': false,
              'name': 'beach.jpg',
              'size': 10,
              'mime': 'image/jpeg',
            },
          ],
        });
      }
      if (path.startsWith('/api/collections/nodes/records/') && req.method == 'PATCH') {
        return _json({'id': 'n1', 'collectionId': 'nodes'});
      }
      return http.Response('{}', 404);
    });
    session = Session(
      store: SecureStore(const FlutterSecureStorage()),
      httpClientFactory: () => client,
    );
    await session.useServer(Uri.parse('https://cloud.example.com'));
    session.pb.authStore.save(
      '${base64Url.encode(utf8.encode('{}'))}.${base64Url.encode(utf8.encode('{"exp":4102444800}'))}.s',
      RecordModel.fromJson({'id': 'u1', 'collectionName': 'users'}),
    );
  });

  testWidgets('lists albums, own and shared, and opens one', (tester) async {
    await tester.pumpWidget(_app(AlbumsScreen(session: session)));
    await tester.pumpAndSettle();
    expect(find.text('Summer'), findsOneWidget);
    expect(find.text('2 items · Shared'), findsOneWidget);
    expect(find.text('1 item · Shared by Camille'), findsOneWidget);
    await tester.tap(find.text('Summer'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Open beach.jpg'), findsOneWidget);
  });

  testWidgets('moves your own photo to the trash after confirming', (tester) async {
    final items = [
      MediaItem(
        RecordModel.fromJson({
          'id': 'm1',
          'collectionId': 'media1',
          'node': 'n1',
          'owner': 'u1',
          'kind': 'image',
          'status': 'ready',
          'taken_at': '2025-07-01 10:00:00.000Z',
          'thumb': '',
          'preview': '',
          'expand': {
            'node': {'id': 'n1', 'collectionId': 'nodes', 'name': 'beach.jpg', 'size': 10},
          },
        }),
      ),
    ];
    MediaItem? trashed;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => PhotoViewer(
            session: session,
            items: items,
            initial: 0,
            onTrashed: (it) {
              trashed = it;
              items.remove(it);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Move to trash'));
    await tester.pumpAndSettle();
    expect(find.text('Move to trash?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Move to trash'));
    await tester.pumpAndSettle();
    expect(trashed?.id, 'm1');
    final patch = requests.lastWhere((r) => r.method == 'PATCH');
    expect(patch.url.path, '/api/collections/nodes/records/n1');
    expect((jsonDecode(patch.body) as Map)['trashed_at'], isNotEmpty);
  });
}
