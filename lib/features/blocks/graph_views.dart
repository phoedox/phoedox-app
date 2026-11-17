import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../api/client.dart';
import '../../app/session.dart';
import '../../l10n/gen/app_localizations.dart';
import '../charts/chart.dart';
import '../entity/entity_page.dart';
import '../floorplan/floorplan_view.dart' show roomColor;
import '../floorplan/plan.dart';
import 'blocks.dart';
import 'graph.dart';

/// Name, kind and live status of entries (the status API of ```status).
typedef Live = Map<String, ({String name, String kind, String status})>;

Future<Live> loadLive(
    PhxClient? c, String project, Iterable<String> slugs) async {
  final out = <String, ({String name, String kind, String status})>{};
  final all = slugs.toSet().toList();
  for (var i = 0; i < all.length; i += 100) {
    final q = all
        .skip(i)
        .take(100)
        .map((s) => 'e=${Uri.encodeQueryComponent(s)}')
        .join('&');
    try {
      final r = (await c?.get('/projects/$project/status?$q'))?.data;
      if (r is Map && r['entries'] is List) {
        for (final e in r['entries'] as List) {
          out['${e['slug']}'] = (
            name: '${e['name'] ?? e['slug']}',
            kind: '${e['kind'] ?? ''}',
            status: '${e['status'] ?? 'unknown'}'
          );
        }
      }
    } catch (_) {
      // no status: names come from the graph
    }
  }
  return out;
}

Color statusColor(String? s, ColorScheme cs) => switch (s) {
      'ok' => Colors.green.shade600,
      'warn' => Colors.amber.shade700,
      'down' || 'fail' => cs.error,
      _ => cs.outlineVariant,
    };

String statusText(AppLocalizations t, String? s) => switch (s) {
      'ok' => t.statusOk,
      'warn' => t.statusWarn,
      'down' || 'fail' => t.statusDown,
      _ => '',
    };

void _openEntry(BuildContext context, String project, String slug) =>
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => EntityPage(project: project, entity: slug)));

/// Loads data for a block, refreshes it every minute and shows a short
/// message instead of failing.
abstract class _LiveState<W extends ConsumerStatefulWidget, D>
    extends ConsumerState<W> {
  D? data;
  String? problem;
  Timer? _timer;

  Future<D> fetch(PhxClient c);
  String notFound(AppLocalizations t);
  String failed(AppLocalizations t);

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final c = await ref.read(clientProvider.future);
    if (c == null || !mounted) return;
    try {
      final d = await fetch(c);
      if (mounted) {
        setState(() {
          data = d;
          problem = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted && data == null) {
        final t = AppLocalizations.of(context);
        setState(() => problem = e.status == 404 ? notFound(t) : failed(t));
      }
    } catch (_) {
      if (mounted && data == null) {
        setState(() => problem = failed(AppLocalizations.of(context)));
      }
    }
  }

  Widget frame(BuildContext context, String title, Widget child) => Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child:
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
            ),
          if (problem != null)
            Text(problem!,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant))
          else if (data == null)
            const LinearProgressIndicator()
          else
            child,
        ]),
      );
}

// --- tree ----------------------------------------------------------------------------

class TreeView extends ConsumerStatefulWidget {
  const TreeView({super.key, required this.spec, required this.ctx});
  final TreeSpec spec;
  final BlockCtx ctx;

  @override
  ConsumerState<TreeView> createState() => _TreeViewState();
}

class _TreeViewState extends _LiveState<TreeView, (TreeNode, Live)> {
  ScrollController? _scroll;

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  @override
  Future<(TreeNode, Live)> fetch(PhxClient c) async {
    final p = widget.ctx.project, s = widget.spec;
    final root =
        (await c.get('/projects/$p/entities/${Uri.encodeComponent(s.root)}'))
            .data;
    final q =
        'dir=${s.direction}&depth=${s.depth}${s.relation.isEmpty ? '' : '&rel=${Uri.encodeQueryComponent(s.relation)}'}';
    final hops = (await c.get(
            '/projects/$p/entities/${Uri.encodeComponent(s.root)}/traverse?$q'))
        .data;
    final tree = buildTree(
        Map<String, dynamic>.from((root as Map)['entity'] as Map), [
      for (final h in (hops as List? ?? const []))
        Map<String, dynamic>.from(h as Map)
    ]);
    final slugs = <String>[];
    void walk(TreeNode n) {
      slugs.add(n.slug);
      n.children.forEach(walk);
    }

    walk(tree);
    return (tree, await loadLive(c, p, slugs));
  }

