import 'dart:async';

import 'package:alcove/core/calendar.dart';
import 'package:alcove/features/calendar/calendar_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';

import 'notes_screen_test.dart' show app, settle, signedIn;

RecordModel event(
  String id,
  String title,
  String start,
  String end, {
  bool allDay = false,
  String rrule = '',
  String location = '',
}) => RecordModel.fromJson({
  'id': id,
  'collectionName': 'events',
  'calendar': 'c1',
  'title': title,
  'description': '',
  'location': location,
  'start': start,
  'end': end,
  'all_day': allDay,
  'rrule': rrule,
});

/// In memory, with a hand-driven realtime stream.
class FakeCalendar extends CalendarApi {
  FakeCalendar(super.session, this.items);

  List<RecordModel> items;
  final created = <Map<String, dynamic>>[];
  final updated = <Map<String, dynamic>>[];
  final deleted = <String>[];
  void Function(CalendarEvent)? listener;

  @override
  Future<List<RecordModel>> calendars(String firstName) async => [
    RecordModel.fromJson({'id': 'c1', 'name': firstName, 'color': 'blue'}),
  ];

  /// When set, loads and creates wait for it (a slow network).
  Completer<void>? gate;

  @override
  Future<List<RecordModel>> events() async {
    final snapshot = items;
    await gate?.future;
    return snapshot;
  }

  @override
  Future<RecordModel> create(Map<String, dynamic> body) async {
    await gate?.future;
    created.add(body);
    final r = RecordModel.fromJson({'id': 'new${created.length}', ...body});
    items = [...items, r];
    return r;
  }

  @override
  Future<RecordModel> update(String id, Map<String, dynamic> body) async {
    updated.add(body);
    final old = items.firstWhere((e) => e.id == id);
    final r = RecordModel.fromJson({...old.toJson(), ...body});
    items = [for (final e in items) e.id == id ? r : e];
    return r;
  }

  @override
  Future<void> delete(String id) async {
    deleted.add(id);
    items = items.where((e) => e.id != id).toList();
  }

  @override
  Future<void Function()> watch(void Function(CalendarEvent) onEvent) async {
    listener = onEvent;
    return () => listener = null;
  }
}

String _utc(DateTime local) => toPb(local);

