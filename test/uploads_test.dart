import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phoedox/api/client.dart';
import 'package:phoedox/sync/uploads.dart';

PhxClient client(Future<http.Response> Function(http.Request) handler) =>
    PhxClient(
        base: Uri.parse('https://phx.test'),
        token: 't',
        httpClient: MockClient(handler));

void main() {
  late Directory dir;
  late UploadQueue queue;
  late File recording;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('uploads');
    queue = UploadQueue(File('${dir.path}/outbox-uploads.json'),
        Directory('${dir.path}/outbox-files'));
    recording = File('${dir.path}/voice-1.m4a')..writeAsBytesSync([1, 2, 3, 4]);
  });
  tearDown(() => dir.delete(recursive: true));

  test('a voice note is kept on the device until it is sent', () async {
    final up = await queue.add(
        project: 'haus',
        name: 'voice-note-2026-11-14-1205.m4a',
        source: recording,
        entity: 'router');
    await recording.delete(); // the temporary recording may go
    expect(File(up.path).readAsBytesSync(), [1, 2, 3, 4]);
    final listed = (await queue.list()).single;
    expect(listed.entity, 'router');
    expect(listed.isAudio, isTrue);

    final offline =
        client((_) async => throw const SocketException('no network'));
    final r1 = await queue.sync(offline);
    expect(r1.offline, isTrue);
    expect(await queue.list(), hasLength(1));

    http.Request? sent;
    final r2 = await queue.sync(client((req) async {
      sent = req;
      return http.Response('{"id":"01JVOICE","name":"x"}', 201);
    }));
    expect(r2.sent, 1);
    expect(sent!.method, 'POST');
    expect(sent!.url.path, '/api/v1/projects/haus/files');
    expect(sent!.url.queryParameters,
        {'name': 'voice-note-2026-11-14-1205.m4a', 'entity': 'router'});
    expect(sent!.bodyBytes, [1, 2, 3, 4]);
    expect(await queue.list(), isEmpty);
    expect(File(up.path).existsSync(), isFalse);
  });

  test('a refused upload stays with the reason', () async {
    await queue.add(
        project: 'haus', name: 'v.m4a', source: recording, entity: 'router');
    final r = await queue.sync(client((_) async =>
        http.Response('{"key":"validation.quota_exceeded"}', 400)));
    expect(r.failed, 1);
    expect((await queue.list()).single.error, 'validation.quota_exceeded');
  });

  test('a plan photo is uploaded and written into the draft', () async {
    final plan = {
      'width': 10000,
      'height': 5000,
      'rooms': [],
      'devices': [
        {'id': 'd1', 'entity': 'router', 'x': 1, 'y': 2}
      ],
    };
    await queue.add(
        project: 'haus',
        name: 'plan-photo.jpg',
        source: recording,
        document: 'DOC1',
        place: const PlanPlacement(
            doc: 'DOC1', photoId: 'phx1', x: 1200, y: 800, caption: 'Hall'));
    final calls = <String>[];
    Map? patch;
    var uploadOk = true;
    var patchOk = false;
    Future<http.Response> server(http.Request req) async {
      calls.add('${req.method} ${req.url.path}');
      if (req.url.path.endsWith('/files')) {
        expect(req.url.queryParameters['document'], 'DOC1');
        return uploadOk
            ? http.Response('{"id":"01JPHOTO"}', 201)
            : http.Response('', 500);
      }
      if (req.method == 'POST' && req.url.path.endsWith('/draft')) {
        return http.Response(
            jsonEncode({
              'documentId': 'DOC1',
              'baseVersion': 7,
              'markdown': jsonEncode(plan)
            }),
            200);
      }
      if (req.method == 'PATCH') {
        if (!patchOk) throw const SocketException('lost');
        patch = jsonDecode(req.body) as Map;
        return http.Response(
            '{"applied":true,"draft":{"documentId":"DOC1"}}', 200);
      }
      return http.Response('', 404);
    }

    // First round: the upload goes through, the connection drops before
    // the plan is saved. The file id is kept, so it is not uploaded again.
    final r1 = await queue.sync(client(server));
    expect(r1.offline, isTrue);
    expect((await queue.list()).single.fileId, '01JPHOTO');

    uploadOk = false;
    patchOk = true;
    calls.clear();
    final r2 = await queue.sync(client(server));
    expect(r2.sent, 1);
    expect(r2.placedInDraft, 1);
    expect(calls, [
      'POST /api/v1/projects/haus/documents/DOC1/draft',
      'PATCH /api/v1/projects/haus/documents/DOC1',
    ]);
    expect(patch!['expectVersion'], 7);
    final saved = patch!['floorplan'] as Map;
    expect(saved['devices'], plan['devices']);
    expect(saved['photos'], [
      {'id': 'phx1', 'file': '01JPHOTO', 'x': 1200, 'y': 800, 'caption': 'Hall'}
    ]);
    expect(calls.any((c) => c.contains('publish')), isFalse);
    expect(await queue.list(), isEmpty);
  });

  test('placing again after a lost answer does not add the photo twice',
      () async {
    final plan = {
      'width': 10000,
      'height': 5000,
      'photos': [
        {'id': 'phx1', 'file': '01JPHOTO', 'x': 1200, 'y': 800}
      ],
    };
    var patched = false;
    final c = client((req) async {
      if (req.method == 'PATCH') patched = true;
      return http.Response(
          jsonEncode({'baseVersion': 3, 'markdown': jsonEncode(plan)}), 200);
    });
    final inDraft = await placePhoto(
        c,
        'haus',
        const PlanPlacement(doc: 'DOC1', photoId: 'phx1', x: 1200, y: 800),
        '01JPHOTO');
    expect(inDraft, isTrue);
    expect(patched, isFalse);
  });
}
