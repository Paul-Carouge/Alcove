import 'package:alcove/core/calendar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';

// The Makefile also runs this file under several TZ values: nothing here may depend on the zone.

RecordModel ev(
  String start,
  String end, {
  bool allDay = false,
  String rrule = '',
  String id = 'e',
}) => RecordModel.fromJson({
  'id': id,
  'title': id,
  'start': start,
  'end': end,
  'all_day': allDay,
  'rrule': rrule,
  'calendar': 'c',
});

RecordModel allDay(String first, String afterLast, {String rrule = ''}) =>
    ev(allDayPb(first), allDayPb(afterLast), allDay: true, rrule: rrule);

/// A timed event at a local wall-clock time, stored in UTC.
RecordModel local(DateTime start, Duration length, {String rrule = ''}) =>
    ev(toPb(start), toPb(start.add(length)), rrule: rrule);

List<String> days(RecordModel e, String from, String to) =>
    expand([e], from, to).map((o) => o.firstDay).toList();

void main() {
  group('rules', () {
    test('reads and writes the supported subset', () {
      expect(parseRule('FREQ=WEEKLY'), const Rule(Freq.weekly));
      expect(parseRule('FREQ=DAILY;COUNT=5'), const Rule(Freq.daily, count: 5));
      expect(
        parseRule('FREQ=YEARLY;UNTIL=20301231', allDay: true),
        const Rule(Freq.yearly, until: '2030-12-31'),
      );
      expect(parseRule('FREQ=WEEKLY;BYDAY=MO'), isNull);
      expect(formatRule(const Rule(Freq.monthly, count: 3), allDay: false), 'FREQ=MONTHLY;COUNT=3');
      expect(
        formatRule(const Rule(Freq.daily, until: '2026-11-02'), allDay: true),
        'FREQ=DAILY;UNTIL=20261102',
      );
    });

    test('a timed series ends on the chosen local day', () {
      final s = formatRule(const Rule(Freq.daily, until: '2026-11-02'), allDay: false);
      expect(parseRule(s)?.until, '2026-11-02');
      expect(parseRule(s)?.untilAt, DateTime(2026, 11, 2, 23, 59, 59).toUtc());
    });
  });

  group('expand', () {
    test('repeats with COUNT and UNTIL', () {
      final daily = local(
        DateTime(2026, 10, 1, 8),
        const Duration(minutes: 30),
        rrule: 'FREQ=DAILY;COUNT=3',
      );
      expect(days(daily, '2026-09-01', '2026-12-01'), ['2026-10-01', '2026-10-02', '2026-10-03']);
      final weekly = local(
        DateTime(2026, 10, 5, 8),
        const Duration(hours: 1),
        rrule: formatRule(const Rule(Freq.weekly, until: '2026-10-26'), allDay: false),
      );
      expect(days(weekly, '2026-10-01', '2026-12-01'), [
        '2026-10-05',
        '2026-10-12',
        '2026-10-19',
        '2026-10-26',
      ]);
    });

    test('jumps to a far range and keeps the index', () {
      final e = local(
        DateTime(2026, 1, 1, 8),
        const Duration(hours: 1),
        rrule: 'FREQ=DAILY;COUNT=288',
      );
      final occ = expand([e], '2026-10-14', '2026-10-17');
      expect(occ.map((o) => (o.firstDay, o.index)), [('2026-10-14', 286), ('2026-10-15', 287)]);
    });

    test('keeps the local time across a DST change', () {
      final e = local(DateTime(2026, 10, 19, 9), const Duration(hours: 1), rrule: 'FREQ=WEEKLY');
      final occ = expand([e], '2026-10-19', '2026-11-10');
      expect(occ.map((o) => o.start.hour), [9, 9, 9, 9]);
    });

    test('skips months without the day', () {
      final e = allDay('2026-01-31', '2026-02-01', rrule: 'FREQ=MONTHLY;COUNT=4');
      expect(days(e, '2026-01-01', '2027-01-01'), [
        '2026-01-31',
        '2026-03-31',
        '2026-05-31',
        '2026-07-31',
      ]);
      final leap = allDay('2024-02-29', '2024-03-01', rrule: 'FREQ=YEARLY');
      expect(days(leap, '2024-01-01', '2033-01-01'), ['2024-02-29', '2028-02-29', '2032-02-29']);
    });

    test('keeps an all-day event on its date in any zone', () {
      final e = allDay('2026-10-24', '2026-10-25', rrule: 'FREQ=YEARLY;UNTIL=20271024');
      final occ = expand([e], '2026-01-01', '2028-01-01');
      expect(occ.map((o) => (o.firstDay, o.lastDay)), [
        ('2026-10-24', '2026-10-24'),
        ('2027-10-24', '2027-10-24'),
      ]);
      expect(dayKey(occ.first.start), '2026-10-24');
    });

    test('shows a multi-day event on each day, seen from its middle too', () {
      final trip = allDay('2026-10-24', '2026-10-27');
      final o = expand([trip], '2026-10-26', '2026-10-30').single;
      expect((o.firstDay, o.lastDay), ('2026-10-24', '2026-10-26'));
      expect(o.covers('2026-10-25'), isTrue);
      expect(o.covers('2026-10-27'), isFalse);
      final late = local(DateTime(2026, 10, 20, 22), const Duration(hours: 2));
      final l = expand([late], '2026-10-01', '2026-11-01').single;
      expect((l.firstDay, l.lastDay), ('2026-10-20', '2026-10-20'));
    });

    test('sorts all-day first, then by time', () {
      final occ = expand(
        [
          local(DateTime(2026, 10, 20, 15), const Duration(hours: 1)),
          allDay('2026-10-20', '2026-10-21'),
          local(DateTime(2026, 10, 20, 8), const Duration(hours: 1)),
        ],
        '2026-10-20',
        '2026-10-21',
      );
      expect(occ.map((o) => o.allDay ? -1 : o.start.hour), [-1, 8, 15]);
    });
  });

  group('drafts', () {
    test('an all-day event is stored as whole UTC dates with an exclusive end', () {
      final d = Draft.on('2026-10-24', 'c')
        ..title = 'Trip'
        ..allDay = true
        ..end = fromKey('2026-10-26');
      final rec = d.toRecord();
      expect((rec['start'], rec['end']), ('2026-10-24 00:00:00.000Z', '2026-10-27 00:00:00.000Z'));
      final back = Draft.of(RecordModel.fromJson({'id': 'x', ...rec}));
      expect(
        (dayKey(back.start), dayKey(back.end), back.allDay),
        ('2026-10-24', '2026-10-26', true),
      );
    });

    test('a timed event round-trips through UTC', () {
      final d = Draft.on('2026-10-20', 'c')
        ..title = ' Dentist '
        ..start = DateTime(2026, 10, 20, 9, 30)
        ..end = DateTime(2026, 10, 20, 10, 15)
        ..repeat = Freq.weekly
        ..ends = Ends.count
        ..count = 4;
      final rec = d.toRecord();
      expect(rec['title'], 'Dentist');
      expect(rec['rrule'], 'FREQ=WEEKLY;COUNT=4');
      expect(fromPb(rec['start'] as String).toLocal(), DateTime(2026, 10, 20, 9, 30));
      final back = Draft.of(RecordModel.fromJson({'id': 'x', ...rec}));
      expect(
        (back.start, back.end, back.repeat, back.count),
        (
          DateTime(2026, 10, 20, 9, 30),
          DateTime(2026, 10, 20, 10, 15),
          Freq.weekly,
          4,
        ),
      );
    });

    test('starts at the next hour today, at 9:00 another day; validates', () {
      final now = DateTime(2026, 10, 15, 14, 20);
      expect(Draft.on('2026-10-15', 'c', now: now).start, DateTime(2026, 10, 15, 15));
      expect(Draft.on('2026-10-16', 'c', now: now).start, DateTime(2026, 10, 16, 9));
      final d = Draft.on('2026-10-16', 'c', now: now)..title = 'x';
      expect(d.validate(), isNull);
      expect((Draft.on('2026-10-16', 'c', now: now)).validate(), 'title');
      d.end = d.start.subtract(const Duration(minutes: 1));
      expect(d.validate(), 'end');
      d.moveStart(DateTime(2026, 10, 17, 9));
      expect(d.validate(), isNull);
    });
  });

  // DST days: 29 March 2026 in Europe, 8 March in the US (the Makefile runs both zones).
  group('DST days', () {
    for (final day in ['2026-03-29', '2026-03-08', '2026-10-25', '2026-11-01']) {
      test('$day: UNTIL round trip, 9:00 start, all-day move by whole days', () {
        final s = formatRule(Rule(Freq.daily, until: day), allDay: false);
        expect(parseRule(s)?.until, day);
        final d = fromKey(day);
        expect(
          Draft.on(day, 'c', now: DateTime(2026, 1, 1)).start,
          DateTime(d.year, d.month, d.day, 9),
        );
        final allDay = Draft.on(addDays(day, -1), 'c')
          ..allDay = true
          ..start = fromKey(addDays(day, -1))
          ..end = fromKey(day);
        allDay.moveStart(fromKey(day));
        expect(dayKey(allDay.end), addDays(day, 1));
      });
    }
  });

  test('a timed series stops at the UNTIL instant, not at the end of its day', () {
    final e = ev(
      '2026-10-18 13:00:00.000Z',
      '2026-10-18 14:00:00.000Z',
      rrule: 'FREQ=DAILY;UNTIL=20261020T120000Z',
    );
    expect(expand([e], '2026-10-01', '2026-11-01'), hasLength(2));
  });

  test('switching all-day off gives 9:00 to 10:00', () {
    final d = Draft.of(
      RecordModel.fromJson({
        'id': 'x',
        'title': 't',
        'all_day': true,
        'start': allDayPb('2026-10-20'),
        'end': allDayPb('2026-10-21'),
        'rrule': '',
        'calendar': 'c',
      }),
    )..setAllDay(false);
    expect((d.start, d.end), (DateTime(2026, 10, 20, 9), DateTime(2026, 10, 20, 10)));
    expect(d.validate(), isNull);
  });
}
