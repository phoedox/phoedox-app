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
      required this.sources,
      this.devices = const [],
      Map<String, bool>? deviceGrants,
      this.selfEdit = false,
      this.canEdit = false})
      : deviceGrants = deviceGrants ?? {};

  final String url;
  final int level;
  final int maxLevel;
  int granted;
  final bool ai;
  final List<Map<String, dynamic>> sources;

  /// Device features the app may ask for (camera, microphone, location,
  /// screen, motion); the person allows each one separately.
  final List<String> devices;

  /// The person's answers per feature; a feature not asked yet is missing.
  Map<String, bool> deviceGrants;

  /// The app may save its own files; [canEdit]: this person may edit it.
  final bool selfEdit;
  final bool canEdit;

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
        devices: ((j['devices'] as List?) ?? const []).cast<String>(),
        deviceGrants: _grants(j['deviceGrants']),
        selfEdit: j['selfEdit'] as bool? ?? false,
        canEdit: j['canEdit'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'url': url,
        'level': level,
        'maxLevel': maxLevel,
        'granted': granted,
        'ai': ai,
        'sources': sources,
        'devices': devices,
        'deviceGrants': deviceGrants,
        'selfEdit': selfEdit,
        'canEdit': canEdit,
      };
}

Map<String, bool> _grants(Object? v) => {
      for (final e in ((v as Map?) ?? const {}).entries)
        '${e.key}': e.value == true
    };

/// Device features the phone gives apps through Phoedox (screen sharing does
/// not exist in the app's WebView).
const nativeDevices = {'camera', 'microphone', 'location', 'motion'};

/// What the page around the app does for the bridge: dialogs and the
/// device's features.
class AppHost {
  const AppHost({
    required this.askDevice,
    required this.confirmDownload,
    required this.saveFile,
    required this.confirmSelfSave,
    required this.location,
    required this.startMotion,
    required this.startWatch,
  });

  /// Asks the person about one feature; true = allowed.
  final Future<bool> Function(String feature) askDevice;
  final Future<bool> Function(String name, int size) confirmDownload;
  final Future<void> Function(String name, List<int> bytes, String type)
      saveFile;
  final Future<bool> Function(List<String> files) confirmSelfSave;

  /// The position once: {lat, lng, accuracy, at}.
  final Future<Map<String, dynamic>> Function() location;
  final void Function() startMotion;

  /// Starts following changes of the app's records (once).
  final void Function() startWatch;
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
      this.host,
      this.outbox,
      this.cache});

  final PhxClient client;
  final String project;
  final String doc;
  final AppFrameInfo info;
  final AskLevel askLevel;
  final ConfirmProposal confirm;
  final void Function(String ref) open;
  final AppHost? host;
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

  String _coll(Map<String, dynamic> a) =>
      '$_base/db/${Uri.encodeComponent('${a['collection'] ?? ''}')}';

  AppHost get _host => host ?? (throw BridgeError('not_supported'));

  /// Asks for one device feature: each one separately and once; people
  /// change their answer in the app's permissions.
  Future<bool> _device(String f) async {
    if (!info.devices.contains(f)) throw BridgeError('not_allowed');
    if (!nativeDevices.contains(f)) throw BridgeError('not_supported');
    final had = info.deviceGrants[f];
    if (had != null) return had;
    final ok = await _host.askDevice(f);
    final res = await client.send('PUT', '$_base/devices/$f', {'allowed': ok});
    info.deviceGrants =
        res is Map ? _grants(res) : {...info.deviceGrants, f: ok};
    return ok;
  }

  /// Bytes of a value the app sends: text, or a file as {base64, type}.
  static (List<int>, String) _bytes(Object? v, String type) {
    if (v is Map && v['base64'] is String) {
      return (base64Decode(v['base64'] as String), '${v['type'] ?? type}');
    }
    return (utf8.encode('${v ?? ''}'), type);
  }

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
            'selfEdit': info.selfEdit && info.canEdit,
          });
        case 'me':
          await _need(1);
          return ok((await client.get('$_base/me')).data);
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
        case 'db.add':
          await _need(2);
          return ok(await client.send('POST', _coll(a),
              {'personal': a['personal'] == true, 'data': a['data']}));
        case 'db.put':
          await _need(2);
          return ok(await client.send(
              'PUT',
              '${_coll(a)}/${Uri.encodeComponent('${a['id']}')}',
              {'data': a['data'], 'merge': a['merge'] == true}));
        case 'db.delete':
          await _need(2);
          await client.send(
              'DELETE', '${_coll(a)}/${Uri.encodeComponent('${a['id']}')}');
          return ok(true);
        case 'db.query':
          await _need(2);
          return ok(await client.send('POST', '${_coll(a)}/query', {
            ...Map<String, dynamic>.from((a['query'] as Map?) ?? const {}),
            'personal': a['personal'] == true,
          }));
        case 'db.watch':
          await _need(2);
          host?.startWatch();
          return ok(true);
        case 'files.upload':
          await _need(2);
          final (bytes, type) = _bytes(a['file'], 'application/octet-stream');
          return ok(await client.sendBytes('POST', '$_base/uploads', bytes,
              contentType: type, query: {'name': '${a['name'] ?? 'file'}'}));
        case 'files.list':
          await _need(2);
          return ok((await client.get('$_base/uploads')).data);
        case 'files.get':
          await _need(2);
          final (bytes, type) = await client
              .getBytes('$_base/uploads/${Uri.encodeComponent('${a['id']}')}');
          return ok({'base64': base64Encode(bytes), 'type': type});
        case 'files.delete':
          await _need(2);
          await client.send(
              'DELETE', '$_base/uploads/${Uri.encodeComponent('${a['id']}')}');
          return ok(true);
        case 'download':
          final name = '${a['name'] ?? ''}'
              .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_');
          final (bytes, type) =
              _bytes(a['data'], '${a['type'] ?? 'text/plain'}');
          if (bytes.length > 50 << 20) throw BridgeError('too_large');
          final file = name.isEmpty
              ? 'file'
              : name.substring(0, name.length > 120 ? 120 : name.length);
          if (!await _host.confirmDownload(file, bytes.length)) {
            throw BridgeError('cancelled');
          }
          await _host.saveFile(file, bytes, type);
          return ok(true);
        case 'device.status':
          return ok({for (final d in info.devices) d: info.deviceGrants[d]});
        case 'device.request':
          return ok(await _device('${a['feature'] ?? ''}'));
        case 'device.location':
          if (!await _device('location')) throw BridgeError('not_allowed');
          return ok(await _host.location());
        case 'device.motion':
          if (!await _device('motion')) throw BridgeError('not_allowed');
          _host.startMotion();
          return ok(true);
        case 'self.files':
          if (!info.selfEdit) throw BridgeError('not_allowed');
          return ok((await client.get('$_base/self')).data);
        case 'self.save':
          if (!info.selfEdit || !info.canEdit) throw BridgeError('not_allowed');
          final files = Map<String, dynamic>.from((a['files'] as Map?) ?? {});
          if (files.isEmpty) throw BridgeError('bad_files');
          if (!await _host.confirmSelfSave(files.keys.toList())) {
            throw BridgeError('cancelled');
          }
          return ok(await client.send('PUT', '$_base/self', {'files': files}));
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
