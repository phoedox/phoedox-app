import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phoedox/api/cache.dart';
import 'package:phoedox/api/client.dart';
import 'package:phoedox/features/apps/app_bridge.dart';
import 'package:phoedox/sync/app_outbox.dart';

void main() {
  test('calls are checked against the granted level and work offline',
      () async {
    final dir = await Directory.systemTemp.createTemp('phx');
    var online = true;
    final store = <String, Object?>{};
    final calls = <String>[];
    final mock = MockClient((req) async {
      if (!online) throw const SocketException('offline');
      final p =
          req.url.path.replaceFirst('/api/v1/projects/haus/apps/todo', '');
      calls.add('${req.method} $p');
      if (req.method == 'PUT' && p == '/grant') {
        return http.Response('{"granted":2}', 200);
      }
      if (p.startsWith('/storage/')) {
        final key = Uri.decodeComponent(p.substring(9));
        if (req.method == 'PUT') {
          store[key] = (jsonDecode(req.body) as Map)['value'];
          return http.Response('', 204);
        }
        return http.Response(jsonEncode(store[key]), 200);
      }
      if (p == '/read') return http.Response('[{"name":"NAS"}]', 200);
      if (req.url.path == '/api/v1/projects/haus/boards/todo/tasks') {
        return http.Response('{"id":"t1"}', 201);
      }
      return http.Response('{"key":"error.not_found"}', 404);
    });
    final client = PhxClient(
        base: Uri.parse('https://app.example.org'),
        token: 't',
        cache: OfflineCache(dir),
        httpClient: mock);
    final outbox = AppOutbox(File('${dir.path}/app_outbox.json'));
    var asked = 0;
    var confirmed = false;
    String? opened;
    final b = AppBridge(
      client: client,
      project: 'haus',
      doc: 'todo',
      info: AppFrameInfo.fromJson({
        'url': '/app-frame/x/',
        'level': 3,
        'maxLevel': 2,
        'granted': 0,
        'sources': []
      }),
      askLevel: (want) async {
        asked++;
        return want;
      },
      confirm: (_) async => confirmed,
      open: (r) => opened = r,
      outbox: outbox,
      cache: OfflineCache(dir),
    );
    Future<Map<String, dynamic>> call(String op,
            [Map<String, dynamic>? args]) =>
        b.handle({'phx': 1, 'id': 1, 'op': op, 'args': args ?? {}});

    // Reading asks once for the level, then works.
    expect((await call('read', {'source': 'nas'}))['result'], [
      {'name': 'NAS'}
    ]);
    expect(asked, 1);
    expect(calls, contains('PUT /grant'));
    expect(
        (await call('storage.set', {
          'key': 'todo',
          'value': [1]
        }))['result'],
        true);
    expect((await call('storage.get', {'key': 'todo'}))['result'], [1]);
    // Writes need level 3, which the instance does not allow here.
    final w =
        await call('write', {'kind': 'task', 'board': 'todo', 'title': 'x'});
    expect(w['code'], 'not_allowed');

    // Offline: writes wait in the outbox, reads see them, reading sources uses the cache.
    online = false;
    expect(
        (await call('storage.set', {
          'key': 'todo',
          'value': [1, 2]
        }))['result'],
        true);
    expect((await call('storage.get', {'key': 'todo'}))['result'], [1, 2]);
    expect((await call('read', {'source': 'nas'}))['result'], [
      {'name': 'NAS'}
    ]);
    expect((await outbox.list()).length, 1);
    online = true;
    final (sent, failed) = await outbox.flush(client);
    expect((sent, failed), (1, 0));
    expect(store['todo'], [1, 2]);
    expect(await outbox.list(), isEmpty);

    expect((await call('open', {'ref': '@nas'}))['result'], true);
    expect(opened, '@nas');
    expect((await call('open', {'ref': '../evil'}))['result'], false);
    expect((await call('ai', {'prompt': 'x'}))['code'], 'ai_unavailable');
    expect((await call('nope'))['code'], 'unknown');
  });
}
