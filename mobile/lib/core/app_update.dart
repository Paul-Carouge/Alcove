import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'session.dart';
import 'version.dart';

/// Whether version [a] is newer than [b] (x.y.z; anything else counts as 0.0.0).
bool isNewer(String a, String b) {
  List<int> parse(String v) {
    final m = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)$').firstMatch(v.trim());
    return m == null ? [0, 0, 0] : [for (var i = 1; i <= 3; i++) int.parse(m[i]!)];
  }

  final x = parse(a), y = parse(b);
  for (var i = 0; i < 3; i++) {
    if (x[i] != y[i]) return x[i] > y[i];
  }
  return false;
}

enum UpdatePhase { idle, checking, available, downloading, readyToInstall, failed }

/// In-app updates (ADR 0024): the app follows its server's version. The server serves the APK of its
/// release; Android installs it after the user confirms, and only if it is signed with the same key.
class AppUpdater extends ChangeNotifier {
  AppUpdater({
    required this.session,
    this.currentVersion = kAppVersion,
    MethodChannel? channel,
    this.httpClient,
  }) : _channel = channel ?? const MethodChannel('alcove/update');

  final Session session;
  final String currentVersion;
  final MethodChannel _channel;
  final http.Client? httpClient;

  UpdatePhase phase = UpdatePhase.idle;
  String? latest;
  double progress = 0;
  String? _path;

  bool get supported => !kIsWeb && Platform.isAndroid;
  bool get hasUpdate => latest != null && isNewer(latest!, currentVersion);

  Future<void> check() async {
    if (!supported || phase == UpdatePhase.downloading) return;
    phase = UpdatePhase.checking;
    notifyListeners();
    try {
      final res = await session.pb.send<Map<String, dynamic>>('/api/v1/app/android');
      final version = res['version'] as String? ?? '';
      latest = res['available'] == true ? version : null;
      phase = hasUpdate ? UpdatePhase.available : UpdatePhase.idle;
    } catch (_) {
      phase = UpdatePhase.idle;
    }
    notifyListeners();
  }

  /// Downloads the update into the app's cache, then opens the system installer.
  Future<void> downloadAndInstall() async {
    if (!hasUpdate) return;
    phase = UpdatePhase.downloading;
    progress = 0;
    notifyListeners();
    final client = httpClient ?? http.Client();
    try {
      final token = await session.fileToken();
      final url = session.pb.buildURL('/api/v1/app/android.apk', {'token': token});
      final res = await client.send(http.Request('GET', url));
      if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}');
      final dir = Directory('${(await getTemporaryDirectory()).path}/updates');
      await dir.create(recursive: true);
      final file = File('${dir.path}/alcove-$latest.apk');
      final sink = file.openWrite();
      final total = res.contentLength ?? 0;
      var received = 0;
      await for (final chunk in res.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          progress = received / total;
          notifyListeners();
        }
      }
      await sink.close();
      _path = file.path;
      phase = UpdatePhase.readyToInstall;
      notifyListeners();
      await install();
    } catch (_) {
      phase = UpdatePhase.failed;
      notifyListeners();
    } finally {
      if (httpClient == null) client.close();
    }
  }

  /// Opens the installer; first sends the user to "allow installs from this app" when needed.
  Future<void> install() async {
    final path = _path;
    if (path == null) return;
    if (await _channel.invokeMethod<bool>('canInstall') != true) {
      await _channel.invokeMethod<void>('allowInstalls');
      return; // the user comes back and taps Install again
    }
    await _channel.invokeMethod<void>('install', {'path': path});
  }
}
