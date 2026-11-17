import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/client.dart';
import '../../app/session.dart';
import '../../l10n/gen/app_localizations.dart';
import '../blocks/interactive.dart' show blockLines, keyValue;
import '../charts/chart.dart';
import '../doc/doc_page.dart';
import '../entity/entity_page.dart';

// The calendar (ADR-0089): the project's dates – maintenance, cards with a
// due date, date fields of entries – and external calendars, as a month or
// a list. The same widgets show the project tab, calendar documents and the
// ```calendar block (web/src/components/calendar.ts).

/// The sources of dates, in the order the chips show them.
const calSources = ['maintenance', 'tasks', 'entities', 'external'];

const _sourceColor = {
  'maintenance': 'orange',
  'tasks': 'blue',
  'entities': 'purple',
  'external': 'gray',
};

const _sourceIcon = {
  'maintenance': LucideIcons.wrench,
  'tasks': LucideIcons.squareKanban,
  'entities': LucideIcons.calendarClock,
  'external': LucideIcons.calendarDays,
};

/// Names of the sources in block sources (English and German).
const _sourceNames = {
  'maintenance': 'maintenance',
  'wartung': 'maintenance',
  'tasks': 'tasks',
  'cards': 'tasks',
  'karten': 'tasks',
  'entities': 'entities',
  'entries': 'entities',
  'einträge': 'entities',
  'external': 'external',
  'extern': 'external',
};

/// What a calendar shows: the view and the filters (a calendar document's
/// content or a ```calendar block).
class CalendarSpec {
  const CalendarSpec(
      {this.view = 'month',
      this.sources = const [],
      this.kinds = const [],
      this.calendars = const [],
      this.days,
      this.doc = ''});

  /// "month" or "list".
  final String view;
  final List<String> sources, kinds, calendars;

  /// Days ahead in the list (null: 60).
  final int? days;

  /// The calendar document whose filters apply (block line "calendar:").
  final String doc;

  int get daysAhead => (days ?? 60).clamp(1, 366);

  /// Reads a ```calendar block; unknown lines are ignored.
  static CalendarSpec parse(String src) {
    var view = 'month', doc = '';
    int? days;
    var sources = <String>[], kinds = <String>[];
    List<String> list(String v) => [
          for (final x in v.split(','))
            if (x.trim().isNotEmpty) x.trim()
        ];
    for (final l in blockLines(src)) {
      final kv = keyValue(l, [
        'view', 'ansicht', 'sources', 'quellen', 'kinds', 'arten', //
        'calendar', 'kalender', 'days', 'tage'
      ]);
      if (kv == null) continue;
      switch (kv.$1) {
        case 'view' || 'ansicht':
          view = RegExp(r'^(list|liste)$', caseSensitive: false).hasMatch(kv.$2)
              ? 'list'
              : 'month';
        case 'sources' || 'quellen':
          sources = [
            for (final s in list(kv.$2))
              if (_sourceNames[s.toLowerCase()] case final n?) n
          ];
        case 'kinds' || 'arten':
          kinds = list(kv.$2);
        case 'calendar' || 'kalender':
          doc = kv.$2;
        default:
          days = int.tryParse(kv.$2)?.clamp(1, 366);
      }
    }
    return CalendarSpec(
        view: view, sources: sources, kinds: kinds, days: days, doc: doc);
  }

  /// A calendar document's content.
  factory CalendarSpec.fromJson(Map m, {String doc = ''}) {
    List<String> strings(Object? v) =>
        [for (final x in (v as List? ?? const [])) '$x'];
    return CalendarSpec(
        view: m['view'] == 'list' ? 'list' : 'month',
        sources: strings(m['sources']),
        kinds: strings(m['kinds']),
        calendars: strings(m['calendars']),
        days: (m['days'] as num?)?.toInt(),
        doc: doc);
  }

  CalendarSpec withView(String v) => CalendarSpec(
      view: v,
      sources: sources,
      kinds: kinds,
      calendars: calendars,
      days: days,
      doc: doc);
}

/// One date of the calendar.
class CalEvent {
  CalEvent(
      {required this.id,
      required this.title,
      required this.start,
      required this.end,
      required this.allDay,
      required this.source,
      this.calendar = '',
      this.color = '',
      this.link = '',
      this.entity = '',
      this.kind = '',
      this.attr = '',
      this.done = false,
      this.location = '',
      this.note = '',
      this.url = ''});

