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

/// Whether [host] is on a private network: home network addresses, `.local`/`.lan` names, single-label
/// names (`nas`) and Tailscale addresses (100.64.0.0/10). Servers installed in "local network" mode serve
/// plain http there.
bool isPrivateHost(String host) {
  final h = host.toLowerCase();
  if (h == 'localhost' || !h.contains('.') && !h.contains(':')) return true;
  for (final suffix in ['.local', '.lan', '.home', '.home.arpa', '.internal', '.localdomain']) {
    if (h.endsWith(suffix)) return true;
  }
  final v4 = RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$').firstMatch(h);
  if (v4 != null) {
    final a = int.parse(v4[1]!), b = int.parse(v4[2]!);
    return a == 10 ||
        a == 127 ||
        (a == 172 && b >= 16 && b <= 31) ||
        (a == 192 && b == 168) ||
        (a == 169 && b == 254) ||
        (a == 100 && b >= 64 && b <= 127);
  }
  final v6 = h.replaceAll(RegExp(r'[\[\]]'), '');
  return v6 == '::1' || v6.startsWith('fc') || v6.startsWith('fd') || v6.startsWith('fe80:');
}

/// Normalizes what the user typed into a base URL.
///
/// - Missing scheme defaults to https.
/// - http:// is accepted only for private-network hosts ([isPrivateHost]), or anywhere when
///   [allowInsecure] (debug builds, for local development).
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
  if (uri.scheme == 'http' && !allowInsecure && !isPrivateHost(uri.host)) {
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
