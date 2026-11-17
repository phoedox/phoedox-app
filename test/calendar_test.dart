import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phoedox/api/cache.dart';
import 'package:phoedox/api/client.dart';
import 'package:phoedox/app/session.dart';
import 'package:phoedox/features/blocks/blocks.dart';
import 'package:phoedox/features/calendar/calendar.dart';
import 'package:phoedox/features/entity/entity_page.dart';
import 'package:phoedox/l10n/gen/app_localizations.dart';

/// A timed event's time in RFC 3339 UTC, from a local time (so the tests
/// do not depend on the time zone they run in).
String utc(DateTime local) => local.toUtc().toIso8601String();

CalEvent timed(DateTime start, DateTime end) => CalEvent(
    id: 'x',
    title: 'x',
    start: utc(start),
    end: utc(end),
    allDay: false,
    source: 'external');

CalEvent allDay(String start, String end) => CalEvent(
    id: 'x', title: 'x', start: start, end: end, allDay: true, source: 'tasks');

Map<String, dynamic> calendarJson() => {
      'from': '2026-10-26',
      'to': '2026-12-07',
      'events': [
        {
          'id': 'm:1',
          'title': 'Change the filter',
          'start': '2026-11-20',
          'end': '2026-11-21',
          'allDay': true,
          'source': 'maintenance',
          'link': 'e/furnace'
        },
        {
          'id': 't:1',
          'title': 'Pay the invoice',
          'start': utc(DateTime(2026, 11, 17, 9)),
          'end': utc(DateTime(2026, 11, 17, 10)),
          'allDay': false,
          'source': 'tasks',
          'link': 'd/household?task=01T'
        },
        {
          'id': 'a:1',
          'title': 'Car',
          'start': '2026-11-25',
          'end': '2026-11-26',
          'allDay': true,
          'source': 'entities',
          'entity': 'car',
          'kind': 'car',
          'attr': 'next_inspection',
          'link': 'e/car'
        },
        {
          'id': 'x:1',
          'title': 'Dentist',
          'start': '2026-11-17',
          'end': '2026-11-18',
          'allDay': true,
          'source': 'external',
          'calendar': 'fam',
          'location': 'Main street',
          'url': 'https://example.org/dentist'
        },
      ],
      'calendars': [
        {
          'id': 'fam',
          'name': 'Family',
          'kind': 'ical',
          'color': 'green',
          'writeBack': false
        }
      ],
    };

