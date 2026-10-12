import 'dart:convert';

import 'package:alcove/app.dart';
import 'package:alcove/core/secure_store.dart';
import 'package:alcove/core/server_checker.dart';
import 'package:alcove/core/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final _token =
    '${base64Url.encode(utf8.encode('{"alg":"HS256"}')).replaceAll('=', '')}.'
    '${base64Url.encode(utf8.encode('{"exp":4102444800,"id":"u1","type":"auth"}')).replaceAll('=', '')}.sig';
const _user = {
  'id': 'u1',
  'collectionId': '_pb_users_auth_',
  'collectionName': 'users',
  'email': 'paul@example.com',
  'name': 'Paul Carouge',
};

http.Response _json(int status, Object body) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

Map<String, dynamic> _media(String id, String taken, {String kind = 'image'}) => {
  'id': id,
  'collectionId': 'media1',
  'collectionName': 'media',
  'kind': kind,
  'status': 'ready',
  'taken_at': taken,
  'thumb': '',
  'duration': kind == 'video' ? 3 : 0,
  'favorite': id == 'a',
  'expand': {
    'node': {'id': 'n$id', 'collectionId': 'nodes', 'name': '$id.jpg', 'size': 1000},
  },
};

/// A tiny fake Alcove server.
http.Response _server(http.Request req) {
  final path = req.url.path;
  if (path.endsWith('/auth-with-password')) {
    final body = jsonDecode(req.body) as Map<String, dynamic>;
    if (body['password'] != 'secret') return _json(400, {'status': 400});
    if (body['totp'] == null) {
      return _json(401, {
        'status': 401,
        'data': {'totpRequired': true, 'invalid': false},
      });
    }
    return _json(200, {'token': _token, 'record': _user});
  }
  if (path.endsWith('/auth-refresh')) return _json(200, {'token': _token, 'record': _user});
  if (path == '/api/files/token') return _json(200, {'token': 'ft'});
  if (path == '/api/collections/media/records') {
    return _json(200, {
      'page': 1,
      'perPage': 120,
      'totalItems': 3,
      'totalPages': 1,
      'items': [
        _media('a', '2025-06-20 12:00:00.000Z'),
        _media('b', '2025-06-02 12:00:00.000Z', kind: 'video'),
        _media('c', '2024-12-24 12:00:00.000Z'),
      ],
    });
  }
  if (path == '/api/collections/nodes/records') {
    return _json(200, {
      'page': 1,
      'perPage': 1000,
      'totalItems': 2,
      'totalPages': 1,
      'items': [
        {
          'id': 'f1',
          'collectionId': 'nodes',
          'name': 'report.pdf',
          'kind': 'file',
          'mime': 'application/pdf',
          'size': 2048,
          'updated': '2025-01-02 10:00:00.000Z',
        },
        {
          'id': 'd1',
          'collectionId': 'nodes',
          'name': 'Holidays',
          'kind': 'folder',
          'mime': '',
          'size': 0,
          'updated': '2025-01-01 10:00:00.000Z',
        },
      ],
    });
  }
  return _json(404, {'status': 404});
}

void main() {
  setUp(
    () => FlutterSecureStorage.setMockInitialValues({'server_url': 'https://cloud.example.com'}),
  );

  Future<void> pumpApp(WidgetTester tester) async {
    final store = SecureStore(const FlutterSecureStorage());
    await tester.pumpWidget(
      AlcoveApp(
        checker: ServerChecker(),
        store: store,
        session: Session(
          store: store,
          httpClientFactory: () => MockClient((r) async => _server(r)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('sign in with an authenticator code, browse photos and files, sign out', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('to cloud.example.com'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Email'), 'paul@example.com');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'wrong');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Wrong email or password.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'secret');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Two-factor code'), findsOneWidget);
    await tester.tap(find.text('Use a recovery code'));
    await tester.pumpAndSettle();
    expect(find.text('Enter one of your recovery codes.'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Code'), 'ABCD-EFGH');
    await tester.tap(find.widgetWithText(FilledButton, 'Verify'));
    await tester.pumpAndSettle();

    // Photos, grouped by month, newest first.
    expect(find.textContaining('June', findRichText: true), findsOneWidget);
    expect(find.textContaining('December', findRichText: true), findsOneWidget);
    expect(find.bySemanticsLabel('Open a.jpg'), findsOneWidget);
    expect(find.text('0:03'), findsOneWidget); // video badge
    expect(find.byIcon(Icons.favorite), findsOneWidget);

    // Files: folders first.
    await tester.tap(find.text('Files'));
    await tester.pumpAndSettle();
    expect(find.text('My files'), findsOneWidget);
    final holidays = tester.getTopLeft(find.text('Holidays'));
    final report = tester.getTopLeft(find.text('report.pdf'));
    expect(holidays.dy, lessThan(report.dy));

    // Account, then sign out back to the login screen.
    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();
    expect(find.text('Paul Carouge'), findsOneWidget);
    expect(find.textContaining('Made by Paul Carouge', skipOffstage: false), findsOneWidget);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
  });

  testWidgets('without a saved server, the connect screen comes first', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await pumpApp(tester);
    expect(find.text('Connect to your server'), findsOneWidget);
  });
}
