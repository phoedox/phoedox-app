import 'package:flutter_test/flutter_test.dart';
import 'package:phoedox/features/blocks/blocks.dart';
import 'package:phoedox/features/blocks/interactive.dart';

void main() {
  // Poll and quiz are plugin blocks now (ADR-0087); their state keys must
  // stay the ones the web uses, so votes and answers survive the move.
  test('state keys match the web', () {
    expect(blockKey('question: Wohin?\n- Zoo\n- Museum'), 'h1pnyoxr');
    expect(blockKey('Ä € ü 😀'), 'h9an6ck');
    expect(blockKey('x', 'ausflug-2026'), 'ausflug-2026');
  });

  test('poll and quiz are split out when the project has their plugins', () {
    const md = 'Text\n```poll\nFrage?\n- a\n- b\n```\n```quiz\n? q\n= a\n```';
    expect(splitBlocks(md).map((p) => p.kind), ['md']);
    expect(splitBlocks(md, {'poll', 'quiz'}).map((p) => p.kind),
        ['md', 'poll', 'quiz']);
  });
}
