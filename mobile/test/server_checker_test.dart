import 'dart:convert';
import 'dart:io';

import 'package:alcove/core/api_compat.dart';
import 'package:alcove/core/server_checker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, Object> health({int min = 1, int max = 1}) => {
  'status': 'ok',
  'name': 'Alcove',
  'version': '0.1.0',
  'api': {'min': min, 'max': max},
  'modules': ['core'],
  'setupRequired': false,
};

ServerChecker checkerReturning(Object body, {int status = 200}) => ServerChecker(
  client: MockClient((req) async {
    expect(req.url.path, '/health');
    return http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});
  }),
);

final base = Uri.parse('https://cloud.example.com');

void main() {
  test('compatible server', () async {
    final r = await checkerReturning(health()).check(base);
    expect(r, isA<ServerCompatible>());
    expect((r as ServerCompatible).health.version, '0.1.0');
  });

  test('client too old', () async {
    final r = await checkerReturning(health(min: 2, max: 3)).check(base);
    expect((r as ServerIncompatible).compatibility, Compatibility.clientTooOld);
  });

  test('server too old', () async {
    final r = await checkerReturning(health(min: 0, max: 0)).check(base);
    expect((r as ServerIncompatible).compatibility, Compatibility.serverTooOld);
  });

  test('non-Alcove JSON is an invalid response', () async {
    final r = await checkerReturning({'hello': 'world'}).check(base);
    expect((r as ServerCheckFailed).failure, ServerFailure.invalidResponse);
  });

  test('HTTP error is an invalid response', () async {
    final r = await checkerReturning({'message': 'nope'}, status: 404).check(base);
    expect((r as ServerCheckFailed).failure, ServerFailure.invalidResponse);
  });

  test('network error is unreachable', () async {
    final checker = ServerChecker(
      client: MockClient((_) async => throw const SocketException('down')),
    );
    final r = await checker.check(base);
    expect((r as ServerCheckFailed).failure, ServerFailure.unreachable);
  });
}