  @override
  String notFound(AppLocalizations t) => t.treeMissing(widget.spec.root);
  @override
  String failed(AppLocalizations t) => t.blockLoadFailed;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final d = data;
    Widget body = const SizedBox();
    if (d != null) {
      final (tree, live) = d;
      final l = layoutTree(tree);
      final map = SizedBox(
        width: l.width + 16,
        height: l.height + 16,
        child: Stack(children: [
          Positioned.fill(
              child: CustomPaint(painter: _TreeLinks(l.boxes, cs.outline))),
          for (final b in l.boxes)
            Positioned(
              left: b.x + 8,
              top: b.y + 8,
              width: TreeBox.w,
              height: TreeBox.h,
              child: _EntryBox(
                name: b.node.name,
                sub: [b.node.kind, statusText(t, live[b.node.slug]?.status)]
                    .where((s) => s.isNotEmpty)
                    .join(' · '),
                color: statusColor(live[b.node.slug]?.status, cs),
                onTap: () =>
                    _openEntry(context, widget.ctx.project, b.node.slug),
              ),
            ),
        ]),
      );
      body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LayoutBuilder(
            builder: (context, c) => l.width + 16 <= c.maxWidth
                ? Center(child: map)
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    controller: _scroll ??= ScrollController(
                        initialScrollOffset: (l.width + 16 - c.maxWidth) / 2),
                    child: map)),
        if (tree.children.isEmpty)
          Text(
              t.treeEmpty(
                  widget.spec.relation.isEmpty ? '*' : widget.spec.relation),
              style: TextStyle(color: cs.onSurfaceVariant)),
      ]);
    }
    return frame(context, widget.spec.title, body);
  }
}

class _EntryBox extends StatelessWidget {
  const _EntryBox(
      {required this.name, required this.sub, required this.color, this.onTap});
  final String name, sub;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: cs.outlineVariant)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(children: [
          Container(
              width: 4,
              margin: const EdgeInsets.symmetric(vertical: 6),
              color: color),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    if (sub.isNotEmpty)
                      Text(sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11, color: cs.onSurfaceVariant)),
                  ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _TreeLinks extends CustomPainter {
  _TreeLinks(this.boxes, this.color);
  final List<TreeBox> boxes;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    for (final b in boxes) {
      final a = b.parent;
      if (a == null) continue;
      final x1 = a.x + 8 + TreeBox.w / 2, y1 = a.y + 8 + TreeBox.h;
      final x2 = b.x + 8 + TreeBox.w / 2, y2 = b.y + 8, my = (y1 + y2) / 2;
      canvas.drawPath(
          Path()
            ..moveTo(x1, y1)
            ..lineTo(x1, my)
            ..lineTo(x2, my)
            ..lineTo(x2, y2),
          p);
    }
  }

  @override
  bool shouldRepaint(_TreeLinks old) => old.boxes != boxes;
}

// --- rack --------------------------------------------------------------------------------

class RackView extends ConsumerStatefulWidget {
  const RackView({super.key, required this.spec, required this.ctx});
  final RackSpec spec;
  final BlockCtx ctx;

  @override
  ConsumerState<RackView> createState() => _RackViewState();
}

