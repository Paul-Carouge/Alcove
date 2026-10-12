import 'package:alcove/core/server_url.dart';
import 'package:flutter_test/flutter_test.dart';

Uri? ok(String input, {bool allowInsecure = false}) =>
    switch (parseServerUrl(input, allowInsecure: allowInsecure)) {
      ValidServerUrl(:final uri) => uri,
      InvalidServerUrl() => null,
    };

ServerUrlError? err(String input) => switch (parseServerUrl(input)) {
  InvalidServerUrl(:final error) => error,
  ValidServerUrl() => null,
};

void main() {
  test('defaults to https and strips trailing slashes', () {
    expect(ok(' cloud.example.com/ ').toString(), 'https://cloud.example.com');
    expect(ok('https://h.example:8443/alcove//').toString(), 'https://h.example:8443/alcove');
  });

  test('rejects http unless explicitly allowed', () {
    expect(err('http://cloud.example.com'), ServerUrlError.httpsRequired);
    expect(ok('http://10.0.2.2:8090', allowInsecure: true).toString(), 'http://10.0.2.2:8090');
  });

  test('accepts http on private networks only', () {
    for (final host in [
      '192.168.1.20:8090',
      '10.0.0.5',
      '172.20.1.1',
      '100.101.102.103', // Tailscale
      'nas.local',
      'nas',
      'server.lan',
      '[fd12::1]:8090',
    ]) {
      expect(ok('http://$host'), isNotNull, reason: host);
    }
    for (final host in [
      'cloud.example.com',
      '8.8.8.8',
      '172.32.0.1',
      '100.128.0.1',
      'local.example.com',
    ]) {
      expect(err('http://$host'), ServerUrlError.httpsRequired, reason: host);
    }
    expect(isPrivateHost('cloud.example.com'), isFalse);
  });

  test('rejects malformed input', () {
    expect(err(''), ServerUrlError.empty);
    expect(err('https://'), ServerUrlError.invalid);
    expect(err('https://user:pw@host'), ServerUrlError.invalid);
    expect(err('https://host/?q=1'), ServerUrlError.invalid);
    expect(err('ftp://host'), ServerUrlError.invalid);
  });
}
