import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../api/client.dart';
import '../../app/session.dart';
import '../../l10n/gen/app_localizations.dart';
import '../charts/chart.dart';
import 'interactive.dart' show blockKey;

// Plugin blocks (ADR-0086): block kinds a project's plugins add. The server
// draws them (the plugin's block_render, cleaned SVG); the app shows that
// picture natively and, when the plugin has an element, opens the block
// interactively in a WebView whose calls go through the app's client.

class PluginBlockInfo {
  PluginBlockInfo(this.kind, this.label, this.plugin, this.element,
      this.frontend, this.board,
      [this.missing]);
  final String kind, label, plugin;
  final String? element, frontend;
  final bool board;

  /// Set for a kind that moved into a plugin which is not active in the
  /// project (ADR-0088): the plugin it needs.
  final String? missing;

  factory PluginBlockInfo.fromJson(Map m) => PluginBlockInfo(
      '${m['kind']}',
      '${m['label'] ?? m['kind']}',
      '${m['plugin'] ?? ''}',
      m['element'] as String?,
      m['frontend'] as String?,
      m['board'] == true,
      (m['missing'] as Map?)?['plugin'] as String?);
}

/// The plugin blocks of a project (kind -> info), cached offline by the client.
final pluginBlocksProvider =
    FutureProvider.family<Map<String, PluginBlockInfo>, String>(
        (ref, project) async {
  final c = await ref.watch(clientProvider.future);
  if (c == null || project.isEmpty) return const {};
  try {
    final r = (await c.get('/projects/$project/plugin-blocks')).data;
    return {
      for (final b in (r as List? ?? const []))
        '${(b as Map)['kind']}': PluginBlockInfo.fromJson(b)
    };
  } catch (_) {
    return const {};
  }
});

/// The theme's colours under the names of the web app's CSS variables.
Map<String, String> themeVars(ChartStyle s, ColorScheme cs) {
  String hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  return {
    'fg': hex(s.fg),
    'muted': hex(s.muted),
    'line': hex(s.line),
    'surface': hex(s.surface),
    'surface2': hex(cs.surfaceContainerHighest),
    'bg': hex(cs.surface),
    'accent': hex(cs.primary),
    'good': hex(Colors.green.shade600),
    'bad': hex(cs.error),
    'signal': hex(Colors.amber.shade700),
    for (final c in [
      'gray',
      'red',
      'orange',
      'yellow',
      'green',
      'blue',
      'purple',
      'pink'
    ]) ...{
      'tc-$c': hex(s.tc(c)),
      'tb-$c': hex(s.tb(c)),
    },
  };
}

/// Replaces the CSS variables a plugin's SVG uses with the theme's colours
/// (flutter_svg does not resolve var()).
String resolveSvgVars(String svg, Map<String, String> vars) => svg
    .replaceAllMapped(
        RegExp(r'var\(--([a-z0-9-]+)(?:\s*,\s*([^()]*))?\)'),
        (m) =>
            vars[m[1]] ??
            (m[2]?.trim().isNotEmpty == true ? m[2]!.trim() : '#888888'))
    .replaceAll(RegExp(r'font-family:[^;"]*;?'), '');

class PluginBlockView extends ConsumerStatefulWidget {
  const PluginBlockView(
      {super.key,
      required this.kind,
      required this.source,
      required this.project});
  final String kind, source, project;

  @override
  ConsumerState<PluginBlockView> createState() => _PluginBlockViewState();
}

class _PluginBlockViewState extends ConsumerState<PluginBlockView> {
  String? _svg;
  List<String> _problems = const [];
  bool _failed = false;
  String? _missing;

