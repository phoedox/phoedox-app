import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phoedox/api/client.dart';
import 'package:phoedox/sync/outbox.dart';

PendingEdit edit(String md, {int base = 1, DateTime? at}) => PendingEdit(
    project: 'haus',
    docId: 'd1',
    title: 'Router',
    baseVersion: base,
    base: 'Router im Flur.',
    markdown: md,
    savedAt: at ?? DateTime(2026, 11, 14, 12));

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('outbox'));
  tearDown(() => dir.delete(recursive: true));

  test('keeps the first base when a page is edited twice', () async {
    final box = Outbox(File('${dir.path}/outbox.json'));
    await box.put(edit('Router im Flur, oben.'));
    await box.put(PendingEdit(
        project: 'haus',
        docId: 'd1',
        title: 'Router',
        baseVersion: 2,
        base: 'other',
        markdown: 'Router im Flur, oben links.',
        savedAt: DateTime(2026, 11, 14, 13)));
    final all = await box.list();
    expect(all, hasLength(1));
    expect(all.first.base, 'Router im Flur.');
    expect(all.first.baseVersion, 1);
    expect(all.first.markdown, 'Router im Flur, oben links.');
  });

  test('sync merges with what changed on the server', () async {
    final box = Outbox(File('${dir.path}/outbox.json'));
    await box.put(edit('Router im Flur, oben links.'));
    Map? patched;
    final client = PhxClient(
        base: Uri.parse('https://phx.test'),
        token: 't',
        httpClient: MockClient((req) async {
          final p = req.url.path;
          if (req.method == 'GET' && p.endsWith('/documents/d1')) {
            return http.Response(
                jsonEncode({
                  'version': 2,
                  'content': {'markdown': 'Hinweis: Router im Flur.'}
                }),
                200);
          }
          if (req.method == 'GET' && p.endsWith('/draft')) {
            return http.Response('{"key":"error.not_found"}', 404);
          }
          if (req.method == 'PATCH') {
            patched = jsonDecode(req.body) as Map;
            return http.Response('{"applied":true}', 200);
          }
          return http.Response('', 500);
        }));
    final r = await box.sync(client);
    expect(r.sent, 1);
    expect(r.merged, 1);
    expect(patched!['markdown'], 'Hinweis: Router im Flur, oben links.');
    expect(patched!['expectVersion'], 2);
    expect(await box.list(), isEmpty);
  });

  test('offline and refused edits stay', () async {
    final box = Outbox(File('${dir.path}/outbox.json'));
    await box.put(edit('x'));
    final offline = PhxClient(
        base: Uri.parse('https://phx.test'),
        token: 't',
        httpClient:
            MockClient((_) async => throw const SocketException('down')));
    expect((await box.sync(offline)).offline, isTrue);
    expect(await box.list(), hasLength(1));
    final refusing = PhxClient(
        base: Uri.parse('https://phx.test'),
        token: 't',
        httpClient: MockClient((req) async => req.method == 'GET' &&
                req.url.path.endsWith('/d1')
            ? http.Response(
                '{"version":1,"content":{"markdown":"Router im Flur."}}', 200)
            : req.method == 'GET'
                ? http.Response('', 404)
                : http.Response('{"key":"error.forbidden"}', 403)));
    final r = await box.sync(refusing);
    expect(r.failed, 1);
    expect((await box.list()).single.error, 'error.forbidden');
  });
}
