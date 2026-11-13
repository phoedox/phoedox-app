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

  Uri url(String path) => base.replace(
      path: '${base.path.replaceAll(RegExp(r'/$'), '')}/api/v1$path');

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
}
