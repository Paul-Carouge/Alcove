import 'dart:convert';

import 'package:alcove/core/notes.dart';
import 'package:alcove/core/secure_store.dart';
import 'package:alcove/core/session.dart';
import 'package:alcove/features/notes/notes_screen.dart';
import 'package:alcove/l10n/gen/app_localizations.dart';
import 'package:alcove/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocketbase/pocketbase.dart';

RecordModel note(
  String id,
  String title, {
  String body = '',
  bool pinned = false,
  String updated = '2026-10-01 10:00:00.000Z',
  String trashed = '',
}) => RecordModel.fromJson({
  'id': id,
  'collectionName': 'notes',
  'title': title,
  'body': body,
  'pinned': pinned,
  'tags': <String>[],
  'trashed_at': trashed,
  'updated': updated,
});

/// In memory, with a hand-driven realtime stream.
class FakeNotes extends NotesApi {
  FakeNotes(super.session, this.items);

  List<RecordModel> items;
  final updates = <Map<String, dynamic>>[];
  final deleted = <String>[];
  void Function(NoteEvent)? listener;
  bool offline = false;
  int _clock = 0;

  @override
  Future<List<RecordModel>> list() async => items;

  @override
  Future<RecordModel> create() async {
    final n = note('new', '');
    items = [...items, n];
    return n;
  }

  @override
  Future<RecordModel> update(String id, Map<String, dynamic> body) async {
    if (offline) throw ClientException(statusCode: 0);
    updates.add(body);
    _clock++;
    final old = items.firstWhere((n) => n.id == id);
    final saved = RecordModel.fromJson({
      ...old.toJson(),
      ...body,
      'updated': '2026-10-02 10:00:${_clock.toString().padLeft(2, '0')}.000Z',
    });
    items = [for (final n in items) n.id == id ? saved : n];
    return saved;
  }

  @override
  Future<void> delete(String id) async {
    deleted.add(id);
    items = items.where((n) => n.id != id).toList();
  }

  @override
  Future<void Function()> watch(void Function(NoteEvent) onEvent) async {
    listener = onEvent;
    return () => listener = null;
  }
}

Future<Session> signedIn(WidgetTester tester) async {
  FlutterSecureStorage.setMockInitialValues({});
  final client = MockClient(
    (req) async => http.Response(
      jsonEncode({
        'items': <Object>[],
        'page': 1,
        'perPage': 500,
        'totalItems': 0,
        'totalPages': 1,
      }),
      200,
      headers: {'content-type': 'application/json'},
    ),
  );
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
  return session;
}

