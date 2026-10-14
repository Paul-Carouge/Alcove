import 'dart:io';

import 'package:alcove/core/app_update.dart';
import 'package:alcove/core/drive.dart';
import 'package:alcove/core/secure_store.dart';
import 'package:alcove/core/server_checker.dart';
import 'package:alcove/core/session.dart';
import 'package:alcove/features/account/account_screen.dart';
import 'package:alcove/features/backup/backup_controller.dart';
import 'package:alcove/features/backup/backup_screen.dart';
import 'package:alcove/features/backup/backup_state.dart';
import 'package:alcove/features/backup/library.dart';
import 'package:alcove/features/connect/connect_screen.dart';
import 'package:alcove/features/files/files_screen.dart';
import 'package:alcove/features/home/home_screen.dart';
import 'package:alcove/features/login/login_screen.dart';
import 'package:alcove/features/photos/albums_screen.dart';
import 'package:alcove/features/photos/media.dart';
import 'package:alcove/features/photos/photo_viewer.dart';
import 'package:alcove/features/search/search_screen.dart';
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

    testWidgets('uploads $suffix', (tester) async {
      await pump(tester, (s) {
        final queue = UploadQueue(s);
        queue.items.addAll([
          UploadItem(
            name: 'Relevé de compte.pdf',
            parent: '',
            open: () => throw UnimplementedError(),
          )..status = UploadStatus.done,
          UploadItem(
              name: 'Scan 2026-10-13 14.32.pdf',
              parent: '',
              open: () => throw UnimplementedError(),
            )
            ..status = UploadStatus.uploading
            ..sent = 620000
            ..total = 1000000,
          UploadItem(name: 'Notes.txt', parent: '', open: () => throw UnimplementedError()),
        ]);
        return FilesScreen(session: s, uploads: queue);
      });
      await shoot(tester, 'uploads-$suffix');
    }, skip: skipShots != false);

    testWidgets('add $suffix', (tester) async {
      await pump(tester, (s) => FilesScreen(session: s, uploads: UploadQueue(s)));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      await tester.tap(find.byKey(const Key('addButton')));
      await shoot(tester, 'add-$suffix');
    }, skip: skipShots != false);

    testWidgets('album $suffix', (tester) async {
      await pump(tester, (s) => AlbumScreen(session: s, id: 'al0', name: 'Été en Provence'));
      await shoot(tester, 'album-$suffix');
    }, skip: skipShots != false);

    Future<void> openActions(WidgetTester tester) async {
      await pump(tester, (s) => FilesScreen(session: s, uploads: UploadQueue(s)));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      await tester.longPress(find.text('Contrat de location.pdf'));
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('actions $suffix', (tester) async {
      await openActions(tester);
      await shoot(tester, 'actions-$suffix');
    }, skip: skipShots != false);

    testWidgets('tags $suffix', (tester) async {
      await openActions(tester);
      await tester.tap(find.byIcon(Icons.sell_outlined));
      await tester.pump(const Duration(milliseconds: 400));
      await shoot(tester, 'tags-$suffix');
    }, skip: skipShots != false);

    testWidgets('details $suffix', (tester) async {
      await pump(
        tester,
        (s) => PhotoViewer(
          session: s,
          items: [for (final m in fakeMedia().take(3)) MediaItem(RecordModel.fromJson(m))],
          initial: 0,
          onTrashed: (_) {},
        ),
      );
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pump(const Duration(milliseconds: 400));
      await shoot(tester, 'details-$suffix');
    }, skip: skipShots != false);

    testWidgets('search $suffix', (tester) async {
      await pump(tester, (s) => SearchScreen(session: s));
      await tester.enterText(find.byType(TextField), 'facture');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await shoot(tester, 'search-$suffix');
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
