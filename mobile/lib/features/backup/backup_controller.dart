import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../core/session.dart';
import 'background.dart';
import 'backup_state.dart';
import 'library.dart';
import 'photo_backup.dart';
import 'tus_client.dart';

/// Backup settings, schedule and live progress, for the screens and the background task.
class BackupController extends ChangeNotifier {
  BackupController({
    required this.session,
    required this.store,
    PhotoLibrary? library,
    Future<bool> Function()? wifiCheck,
    http.Client Function()? httpClient,
  }) : library = library ?? DevicePhotoLibrary(),
       wifiCheck = wifiCheck ?? isOnWifi,
       httpClient = httpClient ?? http.Client.new;

  final Session session;
  final BackupStore store;
  final PhotoLibrary library;
  final Future<bool> Function() wifiCheck;
  final http.Client Function() httpClient;

  BackupState state = BackupState();
  bool running = false;
  BackupProgress? progress;
  BackupReport? lastReport;
  bool _cancel = false;

  /// One state file per server and account.
  static Future<BackupController> create(Session session) async {
    final dir = await getApplicationSupportDirectory();
    final key = '${session.server?.host ?? 'server'}-${session.user?.id ?? 'user'}';
    final c = BackupController(
      session: session,
      store: BackupStore(File('${dir.path}/backup-$key.json')),
    );
    c.state = await c.store.load();
    return c;
  }

  int get uploadedCount => state.done.length;

  Future<void> _update(void Function(BackupState s) change) async {
    change(state);
    await store.save(state);
    notifyListeners();
  }

  /// Turns backup on (asking for library access first) or off.
  Future<bool> setEnabled(bool on, {required String folderName}) async {
    if (on && !await library.requestAccess()) return false;
    await _update((s) {
      s.enabled = on;
      if (s.folderName.isEmpty) s.folderName = folderName;
    });
    await _schedule();
    if (on) unawaited(runNow());
    return true;
  }

  Future<void> setVideos(bool on) => _update((s) => s.videos = on);

  Future<void> setWifiOnly(bool on) async {
    await _update((s) => s.wifiOnly = on);
    await _schedule();
  }

  Future<void> _schedule() async {
    if (!Platform.isAndroid) return; // iOS: backups run when the app is opened (for now)
    if (state.enabled) {
      await scheduleBackgroundBackup(wifiOnly: state.wifiOnly);
    } else {
      await cancelBackgroundBackup();
    }
  }

  /// Runs a backup now (in the app), unless one is already running.
  Future<BackupReport?> runNow({Duration? budget}) async {
    if (running) return null;
    running = true;
    _cancel = false;
    progress = BackupProgress();
    notifyListeners();
    try {
      final report =
          await PhotoBackup(
            session: session,
            library: library,
            store: store,
            uploader: TusUploader(client: httpClient()),
            isOnWifi: wifiCheck,
          ).run(
            budget: budget,
            cancelled: () => _cancel,
            defaultFolderName: state.folderName.isEmpty ? 'Phone backup' : state.folderName,
            onProgress: (p) {
              progress = p;
              notifyListeners();
            },
          );
      lastReport = report;
      state = await store.load();
      return report;
    } finally {
      running = false;
      notifyListeners();
    }
  }

  void cancel() => _cancel = true;

  static Future<bool> isOnWifi() async {
    final types = await Connectivity().checkConnectivity();
    return types.contains(ConnectivityResult.wifi) || types.contains(ConnectivityResult.ethernet);
  }
}
