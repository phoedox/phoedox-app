import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phoedox/features/blocks/blocks.dart';
import 'package:phoedox/features/blocks/interactive.dart';
import 'package:phoedox/l10n/gen/app_localizations.dart';

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
