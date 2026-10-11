/// Why a user-entered server address was rejected.
enum ServerUrlError { empty, invalid, httpsRequired }

sealed class ServerUrlResult {
  const ServerUrlResult();
}

final class ValidServerUrl extends ServerUrlResult {
  const ValidServerUrl(this.uri);
  final Uri uri;
}

final class InvalidServerUrl extends ServerUrlResult {
  const InvalidServerUrl(this.error);
  final ServerUrlError error;
}

/// Normalizes what the user typed into a base URL.
///
/// - Missing scheme defaults to https.
/// - http:// is rejected unless [allowInsecure] (debug builds only, for local dev).
/// - Query, fragment and credentials are rejected; trailing slashes are dropped.
ServerUrlResult parseServerUrl(String input, {bool allowInsecure = false}) {
  final text = input.trim();
  if (text.isEmpty) return const InvalidServerUrl(ServerUrlError.empty);

  final withScheme = text.contains('://') ? text : 'https://$text';
  final uri = Uri.tryParse(withScheme);
  if (uri == null ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      uri.host.contains(' ')) {
    return const InvalidServerUrl(ServerUrlError.invalid);
  }
  if (uri.scheme == 'http' && !allowInsecure) {
    return const InvalidServerUrl(ServerUrlError.httpsRequired);
  }
  if (uri.scheme != 'https' && uri.scheme != 'http') {
    return const InvalidServerUrl(ServerUrlError.invalid);
  }
  final path = uri.path.replaceAll(RegExp(r'/+$'), '');
  return ValidServerUrl(
    Uri(scheme: uri.scheme, host: uri.host, port: uri.hasPort ? uri.port : null, path: path),
  );
}
