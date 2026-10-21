import 'dart:convert';

import 'package:alcove/core/secure_store.dart';
import 'package:alcove/core/session.dart';
import 'package:alcove/features/trash/trash_screen.dart';
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

Map<String, dynamic> _node(String id, String name, {String parent = '', String trashed = ''}) => {
  'id': id,
  'collectionId': 'nodes',
  'collectionName': 'nodes',
  'owner': 'u1',
  'name': name,
  'kind': 'file',
  'parent': parent,
  'mime': 'application/pdf',
  'blob': 'b.pdf',
  'size': 1000,
  'trashed_at': trashed,
  'updated': '2026-10-01 10:00:00.000Z',
};

/// Nodes kept in memory, served like PocketBase's records API.
class FakeNodes {
  final nodes = <String, Map<String, dynamic>>{};
  final updates = <String, Map<String, dynamic>>{};
  final deleted = <String>[];
  final failDelete = <String>{};

  http.Response handle(http.Request req) {
    final path = req.url.path;
    if (path == '/api/files/token') return _json(200, {'token': 'ft'});
    const base = '/api/collections/nodes/records';
    if (path == base && req.method == 'GET') {
      final trashed = nodes.values.where((n) => (n['trashed_at'] as String).isNotEmpty).toList();
      return _json(200, {
        'page': 1,
        'perPage': 500,
        'totalItems': trashed.length,
        'totalPages': 1,
        'items': trashed,
      });
    }
    if (path.startsWith('$base/')) {
      final id = path.substring(base.length + 1);
      final n = nodes[id];
      if (n == null) return _json(404, {'status': 404, 'message': 'not found', 'data': {}});
      if (req.method == 'GET') return _json(200, n);
      if (req.method == 'PATCH') {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        updates[id] = body;
        n.addAll(body);
        return _json(200, n);
      }
      if (req.method == 'DELETE') {
        if (failDelete.contains(id)) return _json(500, {'status': 500, 'message': 'boom'});
        deleted.add(id);
        nodes.remove(id);
        return http.Response('', 204);
      }
    }
    return _json(404, {'status': 404, 'message': 'not found', 'data': {}});
  }
}

Future<Session> _session(FakeNodes fake) async {
  FlutterSecureStorage.setMockInitialValues({});
  final client = MockClient((req) async => fake.handle(req));
  final session = Session(
    store: SecureStore(const FlutterSecureStorage()),
    httpClientFactory: () => client,
  );
  await session.useServer(Uri.parse('https://cloud.example.com'));
  session.pb.authStore.save(
    '${base64Url.encode(utf8.encode('{}'))}.${base64Url.encode(utf8.encode('{"exp":4102444800}'))}.s',
    RecordModel.fromJson({'id': 'u1', 'collectionName': 'users'}),
  );
  return session;
}

Widget _app(Session session) => MaterialApp(
  theme: buildTheme(Brightness.light),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: TrashScreen(session: session),
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
  }
}

void main() {
  late FakeNodes fake;

  setUp(() {
    fake = FakeNodes()
      ..nodes['d1'] = _node('d1', 'Old folder', trashed: '2026-10-10 10:00:00.000Z')
      ..nodes['f1'] = _node(
        'f1',
        'invoice.pdf',
        parent: 'd1',
        trashed: '2026-10-11 10:00:00.000Z',
      )
      ..nodes['f2'] = _node('f2', 'photo.pdf', trashed: '2026-10-12 10:00:00.000Z');
  });

  testWidgets('restores into the root when the original folder is itself trashed', (tester) async {
    await tester.pumpWidget(_app(await _session(fake)));
    await _settle(tester);
    expect(find.text('invoice.pdf'), findsOneWidget);

    await tester.tap(find.text('invoice.pdf'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore'));
    await _settle(tester);

    expect(fake.updates['f1'], {'trashed_at': '', 'parent': ''});
    expect(find.text('invoice.pdf'), findsNothing);
  });

  testWidgets('deletes forever only after confirmation', (tester) async {
    await tester.pumpWidget(_app(await _session(fake)));
    await _settle(tester);

    await tester.tap(find.text('photo.pdf'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete forever'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await _settle(tester);
    expect(fake.deleted, isEmpty);

    await tester.tap(find.text('photo.pdf'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete forever'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete forever'));
    await _settle(tester);
    expect(fake.deleted, ['f2']);
    expect(find.text('photo.pdf'), findsNothing);
  });

  testWidgets('empties the trash and reports what failed', (tester) async {
    fake.failDelete.add('d1');
    await tester.pumpWidget(_app(await _session(fake)));
    await _settle(tester);

    await tester.tap(find.widgetWithText(TextButton, 'Empty'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Empty'));
    await _settle(tester);

    expect(fake.deleted, unorderedEquals(['f1', 'f2']));
    expect(find.text('Old folder'), findsOneWidget);
    expect(find.text('1 item could not be deleted.'), findsOneWidget);
  });

  testWidgets('shows the empty state', (tester) async {
    fake.nodes.clear();
    await tester.pumpWidget(_app(await _session(fake)));
    await _settle(tester);
    expect(find.text('The trash is empty'), findsOneWidget);
  });
}
