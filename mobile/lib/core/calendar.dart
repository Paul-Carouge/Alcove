import 'dart:async';

import 'package:pocketbase/pocketbase.dart';

import 'session.dart';

/// A change to a calendar or an event made anywhere, from the server's realtime stream.
typedef CalendarEvent = ({String collection, String action, RecordModel record});

/// Calendars and events of the signed-in user (ADR 0028), owner-only on the server.
///
/// Times are UTC instants shown in the device time zone. All-day events cover whole dates: start is
/// the first day at 00:00Z, end the day after the last one (exclusive, like iCalendar's DTEND); they
/// are read as dates, never as instants, so they stay on their day in every time zone.
class CalendarApi {
  CalendarApi(this.session);

  final Session session;

  RecordService get _cals => session.pb.collection('calendars');
  RecordService get _events => session.pb.collection('events');

  /// The user's calendars, creating the default one on the first visit. The server allows one
  /// default calendar per user, so two devices doing it at once (in any language) end with one: the
  /// second create fails and it reads again.
  Future<List<RecordModel>> calendars(String firstName) async {
    final list = await _cals.getFullList(batch: 200, sort: 'name');
    if (list.isNotEmpty) return list;
    try {
      return [
        await _cals.create(
          body: {
            'owner': session.user?.id,
            'name': firstName,
            'color': 'green',
            'is_default': true,
          },
        ),
      ];
    } catch (_) {
      return _cals.getFullList(batch: 200, sort: 'name');
    }
  }

  // shortcut: loads every event (a series needs its first occurrence); filter by range on the server
  // once calendars hold many thousands of events.
  Future<List<RecordModel>> events() => _events.getFullList(batch: 500, sort: 'start');

  Future<RecordModel> create(Map<String, dynamic> body) =>
      _events.create(body: {...body, 'owner': session.user?.id});

  Future<RecordModel> update(String id, Map<String, dynamic> body) =>
      _events.update(id, body: body);

  Future<void> delete(String id) => _events.delete(id);

  /// Follows both collections while the screen is open; returns the function that stops listening.
  Future<void Function()> watch(void Function(CalendarEvent event) onEvent) async {
    final stops = <UnsubscribeFunc>[];
    void stopAll() {
      for (final s in stops) {
        unawaited(s());
      }
    }

    try {
      for (final col in ['calendars', 'events']) {
        stops.add(
          await session.pb.collection(col).subscribe('*', (e) {
            final r = e.record;
            if (r != null) onEvent((collection: col, action: e.action, record: r));
          }),
        );
      }
    } catch (_) {
      // Half a subscription is worse than none: the caller retries or shows stale data.
      stopAll();
      rethrow;
    }
    return stopAll;
  }
}

String _pad(int n) => n.toString().padLeft(2, '0');

/// A calendar date (no time, no zone), compared as YYYY-MM-DD text.
String dayKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${_pad(d.month)}-${_pad(d.day)}';

