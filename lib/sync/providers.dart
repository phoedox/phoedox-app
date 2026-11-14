import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../app/session.dart';
import 'outbox.dart';

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
