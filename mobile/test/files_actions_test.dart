import 'dart:convert';
import 'dart:io';

import 'package:alcove/core/drive.dart';
import 'package:alcove/core/secure_store.dart';
import 'package:alcove/core/session.dart';
import 'package:alcove/features/files/files_screen.dart';
import 'package:alcove/l10n/gen/app_localizations.dart';
import 'package:alcove/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocketbase/pocketbase.dart';

http.Response _json(int status, Object body, [Map<String, String> headers = const {}]) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json', ...headers},
    );

/// A fake drive that keeps its state: list, create, update (rename, move, trash) and tus uploads.
class FakeDrive {
  final nodes = <String, Map<String, dynamic>>{};
  var _seq = 0;
  final uploads = <String, ({String name, String parent, int length, int offset})>{};

  Map<String, dynamic> add(String name, {String kind = 'file', String parent = ''}) {
    final id = 'n${_seq++}';
    return nodes[id] = {
      'id': id,
      'collectionId': 'nodes',
      'collectionName': 'nodes',
      'owner': 'u1',
      'name': name,
      'kind': kind,
      'parent': parent,
      'mime': kind == 'file' ? 'application/pdf' : '',
      'blob': kind == 'file' ? 'b.pdf' : '',
      'size': 1000,
      'trashed_at': '',
      'updated': '2026-10-01 10:00:00.000Z',
    };
  }

  http.Response handle(http.Request req) {
    final path = req.url.path;
    if (path == '/api/files/token') return _json(200, {'token': 'ft'});
    if (path == '/api/collections/nodes/records' && req.method == 'GET') {
      final filter = req.url.queryParameters['filter'] ?? '';
      final parent = RegExp(r"parent = '([^']*)'").firstMatch(filter)?.group(1) ?? '';
      final foldersOnly = filter.contains('kind = "folder"');
      final items = nodes.values
          .where(
            (n) =>
                n['parent'] == parent &&
                n['trashed_at'] == '' &&
                (!foldersOnly || n['kind'] == 'folder'),
          )
          .toList();
      return _json(200, {
        'page': 1,
        'perPage': 500,
        'totalItems': items.length,
        'totalPages': 1,
        'items': items,
      });
    }
    if (path == '/api/collections/nodes/records' && req.method == 'POST') {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      return _json(
        200,
        add(body['name'] as String, kind: body['kind'] as String, parent: body['parent'] as String),
      );
    }
    final one = RegExp(r'^/api/collections/nodes/records/(\w+)$').firstMatch(path);
    if (one != null) {
      final n = nodes[one.group(1)]!;
      if (req.method == 'PATCH') n.addAll(jsonDecode(req.body) as Map<String, dynamic>);
      return _json(200, n);
    }
    // tus: creation, then one PATCH that completes the upload.
    if (path == '/api/v1/uploads/' && req.method == 'POST') {
      final meta = {
        for (final pair in req.headers['upload-metadata']!.split(','))
          pair.split(' ').first: utf8.decode(
            base64.decode(pair.split(' ').length > 1 ? pair.split(' ')[1] : ''),
          ),
      };
      final id = 'u${uploads.length}';
      uploads[id] = (
        name: meta['filename']!,
        parent: meta['parent'] ?? '',
        length: int.parse(req.headers['upload-length']!),
        offset: 0,
      );
      return http.Response('', 201, headers: {'location': '/api/v1/uploads/$id'});
    }
    final up = RegExp(r'^/api/v1/uploads/(\w+)$').firstMatch(path);
    if (up != null && req.method == 'PATCH') {
      final u = uploads[up.group(1)]!;
      final node = add(u.name, parent: u.parent);
      return http.Response(
        '',
        204,
        headers: {
          'upload-offset': '${req.bodyBytes.length}',
          'alcove-node-id': node['id'] as String,
        },
      );
    }
    return _json(404, {'status': 404, 'message': 'not found'});
  }
}

Future<Session> _session(http.Client client) async {
  FlutterSecureStorage.setMockInitialValues({});
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

/// Lets real HTTP futures complete, then redraws.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
  }
}

