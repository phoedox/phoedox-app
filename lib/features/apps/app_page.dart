import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
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
      final r = await client.get('$base/open');
      final info =
          AppFrameInfo.fromJson(Map<String, dynamic>.from(r.data as Map));
      final frame = client.base.resolve(info.url);
      _bridge = AppBridge(
          client: client,
          project: widget.project,
          doc: widget.doc,
          info: info,
          askLevel: _askLevel,
          confirm: _confirm,
          open: _open,
          outbox: outbox,
          cache: cache);
      final web = WebViewController()
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
      if (r.offline) {
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