  String get _cacheKey =>
      'pblock:${widget.project}:${widget.kind}:${blockKey(widget.source)}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await ref.read(clientProvider.future);
    final cache = await ref.read(cacheProvider.future);
    if (c == null) return;
    try {
      final lang =
          mounted ? Localizations.localeOf(context).languageCode : 'en';
      final r = await c.send(
          'POST',
          '/projects/${widget.project}/plugin-blocks/${Uri.encodeComponent(widget.kind)}/render',
          {'source': widget.source, 'width': 720, 'locale': lang});
      if (r is Map) {
        await cache.put(_cacheKey, jsonEncode(r));
        _apply(r);
      }
    } on OfflineException {
      final hit = await cache.get(_cacheKey);
      if (hit != null) {
        _apply(jsonDecode(hit) as Map);
      } else if (mounted) {
        setState(() => _failed = true);
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _apply(Map r) {
    if (!mounted) return;
    setState(() {
      _svg = '${r['svg'] ?? ''}';
      _missing = (r['missing'] as Map?)?['plugin'] as String?;
      final t = AppLocalizations.of(context);
      _problems = [
        for (final p in (r['problems'] as List? ?? const []))
          if ((p as Map)['severity'] != 'warning')
            '${t.pluginBlockLine((p['line'] as num?)?.toInt() ?? 1)} ${p['message']}'
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final info =
        ref.watch(pluginBlocksProvider(widget.project)).value?[widget.kind];
    Widget body;
    final missing = info?.missing ?? _missing;
    if (missing != null) {
      body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${info?.label ?? widget.kind}: ${t.pluginBlockNeeds(missing)}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(t.pluginBlockNeedsHint,
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        const SizedBox(height: 6),
        Text(widget.source,
            style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: cs.onSurfaceVariant)),
      ]);
    } else if (_failed || (_svg != null && _svg!.isEmpty)) {
      body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${info?.label ?? widget.kind}: ${t.pluginBlockFailed}',
            style: TextStyle(color: cs.error, fontWeight: FontWeight.w600)),
        for (final p in _problems)
          Text(p, style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 6),
        Text(widget.source,
            style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: cs.onSurfaceVariant)),
      ]);
    } else if (_svg == null) {
      body = const LinearProgressIndicator();
    } else {
      final pic = SvgPicture.string(
          resolveSvgVars(_svg!, themeVars(ChartStyle.of(context), cs)),
          fit: BoxFit.contain,
          alignment: Alignment.topLeft);
      body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Semantics(label: info?.label ?? widget.kind, image: true, child: pic),
        if (info?.element != null && info?.frontend != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(LucideIcons.maximize2, size: 16),
              label: Text(t.pluginBlockOpen),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => PluginBlockPage(
                      info: info!,
                      source: widget.source,
                      project: widget.project,
                      svg: _svg!))),
            ),
          ),
      ]);
    }
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: body,
    );
  }
}

/// The plugin's element in a WebView. The page is built here: the plugin's
/// frontend module (loaded with the app's sign-in) is imported from a blob,
/// its element gets source, svg and project, and the SDK calls it makes
/// (tasks.list, blocks.render, ui.toast) come to the app over a channel.
class PluginBlockPage extends ConsumerStatefulWidget {
  const PluginBlockPage(
      {super.key,
      required this.info,
      required this.source,
      required this.project,
      required this.svg});
  final PluginBlockInfo info;
  final String source, project, svg;

  @override
  ConsumerState<PluginBlockPage> createState() => _PluginBlockPageState();
}