void main() {
  final now = DateTime(2026, 10, 15, 14, 20);

  testWidgets('the agenda groups the coming days, all-day first, and follows live changes', (
    tester,
  ) async {
    final session = await signedIn(tester);
    final api = FakeCalendar(session, [
      event(
        'a',
        'Dentist',
        _utc(DateTime(2026, 10, 16, 9)),
        _utc(DateTime(2026, 10, 16, 10)),
        location: 'Main St',
      ),
      event('b', 'Holiday', allDayPb('2026-10-16'), allDayPb('2026-10-18'), allDay: true),
      event(
        'c',
        'Yoga',
        _utc(DateTime(2026, 10, 1, 18)),
        _utc(DateTime(2026, 10, 1, 19)),
        rrule: 'FREQ=WEEKLY',
      ),
      event('d', 'Long ago', _utc(DateTime(2025, 1, 1, 9)), _utc(DateTime(2025, 1, 1, 10))),
    ]);
    await tester.pumpWidget(
      app(CalendarScreen(session: session, api: api, now: () => now)),
    );
    await settle(tester);

    expect(find.text('Long ago'), findsNothing);
    expect(find.text('Holiday'), findsNWidgets(2), reason: 'on both days');
    expect(find.text('Yoga'), findsWidgets, reason: 'repeats every Thursday');
    final holiday = tester.getTopLeft(find.text('Holiday').first).dy;
    final dentist = tester.getTopLeft(find.text('Dentist')).dy;
    expect(holiday, lessThan(dentist), reason: 'all-day first');
    expect(find.textContaining('Main St'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Repeats')), findsWidgets);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

    // Another device deletes an event and adds one.
    api.listener!((collection: 'events', action: 'delete', record: api.items.first));
    api.listener!((
      collection: 'events',
      action: 'create',
      record: event('e', 'Party', allDayPb('2026-10-20'), allDayPb('2026-10-21'), allDay: true),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Dentist'), findsNothing);
    expect(find.text('Party'), findsOneWidget);

    // The month grid shows the chosen day's events.
    await tester.tap(find.byKey(const Key('calendarView')));
    await tester.pumpAndSettle();
    expect(find.text('October 2026'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(RegExp('Events on Tuesday, October 20')));
    await tester.pumpAndSettle();
    expect(find.text('Party'), findsOneWidget);
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    expect(find.text('November 2026'), findsOneWidget);
  });

  testWidgets('the editor creates, edits a series and deletes', (tester) async {
    final session = await signedIn(tester);
    final api = FakeCalendar(session, []);
    await tester.pumpWidget(
      app(CalendarScreen(session: session, api: api, now: () => now)),
    );
    await settle(tester);
    expect(find.text('Nothing planned for the next 30 days.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('newEvent')));
    await tester.pumpAndSettle();
    // A title is required.
    await tester.tap(find.byKey(const Key('saveEvent')));
    await tester.pumpAndSettle();
    expect(find.text('Give the event a title.'), findsOneWidget);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

    await tester.enterText(find.byKey(const Key('eventTitle')), 'Book club');
    await tester.tap(find.byKey(const Key('repeat')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Every month').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saveEvent')));
    await tester.pumpAndSettle();

    final body = api.created.single;
    expect(body['title'], 'Book club');
    expect(body['rrule'], 'FREQ=MONTHLY');
    expect(fromPb(body['start'] as String).toLocal(), DateTime(2026, 10, 15, 15));
    expect(find.text('Book club'), findsOneWidget);

    // Editing a recurring event says it changes the series; all-day keeps whole dates.
    await tester.tap(find.text('Book club'));
    await tester.pumpAndSettle();
    expect(find.text('Changes apply to every occurrence of this event.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('allDay')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saveEvent')));
    await tester.pumpAndSettle();
    expect(api.updated.single['start'], '2026-10-15 00:00:00.000Z');
    expect(api.updated.single['end'], '2026-10-16 00:00:00.000Z');
    expect(find.text('All day'), findsOneWidget);

    await tester.tap(find.text('Book club'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('deleteEvent')),
      200,
      scrollable: find
          .descendant(of: find.byType(EventEditorScreen), matching: find.byType(Scrollable))
          .first,
    );
    await tester.tap(find.byKey(const Key('deleteEvent')));
    await tester.pumpAndSettle();
    expect(find.textContaining('and all its occurrences'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete event'));
    await tester.pumpAndSettle();
    expect(api.deleted, ['new1']);
    expect(find.text('Book club'), findsNothing);
  });

  testWidgets('realtime changes during a load are kept, late echoes are ignored', (tester) async {
    final session = await signedIn(tester);
    final api = FakeCalendar(session, [
      RecordModel.fromJson({
        ...event(
          'a',
          'Dentist',
          allDayPb('2026-10-16'),
          allDayPb('2026-10-17'),
          allDay: true,
        ).toJson(),
        'updated': '2026-10-10 10:00:00.000Z',
      }),
    ])..gate = Completer<void>();
    await tester.pumpWidget(app(CalendarScreen(session: session, api: api, now: () => now)));
    await tester.pump();
    // Created on another device while the list is loading (the snapshot does not have it).
    api.listener!((
      collection: 'events',
      action: 'create',
      record: event('b', 'Party', allDayPb('2026-10-18'), allDayPb('2026-10-19'), allDay: true),
    ));
    api.gate!.complete();
    await settle(tester);
    expect(find.text('Party'), findsOneWidget);
    expect(find.text('Dentist'), findsOneWidget);

    // An older version arriving late does not undo the newer one.
    api.listener!((
      collection: 'events',
      action: 'update',
      record: RecordModel.fromJson({
        ...event(
          'a',
          'Old title',
          allDayPb('2026-10-16'),
          allDayPb('2026-10-17'),
          allDay: true,
        ).toJson(),
        'updated': '2026-10-09 10:00:00.000Z',
      }),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Dentist'), findsOneWidget);
    expect(find.text('Old title'), findsNothing);
  });

  testWidgets('back during a save does not close the calendar behind the editor', (tester) async {
    final session = await signedIn(tester);
    final api = FakeCalendar(session, []);
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      app(
        Navigator(
          key: nav,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => CalendarScreen(session: session, api: api, now: () => now),
          ),
        ),
      ),
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('newEvent')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('eventTitle')), 'Slow save');
    api.gate = Completer<void>();
    await tester.tap(find.byKey(const Key('saveEvent')));
    await tester.pump();
    // Back while the save is on its way: refused.
    await nav.currentState!.maybePop();
    await tester.pump();
    expect(find.byType(EventEditorScreen), findsOneWidget);
    api.gate!.complete();
    await settle(tester);
    expect(find.byType(EventEditorScreen), findsNothing);
    expect(find.byType(CalendarScreen), findsOneWidget);
    expect(find.text('Slow save'), findsOneWidget);
  });
}