/// Local midnight of a day key.
DateTime fromKey(String key) {
  final p = key.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

/// The day key [n] days after [key] (calendar arithmetic in UTC, so DST never shifts it).
String addDays(String key, int n) {
  final p = key.split('-').map(int.parse).toList();
  final t = DateTime.utc(p[0], p[1], p[2] + n);
  return dayKey(t);
}

int daysBetween(String a, String b) {
  DateTime u(String k) {
    final p = k.split('-').map(int.parse).toList();
    return DateTime.utc(p[0], p[1], p[2]);
  }

  return u(b).difference(u(a)).inDays;
}

/// PocketBase's date format: "2026-10-15 10:00:00.000Z".
String toPb(DateTime d) => d.toUtc().toIso8601String().replaceFirst('T', ' ');

DateTime fromPb(String s) => DateTime.parse(s.replaceFirst(' ', 'T'));

String allDayPb(String key) => '$key 00:00:00.000Z';

/// The date of an all-day boundary, read as a date (its UTC calendar day).
String allDayKey(String pbDate) => pbDate.substring(0, 10);

enum Freq { daily, weekly, monthly, yearly }

/// The recurrence subset Alcove edits and expands (the server refuses anything else).
class Rule {
  const Rule(this.freq, {this.count, this.until, this.untilAt});

  final Freq freq;

  /// Number of occurrences, the first one included.
  final int? count;

  /// Day key of the last day an occurrence may start on (what the editor shows).
  final String? until;

  /// The exact UNTIL instant of a timed series (a UTC date-time in the rule), which expansion uses.
  final DateTime? untilAt;

  @override
  bool operator ==(Object other) =>
      other is Rule &&
      other.freq == freq &&
      other.count == count &&
      other.until == until &&
      other.untilAt == untilAt;

  @override
  int get hashCode => Object.hash(freq, count, until, untilAt);

  @override
  String toString() => 'Rule($freq, count: $count, until: $until, untilAt: $untilAt)';
}

final _rule = RegExp(
  r'^FREQ=(DAILY|WEEKLY|MONTHLY|YEARLY)(?:;(?:COUNT=(\d{1,3})|UNTIL=(\d{8})(T\d{6}Z)?))?$',
);

/// Reads an RRULE; a date-time UNTIL of a timed event becomes the local day of that instant.
Rule? parseRule(String rrule, {bool allDay = false}) {
  final m = _rule.firstMatch(rrule.trim());
  if (m == null) return null;
  final freq = Freq.values.byName(m[1]!.toLowerCase());
  String? until;
  DateTime? untilAt;
  if (m[3] != null) {
    final d = m[3]!;
    final key = '${d.substring(0, 4)}-${d.substring(4, 6)}-${d.substring(6, 8)}';
    final t = m[4];
    if (t != null && !allDay) {
      untilAt = DateTime.parse(
        '${key}T${t.substring(1, 3)}:${t.substring(3, 5)}:${t.substring(5, 7)}Z',
      );
      until = dayKey(untilAt.toLocal());
    } else {
      until = key;
    }
  }
  return Rule(
    freq,
    count: m[2] == null ? null : int.parse(m[2]!),
    until: until,
    untilAt: untilAt,
  );
}

/// Writes an RRULE: all-day series end on a date, timed ones at the last second of that local day.
String formatRule(Rule? rule, {required bool allDay}) {
  if (rule == null) return '';
  var s = 'FREQ=${rule.freq.name.toUpperCase()}';
  if (rule.count != null) {
    s += ';COUNT=${rule.count}';
  } else if (rule.until != null) {
    if (allDay) {
      s += ';UNTIL=${rule.until!.replaceAll('-', '')}';
    } else {
      final d = fromKey(rule.until!);
      // Built from parts, not midnight + 23:59:59, which lands on the next day on DST days.
      final end = DateTime(d.year, d.month, d.day, 23, 59, 59);
      final iso = end.toUtc().toIso8601String();
      s += ';UNTIL=${iso.substring(0, 19).replaceAll(RegExp('[-:]'), '')}Z';
    }
  }
  return s;
}

/// One appearance of an event.
class Occurrence {
  Occurrence(this.event, this.index, this.start, this.end, this.firstDay, this.lastDay);

  final RecordModel event;

  /// Index in the series (0 for the first).
  final int index;

  /// Timed: instants. All-day: local midnight of the first day / of the day after the last.
  final DateTime start;
  final DateTime end;

  /// First and last day (inclusive) it appears on, in the viewer's calendar.
  final String firstDay;
  final String lastDay;

  bool get allDay => event.getBoolValue('all_day');
  bool covers(String day) => firstDay.compareTo(day) <= 0 && lastDay.compareTo(day) >= 0;
}

const _maxSteps = 20000;

typedef _Make = DateTime Function(int y, int m, int d);

/// The n-th date of a series; null when that day does not exist (31 April), as RFC 5545 says.
DateTime? _step(int y, int mo, int d, Freq f, int n, _Make make) {
  final t = switch (f) {
    Freq.daily => make(y, mo, d + n),
    Freq.weekly => make(y, mo, d + 7 * n),
    Freq.monthly => make(y, mo + n, d),
    Freq.yearly => make(y + n, mo, d),
  };
  if ((f == Freq.monthly || f == Freq.yearly) && t.day != d) return null;
  return t;
}

/// Walks a series until [visit] returns false; daily and weekly ones jump close to [fromDay].
void _series(
  Rule rule,
  DateTime first,
  _Make make,
  bool Function(DateTime t, int index) visit,
  String fromDay,
  int spanDays,
) {
  var n = 0;
  if (rule.freq == Freq.daily || rule.freq == Freq.weekly) {
    final every = rule.freq == Freq.daily ? 1 : 7;
    final gap = daysBetween(dayKey(first), fromDay) - spanDays;
    if (gap > 0) n = gap ~/ every;
  }
  var index = n;
  for (var i = 0; i < _maxSteps; i++, n++) {
    if (rule.count != null && index >= rule.count!) return;
    final t = _step(first.year, first.month, first.day, rule.freq, n, make);
    if (t == null) continue;
    if (!visit(t, index)) return;
    index++;
  }
}

/// Occurrences appearing on at least one day of [fromDay, toDay) in the device time zone, sorted by
/// day, all-day first, then time. Repeating timed events keep their local clock time across DST.
List<Occurrence> expand(Iterable<RecordModel> events, String fromDay, String toDay) {
  final out = <Occurrence>[];
  for (final ev in events) {
    final allDay = ev.getBoolValue('all_day');
    final rrule = ev.getStringValue('rrule');
    final rule = rrule.isEmpty ? null : parseRule(rrule, allDay: allDay);
    if (allDay) {
      final first = allDayKey(ev.getStringValue('start'));
      final days = daysBetween(first, allDayKey(ev.getStringValue('end'))).clamp(1, 1 << 20);
      void emit(int index, String key) {
        final last = addDays(key, days - 1);
        if (key.compareTo(toDay) >= 0 || last.compareTo(fromDay) < 0) return;
        out.add(Occurrence(ev, index, fromKey(key), fromKey(addDays(key, days)), key, last));
      }

      if (rule == null) {
        emit(0, first);
        continue;
      }
      final p = first.split('-').map(int.parse).toList();
      _series(
        rule,
        DateTime.utc(p[0], p[1], p[2]),
        DateTime.utc,
        (t, i) {
          final key = dayKey(t);
          if (rule.until != null && key.compareTo(rule.until!) > 0) return false;
          if (key.compareTo(toDay) >= 0) return false;
          emit(i, key);
          return true;
        },
        fromDay,
        days,
      );
    } else {
      final start = fromPb(ev.getStringValue('start')).toLocal();
      final duration = fromPb(ev.getStringValue('end')).difference(start);
      final length = duration.isNegative ? Duration.zero : duration;
      final from = fromKey(fromDay);
      final to = fromKey(toDay);
      void emit(int index, DateTime s) {
        final e = s.add(length);
        // An event ending exactly at midnight does not appear on the next day.
        final last = e.isAfter(s) ? e.subtract(const Duration(milliseconds: 1)) : s;
        if (!s.isBefore(to) || last.isBefore(from)) return;
        out.add(Occurrence(ev, index, s, e, dayKey(s), dayKey(last)));
      }

      if (rule == null) {
        emit(0, start);
        continue;
      }
      // shortcut: series follow the device's time zone (no TZID stored); add a tzid field with CalDAV.
      DateTime local(int y, int m, int d) =>
          DateTime(y, m, d, start.hour, start.minute, start.second, start.millisecond);
      _series(
        rule,
        start,
        local,
        (t, i) {
          final untilAt = rule.untilAt;
          if (untilAt != null
              ? t.isAfter(untilAt)
              : rule.until != null && dayKey(t).compareTo(rule.until!) > 0) {
            return false;
          }
          if (!t.isBefore(to)) return false;
          emit(i, t);
          return true;
        },
        fromDay,
        length.inDays + 1,
      );
    }
  }
  out.sort((a, b) {
    final d = a.firstDay.compareTo(b.firstDay);
    if (d != 0) return d;
    if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
    return a.start.compareTo(b.start);
  });
  return out;
}

enum Ends { never, until, count }

/// The editor's fields. Days are day keys; times in the device time zone.
class Draft {
  Draft({
    required this.title,
    required this.allDay,
    required this.start,
    required this.end,
    required this.calendar,
    this.repeat,
    this.ends = Ends.never,
    required this.until,
    this.count = 10,
    this.location = '',
    this.description = '',
  });

  String title;
  bool allDay;

  /// Timed: local start and end. All-day: local midnight of the first and of the last day (inclusive).
  DateTime start;
  DateTime end;
  String calendar;
  Freq? repeat;
  Ends ends;
  String until;
  int count;
  String location;
  String description;

  /// A one-hour event on [day]: from the next full hour today, from 9:00 another day.
  factory Draft.on(String day, String calendar, {DateTime? now}) {
    final clock = now ?? DateTime.now();
    final d = fromKey(day);
    // Wall-clock hours from parts: midnight + 9 h is 10:00 on a DST day.
    var start = DateTime(d.year, d.month, d.day, 9);
    if (day == dayKey(clock)) {
      start = DateTime(clock.year, clock.month, clock.day, clock.hour + 1);
      if (dayKey(start) != day) start = DateTime(d.year, d.month, d.day, 23);
    }
    return Draft(
      title: '',
      allDay: false,
      start: start,
      end: start.add(const Duration(hours: 1)),
      calendar: calendar,
      until: addDays(day, 30),
    );
  }

  factory Draft.of(RecordModel ev) {
    final allDay = ev.getBoolValue('all_day');
    final rrule = ev.getStringValue('rrule');
    final rule = rrule.isEmpty ? null : parseRule(rrule, allDay: allDay);
    final DateTime start;
    final DateTime end;
    if (allDay) {
      start = fromKey(allDayKey(ev.getStringValue('start')));
      end = fromKey(addDays(allDayKey(ev.getStringValue('end')), -1));
    } else {
      start = fromPb(ev.getStringValue('start')).toLocal();
      end = fromPb(ev.getStringValue('end')).toLocal();
    }
    return Draft(
      title: ev.getStringValue('title'),
      allDay: allDay,
      start: start,
      end: end,
      calendar: ev.getStringValue('calendar'),
      repeat: rule?.freq,
      ends: rule?.count != null
          ? Ends.count
          : rule?.until != null
          ? Ends.until
          : Ends.never,
      until: rule?.until ?? addDays(dayKey(start), 30),
      count: rule?.count ?? 10,
      location: ev.getStringValue('location'),
      description: ev.getStringValue('description'),
    );
  }

  /// Moving the start moves the end with it, so the event keeps its length.
  void moveStart(DateTime to) {
    if (allDay) {
      // Whole days, counted on the calendar: a DST night is 23 or 25 hours long.
      final days = daysBetween(dayKey(start), dayKey(end));
      start = to;
      end = fromKey(addDays(dayKey(to), days < 0 ? 0 : days));
      return;
    }
    final length = end.difference(start);
    start = to;
    end = to.add(length.isNegative ? Duration.zero : length);
  }

  /// Switching all-day off on an event that has no times yet gives it 9:00 to 10:00, like the web.
  void setAllDay(bool value) {
    allDay = value;
    bool midnight(DateTime t) => t.hour == 0 && t.minute == 0;
    if (!value && midnight(start) && midnight(end)) {
      start = DateTime(start.year, start.month, start.day, 9);
      end = DateTime(end.year, end.month, end.day, 10);
    }
  }

  /// null when valid, else the field in error: 'title', 'end', 'until' or 'count'.
  String? validate() {
    if (title.trim().isEmpty) return 'title';
    if (allDay ? dayKey(end).compareTo(dayKey(start)) < 0 : end.isBefore(start)) return 'end';
    if (repeat != null && ends == Ends.until && until.compareTo(dayKey(start)) < 0) return 'until';
    if (repeat != null && ends == Ends.count && (count < 1 || count > 999)) return 'count';
    return null;
  }

  Map<String, dynamic> toRecord() => {
    'title': title.trim(),
    'all_day': allDay,
    'start': allDay ? allDayPb(dayKey(start)) : toPb(start),
    'end': allDay ? allDayPb(addDays(dayKey(end), 1)) : toPb(end),
    'rrule': formatRule(
      repeat == null
          ? null
          : Rule(
              repeat!,
              count: ends == Ends.count ? count : null,
              until: ends == Ends.until ? until : null,
            ),
      allDay: allDay,
    ),
    'calendar': calendar,
    'location': location.trim(),
    'description': description,
  };
}
