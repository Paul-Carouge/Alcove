import 'dart:async';
import 'dart:convert';

import 'package:alcove/core/secure_store.dart';
import 'package:alcove/core/session.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _user = {
  'id': 'u1',
  'collectionId': '_pb_users_auth_',
  'collectionName': 'users',
  'email': 'paul@example.com',
  'name': 'Paul',
};

// A JWT whose exp is far in the future (the auth store checks it).
final _token =
    '${base64Url.encode(utf8.encode('{"alg":"HS256"}')).replaceAll('=', '')}.'
    '${base64Url.encode(utf8.encode('{"exp":4102444800,"id":"u1","type":"auth"}')).replaceAll('=', '')}.sig';

http.Response _json(int status, Object body) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.Request> requests;
  late http.Response Function(http.Request) handler;

  Session newSession() => Session(
    store: SecureStore(const FlutterSecureStorage()),
    httpClientFactory: () => MockClient((req) async {
      requests.add(req);
      return handler(req);
    }),
  );

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    requests = [];
  });

  test('wrong password', () async {
    handler = (_) => _json(400, {'status': 400, 'message': 'Failed to authenticate.'});
    final s = newSession();
    await s.useServer(Uri.parse('https://cloud.example.com'));
    final r = await s.signIn('paul@example.com', 'nope');
    expect(
      r,
      isA<SignInFailed>().having((f) => f.failure, 'failure', SignInFailure.badCredentials),
    );
    expect(s.isSignedIn, isFalse);
  });

  test('authenticator code: asked, then sent with the password', () async {
    handler = (req) {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      if (body['totp'] == null) {
        return _json(401, {
          'status': 401,
          'data': {'totpRequired': true, 'invalid': false},
        });
      }
      if (body['totp'] == '000000') {
        return _json(401, {
          'status': 401,
          'data': {'totpRequired': true, 'invalid': true},
        });
      }
      return _json(200, {'token': _token, 'record': _user});
    };
    final s = newSession();
    await s.useServer(Uri.parse('https://cloud.example.com'));
    expect(await s.signIn('paul@example.com', 'secret'), isA<TotpRequired>());
    expect(
      await s.signIn('paul@example.com', 'secret', totp: '000000'),
      isA<TotpRequired>().having((t) => t.invalid, 'invalid', isTrue),
    );
    expect(await s.signIn('paul@example.com', 'secret', totp: ' 123456 '), isA<SignedIn>());
    expect((jsonDecode(requests.last.body) as Map)['totp'], '123456');
    expect(s.isSignedIn, isTrue);
    expect(s.user?.getStringValue('email'), 'paul@example.com');

    // The session survives a restart, and signing out forgets it.
    final again = newSession();
    handler = (_) => _json(200, {'token': _token, 'record': _user});
    await again.restore();
    expect(again.isSignedIn, isTrue);
    await again.signOut();
    final third = newSession();
    await third.restore();
    expect(third.isSignedIn, isFalse);
  });

  test('email code (PocketBase MFA)', () async {
    handler = (req) {
      if (req.url.path.endsWith('/auth-with-password')) {
        return _json(401, {'status': 401, 'mfaId': 'mfa1', 'message': 'MFA required'});
      }
      if (req.url.path.endsWith('/request-otp')) return _json(200, {'otpId': 'otp1'});
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      if (body['otpId'] == 'otp1' && body['password'] == '42' && body['mfaId'] == 'mfa1') {
        return _json(200, {'token': _token, 'record': _user});
      }
      return _json(400, {'status': 400});
    };
    final s = newSession();
    await s.useServer(Uri.parse('https://cloud.example.com'));
    final step = await s.signIn('paul@example.com', 'secret');
    expect(step, isA<EmailCodeSent>());
    expect(await s.verifyEmailCode(step as EmailCodeSent, '42'), isA<SignedIn>());
    expect(s.isSignedIn, isTrue);
  });

  test('a revoked token signs out on restore', () async {
    handler = (_) => _json(200, {'token': _token, 'record': _user});
    final s = newSession();
    await s.useServer(Uri.parse('https://cloud.example.com'));
    await s.signIn('paul@example.com', 'secret');
    handler = (_) => _json(401, {'status': 401});
    final again = newSession();
    await again.restore();
    expect(again.isSignedIn, isFalse);
  });

  test('coming back to the app renews a stale token, and signs out if it was revoked', () async {
    handler = (_) => _json(200, {'token': _token, 'record': _user});
    final s = newSession();
    await s.useServer(Uri.parse('https://cloud.example.com'));
    await s.signIn('paul@example.com', 'secret');
    requests.clear();

    await s.refreshIfStale();
    await s.refreshIfStale(); // fresh: not asked again
    expect(requests.where((r) => r.url.path.endsWith('/auth-refresh')), hasLength(1));

    handler = (_) => _json(401, {'status': 401});
    await s.refreshIfStale(maxAge: Duration.zero);
    expect(s.isSignedIn, isFalse);
  });

  test('offline: the session is kept', () async {
    handler = (_) => _json(200, {'token': _token, 'record': _user});
    final s = newSession();
    await s.useServer(Uri.parse('https://cloud.example.com'));
    await s.signIn('paul@example.com', 'secret');
    handler = (_) => throw const SocketExceptionLike();
    await s.refreshIfStale(maxAge: Duration.zero);
    expect(s.isSignedIn, isTrue);
  });

  test('a slow server does not hold the start; its late refusal still signs out', () async {
    handler = (_) => _json(200, {'token': _token, 'record': _user});
    final s = newSession();
    await s.useServer(Uri.parse('https://cloud.example.com'));
    await s.signIn('paul@example.com', 'secret');

    final answer = Completer<http.Response>();
    final slow = Session(
      store: SecureStore(const FlutterSecureStorage()),
      httpClientFactory: () => MockClient((_) => answer.future),
    );
    await slow.restore(wait: const Duration(milliseconds: 50));
    expect(slow.isSignedIn, isTrue);

    answer.complete(_json(401, {'status': 401}));
    await pumpEventQueue();
    expect(slow.isSignedIn, isFalse);
  });

  group('late answers of an older session', () {
    late Completer<http.Response> refresh;
    late Session slow;

    // Signed in on the server, then the app restarts and the refresh answers only when told.
    Future<void> restoreSlowly() async {
      handler = (_) => _json(200, {'token': _token, 'record': _user});
      final s = newSession();
      await s.useServer(Uri.parse('https://cloud.example.com'));
      await s.signIn('paul@example.com', 'secret');
      refresh = Completer<http.Response>();
      slow = Session(
        store: SecureStore(const FlutterSecureStorage()),
        httpClientFactory: () => MockClient(
          (req) =>
              req.url.path.endsWith('/auth-refresh') ? refresh.future : Future.value(handler(req)),
        ),
      );
      await slow.restore(wait: const Duration(milliseconds: 20));
      expect(slow.isSignedIn, isTrue);
    }

    test('a refresh that succeeds after sign-out does not sign in again', () async {
      await restoreSlowly();
      await slow.signOut();
      refresh.complete(_json(200, {'token': _token, 'record': _user}));
      await pumpEventQueue();
      expect(slow.isSignedIn, isFalse);
      expect(await slow.store.readAuth(), isNull);
    });

    test('a late refusal does not sign out the account signed in since', () async {
      await restoreSlowly();
      await slow.signOut();
      expect(await slow.signIn('paul@example.com', 'secret'), isA<SignedIn>());
      refresh.complete(_json(401, {'status': 401}));
      await pumpEventQueue();
      expect(slow.isSignedIn, isTrue);
    });

    test("an old server's answer is not saved for the new server", () async {
      await restoreSlowly();
      await slow.useServer(Uri.parse('https://other.example.com'));
      refresh.complete(_json(200, {'token': _token, 'record': _user}));
      await pumpEventQueue();
      expect(slow.isSignedIn, isFalse);
      expect(await slow.store.readAuth(), isNull);
      expect(await slow.store.readServerUrl(), Uri.parse('https://other.example.com'));
    });
  });

  test('a server that never answers fails as a network error', () async {
    final s = Session(
      store: SecureStore(const FlutterSecureStorage()),
      httpClientFactory: () => MockClient((_) => Completer<http.Response>().future),
      responseTimeout: const Duration(milliseconds: 50),
    );
    await s.useServer(Uri.parse('https://cloud.example.com'));
    expect(
      await s.signIn('paul@example.com', 'secret'),
      isA<SignInFailed>().having((f) => f.failure, 'failure', SignInFailure.network),
    );
  });
}

class SocketExceptionLike implements Exception {
  const SocketExceptionLike();
}
