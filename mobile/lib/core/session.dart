import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:pocketbase/pocketbase.dart';

import 'secure_store.dart';

/// Outcome of a sign-in step (mirrors the web login, see web/src/routes/(public)/login).
sealed class SignInResult {
  const SignInResult();
}

final class SignedIn extends SignInResult {
  const SignedIn();
}

/// The account uses an authenticator app (Alcove TOTP): ask for its code, or a recovery code.
final class TotpRequired extends SignInResult {
  const TotpRequired({this.invalid = false});
  final bool invalid;
}

/// The account uses email codes (PocketBase MFA): a code was sent.
final class EmailCodeSent extends SignInResult {
  const EmailCodeSent({required this.mfaId, required this.otpId});
  final String mfaId;
  final String otpId;
}

enum SignInFailure { badCredentials, tooManyAttempts, network, unexpected }

final class SignInFailed extends SignInResult {
  const SignInFailed(this.failure);
  final SignInFailure failure;
}

/// The signed-in state of the app: one server, one account. Tokens live in [SecureStore] only.
class Session extends ChangeNotifier {
  Session({
    required this.store,
    this.httpClientFactory,
    this.responseTimeout = const Duration(seconds: 30),
  });

  final SecureStore store;

  /// Injected in tests.
  final http.Client Function()? httpClientFactory;

  /// How long an API call waits for the server to start answering (uploads and app downloads use
  /// their own clients). Realtime streams answer their headers at once, so they are not cut.
  final Duration responseTimeout;

  /// Bumped by every sign-in, sign-out and server change: an answer that arrives after one of them
  /// belongs to an older session and is ignored.
  int _epoch = 0;

  /// Identifies the current PocketBase client: late auth writes of a replaced one never reach the store.
  Object _owner = Object();

  PocketBase? _pb;
  Uri? _server;
  StreamSubscription<AuthStoreEvent>? _authChanges;

  PocketBase get pb => _pb ?? (throw StateError('no server selected'));
  Uri? get server => _server;
  bool get hasServer => _pb != null;
  bool get isSignedIn => _pb?.authStore.isValid ?? false;
  RecordModel? get user => _pb?.authStore.record;

  /// Loads the saved server and account, refreshing the token when the server answers. A slow or
  /// unreachable server does not hold the app on its splash screen: after [wait] the saved session is
  /// used and the refresh goes on (a revoked token still signs out when the answer comes).
  Future<void> restore({Duration wait = const Duration(seconds: 3)}) async {
    final url = await store.readServerUrl();
    if (url == null) return;
    await _connect(url, initialAuth: await store.readAuth());
    if (!isSignedIn) return;
    await _refresh().timeout(wait, onTimeout: () {});
  }

  /// One connection pool per server (keep-alive saves a TLS handshake per request, about 75 ms on a
  /// fast link), and an unreachable server fails within seconds instead of the OS's minutes.
  static http.Client _defaultClient() =>
      IOClient(HttpClient()..connectionTimeout = const Duration(seconds: 15));

  DateTime? _refreshedAt;

  /// Renews the token when the app comes back after a while (tokens expire after some days), so a
  /// phone that keeps the app open never ends up with failing screens instead of the sign-in page.
  Future<void> refreshIfStale({Duration maxAge = const Duration(hours: 6)}) async {
    if (!isSignedIn) return;
    final at = _refreshedAt;
    if (at != null && DateTime.now().difference(at) < maxAge) return;
    await _refresh();
  }

  Future<void> _refresh() async {
    final epoch = _epoch;
    final client = pb;
    try {
      // Sent by hand (not authRefresh) so that a late answer cannot save its token after a sign-out,
      // another sign-in or a server change.
      final res = await client.send<Map<String, dynamic>>(
        '/api/collections/users/auth-refresh',
        method: 'POST',
      );
      if (epoch != _epoch) return;
      client.authStore.save(
        res['token'] as String,
        RecordModel.fromJson(res['record'] as Map<String, dynamic>),
      );
      _refreshedAt = DateTime.now();
    } on ClientException catch (e) {
      if (epoch != _epoch) return;
      // Revoked or expired token: sign in again. Offline: keep the saved session.
      if (e.statusCode == 401 || e.statusCode == 403) await signOut();
    }
  }