  final String id, title, source, calendar, color, link, entity, kind, attr;
  final String location, note, url;

  /// Dates ("2026-11-20") for all-day events, else RFC 3339; end exclusive.
  final String start, end;
  final bool allDay, done;

  factory CalEvent.fromJson(Map m) {
    String s(String k) => '${m[k] ?? ''}';
    return CalEvent(
        id: s('id'),
        title: s('title'),
        start: s('start'),
        end: s('end'),
        allDay: m['allDay'] == true,
        source: s('source'),
        calendar: s('calendar'),
        color: s('color'),
        link: s('link'),
        entity: s('entity'),
        kind: s('kind'),
        attr: s('attr'),
        done: m['done'] == true,
        location: s('location'),
        note: s('note'),
        url: s('url'));
  }

  /// Local start and end of a timed event.
  DateTime? get startTime =>
      allDay ? null : DateTime.tryParse(start)?.toLocal();
  DateTime? get endTime => allDay ? null : DateTime.tryParse(end)?.toLocal();
}

/// An external calendar (CalDAV or iCal) the project reads.
class CalendarInfo {
  CalendarInfo(this.id, this.name, this.kind, this.color, this.writeBack,
      this.syncedAt, this.lastError);
  final String id, name, kind, color, syncedAt, lastError;
  final bool writeBack;

  factory CalendarInfo.fromJson(Map m) => CalendarInfo(
      '${m['id'] ?? ''}',
      '${m['name'] ?? ''}',
      '${m['kind'] ?? ''}',
      '${m['color'] ?? ''}',
      m['writeBack'] == true,
      '${m['syncedAt'] ?? ''}',
      '${m['lastError'] ?? ''}');
}

/// The answer of GET /projects/{p}/calendar.
class CalendarData {
  CalendarData(this.from, this.to, this.events, this.calendars,
      {this.offline = false});
  final String from, to;
  final List<CalEvent> events;
  final List<CalendarInfo> calendars;

  /// From the offline cache.
  final bool offline;

  factory CalendarData.fromJson(Map m, {bool offline = false}) => CalendarData(
      '${m['from'] ?? ''}',
      '${m['to'] ?? ''}',
      [
        for (final e in (m['events'] as List? ?? const []))
          CalEvent.fromJson(e as Map)
      ],
      [
        for (final c in (m['calendars'] as List? ?? const []))
          CalendarInfo.fromJson(c as Map)
      ],
      offline: offline);

  String calendarName(String id) =>
      calendars.where((c) => c.id == id).firstOrNull?.name ?? '';
}

String _pad(int n) => n.toString().padLeft(2, '0');

/// "2026-11-20" of a local day.
String dayKey(DateTime d) => '${d.year}-${_pad(d.month)}-${_pad(d.day)}';

/// The local day of "2026-11-20" (or the date part of a longer string).
DateTime parseDay(String s) {
  final p = s.length >= 10 ? s.substring(0, 10).split('-') : const <String>[];
  if (p.length != 3) return DateTime(1970);
  return DateTime(int.tryParse(p[0]) ?? 1970, int.tryParse(p[1]) ?? 1,
      int.tryParse(p[2]) ?? 1);
}

DateTime _addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// Monday-first weeks covering a month: 6 rows, 42 days.
List<DateTime> monthGrid(int year, int month) {
  final first = DateTime(year, month, 1);
  final start = _addDays(first, -(first.weekday - DateTime.monday));
  return List.generate(42, (i) => _addDays(start, i));
}

/// The local days an event covers (end exclusive), at most 62.
List<String> eventDays(CalEvent e) {
  final DateTime start;
  DateTime end;
  if (e.allDay) {
    start = parseDay(e.start);
    end = parseDay(e.end);
  } else {
    final s = e.startTime, en = e.endTime;
    if (s == null) return const [];
    start = s;
    end = en ?? s;
    // A timed event that ends at midnight does not reach into that day.
    if (end.isAfter(start) && end.hour == 0 && end.minute == 0) {
      end = end.subtract(const Duration(milliseconds: 1));
    }
  }
  final first = DateTime(start.year, start.month, start.day);
  final out = <String>[];
  for (var d = first, i = 0;
      (e.allDay ? d.isBefore(end) : !d.isAfter(end)) && i < 62;
      d = _addDays(d, 1), i++) {
    out.add(dayKey(d));
  }
  return out.isEmpty ? [dayKey(first)] : out;
}

