import 'dart:io';

import 'package:alcove/core/app_update.dart';
import 'package:alcove/core/secure_store.dart';
import 'package:alcove/core/server_checker.dart';
import 'package:alcove/core/session.dart';
import 'package:alcove/features/account/account_screen.dart';
import 'package:alcove/features/backup/backup_controller.dart';
import 'package:alcove/features/backup/backup_screen.dart';
import 'package:alcove/features/backup/backup_state.dart';
import 'package:alcove/features/backup/library.dart';
import 'package:alcove/features/connect/connect_screen.dart';
import 'package:alcove/features/home/home_screen.dart';
import 'package:alcove/features/login/login_screen.dart';
import 'package:alcove/features/photos/media.dart';
import 'package:alcove/features/photos/photo_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';

import 'fake_server.dart';
import 'harness.dart';

class _NoLibrary implements PhotoLibrary {
  @override
  Future<bool> requestAccess() async => true;
  @override
  Future<List<LibraryAsset>> assets({required bool videos}) async => [];
}

class _FakeChecker implements ServerChecker {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// An updater that pretends the server has a newer app.
class _PendingUpdate extends AppUpdater {
  _PendingUpdate(Session session) : super(session: session, currentVersion: '0.18.1') {
    latest = '0.19.0';
    phase = UpdatePhase.available;
  }
  @override
  bool get supported => true;
}

BackupController _backup(Session session) {
  final dir = Directory.systemTemp.createTempSync('shots');
  return BackupController(
      session: session,
      store: BackupStore(File('${dir.path}/b.json')),
      library: _NoLibrary(),
      wifiCheck: () async => true,
    )
    ..state = BackupState(
      enabled: true,
      folderName: 'Sauvegarde du téléphone',
      done: {for (var i = 0; i < 1284; i++) 'a$i': 'n$i'},
      lastRun: DateTime(2026, 10, 12, 9, 41),
    );
}

void main() {
  setUpAll(() async {
    if (shotsDir == null) return;
    Directory(shotsDir!).createSync(recursive: true);
    await loadFonts();
  });

  final variants = [
    ('light', Brightness.light, const Locale('fr')),
    ('dark', Brightness.dark, const Locale('fr')),
    ('en', Brightness.light, const Locale('en')),
  ];

  for (final (suffix, b, locale) in variants) {
    Future<Session> pump(
      WidgetTester tester,
      Widget Function(Session) build, {
      bool signedIn = true,
    }) async {
      await setPhoneSize(tester);
      final session = (await tester.runAsync(() => fakeSession(signedIn: signedIn)))!;
      await tester.pumpWidget(phone(build(session), brightness: b, locale: locale));
      return session;
    }

    Widget home(Session s) => HomeScreen(
      session: s,
      version: '0.19.0',
      backupFactory: (s) async => _backup(s),
    );

    for (final (i, tab) in ['photos', 'albums', 'files', 'account'].indexed) {
      testWidgets('$tab $suffix', (tester) async {
        await pump(tester, home);
        await tester.pump();
        if (i > 0) {
          await tester.tap(find.byType(NavigationDestination).at(i));
        }
        await shoot(tester, '$tab-$suffix');
      }, skip: skipShots != false);
    }

    testWidgets('update $suffix', (tester) async {
      await pump(
        tester,
        (s) => Scaffold(
          body: AccountScreen(
            session: s,
            version: '0.18.1',
            backup: _backup(s),
            updater: _PendingUpdate(s),
          ),
        ),
      );
      await shoot(tester, 'update-$suffix');
    }, skip: skipShots != false);

    testWidgets('backup $suffix', (tester) async {
      await pump(tester, (s) => BackupScreen(controller: _backup(s)));
      await shoot(tester, 'backup-$suffix');
    }, skip: skipShots != false);

    testWidgets('viewer $suffix', (tester) async {
      await pump(
        tester,
        (s) => PhotoViewer(
          session: s,
          items: [for (final m in fakeMedia().take(3)) MediaItem(RecordModel.fromJson(m))],
          initial: 0,
          onTrashed: (_) {},
        ),
      );
      await shoot(tester, 'viewer-$suffix');
    }, skip: skipShots != false);

    testWidgets('login $suffix', (tester) async {
      await pump(
        tester,
        (s) => LoginScreen(session: s, onChangeServer: () {}),
        signedIn: false,
      );
      await shoot(tester, 'login-$suffix');
    }, skip: skipShots != false);

    testWidgets('connect $suffix', (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      await pump(
        tester,
        (_) => ConnectScreen(
          checker: _FakeChecker(),
          store: SecureStore(const FlutterSecureStorage()),
        ),
        signedIn: false,
      );
      await shoot(tester, 'connect-$suffix');
    }, skip: skipShots != false);
  }
}
