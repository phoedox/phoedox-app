import 'dart:convert';
import 'dart:io';

/// Stores the last answer per API path on disk, so pages stay readable offline.
class OfflineCache {
  OfflineCache(this.dir);

  final Directory dir;

  File _file(String key) => File(
      '${dir.path}/${base64Url.encode(utf8.encode(key)).replaceAll('=', '')}.json');

  Future<void> put(String key, String body) async {
    await dir.create(recursive: true);
    await _file(key).writeAsString(body);
  }

  Future<String?> get(String key) async {
    final f = _file(key);
    return await f.exists() ? f.readAsString() : null;
  }

  Future<void> clear() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}
