import 'dart:io';

import 'package:alcove/core/secure_store.dart';
import 'package:alcove/core/session.dart';
import 'package:alcove/features/backup/backup_controller.dart';
import 'package:alcove/features/backup/backup_state.dart';
import 'package:alcove/features/backup/library.dart';
import 'package:alcove/features/home/home_screen.dart';
import 'package:alcove/l10n/gen/app_localizations.dart';
import 'package:alcove/theme/theme.dart';
import 'package:alcove/ui/shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:pocketbase/pocketbase.dart';

import 'screenshots/fake_server.dart';

class _NoLibrary implements PhotoLibrary {
  @override
  Future<bool> requestAccess() async => true;
  @override
  Future<List<LibraryAsset>> assets({required bool videos}) async => [];
}

/// The fake server of the screenshots, remembering which paths were asked.
Future<(Session, List<String>)> _session() async {
  FlutterSecureStorage.setMockInitialValues({});
  final asked = <String>[];
  final client = MockClient((r) async {
    asked.add(r.url.path);
    return fakeAlcove(r);
  });
  final s = Session(
    store: SecureStore(const FlutterSecureStorage()),
    httpClientFactory: () => client,
  );
  await s.useServer(Uri.parse('https://cloud.example.com'));
  s.pb.authStore.save(fakeToken, RecordModel.fromJson(fakeUser));
  return (s, asked);
}

Future<BackupController> _backup(Session session) async {
  final dir = Directory.systemTemp.createTempSync('home');
  return BackupController(
    session: session,
    store: BackupStore(File('${dir.path}/b.json')),
    library: _NoLibrary(),
    wifiCheck: () async => true,
  )..state = BackupState();
}

Widget _app(Session s, {bool reduceMotion = false}) => MaterialApp(
  theme: buildTheme(Brightness.light),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
    child: child!,
  ),
  home: HomeScreen(session: s, version: '0.31.0', backupFactory: _backup),
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 400));
  }
}

/// Whether the bar is shown (it slides out and fades when hidden).
bool _barShown(WidgetTester tester) => !tester
    .widget<IgnorePointer>(
      find.ancestor(of: find.byType(FloatingNavBar), matching: find.byType(IgnorePointer)).first,
    )
    .ignoring;

