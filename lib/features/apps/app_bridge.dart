import 'dart:convert';

import '../../api/cache.dart';
import '../../api/client.dart';
import '../../sync/app_outbox.dart';

/// What the app may do here (GET /projects/{p}/apps/{doc}/open).
class AppFrameInfo {
  AppFrameInfo(
      {required this.url,
      required this.level,
      required this.maxLevel,
      required this.granted,
      required this.ai,
      required this.sources});

  final String url;
  final int level;
  final int maxLevel;
  int granted;
  final bool ai;
  final List<Map<String, dynamic>> sources;

  /// The level in effect: what the person granted, at most what the app may.
  int get effective => granted < maxLevel ? granted : maxLevel;

  factory AppFrameInfo.fromJson(Map<String, dynamic> j) => AppFrameInfo(
        url: j['url'] as String? ?? '',
        level: (j['level'] as num?)?.toInt() ?? 0,
        maxLevel: (j['maxLevel'] as num?)?.toInt() ??
            (j['level'] as num?)?.toInt() ??
            0,
        granted: (j['granted'] as num?)?.toInt() ?? 0,
        ai: j['ai'] as bool? ?? false,
        sources: ((j['sources'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
      );
}

/// A change an app proposes (level 3); the person confirms it.
typedef ConfirmProposal = Future<bool> Function(Map<String, dynamic> change);

/// Asks the person for the level the app wants; returns the chosen level
/// (-1 = declined).
typedef AskLevel = Future<int> Function(int wanted);

class BridgeError implements Exception {
  BridgeError(this.code, [this.message]);
  final String code;
  final String? message;
}

/// Answers the calls of an app's bridge (internal/core/appbridge.js) the
/// way the web app does: every call is checked against the level the person
/// granted; storage works offline (reads from the cache, writes through the
/// outbox).
class AppBridge {
  AppBridge(
      {required this.client,
      required this.project,
      required this.doc,
      required this.info,
      required this.askLevel,
      required this.confirm,
      required this.open,
      this.outbox,
      this.cache});

  final PhxClient client;
  final String project;
  final String doc;
  final AppFrameInfo info;
  final AskLevel askLevel;
  final ConfirmProposal confirm;
  final void Function(String ref) open;
  final AppOutbox? outbox;
  final OfflineCache? cache;

  String get _base => '/projects/$project/apps/${Uri.encodeComponent(doc)}';

  Future<void> _need(int level) async {
    if (info.effective >= level) return;
    if (info.maxLevel < level) throw BridgeError('not_allowed');
    if (await _ask() < level) throw BridgeError('not_allowed');
  }

  Future<int> _ask() async {
    if (info.effective >= info.maxLevel) return info.effective;
    final lvl = await askLevel(info.maxLevel);
    if (lvl < 0) return info.effective;
    final res =
        await client.send('PUT', '$_base/grant', {'level': lvl}) as Map?;
    info.granted = (res?['granted'] as num?)?.toInt() ?? lvl;
    return info.effective;
  }

  String _storagePath(String key, bool personal) =>
      '$_base/storage/${Uri.encodeComponent(key)}${personal ? '?personal=1' : ''}';

  /// Handles one call; returns the answer message for the app.
  Future<Map<String, dynamic>> handle(Map<String, dynamic> m) async {
    final id = m['id'];
    final op = m['op'] as String? ?? '';
    final a = Map<String, dynamic>.from((m['args'] as Map?) ?? const {});
    Map<String, dynamic> ok(Object? result) =>
        {'phx': 1, 'id': id, 'result': result};
    try {
      switch (op) {
        case 'info':
          return ok({
            'level': info.level,
            'granted': info.effective,
            'project': project,
            'sources': [
              for (final s in info.sources)
                {'id': s['id'], 'kind': s['kind'], 'label': s['label'] ?? ''}
            ],
          });
        case 'grant':
          return ok(await _ask());
        case 'read':
          await _need(1);
          final key = 'appread:${client.base.host}$_base/${a['source']}';
          try {
            final r = await client.send(
                'POST', '$_base/read', {'source': '${a['source'] ?? ''}'});
            await cache?.put(key, jsonEncode(r));
            return ok(r);
          } on OfflineException {
            final c = await cache?.get(key);
            if (c == null) rethrow;
            return ok(jsonDecode(c));
          }
        case 'storage.get':
          await _need(2);
          final key = '${a['key']}';
          final personal = a['personal'] == true;
          final waiting = (await outbox?.pendingFor(
              project, doc))?['${personal ? 'p:' : ''}$key'];
          if (waiting != null) return ok(waiting.delete ? null : waiting.value);
          return ok((await client.get(_storagePath(key, personal))).data);
        case 'storage.list':
          await _need(2);
          final personal = a['personal'] == true;
          return ok((await client
                  .get('$_base/storage${personal ? '?personal=1' : ''}'))
              .data);
        case 'storage.set':
        case 'storage.delete':
          await _need(2);
          final key = '${a['key']}';
          final personal = a['personal'] == true;
          final del = op == 'storage.delete';
          try {
            if (del) {
              await client.send('DELETE', _storagePath(key, personal));
            } else {
              await client.send(
                  'PUT', _storagePath(key, personal), {'value': a['value']});
            }
          } on OfflineException {
            if (outbox == null) rethrow;
            await outbox!.add(AppStorageOp(
                project: project,
                doc: doc,
                key: key,
                personal: personal,
                value: a['value'],
                delete: del));
          }
          return ok(true);
        case 'write':
          await _need(3);
          final kind = a['kind'];
          if (kind != 'task' && kind != 'comment' && kind != 'entity') {
            throw BridgeError('bad_proposal');
          }
          if (!await confirm(a)) throw BridgeError('declined');
          final pr = '/projects/$project';
          return ok(switch (kind) {
            'task' => await client.send('POST',
                  '$pr/boards/${Uri.encodeComponent('${a['board']}')}/tasks', {
                'title': a['title'],
                'description': a['description'] ?? '',
                'column': a['column'] ?? ''
              }),
            'comment' => await client.send(
                'POST',
                '$pr/documents/${Uri.encodeComponent('${a['document']}')}/comments',
                {'body': a['body']}),
            _ => await client.send('POST', '$pr/entities', {
                'kind': a['entityKind'],
                'name': a['name'],
                'attrs': a['attrs'] ?? {}
              }),
          });
        case 'open':
          final ref = '${a['ref'] ?? ''}';
          if (!RegExp(r'^[\w@.-]+$').hasMatch(ref)) return ok(false);
          open(ref);
          return ok(true);
        case 'ai':
          if (!info.ai) throw BridgeError('ai_unavailable');
          final r = await client.send('POST', '$_base/ai', {
            'prompt': '${a['prompt'] ?? ''}',
            'json': a['json'] == true
          }) as Map?;
          return ok(a['json'] == true && r?['json'] != null
              ? r!['json']
              : r?['text']);
        default:
          throw BridgeError('unknown');
      }
    } on BridgeError catch (e) {
      return {'phx': 1, 'id': id, 'error': e.message ?? e.code, 'code': e.code};
    } on OfflineException {
      return {'phx': 1, 'id': id, 'error': 'offline', 'code': 'offline'};
    } on ApiException catch (e) {
      return {'phx': 1, 'id': id, 'error': e.key, 'code': e.key};
    }
  }
}
