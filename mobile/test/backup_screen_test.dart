import 'dart:convert';
import 'dart:io';

import 'package:alcove/core/secure_store.dart';
import 'package:alcove/core/session.dart';
import 'package:alcove/features/backup/backup_controller.dart';
import 'package:alcove/features/backup/backup_screen.dart';
import 'package:alcove/features/backup/backup_state.dart';
import 'package:alcove/features/backup/library.dart';
import 'package:alcove/l10n/gen/app_localizations.dart';
import 'package:alcove/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocketbase/pocketbase.dart';

class EmptyLibrary implements PhotoLibrary {
  bool access = true;
  int asked = 0;
  @override
  Future<bool> requestAccess() async {
    asked++;
    return access;
  }

  @override
  Future<List<LibraryAsset>> assets({required bool videos}) async => [];
}

http.Response _json(Object body) =>
    http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});

void main() {
  testWidgets('enable backup, run it, see the status', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('backupui');
    addTearDown(() => dir.deleteSync(recursive: true));
    final client = MockClient((req) async {
      if (req.method == 'GET') {
        return _json({'page': 1, 'perPage': 1, 'totalItems': 0, 'totalPages': 0, 'items': []});
      }
      return _json({'id': 'folder1', 'collectionId': 'nodes', 'name': 'Phone backup'});
    });
    final session = Session(
      store: SecureStore(const FlutterSecureStorage()),
      httpClientFactory: () => client,
    );
    await tester.runAsync(() async {
      await session.useServer(Uri.parse('https://cloud.example.com'));
      session.pb.authStore.save(
        '${base64Url.encode(utf8.encode('{}'))}.${base64Url.encode(utf8.encode('{"exp":4102444800}'))}.s',
        RecordModel.fromJson({'id': 'u1', 'collectionName': 'users'}),
      );
    });
    final library = EmptyLibrary();
    final controller = BackupController(
      session: session,
      store: BackupStore(File('${dir.path}/backup.json')),
      library: library,
      wifiCheck: () async => true,
      httpClient: () => client,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BackupScreen(controller: controller),
      ),
    );
    expect(find.text('Photo backup'), findsOneWidget);
    expect(find.text('Include videos'), findsOneWidget);
    expect(find.text('Back up now'), findsNothing); // only once enabled

    await tester.runAsync(() async {
      await tester.tap(find.text("Back up this phone's photos"));
      await tester.pump();
      for (var i = 0; i < 200 && (controller.running || controller.lastReport == null); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('Up to date · 0 items backed up'), findsOneWidget);
    expect(find.text('Saved in “Phone backup”'), findsOneWidget);
    expect(find.text('Back up now'), findsOneWidget);
    expect(controller.state.folderId, 'folder1');
  });

  testWidgets('without access to the photos, backup stays off and says why', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('backupui2');
    addTearDown(() => dir.deleteSync(recursive: true));
    final session = Session(store: SecureStore(const FlutterSecureStorage()));
    final library = EmptyLibrary()..access = false;
    final controller = BackupController(
      session: session,
      store: BackupStore(File('${dir.path}/backup.json')),
      library: library,
      wifiCheck: () async => true,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BackupScreen(controller: controller),
      ),
    );
    await tester.tap(find.text("Back up this phone's photos"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));
    expect(library.asked, 1);
    expect(find.textContaining('Allow access to your photos'), findsOneWidget);
    expect(controller.state.enabled, isFalse);
  });
}
