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
}
