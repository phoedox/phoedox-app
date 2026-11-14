import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../api/client.dart';
import '../features/floorplan/plan.dart';

/// Where a queued photo goes on a floor plan once it is uploaded.
class PlanPlacement {
  const PlanPlacement({
    required this.doc,
    required this.photoId,
    required this.x,
    required this.y,
    this.caption = '',
  });

  /// The floor plan document (id or slug).
  final String doc;

  /// The id of the photo on the plan, chosen on the device so a retry after
  /// a lost answer does not place the photo twice.
  final String photoId;

  /// Position in millimetres.
  final double x;
  final double y;
  final String caption;

  Map<String, dynamic> toJson() => {
        'doc': doc,
        'photoId': photoId,
        'x': x,
        'y': y,
        if (caption.isNotEmpty) 'caption': caption,
      };

  factory PlanPlacement.fromJson(Map<String, dynamic> j) => PlanPlacement(
        doc: j['doc'] as String,
        photoId: j['photoId'] as String,
        x: (j['x'] as num).toDouble(),
        y: (j['y'] as num).toDouble(),
        caption: j['caption'] as String? ?? '',
      );
}

/// A file recorded or taken on the device that the server has not got yet:
/// a voice note of an entry or a photo for a floor plan.
class PendingUpload {
  PendingUpload({
    required this.id,
    required this.project,
    required this.name,
    required this.path,
    required this.savedAt,
    this.entity,
    this.document,
    this.place,
    this.fileId,
    this.error,
  });

  /// Local id (also the name of the queued file).
  final String id;
  final String project;

  /// File name on the server, e.g. voice-note-2026-11-14-1205.m4a.
  final String name;

  /// The queued content on the device.
  final String path;
  final DateTime savedAt;

  /// Attach the file to this entry or document (slug or id).
  final String? entity;
  final String? document;

  /// Place the uploaded photo on this floor plan (through its draft).
  final PlanPlacement? place;

  /// Set once the upload went through; only the placement is left then.
  final String? fileId;

  /// Why the last attempt failed (a translation key), if it was refused.
  final String? error;

  bool get isAudio => isAudioName(name);

  Map<String, dynamic> toJson() => {
        'id': id,
        'project': project,
        'name': name,
        'path': path,
        'savedAt': savedAt.toIso8601String(),
        if (entity != null) 'entity': entity,
        if (document != null) 'document': document,
        if (place != null) 'place': place!.toJson(),
        if (fileId != null) 'fileId': fileId,
        if (error != null) 'error': error,
      };

  factory PendingUpload.fromJson(Map<String, dynamic> j) => PendingUpload(
        id: j['id'] as String,
        project: j['project'] as String,
        name: j['name'] as String? ?? 'file',
        path: j['path'] as String,
        savedAt:
            DateTime.tryParse(j['savedAt'] as String? ?? '') ?? DateTime.now(),
        entity: j['entity'] as String?,
        document: j['document'] as String?,
        place: j['place'] == null
            ? null
            : PlanPlacement.fromJson((j['place'] as Map).cast()),
        fileId: j['fileId'] as String?,
        error: j['error'] as String?,
      );

  PendingUpload copyWith(
          {String? fileId, String? error, bool clearError = false}) =>
      PendingUpload(
          id: id,
          project: project,
          name: name,
          path: path,
          savedAt: savedAt,
          entity: entity,
          document: document,
          place: place,
          fileId: fileId ?? this.fileId,
          error: clearError ? null : (error ?? this.error));
}

/// Audio files by name (the server's MIME type for .m4a depends on its system).
bool isAudioName(String name) =>
    RegExp(r'\.(m4a|aac|mp3|ogg|oga|opus|wav|webm)$', caseSensitive: false)
        .hasMatch(name);

/// What sending the queued uploads did.
class UploadReport {
  int sent = 0;
  int failed = 0;
  bool offline = false;

  /// Photos written into a floor plan draft (waiting to be published).
  int placedInDraft = 0;
}

/// Uploads made offline: a JSON list plus the files in [dir], kept until the
/// server has them (and, for plan photos, until the plan's draft has them).
class UploadQueue {
  UploadQueue(this.file, this.dir, {Random? random})
      : _random = random ?? Random.secure();