class _RackViewState
    extends _LiveState<RackView, (String, int, List<Mounted>, Live)> {
  @override
  Future<(String, int, List<Mounted>, Live)> fetch(PhxClient c) async {
    final p = widget.ctx.project;
    final d = (await c.get(
            '/projects/$p/entities/${Uri.encodeComponent(widget.spec.rack)}'))
        .data as Map;
    final e = d['entity'] as Map;
    final attrs = e['attrs'] is Map ? e['attrs'] as Map : const {};
    final units =
        (int.tryParse('${attrs['height_units'] ?? ''}') ?? 42).clamp(1, 60);
    final devices = [
      for (final x in (d['edges'] as List? ?? const []))
        if (x is Map && x['rel'] == 'mounted_in' && x['to'] == e['id'])
          Mounted(
            '${x['fromSlug'] ?? ''}',
            '${x['fromName'] ?? x['fromSlug'] ?? ''}',
            int.tryParse('${(x['attrs'] as Map?)?['u'] ?? ''}'),
            max(1,
                int.tryParse('${(x['attrs'] as Map?)?['height'] ?? ''}') ?? 1),
          )
    ];
    return (
      '${e['name'] ?? widget.spec.rack}',
      units,
      devices,
      await loadLive(c, p, devices.map((d) => d.slug))
    );
  }

  @override
  String notFound(AppLocalizations t) => t.rackMissing(widget.spec.rack);
  @override
  String failed(AppLocalizations t) => t.blockLoadFailed;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final d = data;
    if (d == null) return frame(context, widget.spec.title, const SizedBox());
    final (name, units, devices, live) = d;
    final r = rackSlots(units, devices);
    const unit = 22.0;
    return frame(
      context,
      '${widget.spec.title.isEmpty ? name : widget.spec.title} · ${t.rackUnits(units)}',
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            border: Border.all(color: cs.outline, width: 2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(children: [
            for (final s in r.slots)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: SizedBox(
                  height:
                      (s.top - s.bottom + 1) * unit + (s.top - s.bottom) * 2,
                  child: Row(children: [
                    SizedBox(
                      width: 34,
                      child: Text(
                          s.top == s.bottom
                              ? '${s.top}'
                              : '${s.top}–${s.bottom}',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              fontSize: 11, color: cs.onSurfaceVariant)),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: s.device == null
                          ? Container(
                              decoration: BoxDecoration(
                                  border: Border.all(color: cs.outlineVariant),
                                  borderRadius: BorderRadius.circular(3)))
                          : Semantics(
                              button: true,
                              label: [
                                s.device!.name,
                                statusText(t, live[s.device!.slug]?.status)
                              ].where((x) => x.isNotEmpty).join(', '),
                              child: Material(
                                color: cs.surface,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    side: s.conflict
                                        ? BorderSide(color: cs.error, width: 2)
                                        : BorderSide.none),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () => _openEntry(context,
                                      widget.ctx.project, s.device!.slug),
                                  child: Row(children: [
                                    Container(
                                        width: 4,
                                        color: statusColor(
                                            live[s.device!.slug]?.status, cs)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child: Text(s.device!.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style:
                                                const TextStyle(fontSize: 13))),
                                  ]),
                                ),
                              ),
                            ),
                    ),
                  ]),
                ),
              ),
          ]),
        ),
        if (r.conflicts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(t.rackConflict, style: TextStyle(color: cs.error)),
          ),
        if (r.unplaced.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(t.rackUnplaced(r.unplaced.length),
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
          Wrap(spacing: 6, children: [
            for (final u in r.unplaced)
              ActionChip(
                  label: Text(u.name),
                  onPressed: () =>
                      _openEntry(context, widget.ctx.project, u.slug)),
          ]),
        ],
        if (devices.isEmpty)
          Text(t.rackEmpty, style: TextStyle(color: cs.onSurfaceVariant)),
      ]),
    );
  }
}

// --- floor plan -------------------------------------------------------------------------

class PlanView extends ConsumerStatefulWidget {
  const PlanView({super.key, required this.spec, required this.ctx});
  final PlanSpec spec;
  final BlockCtx ctx;

  @override
  ConsumerState<PlanView> createState() => _PlanViewState();
}