  /// Selects a server (after the connect screen checked it).
  Future<void> useServer(Uri url) async {
    await store.writeServerUrl(url);
    if (_server != url) {
      await store.clearAuth();
      await _connect(url);
    }
    notifyListeners();
  }

  Future<void> _connect(Uri url, {String? initialAuth}) async {
    _epoch++;
    await _authChanges?.cancel();
    _pb?.close();
    _server = url;
    final owner = _owner = Object();
    final factory = httpClientFactory ?? _defaultClient;
    _pb = PocketBase(
      url.toString(),
      authStore: AsyncAuthStore(
        save: (data) async {
          if (identical(_owner, owner)) await store.writeAuth(data);
        },
        clear: () async {
          if (identical(_owner, owner)) await store.clearAuth();
        },
        initial: initialAuth,
      ),
      reuseHTTPClient: true,
      httpClientFactory: () => TimeoutClient(factory(), responseTimeout),
    );
    _authChanges = _pb!.authStore.onChange.listen((_) => notifyListeners());
  }

  /// Email and password, plus the authenticator code once the server asked for it.
  Future<SignInResult> signIn(String email, String password, {String? totp}) async {
    _epoch++;
    try {
      await pb
          .collection('users')
          .authWithPassword(
            email.trim(),
            password,
            body: totp == null ? const {} : {'totp': totp.trim()},
          );
      return const SignedIn();
    } on ClientException catch (e) {
      final data = e.response['data'];
      if (e.statusCode == 401 && data is Map && data['totpRequired'] == true) {
        return TotpRequired(invalid: data['invalid'] == true);
      }
      final mfaId = e.response['mfaId'];
      if (e.statusCode == 401 && mfaId is String && mfaId.isNotEmpty) {
        try {
          final otp = await pb.collection('users').requestOTP(email.trim());
          return EmailCodeSent(mfaId: mfaId, otpId: otp.otpId);
        } on ClientException catch (otpError) {
          return SignInFailed(_failure(otpError));
        }
      }
      return SignInFailed(_failure(e));
    }
  }

  /// The code received by email (second factor).
  Future<SignInResult> verifyEmailCode(EmailCodeSent step, String code) async {
    _epoch++;
    try {
      await pb
          .collection('users')
          .authWithOTP(step.otpId, code.trim(), body: {'mfaId': step.mfaId});
      return const SignedIn();
    } on ClientException catch (e) {
      return SignInFailed(_failure(e));
    }
  }

  Future<void> signOut() async {
    _epoch++;
    _pb?.authStore.clear();
    await store.clearAuth();
    notifyListeners();
  }

  static SignInFailure _failure(ClientException e) => switch (e.statusCode) {
    0 => SignInFailure.network,
    400 || 401 || 403 => SignInFailure.badCredentials,
    429 => SignInFailure.tooManyAttempts,
    _ => SignInFailure.unexpected,
  };

  /// A short-lived token for file URLs (thumbnails, downloads), reused for a while.
  Future<String> fileToken() async {
    final cached = _fileToken;
    if (cached != null && DateTime.now().difference(cached.$2) < const Duration(seconds: 90)) {
      return cached.$1;
    }
    final token = await pb.files.getToken();
    _fileToken = (token, DateTime.now());
    return token;
  }

  (String, DateTime)? _fileToken;

  @override
  void dispose() {
    unawaited(_authChanges?.cancel());
    _pb?.close();
    super.dispose();
  }
}

/// Fails a request whose answer does not start within [timeout] (a server that accepts the connection
/// but never answers), instead of a spinner forever. The body is read without a limit.
class TimeoutClient extends http.BaseClient {
  TimeoutClient(this._inner, this.timeout);

  final http.Client _inner;
  final Duration timeout;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request).timeout(timeout);

  @override
  void close() => _inner.close();
}