Widget app(Widget home) => MaterialApp(
  theme: buildTheme(Brightness.light),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists notes pinned first, hides the trash, filters and follows live changes', (
    tester,
  ) async {
    final session = await signedIn(tester);
    final api = FakeNotes(session, [
      note('a', 'Groceries', body: '- milk', updated: '2026-10-03 10:00:00.000Z'),
      note('b', 'Ideas', body: '# A café', pinned: true),
      note('c', 'Old', trashed: '2026-10-01 10:00:00.000Z'),
    ]);
    await tester.pumpWidget(app(NotesScreen(session: session, api: api)));
    await settle(tester);

    expect(find.text('Old'), findsNothing);
    final ideas = tester.getTopLeft(find.text('Ideas')).dy;
    final groceries = tester.getTopLeft(find.text('Groceries')).dy;
    expect(ideas, lessThan(groceries), reason: 'pinned first');
    expect(find.text('A café'), findsOneWidget);
    expect(find.byIcon(Icons.push_pin), findsOneWidget);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

    // Another device renames a note.
    api.listener!((
      action: 'update',
      record: note('a', 'Market list', body: '- milk', updated: '2026-10-04 10:00:00.000Z'),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Market list'), findsOneWidget);
    // A late echo of an older version changes nothing.
    api.listener!((action: 'update', record: note('a', 'Groceries', body: '- milk')));
    await tester.pumpAndSettle();
    expect(find.text('Market list'), findsOneWidget);

    // The filter field under the title narrows the list as you type.
    await tester.enterText(find.byKey(const Key('notesFilter')), 'cafe');
    await tester.pumpAndSettle();
    expect(find.text('Market list'), findsNothing);
    await tester.enterText(find.byKey(const Key('notesFilter')), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No notes match your search'), findsOneWidget);
  });

  testWidgets('shows an empty state', (tester) async {
    final session = await signedIn(tester);
    await tester.pumpWidget(app(NotesScreen(session: session, api: FakeNotes(session, []))));
    await settle(tester);
    expect(find.text('No notes yet'), findsOneWidget);
    expect(find.text('New note'), findsOneWidget);
  });

  testWidgets('the editor saves after a pause and takes remote edits when idle', (tester) async {
    final session = await signedIn(tester);
    final api = FakeNotes(session, [note('a', 'Groceries', body: '- milk')]);
    await tester.pumpWidget(
      app(
        NoteEditorScreen(
          session: session,
          api: api,
          note: api.items.first,
          saveDelay: const Duration(milliseconds: 300),
        ),
      ),
    );
    await settle(tester);
    expect(find.text('Groceries'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('noteBody')), '- milk\n- eggs');
    await tester.pump();
    expect(find.text('Saving…'), findsOneWidget);
    expect(api.updates, isEmpty, reason: 'debounced');
    await tester.pump(const Duration(milliseconds: 300));
    await settle(tester);
    expect(api.updates, [
      {'title': 'Groceries', 'body': '- milk\n- eggs'},
    ]);
    expect(find.text('Saved'), findsOneWidget);

    // Saved here, then edited elsewhere: the editor follows.
    // A late echo older than the saved version is ignored...
    api.listener!((action: 'update', record: note('a', 'Groceries', body: '- milk')));
    await tester.pumpAndSettle();
    expect(find.text('- milk\n- eggs'), findsOneWidget);
    // ...a newer edit from elsewhere is shown.
    api.listener!((
      action: 'update',
      record: note('a', 'Groceries', body: '- bread', updated: '2026-10-05 10:00:00.000Z'),
    ));
    await tester.pumpAndSettle();
    expect(find.text('- bread'), findsOneWidget);

    // Pin from the toolbar.
    await tester.tap(find.byTooltip('Pin'));
    await settle(tester);
    expect(api.updates.last, {'pinned': true});
    expect(find.byTooltip('Unpin'), findsOneWidget);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });

  test('excerpt and filter helpers', () {
    expect(excerpt('---\n# Title\nbody'), 'Title');
    expect(excerpt('- [x] **Buy** [milk](https://x.y)'), 'Buy milk');
    final notes = [note('1', 'Courses', body: 'Lait'), note('2', 'Ideas', body: 'Lyon trip')];
    expect(filterNotes(notes, 'LYON').map((n) => n.id), ['2']);
    expect(noteTitle(note('3', '', body: '# From body')), 'From body');
  });

  testWidgets('leaving with unsaved edits asks first, and a double back pops once', (tester) async {
    final session = await signedIn(tester);
    final api = FakeNotes(session, [note('a', 'Groceries', body: '- milk')]);
    final popped = <Object?>[];
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async => popped.add(
                  await Navigator.of(context).push<RecordModel>(
                    MaterialPageRoute(
                      builder: (_) => NoteEditorScreen(
                        session: session,
                        api: api,
                        note: api.items.first,
                        saveDelay: const Duration(milliseconds: 100),
                      ),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);

    api.offline = true;
    await tester.enterText(find.byKey(const Key('noteBody')), '- milk\n- tea');
    await tester.pump(const Duration(milliseconds: 100));
    await settle(tester);
    expect(find.text('Not saved. Tap to retry'), findsOneWidget);

    // Back twice in a row: one dialog, the editor stays.
    await tester.tap(find.byType(BackButton));
    await tester.tap(find.byType(BackButton), warnIfMissed: false);
    await settle(tester);
    expect(find.text('Leave without saving?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('noteBody')), findsOneWidget);

    // Back online: back saves, then closes once.
    api.offline = false;
    await tester.tap(find.byType(BackButton));
    await tester.tap(find.byType(BackButton), warnIfMissed: false);
    await settle(tester);
    expect(find.text('open'), findsOneWidget);
    expect(popped, hasLength(1));
    expect(api.updates.last['body'], '- milk\n- tea');
  });

  testWidgets('the trash view restores and deletes notes for good', (tester) async {
    final session = await signedIn(tester);
    final api = FakeNotes(session, [
      note('a', 'Groceries'),
      note('b', 'Old', trashed: '2026-10-01 10:00:00.000Z'),
      note('c', 'Older', trashed: '2026-09-01 10:00:00.000Z'),
    ]);
    await tester.pumpWidget(app(NotesScreen(session: session, api: api)));
    await settle(tester);
    await tester.tap(find.byTooltip('Trash'));
    await tester.pumpAndSettle();
    expect(find.text('Groceries'), findsNothing);
    expect(find.text('Old'), findsOneWidget);
    expect(find.text('New note'), findsNothing);

    await tester.tap(find.text('Old'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore'));
    await settle(tester);
    expect(find.text('Old'), findsNothing);
    expect(api.updates.last, {'trashed_at': ''});

    await tester.tap(find.text('Older'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete forever'));
    await tester.pumpAndSettle();
    expect(find.text('Delete forever?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete forever'));
    await settle(tester);
    expect(api.deleted, ['c']);
    expect(find.text('No notes in the trash'), findsOneWidget);
  });
}
