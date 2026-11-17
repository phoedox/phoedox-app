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

  test('foldable callouts, tabs and steps show their title', () {
    final out = toPlainMarkdown([
      '> [!faq]- Why does the NAS sleep?',
      '> Power saving.',
      '> [!tab] macOS',
      '> Open Terminal.',
      '> [!steps id=s1] Set up the router',
      '> 1. Plug in',
    ].join('\n'));
    expect(out, contains('> **Why does the NAS sleep?**'));
    expect(out, contains('> **macOS**'));
    expect(out, contains('> **Set up the router**'));
    expect(out, isNot(contains('[!')));
  });
}
