import 'dart:convert';
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

import 'package:alcove/core/file_cache.dart';
import 'package:alcove/core/native_files.dart';
import 'package:alcove/core/previews.dart';
import 'package:alcove/core/share_inbox.dart';
import 'package:alcove/features/share/share_screen.dart';
import 'package:alcove/features/viewer/file_viewer.dart';
import 'package:flutter/services.dart';

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

/// PdfRenderer stand-in: three A4 pages, each the scanned test picture.
class _FakeNative extends NativeFiles {
  @override
  Future<PdfInfo> pdfOpen(String path) async =>
      (id: 1, pages: List.filled(3, const Size(595, 842)));
  @override
  Future<Uint8List> pdfRender(int id, int page, int width) async => scanPicture;
  @override
  Future<void> pdfClose(int id) async {}
}

/// A file already in the viewer cache, so the viewer shows it at once.
(RecordModel, FileCache) _cached(String id, String name, String mime, List<int> bytes) {
  final dir = Directory.systemTemp.createTempSync('viewer');
  final node = RecordModel.fromJson({
    'id': id,
    'collectionId': 'nodes',
    'name': name,
    'kind': 'file',
    'mime': mime,
    'size': bytes.length,
    'updated': '2026-10-12 10:00:00.000Z',
  });
  final f = File('${dir.path}/${cacheName(id, node.getStringValue('updated'), name)}')
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes);
  assert(f.existsSync());
  return (node, FileCache(root: () async => dir));
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

    // Each destination of the floating bar (and Albums, Account) as the owner sees it.
    for (final (tab, taps) in [
      ('photos', <Key>[]),
      ('albums', [const Key('photosAlbums')]),
      ('files', [const Key('tabFiles')]),
      ('documents', [const Key('tabDocuments')]),
      ('notes', [const Key('tabNotes')]),
      ('calendar', [const Key('tabCalendar')]),
      ('account', [const Key('accountButton')]),
    ]) {
      testWidgets('$tab $suffix', (tester) async {
        await pump(tester, home);
        await tester.pump();
        for (final k in taps) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
          await tester.pump();
          await tester.tap(find.byKey(k));
          await tester.pump(const Duration(milliseconds: 400));
        }
        await shoot(tester, '$tab-$suffix');
        // Realtime reconnection timers of Notes and Calendar end with the tree.
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(minutes: 5));
      }, skip: skipShots != false);
    }

    testWidgets('photos-scrolled $suffix', (tester) async {
      await pump(tester, home);
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -500));
      await shoot(tester, 'photos-scrolled-$suffix');
    }, skip: skipShots != false);

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
      await tester.longPress(find.text('Contrat de location.pdf').last);
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

    Future<void> viewer(
      WidgetTester tester,
      String shot,
      String name,
      String mime,
      List<int> bytes,
    ) async {
      final (node, cache) = _cached('f$shot', name, mime, bytes);
      await pump(
        tester,
        (s) => FileViewerScreen(
          session: s,
          node: node,
          kind: previewKind(mime, name),
          cache: cache,
          native: _FakeNative(),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await shoot(tester, '$shot-$suffix');
    }

    testWidgets('pdf $suffix', (tester) async {
      await viewer(tester, 'pdf', 'Contrat de location.pdf', 'application/pdf', scanPicture);
    }, skip: skipShots != false);

    testWidgets('text $suffix', (tester) async {
      await viewer(
        tester,
        'text',
        'Notes de réunion.md',
        'text/markdown',
        utf8.encode(
          '# Réunion du 13 octobre\n\nPrésents : Camille, Léa, Paul.\n\n'
          '## Budget 2027\n\nLe budget est voté à l’unanimité. Les travaux de la cage d’escalier '
          'commenceront au printemps, après comparaison de trois devis.\n\n'
          '## Questions diverses\n\n- Local vélos : une clé de plus.\n- Prochaine réunion en janvier.\n',
        ),
      );
    }, skip: skipShots != false);

    testWidgets('code $suffix', (tester) async {
      await viewer(
        tester,
        'code',
        'budget.json',
        'application/json',
        utf8.encode(
          '{"year":2027,"total":48200,"lines":[{"label":"Ravalement","amount":31000},'
          '{"label":"Ascenseur","amount":9800},{"label":"Espaces verts","amount":2400},'
          '{"label":"Assurance","amount":5000}],"approved":true}',
        ),
      );
    }, skip: skipShots != false);

    testWidgets('nopreview $suffix', (tester) async {
      await viewer(tester, 'nopreview', 'Archives 2024.zip', 'application/zip', [1, 2, 3]);
    }, skip: skipShots != false);

    testWidgets('share $suffix', (tester) async {
      await pump(
        tester,
        (s) => ShareScreen(
          session: s,
          files: const [
            SharedFile(
              path: '/x/1',
              name: 'Facture EDF octobre.pdf',
              mime: 'application/pdf',
              size: 182000,
            ),
            SharedFile(
              path: '/x/2',
              name: 'IMG_20261014_1830.jpg',
              mime: 'image/jpeg',
              size: 3400000,
            ),
          ],
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await shoot(tester, 'share-$suffix');
    }, skip: skipShots != false);

    testWidgets('sort $suffix', (tester) async {
      await pump(tester, (s) => FilesScreen(session: s, uploads: UploadQueue(s)));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await tester.pump();
      await tester.tap(find.byKey(const Key('sortButton')));
      await tester.pump(const Duration(milliseconds: 400));
      await shoot(tester, 'sort-$suffix');
    }, skip: skipShots != false);

    testWidgets('pdf-jump $suffix', (tester) async {
      final (node, cache) = _cached(
        'fj',
        'Contrat de location.pdf',
        'application/pdf',
        scanPicture,
      );
      await pump(
        tester,
        (s) => FileViewerScreen(
          session: s,
          node: node,
          kind: PreviewKind.pdf,
          cache: cache,
          native: _FakeNative(),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.byKey(const Key('pageChip')));
      await tester.pump(const Duration(milliseconds: 400));
      await shoot(tester, 'pdf-jump-$suffix');
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
