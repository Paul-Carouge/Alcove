import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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
  Session({required this.store, this.httpClientFactory});

  final SecureStore store;

  /// Injected in tests.
  final http.Client Function()? httpClientFactory;

  PocketBase? _pb;
  Uri? _server;
  StreamSubscription<AuthStoreEvent>? _authChanges;

  PocketBase get pb => _pb ?? (throw StateError('no server selected'));
  Uri? get server => _server;
  bool get hasServer => _pb != null;
  bool get isSignedIn => _pb?.authStore.isValid ?? false;
  RecordModel? get user => _pb?.authStore.record;

  /// Loads the saved server and account, refreshing the token when the server answers.
  Future<void> restore() async {
    final url = await store.readServerUrl();
    if (url == null) return;
    await _connect(url, initialAuth: await store.readAuth());
    if (!isSignedIn) return;
    try {
      await pb.collection('users').authRefresh();
    } on ClientException catch (e) {
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
    await _authChanges?.cancel();
    _server = url;
    _pb = PocketBase(
      url.toString(),
      authStore: AsyncAuthStore(
        save: store.writeAuth,
        clear: store.clearAuth,
        initial: initialAuth,
      ),
      httpClientFactory: httpClientFactory,
    );
    _authChanges = _pb!.authStore.onChange.listen((_) => notifyListeners());
  }

  /// Email and password, plus the authenticator code once the server asked for it.
  Future<SignInResult> signIn(String email, String password, {String? totp}) async {
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
    super.dispose();
  }
}
