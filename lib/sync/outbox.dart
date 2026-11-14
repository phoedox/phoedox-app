import 'dart:convert';
import 'dart:io';

import '../api/client.dart';
import 'merge.dart';

/// A page edited on the device that the server has not seen yet.
class PendingEdit {
  PendingEdit({
    required this.project,
    required this.docId,
    required this.title,
    required this.baseVersion,
    required this.base,
    required this.markdown,
    required this.savedAt,
    this.error,
  });

  final String project;
  final String docId;
  final String title;

  /// The published version and text the edit started from.
  final int baseVersion;
  final String base;

  /// The text on the device.
  final String markdown;
  final DateTime savedAt;

  /// Why the last attempt failed (a translation key), if it was refused.
  final String? error;

  String get key => '$project/$docId';

  Map<String, dynamic> toJson() => {
        'project': project,
        'docId': docId,
        'title': title,
        'baseVersion': baseVersion,
        'base': base,
        'markdown': markdown,
        'savedAt': savedAt.toIso8601String(),
        if (error != null) 'error': error,
      };

  factory PendingEdit.fromJson(Map<String, dynamic> j) => PendingEdit(
        project: j['project'] as String,
        docId: j['docId'] as String,
        title: j['title'] as String? ?? '',
        baseVersion: j['baseVersion'] as int? ?? 0,
        base: j['base'] as String? ?? '',
        markdown: j['markdown'] as String? ?? '',
        savedAt:
            DateTime.tryParse(j['savedAt'] as String? ?? '') ?? DateTime.now(),
        error: j['error'] as String?,
      );

  PendingEdit withError(String? e) => PendingEdit(
      project: project,
      docId: docId,
      title: title,
      baseVersion: baseVersion,
      base: base,
      markdown: markdown,
      savedAt: savedAt,
      error: e);
}

/// What a sync did.
class SyncReport {
  int sent = 0;
  int merged = 0;
  int failed = 0;
  bool offline = false;
}

/// Offline edits, kept in one JSON file until the server has them.
class Outbox {
  Outbox(this.file);

  final File file;

  Future<List<PendingEdit>> list() async {
    if (!await file.exists()) return [];
    try {
      final data = jsonDecode(await file.readAsString()) as List;
      return data
          .map((e) => PendingEdit.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _write(List<PendingEdit> edits) async {
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(edits.map((e) => e.toJson()).toList()));
    await tmp.rename(file.path);
  }

  Future<PendingEdit?> get(String project, String docId) async {
    for (final e in await list()) {
      if (e.project == project && e.docId == docId) return e;
    }
    return null;
  }

  /// Keeps an edit. A second edit of the same page keeps the first base,
  /// so the merge still sees everything changed on the device.
  Future<void> put(PendingEdit edit) async {
    final all = await list();
    final i = all.indexWhere((e) => e.key == edit.key);
    if (i >= 0) {
      final first = all[i];
      all[i] = PendingEdit(
          project: edit.project,
          docId: edit.docId,
          title: edit.title,
          baseVersion: first.baseVersion,
          base: first.base,
          markdown: edit.markdown,
          savedAt: edit.savedAt);
    } else {
      all.add(edit);
    }
    await _write(all);
  }

  Future<void> remove(String key) async {
    await _write((await list()).where((e) => e.key != key).toList());
  }

  /// Sends all edits. If the page changed meanwhile (published or in an open
  /// draft), the device's changes are merged into the current text with
  /// yrs, so nobody's changes are lost. With an open draft the server puts
  /// the change into the draft.
  Future<SyncReport> sync(PhxClient client) async {
    final report = SyncReport();
    final keep = <String, PendingEdit>{};
    final sent = <String, DateTime>{};
    for (final e in await list()) {
      try {
        final doc = await client.send(
            'GET', '/projects/${e.project}/documents/${e.docId}') as Map;
        final version = doc['version'] as int? ?? 0;
        var theirs = ((doc['content'] as Map?)?['markdown'] as String?) ?? '';
        Map? draft;
        try {
          draft = await client.send(
                  'GET', '/projects/${e.project}/documents/${e.docId}/draft')
              as Map?;
        } on ApiException catch (x) {
          if (x.status != 404) rethrow;
        }
        if (draft != null) theirs = draft['markdown'] as String? ?? theirs;
        final changed = draft != null || version != e.baseVersion;
        final text = changed ? merge3(e.base, e.markdown, theirs) : e.markdown;
        await client
            .send('PATCH', '/projects/${e.project}/documents/${e.docId}', {
          'markdown': text,
          if (draft == null) 'expectVersion': version,
        });
        report.sent++;
        sent[e.key] = e.savedAt;
        if (changed) report.merged++;
      } on OfflineException {
        report.offline = true;
        keep[e.key] = e;
      } on ApiException catch (x) {
        // 409: changed again in the meantime; the next sync merges again.
        report.failed++;
        keep[e.key] = x.status == 409 ? e : e.withError(x.key);
      }
    }
    // Edits saved on the device while syncing stay for the next round.
    final now = await list();
    await _write([
      for (final e in now)
        if (sent[e.key] != e.savedAt)
          (keep[e.key]?.savedAt == e.savedAt ? keep[e.key]! : e),
    ]);
    return report;
  }
}
