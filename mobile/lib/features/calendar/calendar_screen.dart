import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../core/calendar.dart';
import '../../core/session.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../ui/shell.dart';
import '../files/file_actions.dart';
import '../files/tags.dart';

const _agendaDays = 30;

/// The user's events: an agenda of the coming days, or a month grid with the chosen day's events.
/// Kept current by realtime updates while the screen is open.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.session, this.api, this.now});

  final Session session;

  /// Replaced in tests.
  final CalendarApi? api;
  final DateTime Function()? now;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late final CalendarApi _api = widget.api ?? CalendarApi(widget.session);
  List<RecordModel>? _calendars;
  List<RecordModel>? _events;
  bool _failed = false;
  bool _month = false;
  late String _today = _todayKey();
  late String _selected = _today;
  void Function()? _stop;

  /// Realtime messages received while a load runs, applied on top of its result.
  List<CalendarEvent>? _buffer;

  // Back in the app the next morning: "today" moves on.
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onResume: () {
      if (mounted) setState(() {});
    },
  );

  String _todayKey() => dayKey((widget.now ?? DateTime.now)());

  @override
  void initState() {
    super.initState();
    _lifecycle;
    _api.watch(_onEvent).then((stop) => mounted ? _stop = stop : stop()).catchError((Object _) {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Needs the localized name of the first calendar.
    if (_calendars == null && !_failed) unawaited(_load());
  }

  @override
  void dispose() {
    _stop?.call();
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final name = AppLocalizations.of(context).calendarDefaultName;
    _buffer = [];
    try {
      final results = await Future.wait([_api.calendars(name), _api.events()]);
      final pending = _buffer ?? const <CalendarEvent>[];
      _buffer = null;
      if (!mounted) return;
      setState(() {
        _calendars = results[0];
        _events = results[1];
        _failed = false;
        pending.forEach(_apply);
      });
    } catch (_) {
      _buffer = null;
      if (mounted) setState(() => _failed = true);
    }
  }

  List<RecordModel> _replace(List<RecordModel>? list, RecordModel r, {bool remove = false}) => [
    for (final x in list ?? <RecordModel>[])
      if (x.id != r.id) x,
    if (!remove) r,
  ];

  void _onEvent(CalendarEvent e) {
    if (!mounted) return;
    final buffer = _buffer;
    if (buffer != null) {
      buffer.add(e);
      return;
    }
    if (_events == null) return;
    setState(() => _apply(e));
  }

  /// Applies a realtime message; late echoes of older versions are ignored.
  void _apply(CalendarEvent e) {
    final remove = e.action == 'delete';
    final isCalendar = e.collection == 'calendars';
    final list = isCalendar ? _calendars : _events;
    if (!remove) {
      final known = list?.where((x) => x.id == e.record.id).firstOrNull;
      if (known != null &&
          known.getStringValue('updated').compareTo(e.record.getStringValue('updated')) >= 0) {
        return;
      }
    }
    if (isCalendar) {
      _calendars = _replace(_calendars, e.record, remove: remove);
      if (remove) {
        _events = _events?.where((x) => x.getStringValue('calendar') != e.record.id).toList();
      }
    } else {
      _events = _replace(_events, e.record, remove: remove);
    }
  }

  Future<void> _edit({RecordModel? event, String? day}) async {
    final cals = _calendars;
    if (cals == null || cals.isEmpty) return;
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => EventEditorScreen(
          api: _api,
          calendars: cals,
          event: event,
          day: day ?? _today,
          now: widget.now?.call(),
          onSaved: (r) {
            if (mounted) setState(() => _events = _replace(_events, r));
          },
          onDeleted: (id) {
            if (mounted) setState(() => _events = _events?.where((x) => x.id != id).toList());
          },
        ),
      ),
    );
  }

  (Color, Color) _tone(AlcoveColors c, RecordModel ev) {
    final cal = _calendars?.where((x) => x.id == ev.getStringValue('calendar')).firstOrNull;
    return tagPalette(c, cal?.getStringValue('color') ?? 'gray');
  }

  void _shiftMonth(int n) {
    final d = fromKey(_selected);
    setState(() => _selected = dayKey(DateTime(d.year, d.month + n, 1)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final events = _events;
    // Recomputed on every build (and on resume), so the agenda starts on the real today.
    _today = _todayKey();

    final List<Widget> content;
    if (_failed && events == null) {
      content = [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.cloud_off_outlined,
            title: l.loadFailed,
            action: OutlinedButton(onPressed: _load, child: Text(l.retry)),
          ),
        ),
      ];
    } else if (events == null) {
      content = [
        SliverList.builder(
          itemCount: 4,
          itemBuilder: (_, _) => const Padding(
            padding: EdgeInsets.symmetric(horizontal: AlcoveSpace.s4, vertical: AlcoveSpace.s2),
            child: SizedBox(height: 64, child: Skeleton(radius: AlcoveRadius.lg)),
          ),
        ),
      ];
    } else if (_month) {
      content = _monthSlivers(context, events);
    } else {
      content = _agendaSlivers(context, events);
    }

    return Scaffold(
      backgroundColor: c.bg,
      body: RefreshIndicator(
        onRefresh: _load,
        edgeOffset: LargeTitleAppBar.edgeOffset(context),
        child: CustomScrollView(
          slivers: [
            LargeTitleAppBar(
              title: l.tabCalendar,
              actions: shellActions(context),
            ),
            // The view switch and "Today", under the title (the top bar keeps search and account).
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AlcoveSpace.s4,
                  AlcoveSpace.s1,
                  AlcoveSpace.s2,
                  AlcoveSpace.s4,
                ),
                child: Row(
                  children: [
                    SegmentedSwitch<bool>(
                      value: _month,
                      onChanged: (v) => setState(() => _month = v),
                      segments: [
                        (false, l.calendarAgenda, const Key('calendarAgenda')),
                        (true, l.calendarMonth, const Key('calendarView')),
                      ],
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _today = _todayKey();
                        _selected = _today;
                      }),
                      icon: const Icon(Icons.today_outlined),
                      label: Text(l.calendarToday),
                    ),
                  ],
                ),
              ),
            ),
            ...content,
            SliverToBoxAdapter(
              child: SizedBox(
                height: AlcoveSpace.s8 + AlcoveSpace.s5 + MediaQuery.paddingOf(context).bottom,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _calendars == null
          ? null
          : FloatingActionButton.extended(
              key: const Key('newEvent'),
              onPressed: () => _edit(day: _month ? _selected : _today),
              icon: const Icon(Icons.add),
              label: Text(l.calendarNewEvent),
            ),
    );
  }

  Widget _rows(BuildContext context, List<Occurrence> list, String day) => InsetGroup(
    children: [
      for (final o in list)
        EventRow(
          occurrence: o,
          day: day,
          tone: _tone(context.colors, o.event).$1,
          onTap: () => _edit(event: o.event),
        ),
    ],
  );

  String _dayTitle(BuildContext context, String day) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final text = DateFormat.MMMMEEEEd(locale).format(fromKey(day));
    final cap = text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
    return day == _today ? '${l.calendarToday} · $cap' : cap;
  }

  List<Widget> _agendaSlivers(BuildContext context, List<RecordModel> events) {
    final l = AppLocalizations.of(context);
    final occs = expand(events, _today, addDays(_today, _agendaDays));
    final days = [
      for (var i = 0; i < _agendaDays; i++) addDays(_today, i),
    ].map((d) => (d, occs.where((o) => o.covers(d)).toList())).where((x) => x.$2.isNotEmpty);
    if (days.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(icon: Icons.event_outlined, title: l.calendarEmpty),
        ),
      ];
    }
    return [
      SliverList.list(
        children: [
          for (final (day, list) in days) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AlcoveSpace.s4),
              child: SectionHeader(title: _dayTitle(context, day)),
            ),
            _rows(context, list, day),
          ],
        ],
      ),
    ];
  }

  List<Widget> _monthSlivers(BuildContext context, List<RecordModel> events) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final loc = MaterialLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final first = fromKey('${_selected.substring(0, 8)}01');
    final lead = (first.weekday % 7 - loc.firstDayOfWeekIndex + 7) % 7;
    final start = addDays(dayKey(first), -lead);
    final nextMonth = dayKey(DateTime(first.year, first.month + 1, 1));
    final weeks = <List<String>>[];
    for (var d = start; d.compareTo(nextMonth) < 0; d = addDays(d, 7)) {
      weeks.add([for (var i = 0; i < 7; i++) addDays(d, i)]);
    }
    final occs = expand(events, start, addDays(start, weeks.length * 7));
    final selectedList = occs.where((o) => o.covers(_selected)).toList();
    final title = DateFormat.yMMMM(locale).format(first);
    final weekdays = [
      for (var i = 0; i < 7; i++) loc.narrowWeekdays[(loc.firstDayOfWeekIndex + i) % 7],
    ];

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AlcoveSpace.s2, 0, AlcoveSpace.s2, AlcoveSpace.s2),
          child: Row(
            children: [
              IconButton(
                tooltip: l.calendarPreviousMonth,
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _shiftMonth(-1),
              ),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    title[0].toUpperCase() + title.substring(1),
                    textAlign: TextAlign.center,
                    style: context.text.titleMedium,
                  ),
                ),
              ),
              IconButton(
                tooltip: l.calendarNextMonth,
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _shiftMonth(1),
              ),
            ],
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AlcoveSpace.s3),
          child: Column(
            children: [
              ExcludeSemantics(
                child: Row(
                  children: [
                    for (final w in weekdays)
                      Expanded(
                        child: Text(
                          w,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: c.textMuted, fontSize: AlcoveFont.sizeXs),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AlcoveSpace.s1),
              for (final week in weeks)
                Row(
                  children: [
                    for (final day in week)
                      Expanded(
                        child: _DayCell(
                          day: day,
                          label: l.calendarDayEvents(
                            DateFormat.MMMMEEEEd(locale).format(fromKey(day)),
                          ),
                          inMonth: day.substring(0, 7) == _selected.substring(0, 7),
                          today: day == _today,
                          selected: day == _selected,
                          dots: [
                            for (final o in occs.where((o) => o.covers(day)).take(3))
                              _tone(c, o.event).$1,
                          ],
                          onTap: () => setState(() => _selected = day),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AlcoveSpace.s4,
            AlcoveSpace.s5,
            AlcoveSpace.s4,
            0,
          ),
          child: SectionHeader(title: _dayTitle(context, _selected)),
        ),
      ),
      SliverToBoxAdapter(
        child: selectedList.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: AlcoveSpace.s5),
                child: Text(l.calendarDayEmpty, style: TextStyle(color: c.textMuted)),
              )
            : _rows(context, selectedList, _selected),
      ),
    ];
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.label,
    required this.inMonth,
    required this.today,
    required this.selected,
    required this.dots,
    required this.onTap,
  });

  final String day;
  final String label;
  final bool inMonth;
  final bool today;
  final bool selected;
  final List<Color> dots;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = today ? c.accentContrast : (inMonth ? c.text : c.textMuted);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AlcoveRadius.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Container(
            margin: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              color: selected ? c.accentSubtle : null,
              borderRadius: BorderRadius.circular(AlcoveRadius.md),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: today ? BoxDecoration(color: c.accent, shape: BoxShape.circle) : null,
                  child: Text(
                    '${int.parse(day.substring(8))}',
                    style: TextStyle(
                      color: fg,
                      fontSize: AlcoveFont.sizeSm,
                      fontWeight: today || selected ? AlcoveFont.semibold : AlcoveFont.regular,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                SizedBox(
                  height: 6,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final d in dots)
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          decoration: BoxDecoration(color: d, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One occurrence in a list: calendar colour, title, time and place.
class EventRow extends StatelessWidget {
  const EventRow({
    super.key,
    required this.occurrence,
    required this.day,
    required this.tone,
    required this.onTap,
  });

  final Occurrence occurrence;
  final String day;
  final Color tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final loc = MaterialLocalizations.of(context);
    final o = occurrence;
    String time(DateTime t) => loc.formatTimeOfDay(
      TimeOfDay.fromDateTime(t),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final when = o.allDay
        ? l.calendarAllDay
        : o.firstDay == o.lastDay
        ? '${time(o.start)} – ${time(o.end)}'
        : day == o.firstDay
        ? '${time(o.start)} →'
        : day == o.lastDay
        ? '→ ${time(o.end)}'
        : l.calendarAllDay;
    final location = o.event.getStringValue('location');
    final repeats = o.event.getStringValue('rrule').isNotEmpty;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AlcoveSpace.s4, vertical: AlcoveSpace.s3),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 36,
                decoration: BoxDecoration(
                  color: tone,
                  borderRadius: BorderRadius.circular(AlcoveRadius.full),
                ),
              ),
              const SizedBox(width: AlcoveSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      o.event.getStringValue('title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.text,
                        fontSize: AlcoveFont.sizeMd,
                        fontWeight: AlcoveFont.medium,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [when, if (location.isNotEmpty) location].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.textMuted, fontSize: AlcoveFont.sizeSm),
                    ),
                  ],
                ),
              ),
              if (repeats)
                Icon(Icons.repeat, size: 18, color: c.textMuted, semanticLabel: l.calendarRepeats),
            ],
          ),
        ),
      ),
    );
  }
}

