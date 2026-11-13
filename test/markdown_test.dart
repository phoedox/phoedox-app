import 'package:flutter_test/flutter_test.dart';
import 'package:phoedox/api/markdown.dart';

void main() {
  test('page extensions become plain Markdown', () {
    final out = toPlainMarkdown([
      '> [!callout icon=User color=orange]',
      '> Wichtig',
      'Text [rot]{color=red} und ++unter++ am <time datetime="2026-12-24">24.12.</time>.',
      '`[x]{color=red}` bleibt.',
      '```board',
      'umbau',
      '```',
    ].join('\n'));
    expect(out, contains('> **Callout**'));
    expect(out, contains('Text rot und unter am 24.12..'));
    expect(out, contains('`[x]{color=red}` bleibt.'));
    expect(out, isNot(contains('```board')));
  });
}
