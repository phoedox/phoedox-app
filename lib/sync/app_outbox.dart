import 'dart:convert';
import 'dart:io';

import '../api/client.dart';

/// A write to an app's storage made offline (set or delete).
class AppStorageOp {
  AppStorageOp(
      {required this.project,
      required this.doc,
      required this.key,
      required this.personal,
      this.value,
      this.delete = false,
      DateTime? at})
      : at = at ?? DateTime.now();

  final String project;
  final String doc;
  final String key;
  final bool personal;
  final Object? value;
  final bool delete;
  final DateTime at;

  String get path =>
      '/projects/$project/apps/${Uri.encodeComponent(doc)}/storage/${Uri.encodeComponent(key)}${personal ? '?personal=1' : ''}';

  Map<String, dynamic> toJson() => {
        'project': project,
        'doc': doc,
        'key': key,
        'personal': personal,
        'value': value,
        'delete': delete,
        'at': at.toIso8601String(),
      };

  factory AppStorageOp.fromJson(Map<String, dynamic> j) => AppStorageOp(
        project: j['project'] as String,
        doc: j['doc'] as String,
        key: j['key'] as String,
        personal: j['personal'] as bool? ?? false,
        value: j['value'],
        delete: j['delete'] as bool? ?? false,
        at: DateTime.tryParse(j['at'] as String? ?? ''),
      );
}

/// Storage writes of apps that wait for the network. Later writes to the
/// same key replace earlier ones; they are sent in order when online.
class AppOutbox {
  AppOutbox(this.file);

  final File file;

  Future<List<AppStorageOp>> list() async {
    if (!await file.exists()) return [];
    try {
      final raw = jsonDecode(await file.readAsString()) as List;
      return raw
          .map(
              (e) => AppStorageOp.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _save(List<AppStorageOp> ops) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(ops.map((o) => o.toJson()).toList()));
  }

  Future<void> add(AppStorageOp op) async {
    final ops = (await list())
        .where((o) => !(o.project == op.project &&
            o.doc == op.doc &&
            o.key == op.key &&
            o.personal == op.personal))
        .toList()
      ..add(op);
    await _save(ops);
  }

  /// The waiting writes of one app, by storage key ("p:" prefix = personal).
  Future<Map<String, AppStorageOp>> pendingFor(
      String project, String doc) async {
    final out = <String, AppStorageOp>{};
    for (final o in await list()) {
      if (o.project == project && o.doc == doc) {
        out['${o.personal ? 'p:' : ''}${o.key}'] = o;
      }
    }
    return out;
  }

  /// Sends what waits; returns (sent, failed). Stops at the first offline error.
  Future<(int, int)> flush(PhxClient client) async {
    final ops = await list();
    var sent = 0, failed = 0;
    final left = <AppStorageOp>[];
    for (var i = 0; i < ops.length; i++) {
      final o = ops[i];
      try {
        if (o.delete) {
          await client.send('DELETE', o.path);
        } else {
          await client.send('PUT', o.path, {'value': o.value});
        }
        sent++;
      } on OfflineException {
        left.addAll(ops.sublist(i));
        break;
      } on ApiException {
        failed++; // refused (e.g. access withdrawn): dropped
      }
    }
    await _save(left);
    return (sent, failed);
  }
}
