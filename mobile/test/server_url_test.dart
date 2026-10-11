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

  test('rejects malformed input', () {
    expect(err(''), ServerUrlError.empty);
    expect(err('https://'), ServerUrlError.invalid);
    expect(err('https://user:pw@host'), ServerUrlError.invalid);
    expect(err('https://host/?q=1'), ServerUrlError.invalid);
    expect(err('ftp://host'), ServerUrlError.invalid);
  });
}
