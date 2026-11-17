import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phoedox/features/blocks/blocks.dart';
import 'package:phoedox/features/blocks/pictures.dart';
import 'package:phoedox/features/charts/chart.dart';
import 'package:phoedox/l10n/gen/app_localizations.dart';

Widget _app(Widget child) => ProviderScope(
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

const _style = ChartStyle(
    dark: false,
    fg: Colors.black,
    muted: Colors.grey,
    line: Color(0xFFDDDDDD),
    surface: Colors.white,
    lang: 'de');

void main() {
  test('images: files, https only, markers in percent', () {
    final ba = BeforeAfter.parse(
        'title: Rack\nbefore: /api/v1/files/AB12 Vorher\nafter: 01M7ND6Y5KRMY1R09EK7Q7NMXT\nstart: 30');
    expect(ba.before!.fileId, 'AB12');
    expect(ba.beforeLabel, 'Vorher');
    expect(ba.after!.fileId, '01M7ND6Y5KRMY1R09EK7Q7NMXT');
    expect(ba.start, 30);
    expect(
        BeforeAfter.parse(
                '![a](/api/v1/files/AB)\n![b](https://example.org/b.jpg)')
            .after!
            .url,
        'https://example.org/b.jpg');
    expect(() => BeforeAfter.parse('before: javascript:alert(1)'),
        throwsFormatException);
    expect(BeforeAfter.parse('title: x\nbefore:\nafter:').before, isNull);
    final an = Annotated.parse(
        'image: /api/v1/files/AB12 Kasten\n- 22, 30: F1 @herd\n- 74,5% ; 64 blue: FI');
    expect((an.markers[1].x, an.markers[1].y, an.markers[1].color),
        (74.5, 64.0, 'blue'));
    expect(() => Annotated.parse('image: /api/v1/files/AB\n- 120, 3: x'),
        throwsFormatException);
    expect(() => Annotated.parse('image: /api/v1/files/AB\n- 1, 3 teal: x'),
        throwsFormatException);
  });

  test('whiteboard painters draw every kind', () async {
    for (final (k, src) in [
      (
        'beforeafter',
        'before: /api/v1/files/AB Vorher\nafter: /api/v1/files/CD Nachher'
      ),
      ('annotate', 'title: Kasten\nimage: /api/v1/files/AB\n- 20, 30: F1'),
    ]) {
      final rec = ui.PictureRecorder();
      blockKinds[k]!.paint!(
          Canvas(rec), const Rect.fromLTWH(0, 0, 500, 320), src, _style);
      final img = await rec.endRecording().toImage(500, 320);
      expect(img.width, 500, reason: k);
    }
  });

  testWidgets('annotated image views build', (tester) async {
    await tester.pumpWidget(_app(Column(children: [
      blockView('annotate', 'title: Kasten\n- 20, 30: F1 Küche und @herd',
          const BlockCtx(project: 'haus')),
      blockView('beforeafter', 'title: x\nbefore:\nafter:', const BlockCtx()),
    ])));
    expect(find.text('Noch kein Bild.'), findsOneWidget);
    expect(find.text('@herd'), findsOneWidget);
    expect(find.text('Es fehlen noch Fotos.'), findsOneWidget);
  });
}
