import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phoedox/api/cache.dart';
import 'package:phoedox/api/client.dart';

void main() {
  test('falls back to the cache when offline', () async {
    final dir = await Directory.systemTemp.createTemp('phx');
    final cache = OfflineCache(dir);
    var online = true;
    final mock = MockClient((req) async {
      if (!online) throw const SocketException('offline');
      expect(req.headers['Authorization'], 'Bearer phx_t');
      expect(req.url.toString(), 'https://app.example.org/api/v1/projects');
      return http.Response('[{"slug":"haus"}]', 200);
    });
    final c = PhxClient(
        base: Uri.parse('https://app.example.org'),
        token: 'phx_t',
        cache: cache,
        httpClient: mock);
    final first = await c.get('/projects');
    expect(first.offline, isFalse);
    online = false;
    final second = await c.get('/projects');
    expect(second.offline, isTrue);
    expect((second.data as List).first['slug'], 'haus');
    await expectLater(c.get('/other'), throwsA(isA<OfflineException>()));
  });

  test('API errors carry the translation key', () async {
    final mock = MockClient(
        (_) async => http.Response('{"key":"error.not_found"}', 404));
    final c = PhxClient(
        base: Uri.parse('https://x.org'), token: 't', httpClient: mock);
    await expectLater(
        c.get('/p'),
        throwsA(isA<ApiException>()
            .having((e) => e.key, 'key', 'error.not_found')));
  });
}
