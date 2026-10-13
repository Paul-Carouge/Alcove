import 'dart:convert';

import 'package:alcove/core/secure_store.dart';
import 'package:alcove/core/session.dart';
import 'package:alcove/features/search/search_screen.dart';
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

Map<String, dynamic> _node(String id, String name, {String kind = 'file'}) => {
  'id': id,
  'collectionId': 'nodes',
  'collectionName': 'nodes',
  'name': name,
  'kind': kind,
  'mime': kind == 'file' ? 'application/pdf' : '',
  'size': 1200,
  'updated': '2026-10-01 10:00:00.000Z',
};

/// Fires the debounce timer (fake clock), lets the HTTP call finish (real clock), then redraws.
Future<void> settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 350));
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('finds files by name and documents by their text', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final queries = <String>[];
    final client = MockClient((req) async {
      if (req.url.path == '/api/files/token') return _json({'token': 'ft'});
      if (req.url.path == '/api/v1/search') {
        final q = req.url.queryParameters['q']!;
        queries.add(q);
        if (q == 'zzz') return _json({'items': <Object>[]});
        return _json({
          'items': [
            {'node': _node('f1', 'Contrats', kind: 'folder'), 'match': 'name'},
            {
              'node': _node('d1', 'bail.pdf'),
              'match': 'content',
              'snippet': [
                {'text': '…Le '},
                {'text': 'dépôt', 'hit': true},
                {'text': ' de garantie…'},
              ],
            },
          ],
        });
      }
      return http.Response('{}', 404);
    });
    final session = Session(
      store: SecureStore(const FlutterSecureStorage()),
      httpClientFactory: () => client,
    );
    await tester.runAsync(() async {
      await session.useServer(Uri.parse('https://cloud.example.com'));
      session.pb.authStore.save(
        '${base64Url.encode(utf8.encode('{}'))}.${base64Url.encode(utf8.encode('{"exp":4102444800}'))}.s',
        RecordModel.fromJson({'id': 'u1', 'collectionName': 'users'}),
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SearchScreen(session: session),
      ),
    );
    expect(find.text('Search'), findsOneWidget); // the prompt before typing

    await tester.enterText(find.byKey(const Key('searchField')), 'depot');
    await settle(tester);
    expect(queries, ['depot']); // debounced: one request
    expect(find.text('FILES AND FOLDERS'), findsOneWidget);
    expect(find.text('INSIDE DOCUMENTS'), findsOneWidget);
    expect(find.text('Contrats'), findsOneWidget);
    expect(find.text('bail.pdf'), findsOneWidget);
    expect(find.textContaining('dépôt', findRichText: true), findsOneWidget);

    await tester.enterText(find.byKey(const Key('searchField')), 'zzz');
    await settle(tester);
    expect(find.text('Nothing matches “zzz”.'), findsOneWidget);
  });
}