class _PlanViewState
    extends _LiveState<PlanView, (String, Map<String, dynamic>, Live)> {
  @override
  Future<(String, Map<String, dynamic>, Live)> fetch(PhxClient c) async {
    final p = widget.ctx.project;
    final d = (await c.get(
            '/projects/$p/documents/${Uri.encodeComponent(widget.spec.plan)}'))
        .data as Map;
    if (d['type'] != 'floorplan') throw const FormatException('type');
    final plan = Map<String, dynamic>.from(d['content'] as Map? ?? const {});
    final slugs = [for (final x in planList(plan, 'devices')) '${x['entity']}'];
    return (
      '${d['title'] ?? widget.spec.plan}',
      plan,
      await loadLive(c, p, slugs)
    );
  }

  @override
  String notFound(AppLocalizations t) => t.floorplanMissing(widget.spec.plan);
  @override
  String failed(AppLocalizations t) => t.blockLoadFailed;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final d = data;
    if (d == null) return frame(context, widget.spec.title, const SizedBox());
    final (title, plan, live) = d;
    final rooms = planList(plan, 'rooms');
    final room =
        widget.spec.room.isEmpty ? null : findRoom(rooms, widget.spec.room);
    if (widget.spec.room.isNotEmpty && room == null) {
      return frame(
          context,
          widget.spec.title.isEmpty ? title : widget.spec.title,
          Text(t.floorplanNoRoom(widget.spec.room, title)));
    }
    final devices = !widget.spec.devices
        ? <Map<String, dynamic>>[]
        : [
            for (final x in planList(plan, 'devices'))
              if (room == null ||
                  (itemPoint(x) != null &&
                      inPolygon(itemPoint(x)!, roomPoints(room))))
                x
          ];
    final heading = widget.spec.title.isNotEmpty
        ? widget.spec.title
        : room != null
            ? '${room['name']} · $title'
            : title;
    final view = room != null ? _roomRect(roomPoints(room)) : planBounds(plan);
    return frame(
      context,
      heading,
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LayoutBuilder(builder: (context, c) {
          final h = min(c.maxWidth * view.height / max(view.width, 1), 420.0);
          return SizedBox(
            width: c.maxWidth,
            height: h,
            child: CustomPaint(
              painter: PlanExcerptPainter(
                plan: plan,
                view: view,
                room: room?['id'] as String?,
                devices: devices,
                live: live,
                scheme: cs,
              ),
            ),
          );
        }),
        if (devices.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              for (final slug in {for (final x in devices) '${x['entity']}'})
                ActionChip(
                  avatar: CircleAvatar(
                      radius: 5,
                      backgroundColor: statusColor(live[slug]?.status, cs)),
                  label: Text(live[slug]?.name ?? slug),
                  tooltip: statusText(t, live[slug]?.status),
                  onPressed: () =>
                      _openEntry(context, widget.ctx.project, slug),
                ),
            ]),
          ),
      ]),
    );
  }
}

Rect _roomRect(List<Offset> pts) {
  var r = Rect.fromPoints(pts.first, pts.first);
  for (final p in pts) {
    r = r.expandToInclude(Rect.fromLTWH(p.dx, p.dy, 0, 0));
  }
  final pad = max(r.width, r.height) * 0.06;
  return r.inflate(pad);
}

/// A floor plan cut to [view] (mm): rooms (others faded when one is
/// chosen), walls, doors and windows, devices with their status.
class PlanExcerptPainter extends CustomPainter {
  PlanExcerptPainter(
      {required this.plan,
      required this.view,
      required this.scheme,
      this.room,
      this.devices = const [],
      this.live = const {}});

