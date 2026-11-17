import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../api/client.dart';
import '../../app/session.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../sync/app_outbox.dart';
import '../doc/doc_page.dart';
import '../entity/entity_page.dart';
import 'app_bridge.dart';

/// The outbox of apps' storage writes (sent with the other offline edits).
final appOutboxProvider = FutureProvider<AppOutbox>((ref) async => AppOutbox(
    File('${(await getApplicationSupportDirectory()).path}/app_outbox.json')));

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// An app document (ADR "What an app is") in a WebView on the app domain,
/// with the same bridge as in the browser: Phoedox's own dialogs ask for
/// access and confirm changes; storage works offline.
class AppBody extends ConsumerStatefulWidget {
  const AppBody({super.key, required this.project, required this.doc});

  final String project;
  final String doc;

  @override
  ConsumerState<AppBody> createState() => _AppBodyState();
}

class _AppBodyState extends ConsumerState<AppBody> {
  WebViewController? _web;
  AppBridge? _bridge;
  String? _error;
  bool _offline = false;
  StreamSubscription<String>? _watch;
  StreamSubscription<AccelerometerEvent>? _acc;
  StreamSubscription<GyroscopeEvent>? _gyro;
  GyroscopeEvent? _lastGyro;
  DateTime _motionAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _watch?.cancel();
    _acc?.cancel();
    _gyro?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  /// WebViews exist on Android, iOS and macOS; elsewhere the app opens in
  /// the browser.
  static bool get supported =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  Future<void> _start() async {
    final client = await ref.read(clientProvider.future);
    if (client == null) return;
    if (!supported) {
      if (mounted) setState(() => _error = 'browser');
      return;
    }
    final cache = await ref.read(cacheProvider.future);
    final outbox = await ref.read(appOutboxProvider.future);
    final base =
        '/projects/${widget.project}/apps/${Uri.encodeComponent(widget.doc)}';
    try {
      // POST /open (the frame's address and what the person allowed); kept
      // for offline use.
      final openKey = 'appopen:${client.base.host}$base';
      Map<String, dynamic> data;
      var offline = false;
      try {
        data = Map<String, dynamic>.from(
            await client.send('POST', '$base/open') as Map);
        await cache.put(openKey, jsonEncode(data));
      } on OfflineException {
        final c = await cache.get(openKey);
        if (c == null) rethrow;
        data = Map<String, dynamic>.from(jsonDecode(c) as Map);
        offline = true;
      }
      final info = AppFrameInfo.fromJson(data);
      final frame = client.base.resolve(info.url);
      _bridge = AppBridge(
          client: client,
          project: widget.project,
          doc: widget.doc,
          info: info,
          askLevel: _askLevel,
          confirm: _confirm,
          open: _open,
          host: AppHost(
              askDevice: _askDevice,
              confirmDownload: _confirmDownload,
              saveFile: _saveFile,
              confirmSelfSave: _confirmSelfSave,
              location: _location,
              startMotion: _startMotion,
              startWatch: () => _startWatch(client, base)),
          outbox: outbox,
          cache: cache);
      // Camera and microphone reach the app only for features the person
      // allowed in Phoedox; the phone asks as well.
      final web = WebViewController(onPermissionRequest: _onPermission)
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..addJavaScriptChannel('PhoedoxBridge',
            onMessageReceived: (m) => _onCall(m.message))
        ..setNavigationDelegate(NavigationDelegate(onNavigationRequest: (req) {
          final u = Uri.parse(req.url);
          // The app stays on its frame; links leave to the browser.
          if (u.origin == frame.origin ||
              u.scheme == 'about' ||
              u.scheme == 'data') {
            return NavigationDecision.navigate;
          }
          launchUrl(u, mode: LaunchMode.externalApplication);
          return NavigationDecision.prevent;
        }));
      final cacheKey = 'appframe:${client.base.host}$base';
      if (offline) {
        // Offline: the page as it was last seen.
        final html = await cache.get(cacheKey);
        if (html == null) throw OfflineException();
        await web.loadHtmlString(html, baseUrl: frame.toString());
        _offline = true;
      } else {
        await web.loadRequest(frame);
        // Keep the page for offline use.
        http.get(frame).then((res) async {
          if (res.statusCode == 200) {
            await cache.put(cacheKey, utf8.decode(res.bodyBytes));
          }
        }, onError: (_) {});
      }
      if (mounted) setState(() => _web = web);
    } on OfflineException {
      if (mounted) setState(() => _error = 'offline');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.key);
    }
  }

  Future<void> _onCall(String raw) async {
    final web = _web, bridge = _bridge;
    if (web == null || bridge == null) return;
    Map<String, dynamic> m;
    try {
      m = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return;
    }
    switch (m['op']) {
      case 'ready':
        return _send(_themeEvent());
      case 'resize':
      case 'console':
        return;
    }
    if (m['id'] == null) return;
    _send(await bridge.handle(m));
  }

  Map<String, dynamic> _themeEvent() {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return {
      'phx': 1,
      'event': 'theme',
      'dark': dark,
      'tokens': {
        'bg': _hex(Theme.of(context).scaffoldBackgroundColor),
        'surface': _hex(cs.surface),
        'surface2': _hex(cs.surfaceContainerHighest),
        'line': _hex(cs.outlineVariant),
        'fg': _hex(cs.onSurface),
        'muted': _hex(cs.onSurfaceVariant),
        'accent': _hex(cs.primary),
        'accent-soft': _hex(cs.primaryContainer),
        'good': _hex(cs.tertiary),
        'bad': _hex(cs.error),
      },
    };
  }

  void _send(Map<String, dynamic> msg) {
    final js = jsonEncode(jsonEncode(msg));
    _web?.runJavaScript(
        "window.dispatchEvent(new MessageEvent('message', {data: JSON.parse($js), source: window}));");
  }

  void _onPermission(WebViewPermissionRequest req) {
    final info = _bridge?.info;
    final wanted = req.types.map((t) => switch (t) {
          WebViewPermissionResourceType.camera => 'camera',
          WebViewPermissionResourceType.microphone => 'microphone',
          _ => '',
        });
    final allowed = info != null &&
        wanted.isNotEmpty &&
        wanted.every((f) =>
            f.isNotEmpty &&
            info.devices.contains(f) &&
            info.deviceGrants[f] == true);
    if (!allowed) {
      req.deny();
      return;
    }
    if (!Platform.isAndroid) {
      req.grant(); // iOS and macOS ask the person themselves
      return;
    }
    // Android: the WebView gets the camera or microphone only when the app
    // has the permission; ask for it now (after the person agreed in Phoedox).
    final perms = [
      if (wanted.contains('camera')) Permission.camera,
      if (wanted.contains('microphone')) Permission.microphone,
    ];
    () async {
      try {
        final r = await perms.request();
        r.values.every((s) => s.isGranted) ? req.grant() : req.deny();
      } catch (_) {
        req.deny();
      }
    }();
  }

  /// Follows changes of the app's records (others' writes) and passes them
  /// to the app; reconnects while the page is open.
  void _startWatch(PhxClient client, String base) {
    if (_watch != null) return;
    void connect() {
      _watch = client.events('$base/events').listen(
          (data) {
            try {
              _send({'phx': 1, 'event': 'db', 'change': jsonDecode(data)});
            } catch (_) {}
          },
          onError: (_) {},
          onDone: () {
            if (_disposed) return;
            Future.delayed(const Duration(seconds: 5), () {
              if (!_disposed) connect();
            });
          },
          cancelOnError: true);
    }

    connect();
  }

  void _startMotion() {
    if (_acc != null) return;
    const deg = 57.29577951308232;
    _gyro =
        gyroscopeEventStream().listen((e) => _lastGyro = e, onError: (_) {});
    _acc = accelerometerEventStream().listen((e) {
      final now = DateTime.now();
      if (now.difference(_motionAt).inMilliseconds < 100) return;
      _motionAt = now;
      final g = _lastGyro;
      // Like the browser's devicemotion: acceleration with gravity (m/s²),
      // rotation rate in degrees per second.
      _send({
        'phx': 1,
        'event': 'motion',
        'motion': {
          'x': e.x,
          'y': e.y,
          'z': e.z,
          'alpha': g == null ? null : g.z * deg,
          'beta': g == null ? null : g.x * deg,
          'gamma': g == null ? null : g.y * deg,
        }
      });
    }, onError: (_) {});
  }

  Future<Map<String, dynamic>> _location() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw BridgeError('location_off');
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      throw BridgeError('not_allowed');
    }
    final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)));
    return {
      'lat': p.latitude,
      'lng': p.longitude,
      'accuracy': p.accuracy,
      'at': p.timestamp.millisecondsSinceEpoch
    };
  }

  /// Asks for one device feature; each one is asked separately.
  Future<bool> _askDevice(String feature) async {
    final t = AppLocalizations.of(context);
    final (icon, what) = switch (feature) {
      'camera' => (LucideIcons.camera, t.appDeviceCamera),
      'microphone' => (LucideIcons.mic, t.appDeviceMicrophone),
      'location' => (LucideIcons.mapPin, t.appDeviceLocation),
      _ => (LucideIcons.smartphone, t.appDeviceMotion),
    };
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        icon: Icon(icon),
        title: Text(t.appDeviceTitle(what)),
        content: Text(t.appDeviceBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(t.appDeviceDeny)),
          FilledButton(
              onPressed: () => Navigator.pop(c, true), child: Text(t.appAllow)),
        ],
      ),
    );
    return ok == true;
  }

  Future<bool> _confirmDownload(String name, int size) async {
    final t = AppLocalizations.of(context);
    final kb = (size / 1024).ceil();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(LucideIcons.download),
        title: Text(t.appDownloadTitle),
        content: Text(t.appDownloadBody(name, kb)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false), child: Text(t.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(t.appDownloadSave)),
        ],
      ),
    );
    return ok == true;
  }

  /// Hands the file to the phone's share sheet (save to files, send, open).
  Future<void> _saveFile(String name, List<int> bytes, String type) async {
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(ShareParams(
        files: [
          XFile.fromData(Uint8List.fromList(bytes), mimeType: type, name: name)
        ],
        fileNameOverrides: [
          name
        ],
        sharePositionOrigin:
            box == null ? null : box.localToGlobal(Offset.zero) & box.size));
  }

  Future<bool> _confirmSelfSave(List<String> files) async {
    final t = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(LucideIcons.filePen),
        title: Text(t.appSelfSaveTitle),
        content: Text(t.appSelfSaveBody(files.join(', '))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false), child: Text(t.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(t.appSelfSaveConfirm)),
        ],
      ),
    );
    return ok == true;
  }

  Future<int> _askLevel(int wanted) async {
    final t = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(LucideIcons.shieldCheck),
        title: Text(t.appAccessTitle),
        content: Text(switch (wanted) {
          1 => t.appLevel1,
          2 => t.appLevel2,
          _ => t.appLevel3,
        }),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(t.appNotNow)),
          FilledButton(
              onPressed: () => Navigator.pop(c, true), child: Text(t.appAllow)),
        ],
      ),
    );
    return ok == true ? wanted : -1;
  }

  Future<bool> _confirm(Map<String, dynamic> change) async {
    final t = AppLocalizations.of(context);
    final what = switch (change['kind']) {
      'task' => t.appProposeTask(
          '${change['title'] ?? ''}', '${change['board'] ?? ''}'),
      'comment' => t.appProposeComment(
          '${change['document'] ?? ''}', '${change['body'] ?? ''}'),
      _ => t.appProposeEntity(
          '${change['name'] ?? ''}', '${change['entityKind'] ?? ''}'),
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t.appProposeTitle),
        content: Text(what),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false), child: Text(t.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(t.appConfirm)),
        ],
      ),
    );
    return ok == true;
  }

  void _open(String ref) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ref.startsWith('@')
            ? EntityPage(project: widget.project, entity: ref.substring(1))
            : DocPage(project: widget.project, doc: ref)));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    if (_error == 'browser') {
      return Center(
          child: FilledButton.tonalIcon(
              icon: const Icon(LucideIcons.externalLink, size: 16),
              label: Text(t.openLink),
              onPressed: () async {
                final c = await ref.read(clientProvider.future);
                if (c != null) {
                  launchUrl(
                      c.base.resolve('/p/${widget.project}/d/${widget.doc}'),
                      mode: LaunchMode.externalApplication);
                }
              }));
    }
    if (_error != null) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(_error == 'offline' ? t.appOffline : t.appUnavailable,
                  textAlign: TextAlign.center)));
    }
    final web = _web;
    if (web == null) return const Center(child: CircularProgressIndicator());
    return Column(children: [
      if (_offline)
        MaterialBanner(
            leading: const Icon(LucideIcons.cloudOff),
            content: Text(t.appOfflineNote),
            actions: const [SizedBox.shrink()]),
      Expanded(child: WebViewWidget(controller: web)),
    ]);
  }
}