class _PluginBlockPageState extends ConsumerState<PluginBlockPage> {
  WebViewController? _web;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    final t = AppLocalizations.of(context);
    final c = await ref.read(clientProvider.future);
    if (c == null) return;
    try {
      final path = widget.info.frontend!.replaceFirst(RegExp(r'^/api/v1'), '');
      final (bytes, _) = await c.getBytes(path);
      final html = blockFrameHtml(
          module: utf8.decode(bytes),
          element: widget.info.element!,
          source: widget.source,
          svg: widget.svg,
          project: widget.project,
          css: _cssVars());
      final web = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..addJavaScriptChannel('PhoedoxBridge',
            onMessageReceived: (m) => _onCall(c, m.message))
        ..setNavigationDelegate(NavigationDelegate(onNavigationRequest: (req) {
          final u = Uri.parse(req.url);
          if (u.scheme == 'about' || u.scheme == 'data' || u.scheme == 'blob') {
            return NavigationDecision.navigate;
          }
          launchUrl(u, mode: LaunchMode.externalApplication);
          return NavigationDecision.prevent;
        }));
      await web.loadHtmlString(html);
      if (mounted) setState(() => _web = web);
    } on OfflineException {
      if (mounted) setState(() => _error = t.blockOffline);
    } catch (_) {
      if (mounted) setState(() => _error = t.pluginBlockFailed);
    }
  }

  String _cssVars() =>
      themeVars(ChartStyle.of(context), Theme.of(context).colorScheme)
          .entries
          .map((e) => '--${e.key}: ${e.value};')
          .join(' ');

  Future<void> _onCall(PhxClient c, String raw) async {
    Map m;
    try {
      m = jsonDecode(raw) as Map;
    } catch (_) {
      return;
    }
    final id = m['id'];
    final args = (m['args'] as Map?) ?? const {};
    Object? result;
    String? error;
    try {
      switch (m['op']) {
        case 'tasks.list':
          result = (await c.get(
                  '/projects/${widget.project}/tasks?board=${Uri.encodeQueryComponent('${args['board']}')}'))
              .data;
        case 'blocks.render':
          result = await c.send(
              'POST',
              '/projects/${widget.project}/plugin-blocks/${Uri.encodeComponent('${args['kind']}')}/render',
              {
                'source': '${args['source'] ?? ''}',
                'width': args['width'] ?? 720,
                'locale': Localizations.localeOf(context).languageCode
              });
        case 'ui.toast':
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('${args['message']}')));
          }
        default:
          error = 'not available in the app';
      }
    } catch (e) {
      error = '$e';
    }
    final msg = jsonEncode({'id': id, 'result': result, 'error': error});
    await _web?.runJavaScript('window.__phxReply(${jsonEncode(msg)})');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.info.label)),
      body: _error != null
          ? Center(child: Text(_error!))
          : _web == null
              ? const Center(child: CircularProgressIndicator())
              : WebViewWidget(controller: _web!),
    );
  }
}

/// The page for a plugin block's element (pure, tested).
String blockFrameHtml(
    {required String module,
    required String element,
    required String source,
    required String svg,
    required String project,
    required String css}) {
  // As JS string literals; "<" is escaped so no value can close the script.
  String js(Object? v) => jsonEncode(v).replaceAll('<', r'\u003c');
  return '''<!doctype html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-inline' blob:; style-src 'unsafe-inline'; img-src data: blob:">
<style>:root { $css } body { margin: 12px; background: var(--bg); color: var(--fg); font-family: system-ui, sans-serif; }</style>
</head><body><div id="root"></div><script type="module">
const pending = new Map(); let seq = 0;
window.__phxReply = (raw) => { const m = JSON.parse(raw); const p = pending.get(m.id); if (!p) return; pending.delete(m.id); m.error ? p.reject(new Error(m.error)) : p.resolve(m.result); };
const call = (op, args) => new Promise((resolve, reject) => { const id = ++seq; pending.set(id, { resolve, reject }); PhoedoxBridge.postMessage(JSON.stringify({ id, op, args })); });
const sdk = {
  tasks: { list: (board) => call("tasks.list", { board }) },
  blocks: { render: (kind, source, width) => call("blocks.render", { kind, source, width }) },
  ui: { toast: (message) => call("ui.toast", { message }) },
  graph: { get: () => Promise.reject(new Error("not available in the app")), watch: () => () => {} },
  docs: { create: () => Promise.reject(new Error("not available in the app")) },
  tool: () => Promise.reject(new Error("not available in the app")),
  commands: { add() {} }, icons: { render: () => document.createElement("span") },
};
const url = URL.createObjectURL(new Blob([${js(module)}], { type: "text/javascript" }));
const def = (await import(url)).default ?? {};
for (const [tag, Base] of Object.entries(def.elements ?? {})) {
  if (!/^phx-[a-z0-9]+(-[a-z0-9]+)*\$/.test(tag) || customElements.get(tag)) continue;
  customElements.define(tag, class extends Base { constructor() { super(); this.sdk = sdk; } });
}
const el = document.createElement(${js(element)});
el.source = ${js(source)}; el.svg = ${js(svg)}; el.project = ${js(project)};
document.getElementById("root").append(el);
</script></body></html>''';
}