/// The title shown: date fields get their label ("Car · next inspection").
/// The app has no attribute labels yet, so the field name is shown.
String eventLabel(CalEvent e) =>
    e.attr.isEmpty ? e.title : '${e.title} · ${e.attr.replaceAll('_', ' ')}';

/// Events by local day ("2026-11-20"), in the order of the answer.
Map<String, List<CalEvent>> eventsByDay(Iterable<CalEvent> events) {
  final m = <String, List<CalEvent>>{};
  for (final e in events) {
    for (final d in eventDays(e)) {
      (m[d] ??= []).add(e);
    }
  }
  return m;
}

/// The theme colour of an event: its own, else its source's.
Color eventColor(ChartStyle st, CalEvent e) =>
    st.tc(e.color.isNotEmpty ? e.color : _sourceColor[e.source] ?? 'gray');

/// A load of the calendar: the API path and the key it is cached under.
class CalQuery {
  const CalQuery(this.path, this.cacheKey);
  final String path, cacheKey;

  /// The request for [from]..[to] (end exclusive) with the spec's filters;
  /// [range] names the range in the cache key (a list "from today" keeps
  /// its key across days, so it stays readable offline the next day).
  factory CalQuery.of(String project, CalendarSpec spec, DateTime from,
      DateTime to, String range) {
    final q = <String, String>{
      'from': dayKey(from),
      'to': dayKey(to),
      if (spec.doc.isNotEmpty) 'doc': spec.doc,
      if (spec.sources.isNotEmpty) 'sources': spec.sources.join(','),
      if (spec.kinds.isNotEmpty) 'kinds': spec.kinds.join(','),
      if (spec.calendars.isNotEmpty) 'calendars': spec.calendars.join(','),
    };
    final query = Uri(queryParameters: q).query;
    final filters = Uri(
            queryParameters: {...q}
              ..remove('from')
              ..remove('to'))
        .query;
    return CalQuery(
        '/projects/$project/calendar?$query', 'cal:$project:$range:$filters');
  }

  @override
  bool operator ==(Object other) =>
      other is CalQuery && other.path == path && other.cacheKey == cacheKey;

  @override
  int get hashCode => Object.hash(path, cacheKey);
}

/// The calendar of a range, cached offline under the query's key.
final calendarProvider =
    FutureProvider.autoDispose.family<CalendarData, CalQuery>((ref, q) async {
  final c = await ref.watch(clientProvider.future);
  if (c == null) throw OfflineException();
  final cache = await ref.watch(cacheProvider.future);
  try {
    final r = await c.get(q.path);
    if (!r.offline) await cache.put(q.cacheKey, jsonEncode(r.data));
    return CalendarData.fromJson(r.data as Map, offline: r.offline);
  } on OfflineException {
    final hit = await cache.get(q.cacheKey);
    if (hit == null) rethrow;
    return CalendarData.fromJson(jsonDecode(hit) as Map, offline: true);
  }
}, retry: (count, error) => null);

/// Opens the place of an event: an entry, a board (with the card) or a
/// page in the app; external events with an address in the browser.
void openCalEvent(BuildContext context, String project, CalEvent e) {
  final link = e.link.isEmpty ? null : Uri.tryParse(e.link);
  final seg = link?.pathSegments ?? const <String>[];
  if (seg.length == 2 && seg[0] == 'e') {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => EntityPage(project: project, entity: seg[1])));
  } else if (seg.length == 2 && seg[0] == 'd') {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DocPage(
            project: project,
            doc: seg[1],
            task: link!.queryParameters['task'])));
  } else if (e.url.isNotEmpty) {
    final u = Uri.tryParse(e.url);
    if (u != null && (u.scheme == 'https' || u.scheme == 'http')) {
      launchUrl(u, mode: LaunchMode.externalApplication);
    }
  }
}

String _sourceLabel(AppLocalizations t, String s) => switch (s) {
      'maintenance' => t.calSrcMaintenance,
      'tasks' => t.calSrcTasks,
      'entities' => t.calSrcEntities,
      _ => t.calSrcExternal,
    };