/// Creates or edits one event. Recurring events are edited as a whole series.
class EventEditorScreen extends StatefulWidget {
  const EventEditorScreen({
    super.key,
    required this.api,
    required this.calendars,
    required this.day,
    required this.onSaved,
    required this.onDeleted,
    this.event,
    this.now,
  });

  final CalendarApi api;
  final List<RecordModel> calendars;
  final RecordModel? event;
  final String day;
  final void Function(RecordModel) onSaved;
  final void Function(String id) onDeleted;
  final DateTime? now;

  @override
  State<EventEditorScreen> createState() => _EventEditorScreenState();
}

class _EventEditorScreenState extends State<EventEditorScreen> {
  late final Draft _d = widget.event != null
      ? Draft.of(widget.event!)
      : Draft.on(widget.day, widget.calendars.first.id, now: widget.now);
  late final _title = TextEditingController(text: _d.title);
  late final _location = TextEditingController(text: _d.location);
  late final _description = TextEditingController(text: _d.description);
  late final _count = TextEditingController(text: '${_d.count}');
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _description.dispose();
    _count.dispose();
    super.dispose();
  }

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  // shortcut: edits and deletes apply to the whole series (no EXDATE / RECURRENCE-ID exceptions);
  // add per-occurrence exceptions with CalDAV (ADR 0028).
  Future<void> _save() async {
    _d
      ..title = _title.text
      ..location = _location.text
      ..description = _description.text
      ..count = int.tryParse(_count.text) ?? 0;
    final error = _d.validate();
    setState(() => _error = error);
    if (error != null || _busy) return;
    setState(() => _busy = true);
    try {
      final ev = widget.event;
      final saved = ev == null
          ? await widget.api.create(_d.toRecord())
          : await widget.api.update(ev.id, _d.toRecord());
      widget.onSaved(saved);
      _leave();
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _snack(errorMessage(context, e));
      }
    }
  }

  Future<void> _delete() async {
    final ev = widget.event;
    if (ev == null) return;
    final l = AppLocalizations.of(context);
    final name = ev.getStringValue('title');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.calendarDeleteEvent),
        content: Text(
          ev.getStringValue('rrule').isEmpty
              ? l.calendarDeleteEventBody(name)
              : l.calendarDeleteSeriesBody(name),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.calendarDeleteEvent),
          ),
        ],
      ),
    );
    if (ok != true || !mounted || _busy) return;
    setState(() => _busy = true);
    try {
      await widget.api.delete(ev.id);
      widget.onDeleted(ev.id);
      _leave();
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _snack(errorMessage(context, e));
      }
    }
  }

  /// Closes the editor once, and only if it is still on top: a back press during the save must not
  /// make this pop the calendar itself.
  void _leave() {
    if (mounted && ModalRoute.of(context)?.isCurrent == true) Navigator.of(context).pop();
  }

  Future<DateTime?> _pickDate(DateTime initial) => showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(1900),
    lastDate: DateTime(2200),
  );

  Future<TimeOfDay?> _pickTime(DateTime initial) =>
      showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));

  DateTime _with(DateTime d, {DateTime? date, TimeOfDay? time}) => DateTime(
    (date ?? d).year,
    (date ?? d).month,
    (date ?? d).day,
    time?.hour ?? d.hour,
    time?.minute ?? d.minute,
  );

  Future<void> _editStart({required bool time}) async {
    if (time) {
      final t = await _pickTime(_d.start);
      if (t != null) setState(() => _d.moveStart(_with(_d.start, time: t)));
    } else {
      final d = await _pickDate(_d.start);
      if (d != null) setState(() => _d.moveStart(_with(_d.start, date: d)));
    }
  }

  Future<void> _editEnd({required bool time}) async {
    if (time) {
      final t = await _pickTime(_d.end);
      if (t != null) setState(() => _d.end = _with(_d.end, time: t));
    } else {
      final d = await _pickDate(_d.end);
      if (d != null) setState(() => _d.end = _with(_d.end, date: d));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final loc = MaterialLocalizations.of(context);
    String date(DateTime d) => DateFormat.yMMMEd(locale).format(d);
    String time(DateTime d) => loc.formatTimeOfDay(
      TimeOfDay.fromDateTime(d),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final errors = {
      'title': l.calendarErrorTitle,
      'end': l.calendarErrorEnd,
      'until': l.calendarErrorUntil,
      'count': l.calendarErrorCount,
    };
    String? err(String key) => _error == key ? errors[key] : null;

    Widget when(String label, DateTime value, Future<void> Function({required bool time}) edit) =>
        Padding(
          padding: const EdgeInsets.only(bottom: AlcoveSpace.s2),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                child: Text(label, style: TextStyle(color: c.textMuted)),
              ),
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: () => edit(time: false),
                    child: Text(date(value), semanticsLabel: '$label, ${date(value)}'),
                  ),
                ),
              ),
              if (!_d.allDay)
                TextButton(
                  onPressed: () => edit(time: true),
                  child: Text(time(value), semanticsLabel: '$label, ${time(value)}'),
                ),
            ],
          ),
        );

    return PopScope(
      // No leaving while a save or delete is on its way.
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: c.surface,
        appBar: AppBar(
          backgroundColor: c.surface,
          leading: CloseButton(onPressed: () => Navigator.of(context).maybePop()),
          title: Text(widget.event == null ? l.calendarNewEvent : l.calendarEditEvent),
          actions: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AlcoveSpace.s2),
              child: FilledButton(
                key: const Key('saveEvent'),
                onPressed: _busy ? null : _save,
                child: Text(l.save),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            AlcoveSpace.s4,
            AlcoveSpace.s2,
            AlcoveSpace.s4,
            AlcoveSpace.s8,
          ),
          children: [
            TextField(
              key: const Key('eventTitle'),
              controller: _title,
              autofocus: widget.event == null,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l.calendarEventTitle,
                errorText: err('title'),
                counterText: '',
              ),
            ),
            const SizedBox(height: AlcoveSpace.s2),
            SwitchListTile(
              key: const Key('allDay'),
              contentPadding: EdgeInsets.zero,
              title: Text(l.calendarAllDay),
              value: _d.allDay,
              onChanged: (v) => setState(() => _d.setAllDay(v)),
            ),
            when(l.calendarStarts, _d.start, _editStart),
            when(l.calendarEnds, _d.end, _editEnd),
            if (err('end') case final e?)
              Padding(
                padding: const EdgeInsets.only(bottom: AlcoveSpace.s2),
                child: Text(
                  e,
                  style: TextStyle(color: c.danger, fontSize: AlcoveFont.sizeSm),
                ),
              ),
            const SizedBox(height: AlcoveSpace.s2),
            if (widget.calendars.length > 1) ...[
              DropdownButtonFormField<String>(
                initialValue: _d.calendar,
                decoration: InputDecoration(labelText: l.calendarCalendar),
                items: [
                  for (final cal in widget.calendars)
                    DropdownMenuItem(value: cal.id, child: Text(cal.getStringValue('name'))),
                ],
                onChanged: (v) => setState(() => _d.calendar = v ?? _d.calendar),
              ),
              const SizedBox(height: AlcoveSpace.s4),
            ],
            DropdownButtonFormField<Freq?>(
              key: const Key('repeat'),
              initialValue: _d.repeat,
              decoration: InputDecoration(labelText: l.calendarRepeat),
              items: [
                DropdownMenuItem(value: null, child: Text(l.calendarRepeatNone)),
                DropdownMenuItem(value: Freq.daily, child: Text(l.calendarRepeatDaily)),
                DropdownMenuItem(value: Freq.weekly, child: Text(l.calendarRepeatWeekly)),
                DropdownMenuItem(value: Freq.monthly, child: Text(l.calendarRepeatMonthly)),
                DropdownMenuItem(value: Freq.yearly, child: Text(l.calendarRepeatYearly)),
              ],
              onChanged: (v) => setState(() => _d.repeat = v),
            ),
            if (_d.repeat != null) ...[
              const SizedBox(height: AlcoveSpace.s4),
              DropdownButtonFormField<Ends>(
                initialValue: _d.ends,
                decoration: InputDecoration(labelText: l.calendarRepeatEnds),
                items: [
                  DropdownMenuItem(value: Ends.never, child: Text(l.calendarEndsNever)),
                  DropdownMenuItem(value: Ends.until, child: Text(l.calendarEndsUntil)),
                  DropdownMenuItem(value: Ends.count, child: Text(l.calendarEndsCount)),
                ],
                onChanged: (v) => setState(() => _d.ends = v ?? Ends.never),
              ),
              if (_d.ends == Ends.until)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.calendarUntil),
                  subtitle: err('until') == null
                      ? null
                      : Text(err('until')!, style: TextStyle(color: c.danger)),
                  trailing: TextButton(
                    onPressed: () async {
                      final d = await _pickDate(fromKey(_d.until));
                      if (d != null) setState(() => _d.until = dayKey(d));
                    },
                    child: Text(date(fromKey(_d.until))),
                  ),
                ),
              if (_d.ends == Ends.count) ...[
                const SizedBox(height: AlcoveSpace.s4),
                TextField(
                  controller: _count,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l.calendarCount,
                    errorText: err('count'),
                  ),
                ),
              ],
              if (widget.event?.getStringValue('rrule').isNotEmpty ?? false)
                Padding(
                  padding: const EdgeInsets.only(top: AlcoveSpace.s3),
                  child: Row(
                    children: [
                      Icon(Icons.repeat, size: 18, color: c.textMuted),
                      const SizedBox(width: AlcoveSpace.s2),
                      Expanded(
                        child: Text(
                          l.calendarSeriesNote,
                          style: TextStyle(color: c.textMuted, fontSize: AlcoveFont.sizeSm),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: AlcoveSpace.s4),
            TextField(
              controller: _location,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: l.calendarLocation,
                counterText: '',
                prefixIcon: const Icon(Icons.place_outlined),
              ),
            ),
            const SizedBox(height: AlcoveSpace.s4),
            TextField(
              controller: _description,
              maxLength: 10000,
              minLines: 3,
              maxLines: null,
              decoration: InputDecoration(labelText: l.calendarDescription, counterText: ''),
            ),
            if (widget.event != null) ...[
              const SizedBox(height: AlcoveSpace.s6),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  key: const Key('deleteEvent'),
                  style: TextButton.styleFrom(foregroundColor: c.danger),
                  onPressed: _busy ? null : _delete,
                  icon: const Icon(Icons.delete_outline),
                  label: Text(l.calendarDeleteEvent),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
