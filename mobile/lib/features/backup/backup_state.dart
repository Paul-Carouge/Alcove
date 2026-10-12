import 'dart:convert';
import 'dart:io';

/// Backup settings and progress, kept in a JSON file in the app's private storage.
class BackupState {
  BackupState({
    this.enabled = false,
    this.videos = true,
    this.wifiOnly = true,
    this.folderId = '',
    this.folderName = '',
    Map<String, String>? done,
    Map<String, String>? pending,
    this.lastRun,
    this.lastError = '',
  }) : done = done ?? {},
       pending = pending ?? {};

  bool enabled;
  bool videos;
  bool wifiOnly;

  /// The drive folder receiving the photos.
  String folderId;
  String folderName;

  /// Library asset id → drive node id ("known" when the server already had the file).
  final Map<String, String> done;

  /// Library asset id → tus upload URL, to resume interrupted uploads.
  final Map<String, String> pending;
  DateTime? lastRun;
  String lastError;

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'videos': videos,
    'wifiOnly': wifiOnly,
    'folderId': folderId,
    'folderName': folderName,
    'done': done,
    'pending': pending,
    'lastRun': lastRun?.toIso8601String(),
    'lastError': lastError,
  };

  factory BackupState.fromJson(Map<String, dynamic> j) => BackupState(
    enabled: j['enabled'] == true,
    videos: j['videos'] != false,
    wifiOnly: j['wifiOnly'] != false,
    folderId: j['folderId'] as String? ?? '',
    folderName: j['folderName'] as String? ?? '',
    done: (j['done'] as Map?)?.cast<String, String>(),
    pending: (j['pending'] as Map?)?.cast<String, String>(),
    lastRun: DateTime.tryParse(j['lastRun'] as String? ?? ''),
    lastError: j['lastError'] as String? ?? '',
  );
}

/// Reads and writes [BackupState]; one file per server account.
class BackupStore {
  BackupStore(this.file);

  final File file;

  Future<BackupState> load() async {
    try {
      return BackupState.fromJson(jsonDecode(await file.readAsString()) as Map<String, dynamic>);
    } catch (_) {
      return BackupState();
    }
  }

  Future<void> _queue = Future.value();

  /// Written atomically (a crash mid-write must not lose the list of uploaded photos) and one at a
  /// time, with the state as it was when [save] was called.
  Future<void> save(BackupState state) {
    final json = jsonEncode(state.toJson());
    return _queue = _queue.then((_) async {
      await file.parent.create(recursive: true);
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(json, flush: true);
      await tmp.rename(file.path);
    });
  }
}
