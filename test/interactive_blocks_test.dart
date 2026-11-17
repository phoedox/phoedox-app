import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phoedox/features/blocks/blocks.dart';
import 'package:phoedox/features/blocks/formula.dart';
import 'package:phoedox/features/blocks/interactive.dart';
import 'package:phoedox/l10n/gen/app_localizations.dart';

const _calc = '''title: Stromkosten des NAS
Leistung (W) = 25
Strompreis (€/kWh) = 0,32
Stunden pro Tag (h) = 24
Kosten pro Jahr (€) = Leistung * Stunden_pro_Tag * 365 / 1000 * Strompreis
Kosten pro Monat (€) = Kosten_pro_Jahr / 12''';

const _matrix = '''title: Welches NAS kaufen wir?
criteria: Preis*3, Lautstärke*2, Speicher*3, Stromverbrauch*1
scale: 1-5
- Synology DS224+: 3, 4, 3, 4
- QNAP TS-264: 4, 3, 4, 3
- Eigenbau: 5, 2, 5, 2''';

const _quiz = '''title: Kennst du unser Netz?
? Welche Adresse hat der Router?
- 192.168.1.1
+ 192.168.10.1
> Seit dem Umbau im März.

? Wie heißt das Gäste-WLAN?
= Gartenhaus''';

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

void main() {
  test('formulas', () {
    Object? ev(String s, [Map<String, Object?> v = const {}]) =>
        evaluate(s, (n) {
          if (!v.containsKey(n)) throw const FormulaError('name');
          return v[n];
        });
    expect(ev('1 + 2 * 3'), 7);
    expect(ev('(1 + 2) * 3 ^ 2'), 27);
    expect(ev('50%'), 0.5);
    expect(ev('ROUND(2,345; 2)'), 2.35);
    expect(ev('IF(a > 3; "groß"; "klein")', {'a': 5}), 'groß');
    expect(ev('SUM(1; 2; 3) & " €"'), '6 €');
    expect(ev('Größe * 2', {'Größe': 4}), 8);
    expect(() => ev('1 / 0'), throwsA(isA<FormulaError>()));
    expect(() => ev('1 +'), throwsA(isA<FormulaError>()));
    expect(formulaNames('a * b + SUM(a; c)'), ['a', 'b', 'c']);
  });

  test('calculator', () {
    final c = Calc.parse(_calc);
    expect(c.rows.where((r) => r.input).length, 3);
    expect(c.rows[1].unit, '€/kWh');
    final v = c.values(const {});
    expect(formatValue(v['Kosten_pro_Jahr'], 'de'), '70,08');
    expect(formatValue(c.values({'Leistung': 50})['Kosten_pro_Jahr']), '140');
    expect(formatValue(1234567.0, 'en'), '1,234,567');
    expect(() => Calc.parse('a = b + 1\nb = a'), throwsFormatException);
    expect(() => Calc.parse('a = x + 1'), throwsFormatException);
    expect(
        calcName('Kosten pro Jahr (€)'), (name: 'Kosten_pro_Jahr', unit: '€'));
  });

  test('matrix', () {
    final m = Matrix.parse(_matrix);
    final s = m.scores();
    expect(s.indexOf(s.reduce((a, b) => a > b ? a : b)), 2);
    // Noise matters most: Synology wins.
    final t = m.scores([3, 10, 3, 1]);
    expect(t.indexOf(t.reduce((a, b) => a > b ? a : b)), 0);
    expect(() => Matrix.parse('criteria: A, B\n- X: 1\n- Y: 2, 3'),
        throwsFormatException);
  });

  test('poll and quiz', () {
    final p = Poll.parse('question: Wohin?\nmultiple: yes\n- Zoo\n- Museum');
    expect(p.multiple, isTrue);
    // Several answers: shares of the people who voted.
    expect(p.share('Zoo', {'Zoo': 2, 'Museum': 1}, 2), 1.0);
    final f = Poll.parse('multiple\nWohin?\n- Zoo\n- Museum\nclosed');
    expect((f.question, f.multiple, f.closed), ('Wohin?', true, true));
    expect(() => Poll.parse('Wohin?\n- Zoo'), throwsFormatException);
    expect(() => Poll.parse('Wohin?\n- Zoo\n- Zoo'), throwsFormatException);
    final z = Quiz.parse(_quiz);
    expect(z.questions.length, 2);
    expect(z.right({'0': 1, '1': 'known'}), 2);
    expect(z.right({'0': 0}), 0);
    expect(() => Quiz.parse('? Frage\n- a\n- b'), throwsFormatException);
  });

  test('state keys match the web', () {
    expect(blockKey('question: Wohin?\n- Zoo\n- Museum'), 'h1pnyoxr');
    expect(blockKey('Ä € ü 😀'), 'h9an6ck');
    expect(blockKey('x', 'ausflug-2026'), 'ausflug-2026');
  });

  test('splitBlocks finds the new kinds', () {
    final parts = splitBlocks(
        'Text\n```poll\nFrage?\n- a\n- b\n```\n```quiz\n? q\n= a\n```');
    expect(parts.map((p) => p.kind), ['md', 'poll', 'quiz']);
  });

  testWidgets('calculator recomputes on input', (tester) async {
    await tester.pumpWidget(_app(blockView('calc', _calc, const BlockCtx())));
    expect(find.text('70,08 €'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '50');
    await tester.pump();
    expect(find.text('140 €'), findsOneWidget);
    expect(find.text('Zurücksetzen'), findsOneWidget);
  });

  testWidgets('matrix weights change the winner', (tester) async {
    await tester
        .pumpWidget(_app(blockView('matrix', _matrix, const BlockCtx())));
    expect(find.text('Gewichte ausprobieren'), findsOneWidget);
    await tester.tap(find.text('Gewichte ausprobieren'));
    await tester.pump();
    for (var i = 0; i < 8; i++) {
      await tester.tap(find.byTooltip('Gewicht von Lautstärke erhöhen'));
      await tester.pump();
    }
    expect(find.text('Nur für dich, wird nicht gespeichert.'), findsOneWidget);
  });

  testWidgets('quiz counts right answers and shows flashcards', (tester) async {
    await tester.pumpWidget(_app(blockView('quiz', _quiz, const BlockCtx())));
    expect(find.text('0 von 2 richtig'), findsOneWidget);
    await tester.tap(find.text('192.168.10.1'));
    await tester.pump();
    expect(find.text('1 von 2 richtig'), findsOneWidget);
    expect(find.text('Seit dem Umbau im März.'), findsOneWidget);
    await tester.tap(find.text('Antwort zeigen'));
    await tester.pump();
    expect(find.text('Gartenhaus'), findsOneWidget);
    await tester.tap(find.text('Gewusst'));
    await tester.pump();
    expect(find.text('2 von 2 richtig'), findsOneWidget);
  });

  testWidgets('poll shows options and broken blocks show their source',
      (tester) async {
    await tester.pumpWidget(_app(Column(children: [
      blockView('poll', 'Wohin?\n- Zoo\n- Museum', const BlockCtx()),
      blockView('poll', 'Wohin?', const BlockCtx()),
    ])));
    expect(find.text('Zoo'), findsOneWidget);
    expect(find.text('Wähle eine Antwort'), findsOneWidget);
    expect(find.textContaining('```poll'), findsOneWidget);
  });
}
