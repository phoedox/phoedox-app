import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import '../../api/client.dart';
import '../../app/session.dart';
import '../../l10n/gen/app_localizations.dart';
import '../blocks/blocks.dart';
import '../charts/chart.dart';
import 'board.dart';
import 'prototype_page.dart';

enum WbTool { hand, select, pen, rect, ellipse, arrow, sticky, text, eraser }

/// A whiteboard: everyone sees the same board; people who may edit draw,
/// move and delete elements. Changes are sent as element operations right
/// away (offline they wait on the device); other people's changes come in
/// every few seconds.
class WhiteboardBody extends ConsumerStatefulWidget {
  const WhiteboardBody(
      {super.key,
      required this.project,
      required this.doc,
      required this.initial,
      required this.canEdit});

  final String project;
  final String doc;
  final Map<String, dynamic> initial;
  final bool canEdit;

  @override
  ConsumerState<WhiteboardBody> createState() => _WhiteboardBodyState();
}

class _WhiteboardBodyState extends ConsumerState<WhiteboardBody> {
  List<El> _server = [];
  List<El> _els = [];
  BoardOps? _ops;
  WbTool _tool = WbTool.hand;
  String _color = 'gray';
  Offset _pan = const Offset(40, 40);
  double _zoom = 1;
  Offset? _focalStart;
  Offset? _panStart;
  double _zoomStart = 1;
  El? _drawing;
  Offset? _dragFrom;
  String? _dragId;
  Map<String, dynamic>? _dragOrig;
  Timer? _send;
  Timer? _poll;
  bool _offline = false;
  List<(String, String)> _protos = [];

  String get _docPath => '/projects/${widget.project}/documents/${widget.doc}';

  @override
  void initState() {
    super.initState();
    _server = _elementsOf(widget.initial);
    _protos = prototypesOf(widget.initial);
    _els = sorted(_server);
    _init();
  }

