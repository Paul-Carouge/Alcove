import 'dart:convert';

import 'package:alcove/core/notes.dart';
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

Map<String, dynamic> _node(
  String id,
  String name, {
  String kind = 'file',
  String parent = '',
  String trashed = '',
}) => {
  'id': id,
  'collectionId': 'nodes',
  'collectionName': 'nodes',
  'owner': 'u1',
  'name': name,
  'kind': kind,
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
  final failGet = <String>{};
  final conflicts = <String>{};

  /// Deletes a node and, like the server's cascade on `parent`, everything under it.
  void _cascade(String id) {
    nodes.remove(id);
    for (final child in nodes.values.where((n) => n['parent'] == id).toList()) {
      _cascade(child['id'] as String);
    }
  }

  http.Response handle(http.Request req) {
    final path = req.url.path;
    if (path == '/api/files/token') return _json(200, {'token': 'ft'});
    const base = '/api/collections/nodes/records';
    if (path == base && req.method == 'GET') {
      final trashed = nodes.values.where((n) => (n['trashed_at'] as String).isNotEmpty).toList()
        ..sort((a, b) => (b['trashed_at'] as String).compareTo(a['trashed_at'] as String));
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
      if (req.method == 'GET') {
        return failGet.contains(id)
            ? _json(500, {'status': 500, 'message': 'boom', 'data': {}})
            : _json(200, n);
      }
      if (req.method == 'PATCH') {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        if (conflicts.contains(id)) {
          return _json(400, {'status': 400, 'message': 'Failed to update record.', 'data': {}});
        }
        updates[id] = body;
        n.addAll(body);
        return _json(200, n);
      }
      if (req.method == 'DELETE') {
        if (failDelete.contains(id)) return _json(500, {'status': 500, 'message': 'boom'});
        deleted.add(id);
        _cascade(id);
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

/// Notes in memory.
class FakeNotes extends NotesApi {
  FakeNotes(super.session, this.items);

  List<RecordModel> items;
  final restored = <String>[];
  final deleted = <String>[];

  @override
  Future<List<RecordModel>> list() async => items;

  @override
  Future<RecordModel> restore(String id) async {
    restored.add(id);
    return items.firstWhere((n) => n.id == id);
  }

  @override
  Future<void> delete(String id) async {
    deleted.add(id);
    items = items.where((n) => n.id != id).toList();
  }
}

RecordModel _note(String id, String title, {String trashed = ''}) => RecordModel.fromJson({
  'id': id,
  'collectionName': 'notes',
  'title': title,
  'body': '',
  'pinned': false,
  'tags': <String>[],
  'trashed_at': trashed,
  'updated': '2026-10-01 10:00:00.000Z',
});

Widget _app(Session session, {NotesApi? notes}) => MaterialApp(
  theme: buildTheme(Brightness.light),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: TrashScreen(session: session, notes: notes ?? FakeNotes(session, [])),
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
      ..nodes['d1'] = _node('d1', 'Old folder', kind: 'folder', trashed: '2026-10-13 10:00:00.000Z')
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

  testWidgets('empties files and notes; a child taken by its folder is not a failure', (
    tester,
  ) async {
    final session = await _session(fake);
    final notes = FakeNotes(session, [
      _note('no1', 'Old idea', trashed: '2026-10-09 10:00:00.000Z'),
      _note('no2', 'Kept note'),
    ]);
    await tester.pumpWidget(_app(session, notes: notes));
    await _settle(tester);
    expect(find.text('Old idea'), findsOneWidget);
    expect(find.text('Kept note'), findsNothing);

    await tester.tap(find.widgetWithText(TextButton, 'Empty'));
    await tester.pumpAndSettle();
    expect(find.textContaining('4 items will be permanently deleted.'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Empty'));
    await _settle(tester);

    expect(fake.nodes, isEmpty);
    expect(notes.deleted, ['no1']);
    expect(find.textContaining('could not be deleted'), findsNothing);
    expect(find.text('The trash is empty'), findsOneWidget);
  });

  testWidgets('emptying keeps and reports what the server refused', (tester) async {
    fake.failDelete.add('f2');
    await tester.pumpWidget(_app(await _session(fake)));
    await _settle(tester);

    await tester.tap(find.widgetWithText(TextButton, 'Empty'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Empty'));
    await _settle(tester);

    expect(find.text('photo.pdf'), findsOneWidget);
    expect(find.text('Old folder'), findsNothing);
    expect(find.text('1 item could not be deleted.'), findsOneWidget);
  });

  testWidgets('deleting a folder forever also clears its trashed children', (tester) async {
    await tester.pumpWidget(_app(await _session(fake)));
    await _settle(tester);

    await tester.tap(find.text('Old folder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete forever'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete forever'));
    await _settle(tester);

    expect(find.text('Old folder'), findsNothing);
    expect(find.text('invoice.pdf'), findsNothing);
    expect(find.text('photo.pdf'), findsOneWidget);
  });

  testWidgets('restores into the root when the original folder is gone', (tester) async {
    fake.nodes['f3'] = _node('f3', 'lost.pdf', parent: 'gone', trashed: '2026-10-01 10:00:00.000Z');
    await tester.pumpWidget(_app(await _session(fake)));
    await _settle(tester);

    await tester.tap(find.text('lost.pdf'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore'));
    await _settle(tester);

    expect(fake.updates['f3'], {'trashed_at': '', 'parent': ''});
  });

  testWidgets('does not restore when the original folder cannot be checked', (tester) async {
    fake.failGet.add('d1');
    await tester.pumpWidget(_app(await _session(fake)));
    await _settle(tester);

    await tester.tap(find.text('invoice.pdf'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore'));
    await _settle(tester);

    expect(fake.updates, isEmpty);
    expect(find.text('invoice.pdf'), findsOneWidget);
  });

  testWidgets('explains a name conflict on restore', (tester) async {
    fake.conflicts.add('f2');
    await tester.pumpWidget(_app(await _session(fake)));
    await _settle(tester);

    await tester.tap(find.text('photo.pdf'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore'));
    await _settle(tester);

    expect(find.textContaining('An item named “photo.pdf” already exists'), findsOneWidget);
    expect(find.text('photo.pdf'), findsOneWidget);
  });

  testWidgets('restores a note from the trash', (tester) async {
    final session = await _session(fake);
    final notes = FakeNotes(session, [
      _note('no1', 'Old idea', trashed: '2026-10-09 10:00:00.000Z'),
    ]);
    await tester.pumpWidget(_app(session, notes: notes));
    await _settle(tester);

    await tester.scrollUntilVisible(find.text('Old idea'), 200);
    await tester.tap(find.text('Old idea'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore'));
    await _settle(tester);

    expect(notes.restored, ['no1']);
    expect(find.text('Old idea'), findsNothing);
  });

  testWidgets('shows the empty state', (tester) async {
    fake.nodes.clear();
    await tester.pumpWidget(_app(await _session(fake)));
    await _settle(tester);
    expect(find.text('The trash is empty'), findsOneWidget);
  });
}