/// A calendar as its spec says: month or list.
class CalendarView extends StatelessWidget {
  const CalendarView(
      {super.key,
      required this.project,
      this.spec = const CalendarSpec(),
      this.allChips = false,
      this.today});
  final String project;
  final CalendarSpec spec;

  /// Shows a chip for every source, even those without dates.
  final bool allChips;

  /// Today (for tests); null: now.
  final DateTime? today;

  @override
  Widget build(BuildContext context) => spec.view == 'list'
      ? CalendarList(
          project: project, spec: spec, allChips: allChips, today: today)
      : CalendarMonth(
          project: project, spec: spec, allChips: allChips, today: today);
}

/// Sources switched off with the chips.
mixin _SourceFilter<W extends ConsumerStatefulWidget> on ConsumerState<W> {
  final Set<String> off = {};

  Iterable<CalEvent> shown(CalendarData? d) =>
      (d?.events ?? const <CalEvent>[]).where((e) => !off.contains(e.source));

  Widget chips(
      BuildContext context, CalendarSpec spec, CalendarData? d, bool all) {
    final t = AppLocalizations.of(context);
    final st = ChartStyle.of(context);
    final present = {for (final e in d?.events ?? const <CalEvent>[]) e.source};
    final srcs = [
      for (final s in calSources)
        if ((spec.sources.isEmpty || spec.sources.contains(s)) &&
            (all || present.contains(s)))
          s
    ];
    if (srcs.length < 2) return const SizedBox.shrink();
    return Semantics(
      label: t.calSources,
      child: Wrap(spacing: 6, runSpacing: 4, children: [
        for (final s in srcs)
          FilterChip(
            visualDensity: VisualDensity.compact,
            avatar:
                Icon(_sourceIcon[s], size: 16, color: st.tc(_sourceColor[s]!)),
            label: Text(_sourceLabel(t, s)),
            selected: !off.contains(s),
            showCheckmark: false,
            onSelected: (on) => setState(() => on ? off.remove(s) : off.add(s)),
          ),
      ]),
    );
  }

  /// Loading, offline note or the problem above the calendar.
  Widget status(
      BuildContext context, AsyncValue<CalendarData> v, VoidCallback retry) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    if (v.isLoading) return const LinearProgressIndicator();
    if (v.hasError) {
      return Row(children: [
        Icon(
            v.error is OfflineException
                ? LucideIcons.wifiOff
                : LucideIcons.circleAlert,
            size: 16,
            color: cs.error),
        const SizedBox(width: 8),
        Expanded(
            child:
                Text(v.error is OfflineException ? t.notCached : t.calFailed)),
        TextButton(onPressed: retry, child: Text(t.retry)),
      ]);
    }
    if (v.value?.offline == true) {
      return Row(children: [
        Icon(LucideIcons.wifiOff, size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
            child: Text(t.offline,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))),
      ]);
    }
    return const SizedBox.shrink();
  }
}

/// A month: Monday-first grid of six weeks with the dates of each day;
/// tapping a day lists its dates below.
class CalendarMonth extends ConsumerStatefulWidget {
  const CalendarMonth(
      {super.key,
      required this.project,
      this.spec = const CalendarSpec(),
      this.allChips = false,
      this.today});
  final String project;
  final CalendarSpec spec;
  final bool allChips;
  final DateTime? today;

  @override
  ConsumerState<CalendarMonth> createState() => _CalendarMonthState();
}