void main() {
  test('invalidName follows the server rule', () {
    expect(invalidName('Factures 2026'), isNull);
    expect(invalidName('.bashrc'), isNull);
    expect(invalidName('   '), 'empty');
    expect(invalidName('a/b'), 'invalid');
    expect(invalidName('..'), 'invalid');
    expect(invalidName('tab\there'), 'invalid');
    expect(invalidName('x' * 256), 'long');
  });

  testWidgets('create a folder, rename, move to the trash and undo', (tester) async {
    final drive = FakeDrive()..add('bail.pdf');
    final client = MockClient((r) async => drive.handle(r));
    final session = (await tester.runAsync(() => _session(client)))!;
    final uploads = UploadQueue(session, httpClient: () => client);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: FilesScreen(session: session, uploads: uploads),
      ),
    );
    await settle(tester);
    expect(find.text('bail.pdf'), findsOneWidget);

    // New folder; names are checked before asking the server.
    await tester.tap(find.byKey(const Key('addButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New folder'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('nameField')), 'a/b');
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pump();
    expect(find.text('A name cannot contain “/” or be only dots.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('nameField')), 'Factures');
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await settle(tester);
    expect(find.text('Factures'), findsOneWidget);

    // Rename from the actions.
    await tester.tap(find.byTooltip('More actions for bail.pdf'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('nameField')), 'bail 2025.pdf');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);
    expect(find.text('bail 2025.pdf'), findsOneWidget);

    // Trash, then undo.
    await tester.longPress(find.text('bail 2025.pdf'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to trash'));
    await settle(tester);
    expect(find.text('bail 2025.pdf'), findsNothing);
    expect(find.text('“bail 2025.pdf” moved to the trash'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(find.text('bail 2025.pdf'), findsOneWidget);
  });

  testWidgets('move into a folder', (tester) async {
    final drive = FakeDrive();
    drive.add('Archives', kind: 'folder');
    drive.add('note.pdf');
    final client = MockClient((r) async => drive.handle(r));
    final session = (await tester.runAsync(() => _session(client)))!;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: FilesScreen(
          session: session,
          uploads: UploadQueue(session, httpClient: () => client),
        ),
      ),
    );
    await settle(tester);
    await tester.tap(find.byTooltip('More actions for note.pdf'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move'));
    await settle(tester);
    // Already at the root: the button says so.
    expect(find.text('Already in this folder'), findsOneWidget);
    await tester.tap(find.text('Archives').last);
    await settle(tester);
    await tester.tap(find.byKey(const Key('moveHere')));
    await settle(tester);
    expect(find.text('note.pdf'), findsNothing);
    expect(find.text('Moved to “Archives”'), findsOneWidget);
    expect(drive.nodes.values.firstWhere((n) => n['name'] == 'note.pdf')['parent'], 'n0');
  });

  test('the upload queue sends files one by one and reports them', () async {
    final drive = FakeDrive();
    final client = MockClient((r) async => drive.handle(r));
    final session = await _session(client);
    final dir = Directory.systemTemp.createTempSync('uploads');
    addTearDown(() => dir.deleteSync(recursive: true));
    final a = File('${dir.path}/a.txt')..writeAsStringSync('hello');
    final b = File('${dir.path}/b.txt')..writeAsStringSync('world!');
    final queue = UploadQueue(session, httpClient: () => client);
    final arrived = <String>[];
    queue.completed.listen(arrived.add);
    queue.add([
      UploadItem(name: 'a.txt', parent: 'n9', open: () async => a),
      UploadItem(name: 'b.txt', parent: 'n9', open: () async => b),
      UploadItem(name: 'gone.txt', parent: 'n9', open: () async => File('${dir.path}/missing')),
    ]);
    while (queue.active) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(queue.finished, 2);
    expect(queue.failedCount, 1);
    expect(arrived, ['n9', 'n9']);
    expect(drive.nodes.values.map((n) => n['name']), containsAll(['a.txt', 'b.txt']));
    queue.clear();
    expect(queue.items, isEmpty);
  });
}
