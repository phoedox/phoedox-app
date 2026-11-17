import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'cache.dart';

/// An answer of the API, possibly from the offline cache.
class ApiResult<T> {
  const ApiResult(this.data, {this.offline = false});

  final T data;
  final bool offline;
}

class ApiException implements Exception {
  ApiException(this.status, this.key);

  final int status;

  /// Translation key from the server (e.g. validation.title_required).
  final String key;

  @override
  String toString() => 'ApiException($status, $key)';
}

class OfflineException implements Exception {}

/// REST client for one Phoedox instance (Bearer token, see /api/v1/openapi.json).
class PhxClient {
  PhxClient(
      {required this.base,
      required this.token,
      this.cache,
      http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final Uri base;
  final String token;
  final OfflineCache? cache;
  final http.Client _http;

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'X-Phoedox': '1'
      };

  /// The URL of an API path; a query after "?" stays a query.
  Uri url(String path) {
    final q = path.indexOf('?');
    return base.replace(
        path:
            '${base.path.replaceAll(RegExp(r'/$'), '')}/api/v1${q < 0 ? path : path.substring(0, q)}',
        query: q < 0 ? null : path.substring(q + 1));
  }

  /// GETs JSON; falls back to the cached answer when the network fails.
  Future<ApiResult<dynamic>> get(String path) async {
    final key = '${base.host}$path';
    try {
      final res = await _http
          .get(url(path), headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (res.statusCode >= 400) {
        var k = 'error.unknown';
        try {
          k = (jsonDecode(res.body) as Map)['key'] as String? ?? k;
        } catch (_) {}
        throw ApiException(res.statusCode, k);
      }
      await cache?.put(key, res.body);
      return ApiResult(jsonDecode(utf8.decode(res.bodyBytes)));
    } on ApiException {
      rethrow;
    } catch (_) {
      final cached = await cache?.get(key);
      if (cached == null) throw OfflineException();
      return ApiResult(jsonDecode(cached), offline: true);
    }
  }

  ApiException _error(http.Response res) {
    var k = 'error.unknown';
    try {
      k = (jsonDecode(res.body) as Map)['key'] as String? ?? k;
    } catch (_) {}
    return ApiException(res.statusCode, k);
  }

  /// Sends JSON (POST, PUT, PATCH, DELETE). Throws [OfflineException] when
  /// the server cannot be reached and [ApiException] when it refuses.
  Future<dynamic> send(String method, String path, [Object? body]) async {
    final req = http.Request(method, url(path))
      ..headers.addAll({..._headers, 'Content-Type': 'application/json'});
    if (body != null) req.body = jsonEncode(body);
    final http.Response res;
    try {
      res = await http.Response.fromStream(
          await _http.send(req).timeout(const Duration(seconds: 30)));
    } catch (_) {
      throw OfflineException();
    }
    if (res.statusCode >= 400) throw _error(res);
    return res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
  }

  /// Downloads the content of a file (GET /files/{id}).
  Future<List<int>> download(String fileId) async {
    final http.Response res;
    try {
      res = await _http.get(url('/files/${Uri.encodeComponent(fileId)}'),
          headers: {
            ..._headers,
            'Accept': '*/*'
          }).timeout(const Duration(minutes: 2));
    } catch (_) {
      throw OfflineException();
    }
    if (res.statusCode >= 400) throw _error(res);
    return res.bodyBytes;
  }

  /// Uploads a file into a project (raw body), e.g. attached to an entry.
  Future<Map<String, dynamic>> upload(
      String project, String name, List<int> bytes,
      {String? entity, String? document}) async {
    final q = {
      'name': name,
      if (entity != null) 'entity': entity,
      if (document != null) 'document': document,
    };
    final u = url('/projects/$project/files').replace(queryParameters: q);
    final http.Response res;
    try {
      res = await _http
          .post(u,
              headers: {
                ..._headers,
                'Content-Type': 'application/octet-stream'
              },
              body: bytes)
          .timeout(const Duration(minutes: 2));
    } catch (_) {
      throw OfflineException();
    }
    if (res.statusCode >= 400) throw _error(res);
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  /// Sends raw bytes (e.g. a file people add in an app) and returns the JSON
  /// answer.
  Future<dynamic> sendBytes(String method, String path, List<int> bytes,
      {String contentType = 'application/octet-stream',
      Map<String, String>? query}) async {
    var u = url(path);
    if (query != null && query.isNotEmpty) {
      u = u.replace(queryParameters: query);
    }
    final req = http.Request(method, u)
      ..headers.addAll({..._headers, 'Content-Type': contentType})
      ..bodyBytes = bytes;
    final http.Response res;
    try {
      res = await http.Response.fromStream(
          await _http.send(req).timeout(const Duration(minutes: 2)));
    } catch (_) {
      throw OfflineException();
    }
    if (res.statusCode >= 400) throw _error(res);
    return res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
  }

  /// GETs raw bytes with their content type.
  Future<(List<int>, String)> getBytes(String path) async {
    final http.Response res;
    try {
      res = await _http.get(url(path), headers: {
        ..._headers,
        'Accept': '*/*'
      }).timeout(const Duration(minutes: 2));
    } catch (_) {
      throw OfflineException();
    }
    if (res.statusCode >= 400) throw _error(res);
    return (
      res.bodyBytes as List<int>,
      res.headers['content-type'] ?? 'application/octet-stream'
    );
  }

  /// Follows a server-sent event stream (text/event-stream) and yields the
  /// data of each event named [event]. Ends when the connection ends.
  Stream<String> events(String path, {String event = 'change'}) async* {
    final req = http.Request('GET', url(path))
      ..headers.addAll({..._headers, 'Accept': 'text/event-stream'});
    final res = await _http.send(req);
    if (res.statusCode >= 400) {
      throw ApiException(res.statusCode, 'error.unknown');
    }
    var name = 'message';
    final data = <String>[];
    await for (final line
        in res.stream.transform(utf8.decoder).transform(const LineSplitter())) {
      if (line.isEmpty) {
        if (name == event && data.isNotEmpty) yield data.join('\n');
        name = 'message';
        data.clear();
      } else if (line.startsWith('event:')) {
        name = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        data.add(line.substring(5).trimLeft());
      }
    }
  }
}