void main() {
  group('block source', () {
    test('reads view, sources with aliases, kinds, calendar and days', () {
      final s = CalendarSpec.parse('''
# the household's dates
view: list
sources: Wartung, karten, einträge, extern, nonsense
kinds: car, contract
calendar: household-dates
days: 30
colour: red
''');
      expect(s.view, 'list');
      expect(s.sources, ['maintenance', 'tasks', 'entities', 'external']);
      expect(s.kinds, ['car', 'contract']);
      expect(s.doc, 'household-dates');
      expect(s.daysAhead, 30);
    });

    test('defaults: month, all sources, 60 days; days are bounded', () {
      final s = CalendarSpec.parse('');
      expect(s.view, 'month');
      expect(s.sources, isEmpty);
      expect(s.daysAhead, 60);
      expect(CalendarSpec.parse('ansicht: Monat\ntage: 9999').daysAhead, 366);
      expect(CalendarSpec.parse('sources: entries, cards').sources,
          ['entities', 'tasks']);
    });

    test('a calendar document\'s content', () {
      final s = CalendarSpec.fromJson({
        'view': 'list',
        'sources': ['tasks'],
        'calendars': ['fam'],
        'days': 14
      }, doc: 'dates');
      expect(s.view, 'list');
      expect(s.sources, ['tasks']);
      expect(s.calendars, ['fam']);
      expect(s.daysAhead, 14);
      expect(s.doc, 'dates');
    });

    test('the request carries the document and the filters', () {
      final q = CalQuery.of(
          'haus',
          CalendarSpec.parse('calendar: dates\nsources: tasks, wartung'),
          DateTime(2026, 11, 1),
          DateTime(2026, 12, 1),
          'r');
      final u = Uri.parse(q.path);
      expect(u.path, '/projects/haus/calendar');
      expect(u.queryParameters, {
        'from': '2026-11-01',
        'to': '2026-12-01',
        'doc': 'dates',
        'sources': 'tasks,maintenance'
      });
      expect(q.cacheKey, startsWith('cal:haus:r:'));
      expect(q.cacheKey, isNot(contains('2026')));
    });
  });

  test('the month grid starts on Monday and has 42 days', () {
    // November 2026 starts on a Sunday.
    final g = monthGrid(2026, 11);
    expect(g, hasLength(42));
    expect(g.first, DateTime(2026, 10, 26));
    expect(g.first.weekday, DateTime.monday);
    expect(g[6], DateTime(2026, 11, 1));
    expect(g.last, DateTime(2026, 12, 6));
    // A month starting on Monday starts in its first cell.
    expect(monthGrid(2026, 6).first, DateTime(2026, 6, 1));
    for (var i = 0; i < 42; i += 7) {
      expect(g[i].weekday, DateTime.monday);
    }
  });

  group('days of an event', () {
    test('all-day: the end date is exclusive', () {
      expect(eventDays(allDay('2026-11-20', '2026-11-21')), ['2026-11-20']);
      expect(eventDays(allDay('2026-11-30', '2026-12-02')),
          ['2026-11-30', '2026-12-01']);
      // An empty range still shows on its first day.
      expect(eventDays(allDay('2026-11-20', '2026-11-20')), ['2026-11-20']);
    });

    test('timed: local days from start to end, midnight end excluded', () {
      expect(
          eventDays(
              timed(DateTime(2026, 11, 18, 9), DateTime(2026, 11, 18, 10))),
          ['2026-11-18']);
      expect(
          eventDays(
              timed(DateTime(2026, 11, 18, 22), DateTime(2026, 11, 19, 1))),
          ['2026-11-18', '2026-11-19']);
      expect(
          eventDays(timed(DateTime(2026, 11, 18, 20), DateTime(2026, 11, 19))),
          ['2026-11-18']);
    });

    test('events by day', () {
      final m = eventsByDay([
        allDay('2026-11-20', '2026-11-22'),
        timed(DateTime(2026, 11, 21, 8), DateTime(2026, 11, 21, 9)),
      ]);
      expect(m.keys, ['2026-11-20', '2026-11-21']);
      expect(m['2026-11-21'], hasLength(2));
    });
  });

  test('date fields show their name after the title', () {
    final e = CalEvent.fromJson(calendarJson()['events'][2] as Map);
    expect(eventLabel(e), 'Car · next inspection');
    expect(eventLabel(CalEvent.fromJson(calendarJson()['events'][0] as Map)),
        'Change the filter');
  });

  group('widgets', () {
    late Directory dir;
    final requests = <Uri>[];

    setUp(() {
      dir = Directory.systemTemp.createTempSync('cal');
      requests.clear();
    });
    tearDown(() => dir.deleteSync(recursive: true));

    Future<void> pump(WidgetTester tester, Widget child,
        {bool online = true}) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final mock = MockClient((req) async {
        requests.add(req.url);
        if (!online) throw const SocketException('offline');
        if (req.url.path.endsWith('/calendar')) {
          return http.Response(jsonEncode(calendarJson()), 200);
        }
        return http.Response('{"key":"error.not_found"}', 404);
      });
      final client = PhxClient(
          base: Uri.parse('https://app.example.org'),
          token: 't',
          cache: OfflineCache(Directory('${dir.path}/client')),
          httpClient: mock);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          clientProvider.overrideWith((_) async => client),
          cacheProvider.overrideWith((_) async => OfflineCache(dir))
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
              body: SingleChildScrollView(
                  padding: const EdgeInsets.all(8), child: child)),
        ),
      ));
      await settle(tester);
    }

    testWidgets('a block asks with its calendar document and filters',
        (tester) async {
      await pump(
          tester,
          blockView(
              'calendar',
              'view: list\ncalendar: household-dates\nsources: wartung\ndays: 7',
              const BlockCtx(project: 'haus')));
      final q = requests.single.queryParameters;
      expect(q['doc'], 'household-dates');
      expect(q['sources'], 'maintenance');
      expect(DateTime.parse(q['to']!).difference(DateTime.parse(q['from']!)),
          const Duration(days: 7));
    });

    testWidgets('the month shows its dates, a tapped day lists them',
        (tester) async {
      await pump(
          tester,
          CalendarMonth(
              project: 'haus',
              spec: const CalendarSpec(doc: 'household-dates'),
              today: DateTime(2026, 11, 17)));
      expect(requests.first.path, '/api/v1/projects/haus/calendar');
      expect(requests.first.queryParameters,
          {'from': '2026-10-26', 'to': '2026-12-07', 'doc': 'household-dates'});
      expect(find.text('November 2026'), findsOneWidget);
      // Short titles in the cells.
      expect(find.text('Change the filter'), findsOneWidget);
      expect(find.text('Car · next inspection'), findsOneWidget);
      // Today is selected: its dates are listed below with time and place.
      expect(find.text('Tuesday, November 17, 2026'), findsOneWidget);
      expect(find.byType(CalEventTile), findsNWidgets(2));
      expect(find.text('all day · Main street · Family'), findsOneWidget);
      // Source chips switch dates off.
      expect(find.byType(FilterChip), findsNWidgets(4));
      await tester.tap(find.widgetWithText(FilterChip, 'Maintenance'));
      await tester.pump();
      expect(find.text('Change the filter'), findsNothing);
      await tester.tap(find.widgetWithText(FilterChip, 'Maintenance'));
      await tester.pump();
      // A tapped day lists its dates; a date opens its entry.
      await tester.tap(find.text('20'));
      await tester.pump();
      expect(find.text('Friday, November 20, 2026'), findsOneWidget);
      final tile = find.widgetWithText(CalEventTile, 'Change the filter');
      expect(tile, findsOneWidget);
      await tester.tap(tile);
      await settle(tester);
      expect(find.byType(EntityPage), findsOneWidget);
      expect(requests.map((u) => u.path),
          contains('/api/v1/projects/haus/entities/furnace'));
    });

    testWidgets('month navigation loads the next month', (tester) async {
      await pump(tester,
          CalendarMonth(project: 'haus', today: DateTime(2026, 11, 17)));
      await tester.tap(find.byTooltip('Next month'));
      await settle(tester);
      expect(find.text('December 2026'), findsOneWidget);
      expect(requests.last.queryParameters['from'], '2026-11-30');
      await tester.tap(find.text('Today'));
      await settle(tester);
      expect(find.text('November 2026'), findsOneWidget);
    });

    testWidgets('the list shows the coming days and stays readable offline',
        (tester) async {
      const spec = CalendarSpec(view: 'list', days: 14);
      await pump(
          tester,
          CalendarView(
              project: 'haus', spec: spec, today: DateTime(2026, 11, 17)));
      expect(requests.single.queryParameters,
          {'from': '2026-11-17', 'to': '2026-12-01'});
      expect(find.text('Today · Tuesday, November 17, 2026'), findsOneWidget);
      expect(find.text('Wednesday, November 25, 2026'), findsOneWidget);
      expect(find.text('Car · next inspection'), findsOneWidget);
      expect(find.text('Pay the invoice'), findsOneWidget);
      expect(find.text('Offline – last loaded state'), findsNothing);

      // The next day without a connection: the cached list is shown.
      await tester.pumpWidget(const SizedBox());
      await pump(
          tester,
          CalendarView(
              project: 'haus', spec: spec, today: DateTime(2026, 11, 18)),
          online: false);
      expect(find.text('Offline – last loaded state'), findsOneWidget);
      expect(find.text('Car · next inspection'), findsOneWidget);
      // Dates before the new today are not listed.
      expect(find.text('Pay the invoice'), findsNothing);
    });

    testWidgets('the block needs a project', (tester) async {
      await pump(tester, blockView('calendar', 'view: list', const BlockCtx()));
      expect(find.textContaining('```calendar'), findsOneWidget);
      expect(requests, isEmpty);
    });
  });
}

/// Lets the client (real futures and file access) answer.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump();
  }
}
