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

  test('collections, files, downloads, devices one by one and self-editing',
      () async {
    final calls = <String>[];
    final grants = <String, bool>{'motion': false};
    final mock = MockClient((req) async {
      final p =
          req.url.path.replaceFirst('/api/v1/projects/haus/apps/poll', '');
      calls.add('${req.method} $p');
      switch ('${req.method} $p') {
        case 'GET /me':
          return http.Response('{"id":"u1","name":"Ann","editor":true}', 200);
        case 'POST /db/votes':
          final b = jsonDecode(req.body) as Map;
          return http.Response(
              jsonEncode({'id': 'r1', 'data': b['data'], 'mine': true}), 201);
        case 'POST /db/votes/query':
          expect((jsonDecode(req.body) as Map)['limit'], 5);
          return http.Response('[{"id":"r1","data":{"c":"pizza"}}]', 200);
        case 'PUT /db/votes/r1':
          expect((jsonDecode(req.body) as Map)['merge'], true);
          return http.Response('{"id":"r1"}', 200);
        case 'POST /uploads':
          expect(req.url.queryParameters['name'], 'a.txt');
          expect(req.headers['content-type'], 'text/plain');
          expect(utf8.decode(req.bodyBytes), 'hello');
          return http.Response('{"id":"f1","name":"a.txt"}', 201);
        case 'GET /uploads/f1':
          return http.Response('hello', 200,
              headers: {'content-type': 'text/plain'});
        case 'PUT /self':
          return http.Response('{"document":{"version":2}}', 200);
      }
      if (req.method == 'PUT' && p.startsWith('/devices/')) {
        grants[p.substring(9)] = (jsonDecode(req.body) as Map)['allowed'];
        return http.Response(jsonEncode(grants), 200);
      }
      return http.Response('{"key":"error.not_found"}', 404);
    });
    final client = PhxClient(
        base: Uri.parse('https://app.example.org'),
        token: 't',
        httpClient: mock);
    final asked = <String>[];
    var allow = true, confirmDl = false, watching = 0, motion = 0;
    final saved = <String, List<int>>{};
    List<String>? selfFiles;
    final b = AppBridge(
      client: client,
      project: 'haus',
      doc: 'poll',
      info: AppFrameInfo.fromJson({
        'url': '/app-frame/x/',
        'level': 2,
        'maxLevel': 2,
        'granted': 2,
        'sources': [],
        'devices': ['camera', 'location', 'screen', 'motion'],
        'deviceGrants': {'motion': false},
        'selfEdit': true,
        'canEdit': true,
      }),
      askLevel: (want) async => want,
      confirm: (_) async => true,
      open: (_) {},
      host: AppHost(
        askDevice: (f) async {
          asked.add(f);
          return allow;
        },
        confirmDownload: (name, size) async => confirmDl,
        saveFile: (name, bytes, type) async => saved[name] = bytes,
        confirmSelfSave: (files) async {
          selfFiles = files;
          return true;
        },
        location: () async => {'lat': 52.5, 'lng': 13.4, 'accuracy': 10},
        startMotion: () => motion++,
        startWatch: () => watching++,
      ),
    );
    Future<Map<String, dynamic>> call(String op,
            [Map<String, dynamic>? args]) =>
        b.handle({'phx': 1, 'id': 1, 'op': op, 'args': args ?? {}});

    expect((await call('me'))['result']['name'], 'Ann');
    expect((await call('info'))['result']['selfEdit'], true);
    // Collections
    expect(
        (await call('db.add', {
          'collection': 'votes',
          'data': {'c': 'pizza'}
        }))['result']['id'],
        'r1');
    expect(
        (await call('db.query', {
          'collection': 'votes',
          'query': {'limit': 5}
        }))['result'],
        hasLength(1));
    await call('db.put', {
      'collection': 'votes',
      'id': 'r1',
      'data': {'c': null},
      'merge': true
    });
    await call('db.watch', {'collection': 'votes'});
    expect(watching, 1);
    // Files travel as base64 over the text channel.
    expect(
        (await call('files.upload', {
          'file': {
            'base64': base64Encode(utf8.encode('hello')),
            'type': 'text/plain'
          },
          'name': 'a.txt'
        }))['result']['id'],
        'f1');
    final got = (await call('files.get', {'id': 'f1'}))['result'] as Map;
    expect(utf8.decode(base64Decode(got['base64'] as String)), 'hello');
    // Downloads need the person's yes.
    expect((await call('download', {'name': 'a/b.csv', 'data': 'x,y'}))['code'],
        'cancelled');
    confirmDl = true;
    expect(
        (await call('download', {'name': 'a/b.csv', 'data': 'x,y'}))['result'],
        true);
    expect(utf8.decode(saved['a_b.csv']!), 'x,y');
    // Devices: each feature asked separately and once; only listed ones.
    expect((await call('device.status'))['result'],
        {'camera': null, 'location': null, 'screen': null, 'motion': false});
    expect(
        (await call('device.request', {'feature': 'camera'}))['result'], true);
    expect(
        (await call('device.request', {'feature': 'camera'}))['result'], true);
    expect(asked, ['camera']);
    expect((await call('device.request', {'feature': 'microphone'}))['code'],
        'not_allowed');
    expect((await call('device.request', {'feature': 'screen'}))['code'],
        'not_supported');
    expect(
        (await call('device.motion'))['code'], 'not_allowed'); // said no before
    expect(motion, 0);
    allow = false;
    expect((await call('device.location'))['code'], 'not_allowed');
    expect(asked, ['camera', 'location']);
    expect(b.info.deviceGrants,
        {'motion': false, 'camera': true, 'location': false});
    // Self-editing asks first.
    final r = await call('self.save', {
      'files': {'index.html': '<h1>v2</h1>'}
    });
    expect(r['result']['document']['version'], 2);
    expect(selfFiles, ['index.html']);
  });

  test('server-sent events are read by name', () async {
    final mock = MockClient.streaming((req, _) async => http.StreamedResponse(
        Stream.fromIterable([
          utf8.encode('retry: 5000\n\n: ping\n\n'),
          utf8.encode('event: change\ndata: {"id":"r1",'),
          utf8.encode('"kind":"add"}\n\nevent: other\ndata: x\n\n'),
        ]),
        200,
        headers: {'content-type': 'text/event-stream'}));
    final client = PhxClient(
        base: Uri.parse('https://app.example.org'),
        token: 't',
        httpClient: mock);
    expect(await client.events('/x').toList(), ['{"id":"r1","kind":"add"}']);
  });
}