class _CalendarMonthState extends ConsumerState<CalendarMonth>
    with _SourceFilter {
  late DateTime _today, _month;
  late String _selected;

  @override
  void initState() {
    super.initState();
    final now = widget.today ?? DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _month = DateTime(_today.year, _today.month);
    _selected = dayKey(_today);
  }

  void _shift(int n) => setState(() {
        if (n == 0) {
          _month = DateTime(_today.year, _today.month);
          _selected = dayKey(_today);
        } else {
          _month = DateTime(_month.year, _month.month + n);
          _selected = _month.year == _today.year && _month.month == _today.month
              ? dayKey(_today)
              : dayKey(_month);
        }
      });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final ml = MaterialLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final grid = monthGrid(_month.year, _month.month);
    final q = CalQuery.of(widget.project, widget.spec, grid.first,
        _addDays(grid.last, 1), '${dayKey(grid.first)}..${dayKey(grid.last)}');
    final v = ref.watch(calendarProvider(q));
    final byDay = eventsByDay(shown(v.value));
    // Monday first; narrowWeekdays starts on Sunday.
    final wd = [for (var i = 1; i <= 7; i++) ml.narrowWeekdays[i % 7]];
    final selDay = parseDay(_selected);
    final sel = byDay[_selected] ?? const <CalEvent>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          IconButton(
              tooltip: t.calPrev,
              icon: const Icon(LucideIcons.chevronLeft, size: 18),
              onPressed: () => _shift(-1)),
          Expanded(
            child: Text(ml.formatMonthYear(_month),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
          ),
          IconButton(
              tooltip: t.calNext,
              icon: const Icon(LucideIcons.chevronRight, size: 18),
              onPressed: () => _shift(1)),
          TextButton(onPressed: () => _shift(0), child: Text(t.calToday)),
        ]),
        chips(context, widget.spec, v.value, widget.allChips),
        const SizedBox(height: 4),
        status(context, v, () => ref.invalidate(calendarProvider(q))),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: cs.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            Row(children: [
              for (final d in wd)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(d,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11.5, color: cs.onSurfaceVariant)),
                  ),
                ),
            ]),
            for (var w = 0; w < 6; w++)
              Row(children: [
                for (final d in grid.sublist(w * 7, w * 7 + 7))
                  Expanded(
                    child: _DayCell(
                      day: d,
                      events: byDay[dayKey(d)] ?? const [],
                      outside: d.month != _month.month,
                      today: dayKey(d) == dayKey(_today),
                      selected: dayKey(d) == _selected,
                      onTap: () => setState(() => _selected = dayKey(d)),
                    ),
                  ),
              ]),
          ]),
        ),
        const SizedBox(height: 12),
        Text(ml.formatFullDate(selDay),
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        if (v.hasValue && sel.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child:
                Text(t.calNone, style: TextStyle(color: cs.onSurfaceVariant)),
          ),
        for (final e in sel)
          CalEventTile(project: widget.project, event: e, data: v.value),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell(
      {required this.day,
      required this.events,
      required this.outside,
      required this.today,
      required this.selected,
      required this.onTap});
  final DateTime day;
  final List<CalEvent> events;
  final bool outside, today, selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final st = ChartStyle.of(context);
    final ml = MaterialLocalizations.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: '${ml.formatFullDate(day)}, ${events.length}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 64,
          padding: const EdgeInsets.fromLTRB(3, 3, 3, 2),
          decoration: BoxDecoration(
            color: selected
                ? cs.secondaryContainer
                : outside
                    ? cs.surfaceContainerLow
                    : null,
            border: Border(top: BorderSide(color: cs.outlineVariant)),
          ),
          child: LayoutBuilder(builder: (context, box) {
            // Wide cells show short titles, narrow ones coloured dots.
            final titles = box.maxWidth >= 72;
            final max = titles ? 2 : 4;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: today
                      ? BoxDecoration(
                          color: cs.primary,
                          borderRadius: BorderRadius.circular(99))
                      : null,
                  child: Text('${day.day}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: today
                              ? cs.onPrimary
                              : outside
                                  ? cs.onSurfaceVariant
                                  : cs.onSurface)),
                ),
                const SizedBox(height: 2),
                if (titles)
                  for (final e in events.take(max))
                    Row(children: [
                      _Dot(color: eventColor(st, e), size: 6),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(eventLabel(e),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 10.5,
                                height: 1.25,
                                decoration:
                                    e.done ? TextDecoration.lineThrough : null,
                                color: e.done ? cs.onSurfaceVariant : null)),
                      ),
                    ])
                else
                  Wrap(spacing: 3, runSpacing: 3, children: [
                    for (final e in events.take(max))
                      _Dot(color: eventColor(st, e), size: 7),
                  ]),
                if (events.length > max)
                  Text('+${events.length - max}',
                      style:
                          TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, this.size = 8});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

/// One date in a list: colour, source, label, time and place; tapping
/// opens where it comes from.
class CalEventTile extends StatelessWidget {
  const CalEventTile(
      {super.key, required this.project, required this.event, this.data});
  final String project;
  final CalEvent event;
  final CalendarData? data;

