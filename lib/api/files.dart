import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../app/session.dart';
import 'client.dart';

/// Keeps downloaded files on the device (inside the offline cache, so signing
/// out removes them): a voice note or photo loaded once plays offline.
class FileCache {
  FileCache(this.dir);

  final Directory dir;

  File fileOf(String id) =>
      File('${dir.path}/${id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}');

  /// The local copy of a file, downloaded first if needed.
  Future<File> get(PhxClient? client, String id) async {
    final f = fileOf(id);
    if (await f.exists()) return f;
    if (client == null) throw OfflineException();
    final bytes = await client.download(id);
    await dir.create(recursive: true);
    final tmp = File('${f.path}.part');
    await tmp.writeAsBytes(bytes, flush: true);
    return tmp.rename(f.path);
  }
}

final fileCacheProvider = FutureProvider<FileCache>((ref) async => FileCache(
    Directory('${(await getApplicationSupportDirectory()).path}/cache/files')));

/// A project file on the device, by file id.
final localFileProvider = FutureProvider.family<File, String>((ref, id) async {
  final cache = await ref.watch(fileCacheProvider.future);
  return cache.get(await ref.watch(clientProvider.future), id);
});
