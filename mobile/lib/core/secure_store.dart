import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists sensitive values in the Android Keystore / iOS Keychain.
/// Auth tokens must only ever be stored through this class.
class SecureStore {
  SecureStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _serverUrlKey = 'server_url';
  static const _authKey = 'auth';

  Future<Uri?> readServerUrl() async {
    final v = await _storage.read(key: _serverUrlKey);
    return v == null ? null : Uri.tryParse(v);
  }

  Future<void> writeServerUrl(Uri url) => _storage.write(key: _serverUrlKey, value: url.toString());

  /// The PocketBase auth state (token and user record, JSON).
  Future<String?> readAuth() => _storage.read(key: _authKey);

  Future<void> writeAuth(String value) => _storage.write(key: _authKey, value: value);

  Future<void> clearAuth() => _storage.delete(key: _authKey);
}