  final Map<String, dynamic> plan;
  final Rect view;
  final String? room;
  final List<Map<String, dynamic>> devices;
  final Live live;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final tf = PlanTransform(view, size, padding: 4);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (final r in planList(plan, 'rooms')) {
      final pts = roomPoints(r).map(tf.toView).toList();
      if (pts.length < 3) continue;
      final faded = room != null && r['id'] != room;
      final c = roomColor(r['color'] as String?, scheme);
      final path = Path()..addPolygon(pts, true);
      canvas.drawPath(
          path, Paint()..color = c.withValues(alpha: faded ? 0.06 : 0.16));
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = c.withValues(alpha: faded ? 0.3 : 0.7));
      if (!faded) {
        final centre = pts.reduce((a, b) => a + b) / pts.length.toDouble();
        final sqm = polygonArea(roomPoints(r)) / 1e6;
        _label(canvas, '${r['name'] ?? ''}', centre, 14, true);
        if (sqm >= 1) {
          _label(canvas, '${sqm.toStringAsFixed(1)} m²',
              centre + const Offset(0, 16), 11, false);
        }
      }
    }
    final walls = {for (final w in planList(plan, 'walls')) '${w['id']}': w};
    Offset? pt(Object? p) => p is List && p.length >= 2
        ? Offset((p[0] as num).toDouble(), (p[1] as num).toDouble())
        : null;
    final wallPaint = Paint()
      ..color = scheme.onSurfaceVariant
      ..strokeCap = StrokeCap.square;
    for (final w in walls.values) {
      final a = pt(w['a']), b = pt(w['b']);
      if (a == null || b == null) continue;
      final thick = (w['thickness'] as num?)?.toDouble() ?? 120;
      canvas.drawLine(tf.toView(a), tf.toView(b),
          wallPaint..strokeWidth = (thick * tf.scale).clamp(1.5, 40.0));
    }
    // Doors cut the wall; windows are a thin blue line in the gap.
    for (final o in planList(plan, 'openings')) {
      final w = walls['${o['wall']}'];
      final a = pt(w?['a']), b = pt(w?['b']);
      if (w == null || a == null || b == null) continue;
      final len = (b - a).distance;
      if (len == 0) continue;
      final dir = (b - a) / len;
      final off = (o['offset'] as num?)?.toDouble() ?? 0,
          wid = (o['width'] as num?)?.toDouble() ?? 900;
      final p1 = a + dir * (off - wid / 2), p2 = a + dir * (off + wid / 2);
      final thick = ((w['thickness'] as num?)?.toDouble() ?? 120) * tf.scale;
      canvas.drawLine(
          tf.toView(p1),
          tf.toView(p2),
          Paint()
            ..color = scheme.surface
            ..strokeWidth = (thick * 1.1).clamp(2.0, 44.0));
      if (o['kind'] == 'window') {
        canvas.drawLine(
            tf.toView(p1),
            tf.toView(p2),
            Paint()
              ..color = Colors.blue
              ..strokeWidth = (thick / 3).clamp(1.0, 14.0));
      }
    }
    for (final d in devices) {
      final p = itemPoint(d);
      if (p == null) continue;
      final c = tf.toView(p);
      final e = live['${d['entity']}'];
      canvas.drawCircle(c, 7, Paint()..color = statusColor(e?.status, scheme));
      canvas.drawCircle(
          c,
          7,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = scheme.surface);
      final tp = TextPainter(
        text: TextSpan(
            text: e?.name ?? '${d['entity']}',
            style: TextStyle(fontSize: 12, color: scheme.onSurface)),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: 140);
      tp.paint(canvas, c + Offset(10, -tp.height / 2));
    }
    canvas.restore();
  }

  void _label(Canvas canvas, String text, Offset c, double size, bool bold) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              fontSize: size,
              color: bold ? scheme.onSurface : scheme.onSurfaceVariant,
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 180);
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(PlanExcerptPainter old) =>
      old.plan != plan || old.live != live || old.scheme != scheme;
}

/// Whiteboards draw graph blocks as a sketch; tapping opens the live view.
void paintGraphSketch(
    Canvas canvas, Rect r, String title, String detail, ChartStyle s) {
  void text(String v, double y, double size, Color c, bool bold) {
    final tp = TextPainter(
      text: TextSpan(
          text: v,
          style: TextStyle(
              fontSize: size,
              color: c,
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: max(1, r.width - 12));
    tp.paint(canvas, Offset(r.left + 6, y));
  }

  text(title, r.top + 4, 15, s.fg, true);
  text(detail, r.top + 28, 12, s.muted, false);
}
