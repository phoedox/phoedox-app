import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phoedox/api/cache.dart';
import 'package:phoedox/api/client.dart';
import 'package:phoedox/app/session.dart';
import 'package:phoedox/features/blocks/blocks.dart';
import 'package:phoedox/features/blocks/plugin_blocks.dart';
import 'package:phoedox/l10n/gen/app_localizations.dart';

void main() {
  test('plugin kinds are split out of pages only when the project has them',
      () {
    const md =
        'Text\n```gantt\nA: 2026-01-01, 2w\n```\n```python\nprint(1)\n```';
    expect(splitBlocks(md).map((p) => p.kind), ['md']);
    expect(
        splitBlocks(md, {'gantt'}).map((p) => p.kind), ['md', 'gantt', 'md']);
  });

  test('CSS variables of plugin pictures become theme colours', () {
    final out = resolveSvgVars(
        '<rect style="fill:var(--tc-red);stroke:var(--line)"/><text style="font-family:var(--font-body,system-ui);fill:var(--unknown, #123456)">x</text>',
        {'tc-red': '#ff0000', 'line': '#dddddd'});
    expect(out, contains('fill:#ff0000'));
    expect(out, contains('stroke:#dddddd'));
    expect(out, contains('fill:#123456'));
    expect(out, isNot(contains('var(')));
    expect(out, isNot(contains('font-family')));
  });

  test('the WebView page loads the plugin module and only talks to the app',
      () {
    final html = blockFrameHtml(
        module: 'export default {elements:{}}',
        element: 'phx-gantt',
        source: 'A: 2026-01-01</script><script>alert(1)',
        svg: '<svg/>',
        project: 'haus',
        css: '--fg: #000;');
    expect(html, contains("default-src 'none'"));
    expect(html, contains('PhoedoxBridge.postMessage'));
    expect(html, contains('document.createElement("phx-gantt")'));
    // The source is a JS string, it cannot close the script.
    expect(html, isNot(contains('</script><script>alert(1)')));
  });

  testWidgets(
      'a plugin block shows its picture, problems and the way to the element',
      (tester) async {
    final dir = Directory.systemTemp.createTempSync('pblock');
    addTearDown(() => dir.deleteSync(recursive: true));
    final mock = MockClient((req) async {
      if (req.url.path.endsWith('/plugin-blocks')) {
        return http.Response(
            jsonEncode([
              {
                'kind': 'gantt',
                'label': 'Schedule (Gantt)',
                'plugin': 'com.phoedox.gantt',
                'element': 'phx-gantt',
                'frontend':
                    '/api/v1/plugins/com.phoedox.gantt/1.0.0/files/frontend/index.js',
                'board': true
              }
            ]),
            200);
      }
      if (req.url.path.endsWith('/render')) {
        final src = (jsonDecode(req.body) as Map)['source'] as String;
        return http.Response(
            jsonEncode(src == 'bad'
                ? {
                    'svg': '',
                    'problems': [
                      {
                        'line': 1,
                        'message': 'bad is not a date',
                        'severity': 'error'
                      }
                    ]
                  }
                : {
                    'svg':
                        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 20"><rect width="100" height="20" style="fill:var(--tc-blue)"/></svg>',
                    'problems': []
                  }),
            200);
      }
      return http.Response('{}', 404);
    });
    final client = PhxClient(
        base: Uri.parse('https://app.example.org'),
        token: 't',
        cache: OfflineCache(dir),
        httpClient: mock);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        clientProvider.overrideWith((_) async => client),
        cacheProvider.overrideWith((_) async => OfflineCache(dir))
      ],
      child: MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
            body: SingleChildScrollView(
                child: Column(children: [
          blockView(
              'gantt', 'A: 2026-01-01, 2w', const BlockCtx(project: 'haus')),
          blockView('gantt', 'bad', const BlockCtx(project: 'haus')),
        ]))),
      ),
    ));
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.text('Interaktiv öffnen'), findsOneWidget);
    expect(find.textContaining('bad is not a date'), findsOneWidget);
  });
}
