import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../app/session.dart';
import 'outbox.dart';
import 'uploads.dart';

final outboxProvider = FutureProvider<Outbox>((ref) async => Outbox(
    File('${(await getApplicationSupportDirectory()).path}/outbox.json')));

/// Page edits waiting for the server; [sync] sends them.
class PendingNotifier extends AsyncNotifier<List<PendingEdit>> {
  bool _syncing = false;

  @override
  Future<List<PendingEdit>> build() async =>
      (await ref.watch(outboxProvider.future)).list();

  Future<void> save(PendingEdit e) async {
    final box = await ref.read(outboxProvider.future);
    await box.put(e);
    state = AsyncData(await box.list());
    unawaited(sync());
  }

  /// Sends all waiting edits; null when nothing could be tried.
  Future<SyncReport?> sync() async {
    if (_syncing) return null;
    final client = await ref.read(clientProvider.future);
    if (client == null) return null;
    _syncing = true;
    try {
      final box = await ref.read(outboxProvider.future);
      if ((await box.list()).isEmpty) return SyncReport();
      final report = await box.sync(client);
      state = AsyncData(await box.list());
      // Pages show the server's text again.
      if (report.sent > 0) ref.invalidate(apiProvider);
      return report;
    } finally {
      _syncing = false;
    }
  }
}

final pendingProvider =
    AsyncNotifierProvider<PendingNotifier, List<PendingEdit>>(
        PendingNotifier.new);

final uploadQueueProvider = FutureProvider<UploadQueue>((ref) async {
  final dir = (await getApplicationSupportDirectory()).path;
  return UploadQueue(
      File('$dir/outbox-uploads.json'), Directory('$dir/outbox-files'));
});

/// Voice notes and plan photos waiting for the server; [sync] sends them.
class UploadsNotifier extends AsyncNotifier<List<PendingUpload>> {
  Future<UploadReport?>? _running;

  @override
  Future<List<PendingUpload>> build() async =>
      (await ref.watch(uploadQueueProvider.future)).list();

  /// Queues a file; call [sync] afterwards to try sending it right away.
  Future<PendingUpload> add({
    required String project,
    required String name,
    required File source,
    String? entity,
    String? document,
    PlanPlacement? place,
  }) async {
    final q = await ref.read(uploadQueueProvider.future);
    final up = await q.add(
        project: project,
        name: name,
        source: source,
        entity: entity,
        document: document,
        place: place);
    state = AsyncData(await q.list());
    return up;
  }

  Future<void> remove(String id) async {
    final q = await ref.read(uploadQueueProvider.future);
    await q.remove(id);
    state = AsyncData(await q.list());
  }

  /// Sends all waiting uploads; null without a session. A second call while
  /// one runs waits for that one.
  Future<UploadReport?> sync() => _running ??= _sync().whenComplete(() {
        _running = null;
      });

  Future<UploadReport?> _sync() async {
    final client = await ref.read(clientProvider.future);
    if (client == null) return null;
    final q = await ref.read(uploadQueueProvider.future);
    if ((await q.list()).isEmpty) return UploadReport();
    final report = await q.sync(client);
    state = AsyncData(await q.list());
    // Attachments and plans show the server's state again.
    if (report.sent > 0) ref.invalidate(apiProvider);
    return report;
  }
}

final uploadsProvider =
    AsyncNotifierProvider<UploadsNotifier, List<PendingUpload>>(
        UploadsNotifier.new);