  String _time(BuildContext context, DateTime d) =>
      MaterialLocalizations.of(context).formatTimeOfDay(
          TimeOfDay.fromDateTime(d),
          alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context));

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final st = ChartStyle.of(context);
    final e = event;
    final s = e.startTime, en = e.endTime;
    final time = e.allDay || s == null
        ? t.calAllDay
        : en == null
            ? _time(context, s)
            : '${_time(context, s)}–${_time(context, en)}';
    final meta = [
      time,
      if (e.location.isNotEmpty) e.location,
      if (e.source == 'external' && data != null)
        if (data!.calendarName(e.calendar) case final n when n.isNotEmpty) n,
    ].join(' · ');
    final canOpen = e.link.isNotEmpty || e.url.isNotEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        dense: true,
        leading: Row(mainAxisSize: MainAxisSize.min, children: [
          _Dot(color: eventColor(st, e)),
          const SizedBox(width: 6),
          Icon(_sourceIcon[e.source] ?? LucideIcons.calendar,
              size: 18, color: cs.onSurfaceVariant),
        ]),
        title: Text(eventLabel(e),
            style: e.done
                ? TextStyle(
                    decoration: TextDecoration.lineThrough,
                    color: cs.onSurfaceVariant)
                : null),
        subtitle: Text(meta),
        trailing: e.link.isEmpty && e.url.isNotEmpty
            ? const Icon(LucideIcons.externalLink, size: 16)
            : null,
        onTap: canOpen ? () => openCalEvent(context, project, e) : null,
      ),
    );
  }
}

/// The dates from today on, by day, for the spec's days ahead.
class CalendarList extends ConsumerStatefulWidget {
  const CalendarList(
      {super.key,
      required this.project,
      this.spec = const CalendarSpec(view: 'list'),
      this.allChips = false,
      this.today});
  final String project;
  final CalendarSpec spec;
  final bool allChips;
  final DateTime? today;

  @override
  ConsumerState<CalendarList> createState() => _CalendarListState();
}

class _CalendarListState extends ConsumerState<CalendarList>
    with _SourceFilter {
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final ml = MaterialLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final now = widget.today ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = widget.spec.daysAhead;
    final end = _addDays(today, days);
    final q = CalQuery.of(widget.project, widget.spec, today, end, 'next$days');
    final v = ref.watch(calendarProvider(q));
    final byDay = eventsByDay(shown(v.value));
    final first = dayKey(today), last = dayKey(end);
    final keys = byDay.keys
        .where((k) => k.compareTo(first) >= 0 && k.compareTo(last) < 0)
        .toList()
      ..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        chips(context, widget.spec, v.value, widget.allChips),
        const SizedBox(height: 4),
        status(context, v, () => ref.invalidate(calendarProvider(q))),
        if (v.hasValue && keys.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child:
                Text(t.calNone, style: TextStyle(color: cs.onSurfaceVariant)),
          ),
        for (final k in keys) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 10, 2, 4),
            child: Text(
                k == first
                    ? '${t.calToday} · ${ml.formatFullDate(parseDay(k))}'
                    : ml.formatFullDate(parseDay(k)),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: k == first ? cs.primary : cs.onSurfaceVariant)),
          ),
          for (final e in byDay[k]!)
            CalEventTile(project: widget.project, event: e, data: v.value),
        ],
      ],
    );
  }
}

/// A ```calendar block in a page.
class CalendarBlockView extends StatelessWidget {
  const CalendarBlockView(
      {super.key, required this.spec, required this.project});
  final CalendarSpec spec;
  final String project;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: CalendarView(project: project, spec: spec),
      );
}

/// The project's calendar (project tab): all sources, month or list.
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, required this.project});
  final String project;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  var _view = 'month';

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.calTitle), actions: [
        IconButton(
          tooltip: _view == 'month' ? t.calViewList : t.calViewMonth,
          icon: Icon(
              _view == 'month' ? LucideIcons.list : LucideIcons.calendarDays),
          onPressed: () =>
              setState(() => _view = _view == 'month' ? 'list' : 'month'),
        ),
      ]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 40),
        children: [
          CalendarView(
              key: ValueKey(_view),
              project: widget.project,
              spec: CalendarSpec(view: _view),
              allChips: true),
        ],
      ),
    );
  }
}
