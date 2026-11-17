import 'dart:io';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phoedox/features/charts/chart.dart';

const vormaerz = '''{
  "title": "Pressure of the movement",
  "x": {"segments": [{"from": "1815", "to": "1847-12", "label": "compressed"}, {"from": "1848-01", "to": "1849-10", "weight": 1.1, "label": "stretched"}]},
  "y": {"ticks": [{"value": 0, "label": "low"}, {"value": 5, "label": "medium"}, {"value": 10, "label": "high"}]},
  "bands": [{"from": "1815", "to": "1848-02", "label": "Restoration", "color": "orange"},
            {"from": "1848-02", "to": "1848-05", "label": "March", "color": "red"},
            {"from": "1848-05", "to": "1849-10", "label": "Counter-revolution", "color": "gray"}],
  "series": [{"points": [
    {"x": "1815", "y": 1, "label": "1", "title": "Congress of Vienna", "text": "Restoration."},
    {"x": "1832", "y": 4, "label": "7", "title": "Hambach Festival"},
    {"x": "1848-03-18", "y": 9.5, "label": "14", "title": "March 1848", "text": "Barricades."},
    {"x": "1849-08", "y": 0.5, "label": "25", "title": "Hungary capitulates"}]},
    {"dashed": true, "points": [{"x": "1849-08", "y": 0.5}, {"x": "1849-10", "y": 2}]}],
  "notes": [{"x": "1849-06", "y": 2.5, "text": "ideas live on"}]
}''';

void main() {
  test('charts are read like on the web', () {
    final c = Chart.parse(vormaerz);
    expect(c.xKind, 'time');
    expect(c.items.map((i) => i.n), ['1', '7', '14', '25']);
    expect(c.items.map((i) => i.color), ['orange', 'orange', 'red', 'gray']);
    expect(c.seriesColor(0), 'gray');
    for (final bad in [
      '{',
      '{"points": []}',
      '{"points": [{"x": "2026", "y": "high"}]}',
      '{"type": "pie", "points": [{"x": 1, "y": 1}]}',
      '{"points": [{"x": 1, "y": 1, "color": "teal"}]}',
      '{"x": {"type": "time"}, "points": [{"x": "May", "y": 1}]}',
    ]) {
      expect(() => Chart.parse(bad), throwsFormatException, reason: bad);
    }
    expect(Chart.parse('{"type":"bar","points":[{"x":"NAS","y":4}]}').xKind,
        'category');
  });

  test('segments have their own scale', () {
    final c = Chart.parse(vormaerz);
    final sc = XScale('time', c, 0, 1000);
    expect(sc.segs.first.x1.round(), 476);
    expect(sc.at('1815'), 0);
    expect(sc.at('1849-10'), closeTo(1000, 1e-6));
    expect(sc.at('1848-06') - sc.at('1848-05'),
        greaterThan((sc.at('1830-06') - sc.at('1830-05')) * 10));
    final ticks = xTicks(sc, lang: 'de');
    expect(ticks.map((t) => t.label), containsAll(['1820', 'Jan 48']));
    expect(yScale(c).ticks.map((t) => t.label), ['low', 'medium', 'high']);
  });

  test('pages are split into text and charts', () {
    final parts = splitCharts(
        '# A\n\n```chart\n{"points":[{"x":1,"y":2}]}\n```\n\nafter\n```js\nx\n```');
    expect(parts.map((p) => p.kind), ['md', 'chart', 'md']);
    expect(parts[1].text, '{"points":[{"x":1,"y":2}]}');
    expect(parts[2].text, contains('```js'));
  });

  testWidgets('a chart shows its list and the text of a tapped point',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: SizedBox(
                    width: 700, child: ChartView(source: vormaerz))))));
    expect(find.text('Pressure of the movement'), findsOneWidget);
    expect(find.text('14'), findsOneWidget); // the badge in the list
    expect(find.textContaining('Barricades.'), findsOneWidget); // in the list
    expect(find.text('Restoration'), findsOneWidget); // legend
    // Tap where point 14 is drawn: find it through the painter's layout.
    final c = Chart.parse(vormaerz);
    final box = tester.getRect(find.byType(CustomPaint).last);
    final recorder = ui.PictureRecorder();
    final hits = paintChart(
        Canvas(recorder),
        Offset.zero & box.size,
        c,
        const ChartStyle(
            dark: false,
            fg: Colors.black,
            muted: Colors.grey,
            line: Colors.black12,
            surface: Colors.white));
    final h = hits.firstWhere((h) => h.series == 0 && h.point == 2);
    await tester.tapAt(box.topLeft + h.box.center);
    await tester.pump();
    expect(
        find.textContaining('Barricades.'), findsNWidgets(2)); // list + tooltip
    expect(find.text('Chart: no points'), findsNothing);
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: ChartView(source: '{"points": []}'))));
    expect(find.text('Chart: no points'), findsOneWidget);
  });

  test('the 1848 example renders (picture for a look)', () async {
    final f = File(
        '/tmp/claude-0/-home-user/e6608548-4d02-5234-8e08-39944318ca6f/scratchpad/1848.json');
    if (!f.existsSync()) return;
    final c = Chart.parse(f.readAsStringSync());
    const size = Size(900, 380);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final hits = paintChart(
        canvas,
        Offset.zero & size,
        c,
        const ChartStyle(
            dark: false,
            fg: Colors.black,
            muted: Color(0xFF6B6159),
            line: Color(0xFFDDD5CE),
            surface: Colors.white,
            lang: 'de'));
    expect(hits.length, 25);
    final img = await recorder.endRecording().toImage(900, 380);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File('/tmp/claude-0/-home-user/e6608548-4d02-5234-8e08-39944318ca6f/scratchpad/flutter-1848.png')
        .writeAsBytesSync(png!.buffer.asUint8List());
  });
}
