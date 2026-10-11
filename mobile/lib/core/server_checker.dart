import 'dart:async';
import 'dart:io';

import 'package:alcove_api/api.dart';
import 'package:http/http.dart' as http;

import 'api_compat.dart';

sealed class ServerCheckResult {
  const ServerCheckResult();
}

final class ServerCompatible extends ServerCheckResult {
  const ServerCompatible(this.health);
  final Health health;
}

final class ServerIncompatible extends ServerCheckResult {
  const ServerIncompatible(this.health, this.compatibility);
  final Health health;
  final Compatibility compatibility;
}

enum ServerFailure { unreachable, tls, invalidResponse }

final class ServerCheckFailed extends ServerCheckResult {
  const ServerCheckFailed(this.failure);
  final ServerFailure failure;
}

/// Calls GET /health on a server and checks API compatibility.
class ServerChecker {
  ServerChecker({this.client, this.timeout = const Duration(seconds: 10)});

  /// Injected in tests; the generated ApiClient creates its own otherwise.
  final http.Client? client;
  final Duration timeout;

  Future<ServerCheckResult> check(Uri baseUrl) async {
    final apiClient = ApiClient(basePath: baseUrl.toString());
    final injected = client;
    if (injected != null) apiClient.client = injected;

    final Health? health;
    try {
      health = await SystemApi(apiClient).getHealth().timeout(timeout);
    } on HandshakeException {
      return const ServerCheckFailed(ServerFailure.tls);
    } on ApiException catch (e) {
      // The generated client wraps transport errors with code 400 and an inner exception.
      if (e.innerException is HandshakeException) {
        return const ServerCheckFailed(ServerFailure.tls);
      }
      if (e.innerException is SocketException || e.innerException is http.ClientException) {
        return const ServerCheckFailed(ServerFailure.unreachable);
      }
      return const ServerCheckFailed(ServerFailure.invalidResponse);
    } on TimeoutException {
      return const ServerCheckFailed(ServerFailure.unreachable);
    } on SocketException {
      return const ServerCheckFailed(ServerFailure.unreachable);
    } on http.ClientException {
      return const ServerCheckFailed(ServerFailure.unreachable);
    } on FormatException {
      return const ServerCheckFailed(ServerFailure.invalidResponse);
    } catch (_) {
      // Malformed JSON surfaces as TypeError/ArgumentError from generated models.
      return const ServerCheckFailed(ServerFailure.invalidResponse);
    }
    if (health == null) return const ServerCheckFailed(ServerFailure.invalidResponse);

    final compat = checkCompatibility((min: health.api.min, max: health.api.max));
    return compat == Compatibility.ok
        ? ServerCompatible(health)
        : ServerIncompatible(health, compat);
  }
}