  Future<void> _init() async {
    final dir = await getApplicationSupportDirectory();
    final ops = BoardOps(
        File('${dir.path}/boards/${widget.project}_${widget.doc}.json'));
    await ops.load();
    if (!mounted) return;
    setState(() {
      _ops = ops;
      _els = ops.apply(_server);
    });
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _sync());
    if (ops.pending.isNotEmpty) _sync();
  }

  @override
  void dispose() {
    _send?.cancel();
    _poll?.cancel();
    _sync();
    super.dispose();
  }

  List<El> _elementsOf(Map<String, dynamic> doc) {
    final c = doc['content'];
    final list = c is Map ? c['elements'] : null;
    return [
      for (final e in (list as List?) ?? const [])
        Map<String, dynamic>.from(e as Map)
    ];
  }

  bool _syncing = false;

  /// Sends waiting operations, then loads the board as others left it.
  Future<void> _sync() async {
    final ops = _ops;
    if (ops == null || _syncing) return;
    _syncing = true;
    try {
      final client = await ref.read(clientProvider.future);
      if (client == null) return;
      await ops.flush((list) async {
        await client.send('POST', '$_docPath/whiteboard/ops', {'ops': list});
      }, {for (final e in _server) '${e['id']}'});
      final r = await client.get(_docPath);
      if (!mounted) return;
      setState(() {
        _offline = r.offline;
        if (!r.offline) {
          _server = _elementsOf(Map<String, dynamic>.from(r.data as Map));
          _protos = prototypesOf(Map<String, dynamic>.from(r.data as Map));
        }
        if (_drawing == null && _dragId == null) _els = ops.apply(_server);
      });
    } on OfflineException {
      if (mounted) setState(() => _offline = true);
    } on ApiException {
      // Refused (e.g. the board was deleted or access changed): start over
      // from the server's board.
      ops.pending = [];
    } finally {
      _syncing = false;
    }
  }

  void _changed() {
    setState(() => _els = _ops?.apply(_server) ?? _els);
    _send?.cancel();
    _send = Timer(const Duration(milliseconds: 700), _sync);
  }

  Offset _toBoard(Offset screen) => (screen - _pan) / _zoom;

  El _newEl(String type, Offset at) => {
        'id': newElementId(),
        'type': type,
        'order': '~${DateTime.now().millisecondsSinceEpoch}',
        'stroke': _color,
        'seed': Random().nextInt(1 << 30),
        if (type == 'pen' || type == 'arrow')
          'points': [
            [at.dx, at.dy],
            [at.dx, at.dy]
          ]
        else ...{'x': at.dx, 'y': at.dy, 'w': 0.0, 'h': 0.0},
        if (type == 'pen') 'width': 2,
      };

  // --- gestures -------------------------------------------------------------

  void _start(ScaleStartDetails d) {
    final p = _toBoard(d.localFocalPoint);
    if (d.pointerCount > 1 || _tool == WbTool.hand || !widget.canEdit) {
      _focalStart = d.localFocalPoint;
      _panStart = _pan;
      _zoomStart = _zoom;
      return;
    }
    switch (_tool) {
      case WbTool.pen:
      case WbTool.arrow:
        _drawing = _newEl(_tool == WbTool.pen ? 'pen' : 'arrow', p);
      case WbTool.rect:
      case WbTool.ellipse:
        _drawing = _newEl(_tool == WbTool.rect ? 'rect' : 'ellipse', p);
        _dragFrom = p;
      case WbTool.select:
        final e = elementAt(_els, p, 8 / _zoom);
        if (e != null && e['locked'] != true) {
          _dragId = '${e['id']}';
          _dragFrom = p;
          _dragOrig = Map<String, dynamic>.from(e);
        }
      case WbTool.eraser:
        _erase(p);
      default:
        break;
    }
    setState(() {});
  }

  void _update(ScaleUpdateDetails d) {
    if (_focalStart != null) {
      setState(() {
        _zoom = (_zoomStart * d.scale).clamp(0.2, 4.0);
        // Keep the point under the fingers where it was.
        final boardAtStart = (_focalStart! - _panStart!) / _zoomStart;
        _pan = d.localFocalPoint - boardAtStart * _zoom;
      });
      return;
    }
    final p = _toBoard(d.localFocalPoint);
    final dr = _drawing;
    if (dr != null) {
      setState(() {
        if (dr['type'] == 'pen') {
          (dr['points'] as List).add([p.dx, p.dy]);
        } else if (dr['type'] == 'arrow') {
          (dr['points'] as List)[1] = [p.dx, p.dy];
        } else {
          final r = Rect.fromPoints(_dragFrom!, p);
          dr
            ..['x'] = r.left
            ..['y'] = r.top
            ..['w'] = r.width
            ..['h'] = r.height;
        }
      });
      return;
    }
    if (_dragId != null) {
      final delta = p - _dragFrom!;
      setState(() {
        final i = _els.indexWhere((e) => e['id'] == _dragId);
        if (i >= 0) _els[i] = _moved(_dragOrig!, delta);
      });
      return;
    }
    if (_tool == WbTool.eraser) _erase(p);
  }

  void _end(ScaleEndDetails d) {
    _focalStart = null;
    final dr = _drawing;
    _drawing = null;
    if (dr != null) {
      final b = boundsOf(dr);
      if (b.width + b.height > 6) {
        if (dr['type'] == 'pen') dr['points'] = _thin(dr['points'] as List);
        _ops?.add(dr);
        _changed();
      } else {
        setState(() {});
      }
    }
    if (_dragId != null) {
      final i = _els.indexWhere((e) => e['id'] == _dragId);
      if (i >= 0) {
        final e = _els[i];
        _ops?.update(_dragId!, {
          if (e.containsKey('points')) 'points': e['points'],
          if (!isLinear(e)) ...{'x': e['x'], 'y': e['y']},
        });
        _changed();
      }
      _dragId = null;
      _dragOrig = null;
    }
  }

  El _moved(El e, Offset delta) {
    final out = Map<String, dynamic>.from(e);
    if (isLinear(e)) {
      out['points'] = [
        for (final p in pointsOf(e)) [p.dx + delta.dx, p.dy + delta.dy]
      ];
    } else {
      out['x'] = ((e['x'] as num?) ?? 0) + delta.dx;
      out['y'] = ((e['y'] as num?) ?? 0) + delta.dy;
    }
    return out;
  }

  /// Fewer points for strokes (every 2 board units at least).
  List _thin(List pts) {
    final out = <List>[];
    Offset? last;
    for (final p in pts) {
      final o = Offset((p[0] as num).toDouble(), (p[1] as num).toDouble());
      if (last == null || (o - last).distance >= 2) {
        out.add([
          double.parse(o.dx.toStringAsFixed(1)),
          double.parse(o.dy.toStringAsFixed(1))
        ]);
        last = o;
      }
    }
    return out;
  }

  void _erase(Offset p) {
    final e = elementAt(_els, p, 8 / _zoom);
    if (e == null || e['locked'] == true) return;
    _ops?.delete('${e['id']}');
    _changed();
  }

  Future<void> _tap(TapUpDetails d) async {
    if (!widget.canEdit) return;
    final p = _toBoard(d.localPosition);
    if (_tool == WbTool.sticky || _tool == WbTool.text) {
      final sticky = _tool == WbTool.sticky;
      final text = await _askText('');
      if (text == null || text.trim().isEmpty) return;
      final e = _newEl(sticky ? 'sticky' : 'text', p)
        ..['w'] = sticky ? 180.0 : 240.0
        ..['h'] = sticky ? 120.0 : 40.0
        ..['text'] = text.trim();
      if (sticky) e['fill'] = _color == 'gray' ? 'yellow' : _color;
      await _ops?.add(e);
      _changed();
    }
  }

  Future<void> _longPress(LongPressStartDetails d) async {
    if (!widget.canEdit) return;
    final e = elementAt(_els, _toBoard(d.localPosition), 8 / _zoom);
    if (e == null || e['locked'] == true || e['type'] == 'pen') return;
    final text = await _askText('${e['text'] ?? ''}');
    if (text == null) return;
    await _ops?.update(
        '${e['id']}', {'text': text.trim().isEmpty ? null : text.trim()});
    _changed();
  }

  Future<String?> _askText(String start) {
    final t = AppLocalizations.of(context);
    final c = TextEditingController(text: start);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.wbText),
        content:
            TextField(controller: c, autofocus: true, maxLines: 5, minLines: 1),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(t.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text), child: Text(t.save)),
        ],
      ),
    );
  }

  // --- view -----------------------------------------------------------------------

  Widget _toolButton(WbTool tool, IconData icon, String label) => IconButton(
        tooltip: label,
        isSelected: _tool == tool,
        icon: Icon(icon, size: 20),
        onPressed: () => setState(() => _tool = tool),
      );

  /// Plays a prototype of the board (asks which one if there are several).
  Future<void> _play() async {
    var pick = _protos.length == 1 ? _protos.first : null;
    pick ??= await showModalBottomSheet<(String, String)>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          for (final p in _protos)
            ListTile(
              leading: const Icon(LucideIcons.play),
              title: Text(p.$2),
              onTap: () => Navigator.pop(ctx, p),
            ),
        ]),
      ),
    );
    if (pick == null || !mounted) return;
    final chosen = pick;
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PrototypePage(
            project: widget.project,
            doc: widget.doc,
            proto: chosen.$1,
            name: chosen.$2)));
    _sync();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final shown = [..._els, if (_drawing != null) _drawing!];
    return Column(children: [
      if (_offline || (_ops?.pending.isNotEmpty ?? false))
        Material(
          color: cs.secondaryContainer,
          child: ListTile(
            dense: true,
            leading: Icon(
                _offline ? LucideIcons.cloudOff : LucideIcons.cloudUpload,
                size: 18),
            title: Text(_offline ? t.wbOffline : t.wbSending),
          ),
        ),
      Expanded(
        child: Stack(children: [
          Positioned.fill(
              child: ClipRect(
            child: GestureDetector(
              onScaleStart: _start,
              onScaleUpdate: _update,
              onScaleEnd: _end,
              onTapUp: _tap,
              onLongPressStart: _longPress,
              child: CustomPaint(
                painter: BoardPainter(shown, _pan, _zoom,
                    dark: Theme.of(context).brightness == Brightness.dark,
                    line: cs.outlineVariant,
                    muted: cs.onSurfaceVariant,
                    surface: cs.surface,
                    accent: cs.primary),
                size: Size.infinite,
              ),
            ),
          )),
          if (_protos.isNotEmpty)
            Positioned(
              right: 12,
              top: 12,
              child: FilledButton.tonalIcon(
                icon: const Icon(LucideIcons.play, size: 18),
                label: Text(t.protoPlay),
                onPressed: _play,
              ),
            ),
        ]),
      ),
      if (widget.canEdit)
        Material(
          elevation: 2,
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _toolButton(WbTool.hand, LucideIcons.hand, t.wbHand),
                _toolButton(
                    WbTool.select, LucideIcons.mousePointer2, t.wbSelect),
                _toolButton(WbTool.pen, LucideIcons.pencil, t.wbPen),
                _toolButton(WbTool.rect, LucideIcons.square, t.wbRect),
                _toolButton(WbTool.ellipse, LucideIcons.circle, t.wbEllipse),
                _toolButton(WbTool.arrow, LucideIcons.moveUpRight, t.wbArrow),
                _toolButton(WbTool.sticky, LucideIcons.stickyNote, t.wbSticky),
                _toolButton(WbTool.text, LucideIcons.type, t.wbTextTool),
                _toolButton(WbTool.eraser, LucideIcons.eraser, t.wbEraser),
                const SizedBox(width: 8),
                for (final c in palette)
                  GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: Container(
                      width: 26,
                      height: 26,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: strokeColors[c],
                        shape: BoxShape.circle,
                        border: Border.all(
                            color:
                                _color == c ? cs.primary : Colors.transparent,
                            width: 3),
                      ),
                      child: Semantics(label: c, selected: _color == c),
                    ),
                  ),
              ]),
            ),
          ),
        ),
    ]);
  }
}