void main() {
  testWidgets('five destinations, the selected one named, tabs built on first visit', (
    tester,
  ) async {
    final (s, asked) = (await tester.runAsync(_session))!;
    await tester.pumpWidget(_app(s));
    await _settle(tester);

    final bar = find.byType(FloatingNavBar);
    expect(bar, findsOneWidget);
    expect(find.descendant(of: bar, matching: find.byType(Icon)), findsNWidgets(5));
    // Only the current destination shows its label; all five are named for screen readers.
    expect(find.descendant(of: bar, matching: find.text('Photos')), findsOneWidget);
    expect(find.descendant(of: bar, matching: find.text('Files')), findsNothing);
    for (final label in ['Photos', 'Files', 'Documents', 'Notes', 'Calendar']) {
      expect(find.bySemanticsLabel(label), findsWidgets, reason: label);
    }
    expect(
      tester.getSemantics(
        find.descendant(of: find.byKey(const Key('tabPhotos')), matching: find.byType(InkWell)),
      ),
      matchesSemantics(
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        label: 'Photos',
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
      ),
    );

    // Lazy: nothing of Files, Documents, Albums, Notes or Calendar yet.
    expect(asked, contains('/api/collections/media/records'));
    expect(asked, isNot(contains('/api/collections/nodes/records')));
    expect(asked, isNot(contains('/api/v1/albums')));
    expect(asked, isNot(contains('/api/collections/documents/records')));
    expect(asked, isNot(contains('/api/collections/notes/records')));

    // Albums live inside Photos, behind the switch.
    await tester.tap(find.byKey(const Key('photosAlbums')));
    await _settle(tester);
    expect(asked, contains('/api/v1/albums'));
    expect(find.text('Été en Provence'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tabFiles')));
    await _settle(tester);
    expect(asked, contains('/api/collections/nodes/records'));
    expect(find.descendant(of: bar, matching: find.text('Files')), findsOneWidget);
    expect(find.text('My files'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tabDocuments')));
    await _settle(tester);
    expect(asked, contains('/api/collections/documents/records'));
    expect(find.text('Attestation d’assurance.pdf'), findsOneWidget);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });

  testWidgets('the bar steps aside while scrolling down and returns on the way up', (
    tester,
  ) async {
    final (s, _) = (await tester.runAsync(_session))!;
    await tester.pumpWidget(_app(s));
    await _settle(tester);
    expect(_barShown(tester), isTrue);

    final list = find.byType(CustomScrollView).first;
    await tester.drag(list, const Offset(0, -400));
    await tester.pump(const Duration(milliseconds: 500));
    expect(_barShown(tester), isFalse);

    await tester.drag(list, const Offset(0, 120));
    await tester.pump(const Duration(milliseconds: 500));
    expect(_barShown(tester), isTrue);
  });

  testWidgets('with reduced motion the bar moves without animating', (tester) async {
    final (s, _) = (await tester.runAsync(_session))!;
    await tester.pumpWidget(_app(s, reduceMotion: true));
    await _settle(tester);
    final slide = tester.widget<AnimatedSlide>(
      find.ancestor(of: find.byType(FloatingNavBar), matching: find.byType(AnimatedSlide)),
    );
    expect(slide.duration, Duration.zero);
  });

  testWidgets('the content keeps room for the bar, and the FAB sits above it', (tester) async {
    final (s, _) = (await tester.runAsync(_session))!;
    await tester.pumpWidget(_app(s));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('tabFiles')));
    await _settle(tester);
    final barTop = tester.getTopLeft(find.byType(FloatingNavBar)).dy;
    final fabBottom = tester.getBottomLeft(find.byKey(const Key('addButton'))).dy;
    expect(fabBottom, lessThan(barTop));
  });

  testWidgets('search and account open from the top bar, above the navigation', (tester) async {
    final (s, _) = (await tester.runAsync(_session))!;
    await tester.pumpWidget(_app(s));
    await _settle(tester);

    await tester.tap(find.byKey(const Key('globalSearch')));
    await _settle(tester);
    expect(find.byKey(const Key('searchField')), findsOneWidget);
    expect(find.byType(FloatingNavBar), findsNothing, reason: 'pushed above the shell');
    await tester.pageBack();
    await _settle(tester);

    await tester.tap(find.byKey(const Key('accountButton')));
    await _settle(tester);
    expect(find.text('Paul Carouge'), findsWidgets);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('tapping the current destination goes back to its first screen', (tester) async {
    final (s, _) = (await tester.runAsync(_session))!;
    await tester.pumpWidget(_app(s));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('tabFiles')));
    await _settle(tester);
    await tester.tap(find.text('Documents').first);
    await _settle(tester);
    expect(find.text('My files'), findsNothing);
    await tester.tap(find.byKey(const Key('tabFiles')));
    await _settle(tester);
    expect(find.text('My files'), findsOneWidget);
  });

  testWidgets('Android back on Albums returns to the library', (tester) async {
    final (s, _) = (await tester.runAsync(_session))!;
    await tester.pumpWidget(_app(s));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('photosAlbums')));
    await _settle(tester);
    expect(find.text('Été en Provence'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(find.text('Été en Provence'), findsNothing);
    expect(find.text('Memories'), findsOneWidget);
  });

  testWidgets('the bar comes back on every push and pop inside a tab', (tester) async {
    final (s, _) = (await tester.runAsync(_session))!;
    await tester.pumpWidget(_app(s));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('tabFiles')));
    await _settle(tester);
    await tester.drag(find.byType(CustomScrollView).last, const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 500));
    expect(_barShown(tester), isFalse);
    // Opening a folder (which may be too short to scroll) brings it back.
    await tester.ensureVisible(find.text('Vacances 2025'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(_barShown(tester), isFalse);
    await tester.tap(find.text('Vacances 2025'));
    await _settle(tester);
    expect(find.text('My files'), findsNothing, reason: 'inside the folder');
    expect(_barShown(tester), isTrue);
    await tester.drag(find.byType(CustomScrollView).last, const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(_barShown(tester), isTrue, reason: 'back on the parent folder');
  });
}
