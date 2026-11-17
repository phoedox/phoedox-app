import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../api/client.dart';
import '../../app/session.dart';
import '../../l10n/gen/app_localizations.dart';

/// The prototypes of a whiteboard (id, name), from its content.
List<(String, String)> prototypesOf(Map<String, dynamic> doc) {
  final c = doc['content'];
  final list = c is Map ? c['prototypes'] : null;
  return [
    for (final p in (list as List?) ?? const [])
      if (p is Map) ('${p['id']}', '${p['name'] ?? p['id']}')
  ];
}

/// Plays a whiteboard prototype full screen: the same player as in the
/// browser, in a WebView. The page is kept for offline use; comments land
/// on the board.
class PrototypePage extends ConsumerStatefulWidget {
  const PrototypePage(
      {super.key,
      required this.project,
      required this.doc,
      required this.proto,
      required this.name});

  final String project;
  final String doc;
  final String proto;
  final String name;

  @override
  ConsumerState<PrototypePage> createState() => _PrototypePageState();
}

class _PrototypePageState extends ConsumerState<PrototypePage> {
  WebViewController? _web;
  String? _error;
  bool _offline = false;

  static bool get supported =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  String get _base => '/projects/${widget.project}/documents/${widget.doc}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final lang = Localizations.localeOf(context).languageCode;
    final client = await ref.read(clientProvider.future);
    if (client == null) return;
    final path =
        '$_base/prototypes/${Uri.encodeComponent(widget.proto)}/export?as=json&lang=$lang';
    if (!supported) {
      if (mounted) setState(() => _error = 'browser');
      return;
    }
    final cache = await ref.read(cacheProvider.future);
    final key =
        'proto:${client.base.host}${widget.project}/${widget.doc}/${widget.proto}';
    String? page;
    try {
      final r = await client.get(path);
      if (r.offline) {
        page = await cache.get(key);
        _offline = true;
      } else {
        page = '${(r.data as Map)['html'] ?? ''}';
        await cache.put(key, page);
      }
    } on OfflineException {
      page = await cache.get(key);
      _offline = true;
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.key);
      return;
    }
    if (page == null || page.isEmpty) {
      if (mounted) setState(() => _error = 'offline');
      return;
    }
    final web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('PhoedoxBridge',
          onMessageReceived: (m) => _onMessage(client, m.message))
      ..setNavigationDelegate(NavigationDelegate(onNavigationRequest: (req) {
        final u = Uri.parse(req.url);
        if (u.scheme == 'about' ||
            u.scheme == 'data' ||
            u.toString() == client.base.toString()) {
          return NavigationDecision.navigate;
        }
        launchUrl(u, mode: LaunchMode.externalApplication);
        return NavigationDecision.prevent;
      }));
    // The page brings its images inline; it never talks to the server itself.
    await web.loadHtmlString(page, baseUrl: client.base.toString());
    if (mounted) setState(() => _web = web);
  }

  Future<void> _onMessage(PhxClient client, String raw) async {
    Map<String, dynamic> m;
    try {
      m = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return;
    }
    switch (m['op']) {
      case 'link':
        final u = Uri.tryParse('${m['url'] ?? ''}');
        if (u != null &&
            (u.scheme == 'https' ||
                u.scheme == 'http' ||
                u.scheme == 'mailto')) {
          launchUrl(u, mode: LaunchMode.externalApplication);
        }
      case 'comment':
        final id = (m['id'] as num?)?.toInt() ?? 0;
        try {
          final c = await client.send(
              'POST', '$_base/whiteboard/comments', m['comment']);
          _reply(id, true, c);
        } catch (_) {
          _reply(id, false, null);
        }
    }
  }

  void _reply(int id, bool ok, Object? data) {
    _web?.runJavaScript(
        'window.__phxReply && window.__phxReply($id, $ok, ${jsonEncode(data)});');
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final web = _web;
    Widget body;
    if (_error == 'browser') {
      body = Center(
        child: FilledButton.tonalIcon(
          icon: const Icon(LucideIcons.externalLink, size: 16),
          label: Text(t.openLink),
          onPressed: () async {
            final c = await ref.read(clientProvider.future);
            if (c != null) {
              launchUrl(
                  c.base.resolve(
                      '/p/${widget.project}/d/${widget.doc}?play=${Uri.encodeQueryComponent(widget.proto)}'),
                  mode: LaunchMode.externalApplication);
            }
          },
        ),
      );
    } else if (_error != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error == 'offline' ? t.protoOffline : t.protoUnavailable,
              textAlign: TextAlign.center),
        ),
      );
    } else if (web == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = Column(children: [
        if (_offline)
          MaterialBanner(
            leading: const Icon(LucideIcons.cloudOff),
            content: Text(t.protoOfflineNote),
            actions: const [SizedBox.shrink()],
          ),
        Expanded(child: WebViewWidget(controller: web)),
      ]);
    }
    return Scaffold(
        appBar: AppBar(title: Text(widget.name)),
        body: SafeArea(top: false, child: body));
  }
}