/// Paints the elements like the web editor (without the hand-drawn look).
class BoardPainter extends CustomPainter {
  BoardPainter(this.els, this.pan, this.zoom,
      {required this.dark,
      required this.line,
      required this.muted,
      this.surface = Colors.white,
      this.accent = const Color(0xFFC2410C)});

  final List<El> els;
  final Offset pan;
  final double zoom;
  final bool dark;
  final Color line;
  final Color muted;
  final Color surface;
  final Color accent;

  Color _stroke(El e) {
    final c = strokeColors['${e['stroke'] ?? 'gray'}'] ?? strokeColors['gray']!;
    return dark && e['stroke'] == null || dark && e['stroke'] == 'gray'
        ? const Color(0xFFE9ECEF)
        : c;
  }

  void _text(Canvas c, String text, Rect box,
      {double size = 20,
      Color? color,
      TextAlign align = TextAlign.center,
      bool top = false}) {
    if (text.isEmpty) return;
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              fontSize: size,
              color: color ?? (dark ? Colors.white : Colors.black87))),
      textAlign: align,
      textDirection: TextDirection.ltr,
      maxLines: 20,
      ellipsis: '…',
    )..layout(maxWidth: max(20, box.width));
    final dy = top ? box.top : box.center.dy - tp.height / 2;
    final dx =
        align == TextAlign.center ? box.center.dx - tp.width / 2 : box.left;
    tp.paint(c, Offset(dx, dy));
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(pan.dx, pan.dy);
    canvas.scale(zoom);
    // Screens are opaque: always behind what is on them.
    final order = [
      ...els.where((e) => e['screen'] != null),
      ...els.where((e) => e['screen'] == null)
    ];
    for (final e in order) {
      final b = boundsOf(e);
      final stroke = Paint()
        ..color = _stroke(e)
        ..style = PaintingStyle.stroke
        ..strokeWidth = ((e['width'] as num?)?.toDouble() ?? 2) +
            (e['type'] == 'pen' ? 1.5 : 0)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final fillName = e['fill'] as String?;
      final fill = fillName == null
          ? null
          : (Paint()..color = fillColors[fillName] ?? fillColors['yellow']!);
      switch (e['type']) {
        case 'frame' when e['screen'] is Map:
          final dev = '${(e['screen'] as Map)['device'] ?? 'phone'}';
          final rad = dev == 'phone'
              ? 40.0
              : dev == 'tablet'
                  ? 26.0
                  : dev == 'desktop'
                      ? 10.0
                      : 14.0;
          final r = RRect.fromRectAndRadius(b, Radius.circular(rad));
          canvas.drawRRect(
              r,
              Paint()
                ..color = fillName == null
                    ? surface
                    : fillColors[fillName] ?? surface);
          canvas.drawRRect(
              r,
              Paint()
                ..color = line
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5);
          _text(canvas, '${e['text'] ?? ''}',
              Rect.fromLTWH(b.left + 4, b.top - 26, b.width, 20),
              size: 14, color: muted, align: TextAlign.left, top: true);
        case 'ui':
          final ui = e['ui'] is Map ? e['ui'] as Map : const {};
          final comp = '${ui['comp'] ?? ''}';
          final primary = comp == 'button' &&
              (ui['variant'] == null || ui['variant'] == 'primary');
          final rr = RRect.fromRectAndRadius(
              b, Radius.circular(comp == 'avatar' ? b.shortestSide / 2 : 10));
          canvas.drawRRect(rr,
              Paint()..color = primary ? accent : line.withValues(alpha: 0.25));
          final opts =
              ui['options'] is List ? (ui['options'] as List).join(' · ') : '';
          _text(
              canvas,
              '${e['text'] ?? (opts.isNotEmpty ? opts : ui['placeholder'] ?? comp)}',
              b.deflate(6),
              size: 14,
              color: primary ? Colors.white : muted);
        case 'frame':
          final r = RRect.fromRectAndRadius(b, const Radius.circular(14));
          canvas.drawRRect(
              r,
              Paint()
                ..color = line
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5);
          _text(canvas, '${e['text'] ?? ''}',
              Rect.fromLTWH(b.left + 12, b.top + 6, b.width - 24, 20),
              size: 13, color: muted, align: TextAlign.left, top: true);
        case 'rect':
          if (fill != null) canvas.drawRect(b, fill);
          canvas.drawRect(b, stroke);
          _text(canvas, '${e['text'] ?? ''}', b.deflate(8),
              size: (e['fontSize'] as num?)?.toDouble() ?? 20);
        case 'ellipse':
          if (fill != null) canvas.drawOval(b, fill);
          canvas.drawOval(b, stroke);
          _text(canvas, '${e['text'] ?? ''}', b.deflate(b.width * 0.15),
              size: (e['fontSize'] as num?)?.toDouble() ?? 20);
        case 'diamond':
          final path = Path()
            ..moveTo(b.center.dx, b.top)
            ..lineTo(b.right, b.center.dy)
            ..lineTo(b.center.dx, b.bottom)
            ..lineTo(b.left, b.center.dy)
            ..close();
          if (fill != null) canvas.drawPath(path, fill);
          canvas.drawPath(path, stroke);
          _text(canvas, '${e['text'] ?? ''}', b.deflate(b.width * 0.22),
              size: (e['fontSize'] as num?)?.toDouble() ?? 20);
        case 'sticky':
          canvas.drawRRect(
              RRect.fromRectAndRadius(b, const Radius.circular(4)),
              Paint()
                ..color =
                    fillColors[fillName ?? 'yellow'] ?? fillColors['yellow']!);
          _text(canvas, '${e['text'] ?? ''}', b.deflate(12),
              size: (e['fontSize'] as num?)?.toDouble() ?? 18,
              color: Colors.black87,
              align: TextAlign.left,
              top: true);
        case 'text':
          _text(canvas, '${e['text'] ?? ''}',
              Rect.fromLTWH(b.left, b.top, max(b.width, 60), max(b.height, 30)),
              size: (e['fontSize'] as num?)?.toDouble() ?? 24,
              color: _stroke(e),
              align: TextAlign.left,
              top: true);
        case 'pen':
          final pts = pointsOf(e);
          if (pts.isEmpty) break;
          final path = Path()..moveTo(pts.first.dx, pts.first.dy);
          for (var i = 1; i < pts.length - 1; i++) {
            final m = (pts[i] + pts[i + 1]) / 2;
            path.quadraticBezierTo(pts[i].dx, pts[i].dy, m.dx, m.dy);
          }
          if (pts.length > 1) path.lineTo(pts.last.dx, pts.last.dy);
          canvas.drawPath(path, stroke);
        case 'line':
        case 'arrow':
          final pts = pointsOf(e);
          if (pts.length < 2) break;
          final path = Path()..moveTo(pts.first.dx, pts.first.dy);
          for (final p in pts.skip(1)) {
            path.lineTo(p.dx, p.dy);
          }
          canvas.drawPath(path, stroke);
          if (e['type'] == 'arrow') {
            final a = pts[pts.length - 2], z = pts.last;
            final ang = atan2(z.dy - a.dy, z.dx - a.dx);
            const l = 14.0;
            canvas.drawPath(
                Path()
                  ..moveTo(
                      z.dx - l * cos(ang - 0.45), z.dy - l * sin(ang - 0.45))
                  ..lineTo(z.dx, z.dy)
                  ..lineTo(
                      z.dx - l * cos(ang + 0.45), z.dy - l * sin(ang + 0.45)),
                stroke);
          }
        case 'chart':
        case 'block':
          // Blocks (ADR-0085): the same drawing as in pages.
          canvas.drawRRect(
              RRect.fromRectAndRadius(b, const Radius.circular(10)),
              Paint()..color = surface);
          canvas.drawRRect(
              RRect.fromRectAndRadius(b, const Radius.circular(10)),
              Paint()
                ..color = line
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5);
          final kind = e['type'] == 'chart' ? 'chart' : '${e['kind'] ?? ''}';
          final src = e['type'] == 'chart'
              ? jsonEncode(e['chart'])
              : '${e['source'] ?? ''}';
          try {
            final def = blockKinds[kind];
            if (def == null) throw const FormatException('unknown kind');
            def.paint(
                canvas,
                b.deflate(8),
                src,
                ChartStyle(
                    dark: dark,
                    fg: dark ? Colors.white : Colors.black87,
                    muted: muted,
                    line: line,
                    surface: surface));
          } on FormatException {
            _text(canvas, kind, b.deflate(10), size: 14, color: muted);
          }
        default:
          // Images, embeds and entries: a card with their name.
          canvas.drawRRect(RRect.fromRectAndRadius(b, const Radius.circular(8)),
              Paint()..color = line.withValues(alpha: 0.35));
          final preview =
              e['preview'] is Map ? (e['preview'] as Map)['title'] : null;
          _text(
              canvas,
              '${e['text'] ?? preview ?? e['entity'] ?? e['url'] ?? e['type']}',
              b.deflate(10),
              size: 14,
              color: muted);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(BoardPainter old) => true;
}
