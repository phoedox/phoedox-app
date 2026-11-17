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
import 'package:phoedox/features/blocks/graph.dart';
import 'package:phoedox/l10n/gen/app_localizations.dart';

Map<String, dynamic> _e(String slug, String name, String kind) =>
    {'id': 'id-$slug', 'slug': slug, 'name': name, 'kind': kind};

final _answers = <String, Object>{
  '/api/v1/projects/haus/entities/router': {
    'entity': _e('router', 'Fritzbox', 'router'),
    'edges': []
  },
  '/api/v1/projects/haus/entities/router/traverse': [
    {'entity': _e('sw', 'Switch', 'switch'), 'parent': 'id-router', 'depth': 1},
    {'entity': _e('nas', 'NAS', 'server'), 'parent': 'id-sw', 'depth': 2},
    {
      'entity': _e('tv', 'Fernseher', 'device'),
      'parent': 'id-router',
      'depth': 1
    },
  ],
  '/api/v1/projects/haus/entities/rack': {
    'entity': {
      ..._e('rack', 'Rack Keller', 'rack'),
      'attrs': {'height_units': 6}
    },
    'edges': [
      {
        'rel': 'mounted_in',
        'to': 'id-rack',
        'fromSlug': 'nas',
        'fromName': 'NAS',
        'attrs': {'u': 2, 'height': 2}
      },
      {
        'rel': 'mounted_in',
        'to': 'id-rack',
        'fromSlug': 'ups',
        'fromName': 'USV',
        'attrs': {'height': 1}
      },
    ]
  },
  '/api/v1/projects/haus/documents/eg': {
    'type': 'floorplan',
    'title': 'Erdgeschoss',
    'content': {
      'width': 10000,
      'height': 8000,
      'rooms': [
        {
          'id': 'k',
          'name': 'Küche',
          'points': [
            [0, 0],
            [4000, 0],
            [4000, 4000],
            [0, 4000]
          ]
        },
        {
          'id': 'b',
          'name': 'Bad',
          'points': [
            [4000, 0],
            [8000, 0],
            [8000, 4000],
            [4000, 4000]
          ]
        },
      ],
      'walls': [
        {
          'id': 'w',
          'a': [0, 0],
          'b': [8000, 0],
          'thickness': 120
        }
      ],
      'openings': [
        {
          'id': 'o',
          'wall': 'w',
          'kind': 'window',
          'offset': 2000,
          'width': 1200
        }
      ],
      'devices': [
        {'id': 'd1', 'entity': 'herd', 'x': 1000, 'y': 1000},
        {'id': 'd2', 'entity': 'wm', 'x': 5000, 'y': 1000}
      ],
    }
  },
};

Widget _app(Widget child, Directory dir) {
  final mock = MockClient((req) async {
    if (req.url.path.endsWith('/status')) {
      final slugs = req.url.queryParametersAll['e'] ?? const [];
      return http.Response(
          jsonEncode({
            'entries': [
              for (final s in slugs)
                {
                  'slug': s,
                  'name': s == 'herd' ? 'Herd' : s,
                  'kind': 'device',
                  'status': s == 'nas' ? 'down' : 'ok'
                }
            ]
          }),
          200);
    }
    final a = _answers[req.url.path];
    return a == null
        ? http.Response('{"key":"error.not_found"}', 404)
        : http.Response(jsonEncode(a), 200);
  });
  final client = PhxClient(
      base: Uri.parse('https://app.example.org'),
      token: 't',
      cache: OfflineCache(dir),
      httpClient: mock);
  return ProviderScope(
    overrides: [clientProvider.overrideWith((_) async => client)],
    child: MaterialApp(
      locale: const Locale('de'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('graph'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('sources and layouts like the web', () {
    final t = TreeSpec.parse(
        'root: @router\nrelation: wired_to\nrichtung: out\ndepth: 3');
    expect((t.root, t.relation, t.direction, t.depth),
        ('router', 'wired_to', 'out', 3));
    expect(() => TreeSpec.parse('relation: x'), throwsFormatException);
    expect(RackSpec.parse('@rack-keller').rack, 'rack-keller');
    expect(() => RackSpec.parse('Rack im Keller'), throwsFormatException);
    final p = PlanSpec.parse('plan: eg\nroom: Küche\ndevices: nein');
    expect((p.plan, p.room, p.devices), ('eg', 'Küche', false));
    final tree = buildTree(_e('r', 'Router', 'router'), [
      {'entity': _e('a', 'A', 'switch'), 'parent': 'id-r'},
      {'entity': _e('b', 'B', 'switch'), 'parent': 'id-r'},
      {'entity': _e('c', 'C', 'device'), 'parent': 'id-b'},
    ]);
    final l = layoutTree(tree);
    final b = l.boxes.firstWhere((x) => x.node.name == 'B');
    final c = l.boxes.firstWhere((x) => x.node.name == 'C');
    expect(b.x, c.x);
    expect(c.y > b.y, isTrue);
    final r = rackSlots(6, [
      Mounted('nas', 'NAS', 2, 2),
      Mounted('x', 'X', 3, 1),
      Mounted('ups', 'USV', null, 1)
    ]);
    expect(r.unplaced.single.slug, 'ups');
    expect(r.conflicts, {'nas', 'x'});
  });

  testWidgets('tree, rack and floor plan load live data', (tester) async {
    await tester.pumpWidget(_app(
        Column(children: [
          blockView('tree', 'root: @router\nrelation: wired_to',
              const BlockCtx(project: 'haus')),
          blockView('rack', '@rack', const BlockCtx(project: 'haus')),
          blockView('floorplan', 'plan: eg\nroom: küche',
              const BlockCtx(project: 'haus')),
          blockView('tree', '@gibtsnicht', const BlockCtx(project: 'haus')),
        ]),
        dir));
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    expect(find.text('Fritzbox'), findsOneWidget);
    expect(find.text('server · Gestört'), findsOneWidget);
    expect(find.text('Rack Keller · 6 HE'), findsOneWidget);
    expect(find.text('NAS'), findsWidgets);
    expect(find.text('1 Gerät ohne Position'), findsOneWidget);
    expect(find.text('Küche · Erdgeschoss'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'Herd'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'wm'), findsNothing);
    expect(
        find.text('Den Eintrag „gibtsnicht“ gibt es nicht.'), findsOneWidget);
  });
}