  final File file;
  final Directory dir;
  final Random _random;

  Future<List<PendingUpload>> list() async {
    if (!await file.exists()) return [];
    try {
      final data = jsonDecode(await file.readAsString()) as List;
      return data
          .map((e) => PendingUpload.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _write(List<PendingUpload> all) async {
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(all.map((e) => e.toJson()).toList()));
    await tmp.rename(file.path);
  }

  String newId() =>
      '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}${_random.nextInt(1 << 30).toRadixString(36)}';

  /// Queues [source] (copied into the queue's folder, so a temporary
  /// recording may be deleted afterwards).
  Future<PendingUpload> add({
    required String project,
    required String name,
    required File source,
    String? entity,
    String? document,
    PlanPlacement? place,
    DateTime? now,
  }) async {
    await dir.create(recursive: true);
    final id = newId();
    final ext = name.contains('.') ? name.substring(name.lastIndexOf('.')) : '';
    final kept = await source.copy('${dir.path}/$id$ext');
    final up = PendingUpload(
        id: id,
        project: project,
        name: name,
        path: kept.path,
        savedAt: now ?? DateTime.now(),
        entity: entity,
        document: document,
        place: place);
    await _write([...await list(), up]);
    return up;
  }

  /// Drops an upload and its file.
  Future<void> remove(String id) async {
    final all = await list();
    for (final u in all.where((u) => u.id == id)) {
      try {
        await File(u.path).delete();
      } catch (_) {}
    }
    await _write(all.where((u) => u.id != id).toList());
  }

  Future<void> _update(PendingUpload u) async {
    final all = await list();
    final i = all.indexWhere((e) => e.id == u.id);
    if (i < 0) return;
    all[i] = u;
    await _write(all);
  }

  /// Sends everything waiting, oldest first. An upload refused by the
  /// server stays with its error; offline ones stay as they are.
  Future<UploadReport> sync(PhxClient client) async {
    final report = UploadReport();
    for (var u in await list()) {
      try {
        if (u.fileId == null) {
          final f = File(u.path);
          if (!await f.exists()) {
            await remove(u.id); // nothing left to send
            continue;
          }
          final res = await client.upload(
              u.project, u.name, await f.readAsBytes(),
              entity: u.entity, document: u.document);
          u = u.copyWith(fileId: res['id'] as String, clearError: true);
          await _update(u);
        }
        if (u.place != null) {
          final inDraft =
              await placePhoto(client, u.project, u.place!, u.fileId!);
          if (inDraft) report.placedInDraft++;
        }
        await remove(u.id);
        report.sent++;
      } on OfflineException {
        report.offline = true;
        break; // the rest would fail the same way
      } on ApiException catch (x) {
        report.failed++;
        // 409: the plan changed meanwhile; the next round tries again.
        await _update(x.status == 409 ? u : u.copyWith(error: x.key));
      }
    }
    return report;
  }
}

/// Writes a photo into a floor plan through its draft (ADR-0027/0039): it
/// starts or joins the draft, adds the photo to the draft's plan and saves it.
/// It never publishes. Returns whether the change went into a draft.
///
/// The plan is saved with PATCH on the document: while a draft is open the
/// server puts it into the draft and tells people editing the plan live in
/// the browser to reload it, so their next save keeps the photo (a plain PUT
/// on the draft would not tell them). expectVersion guards the short moment
/// in which the draft could be published between both calls.
Future<bool> placePhoto(PhxClient client, String project, PlanPlacement place,
    String fileId) async {
  final docPath = '/projects/$project/documents/${place.doc}';
  final draft = await client.send('POST', '$docPath/draft') as Map;
  final raw = draft['markdown'];
  final plan = raw is String && raw.trim().isNotEmpty
      ? (jsonDecode(raw) as Map).cast<String, dynamic>()
      : <String, dynamic>{};
  final next = withPhoto(plan,
      id: place.photoId,
      file: fileId,
      x: place.x,
      y: place.y,
      caption: place.caption);
  if (identical(next, plan)) return true; // placed by an earlier attempt
  final res = await client.send('PATCH', docPath, {
    'floorplan': next,
    if (draft['baseVersion'] is int) 'expectVersion': draft['baseVersion'],
  });
  return res is Map && res['draft'] != null;
}
