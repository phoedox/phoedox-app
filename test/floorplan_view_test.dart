import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phoedox/features/floorplan/floorplan_view.dart';
import 'package:phoedox/l10n/gen/app_localizations.dart';
import 'package:phoedox/sync/providers.dart';
import 'package:phoedox/sync/uploads.dart';

const doc = {
  'id': 'DOC1',
  'slug': 'ground-floor',
  'type': 'floorplan',
  'title': 'Ground floor',
  'content': {
    'width': 10000,
    'height': 5000,
    'rooms': [
      {
        'id': 'r1',
        'name': 'Hall',
        'points': [
          [0, 0],
          [5000, 0],
          [5000, 5000],
          [0, 5000]
        ]
      }
    ],
    'devices': [
      {'id': 'd1', 'entity': 'router', 'x': 1000, 'y': 1000}
    ],
  },
};

void main() {
  late Directory dir;
  late UploadQueue queue;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('plan');
    queue = UploadQueue(File('${dir.path}/q.json'), Directory('${dir.path}/f'));
  });
  tearDown(() => dir.delete(recursive: true));

  ProviderContainer container() => ProviderContainer(
      overrides: [uploadQueueProvider.overrideWith((_) async => queue)]);

  Widget app(ProviderContainer c, bool canEdit) => UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates
          ],
          home: Scaffold(
              body: FloorplanBody(project: 'haus', doc: doc, canEdit: canEdit)),
        ),
      );

  testWidgets('editors get the photo button, readers do not', (t) async {
    final c = container();
    addTearDown(c.dispose);
    await t.pumpWidget(app(c, false));
    await t.pumpAndSettle();
    expect(find.text('Ground floor'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.text('Place photo'), findsNothing);

    await t.pumpWidget(app(c, true));
    await t.pumpAndSettle();
    expect(find.text('Place photo'), findsOneWidget);
  });

  testWidgets('photos waiting on the device are shown', (t) async {
    final src = File('${dir.path}/p.jpg')..writeAsBytesSync([1]);
    await t.runAsync(() => queue.add(
        project: 'haus',
        name: 'plan-photo.jpg',
        source: src,
        document: 'DOC1',
        place: const PlanPlacement(doc: 'DOC1', photoId: 'ph1', x: 1, y: 2)));
    final c = container();
    addTearDown(c.dispose);
    // The queue is read from disk (real I/O) before the first frame.
    await t.runAsync(() => c.read(uploadsProvider.future));
    await t.pumpWidget(app(c, true));
    await t.pumpAndSettle();
    expect(find.text('1 photo not in the draft yet'), findsOneWidget);
  });
}
