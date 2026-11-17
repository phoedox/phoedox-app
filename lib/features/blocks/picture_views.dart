import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../api/files.dart';
import '../../l10n/gen/app_localizations.dart';
import '../charts/chart.dart';
import '../entity/entity_page.dart';
import 'blocks.dart';
import 'pictures.dart';

Widget _frame(BuildContext context, Widget child) => Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );

Widget _title(BuildContext context, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );

/// Paints one line of text and returns its size.
Size _text(Canvas canvas, String text, Offset at, double maxW, double size,
    Color color,
    {bool bold = false, TextAlign align = TextAlign.left}) {
  final tp = TextPainter(
    text: TextSpan(
        text: text,
        style: TextStyle(
            fontSize: size,
            color: color,
            fontWeight: bold ? FontWeight.w600 : FontWeight.normal)),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: maxW < 1 ? 1 : maxW);
  final dx = align == TextAlign.center
      ? -tp.width / 2
      : align == TextAlign.right
          ? -tp.width
          : 0.0;
  tp.paint(canvas, at + Offset(dx, -tp.height / 2));
  return tp.size;
}

// --- mind map ------------------------------------------------------------------------

void _paintMind(Canvas canvas, List<MindPlaced> nodes, ChartStyle s) {
  for (final n in nodes) {
    final p = n.parent;
    if (p == null) continue;
    final x1 = n.side == 1 ? p.x + p.w : p.x, y1 = p.y + p.h / 2;
    final x2 = n.side == 1 ? n.x : n.x + n.w, y2 = n.y + n.h / 2;
    final mx = (x1 + x2) / 2;
    canvas.drawPath(
        Path()
          ..moveTo(x1, y1)
          ..cubicTo(mx, y1, mx, y2, x2, y2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = n.depth == 1 ? 2.5 : 1.5
          ..color = s.tc(n.color));
  }
  for (final n in nodes) {
    final r = RRect.fromRectAndRadius(Rect.fromLTWH(n.x, n.y, n.w, n.h),
        Radius.circular(n.depth == 0 ? 12 : 8));
    canvas.drawRRect(
        r,
        Paint()
          ..color = n.depth == 0
              ? s.line.withValues(alpha: 0.5)
              : n.depth == 1
                  ? s.tb(n.color)
                  : s.surface);
    canvas.drawRRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = n.depth == 0 ? 1.5 : 1
          ..color = n.depth == 0 ? s.line : s.tc(n.color));
    _text(canvas, n.node.text, Offset(n.x + n.w / 2, n.y + n.h / 2), n.w - 10,
        n.depth == 0 ? 16 : 13, s.fg,
        bold: n.depth <= 1, align: TextAlign.center);
    if (n.hidden > 0) {
      final c = Offset(n.side == -1 ? n.x - 12 : n.x + n.w + 12, n.y + n.h / 2);
      canvas.drawCircle(c, 10, Paint()..color = s.tc(n.color));
      _text(canvas, n.hidden > 99 ? '99+' : '${n.hidden}', c, 30, 10, s.surface,
          bold: true, align: TextAlign.center);
    }
  }
}

void paintMindmap(Canvas canvas, Rect r, MindNode root, ChartStyle s) {
  final l = layoutMindmap(root);
  final k = [r.width / l.width, r.height / l.height, 1.0]
      .reduce((a, b) => a < b ? a : b);
  canvas.save();
  canvas.translate(r.left + (r.width - l.width * k) / 2,
      r.top + (r.height - l.height * k) / 2);
  canvas.scale(k);
  _paintMind(canvas, l.nodes, s);
  canvas.restore();
}

class MindmapView extends StatefulWidget {
  const MindmapView({super.key, required this.root});
  final MindNode root;

  @override
  State<MindmapView> createState() => _MindmapViewState();
}

class _MindmapViewState extends State<MindmapView> {
  final _collapsed = <String>{};
  ScrollController? _scroll;

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final l = layoutMindmap(widget.root, _collapsed);
    final style = ChartStyle.of(context);
    return _frame(
      context,
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LayoutBuilder(builder: (context, c) {
          final map = SizedBox(
            width: l.width,
            height: l.height,
            child: Stack(children: [
              Positioned.fill(
                  child: CustomPaint(painter: _MindPainter(l.nodes, style))),
              // Branches with children are buttons that fold them.
              for (final n in l.nodes)
                if (n.depth > 0 && n.node.children.isNotEmpty)
                  Positioned(
                    left: n.x,
                    top: n.y - 6,
                    width: n.w,
                    height: n.h + 12,
                    child: Semantics(
                      button: true,
                      expanded: n.hidden == 0,
                      label: n.node.text,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => setState(() =>
                            _collapsed.contains(n.node.id)
                                ? _collapsed.remove(n.node.id)
                                : _collapsed.add(n.node.id)),
                      ),
                    ),
                  ),
            ]),
          );
          // Small enough to read: scaled to the width; else scrolled, starting in the middle.
          final k = c.maxWidth / l.width;
          if (k >= 1) return Center(child: map);
          if (k >= 0.55) {
            return SizedBox(
                width: c.maxWidth,
                height: l.height * k,
                child: FittedBox(fit: BoxFit.contain, child: map));
          }
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: _scroll ??= ScrollController(
                initialScrollOffset: (l.width - c.maxWidth) / 2),
            child: map,
          );
        }),
        if (_collapsed.isNotEmpty)
          TextButton(
              onPressed: () => setState(_collapsed.clear),
              child: Text(t.mindmapExpandAll)),
      ]),
    );
  }
}

class _MindPainter extends CustomPainter {
  _MindPainter(this.nodes, this.style);
  final List<MindPlaced> nodes;
  final ChartStyle style;
  @override
  void paint(Canvas canvas, Size size) => _paintMind(canvas, nodes, style);
  @override
  bool shouldRepaint(_MindPainter old) => true;
}

// --- images ------------------------------------------------------------------------------

/// A block's image: a project file (cached on the device) or an https address.
class BlockImage extends ConsumerWidget {
  const BlockImage({super.key, required this.image, this.label = '', this.fit});
  final ({String? fileId, String? url}) image;
  final String label;
  final BoxFit? fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    Widget broken() => Container(
        height: 160,
        color: cs.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Icon(LucideIcons.imageOff, color: cs.onSurfaceVariant));
    if (image.url != null) {
      return Image.network(image.url!,
          fit: fit,
          semanticLabel: label,
          errorBuilder: (_, __, ___) => broken());
    }
    return ref.watch(localFileProvider(image.fileId!)).when(
          loading: () => Container(
              height: 200,
              color: cs.surfaceContainerHighest,
              alignment: Alignment.center,
              child: const CircularProgressIndicator()),
          error: (_, __) => broken(),
          data: (f) => Image.file(f, fit: fit, semanticLabel: label),
        );
  }
}

class BeforeAfterView extends StatefulWidget {
  const BeforeAfterView({super.key, required this.m});
  final BeforeAfter m;

  @override
  State<BeforeAfterView> createState() => _BeforeAfterViewState();
}

class _BeforeAfterViewState extends State<BeforeAfterView> {
  late double _pos = widget.m.start;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final m = widget.m;
    final bl = m.beforeLabel.isEmpty ? t.beforeAfterBefore : m.beforeLabel;
    final al = m.afterLabel.isEmpty ? t.beforeAfterAfter : m.afterLabel;
    if (m.before == null || m.after == null) {
      return _frame(
          context,
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (m.title.isNotEmpty) _title(context, m.title),
            Text(t.beforeAfterMissing),
          ]));
    }
    Widget tag(String s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(6)),
        child: Text(s,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600)));
    return _frame(
      context,
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (m.title.isNotEmpty) _title(context, m.title),
        LayoutBuilder(builder: (context, c) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (d) => setState(() =>
                _pos = (_pos + d.delta.dx / c.maxWidth * 100).clamp(0, 100)),
            onTapUp: (d) => setState(() =>
                _pos = (d.localPosition.dx / c.maxWidth * 100).clamp(0, 100)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(children: [
                BlockImage(image: m.after!, label: al),
                Positioned.fill(
                  child: ClipRect(
                    clipper: _LeftClip(_pos / 100),
                    child: BlockImage(
                        image: m.before!, label: bl, fit: BoxFit.cover),
                  ),
                ),
                Positioned(
                    left: c.maxWidth * _pos / 100 - 1,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 2, color: Colors.white)),
                Positioned(left: 8, top: 8, child: tag(bl)),
                Positioned(right: 8, top: 8, child: tag(al)),
              ]),
            ),
          );
        }),
        // The slider is the accessible control (screen readers, keyboards).
        Slider(
          value: _pos,
          max: 100,
          label: '${_pos.round()} %',
          semanticFormatterCallback: (v) => t.beforeAfterValue(v.round(), bl),
          onChanged: (v) => setState(() => _pos = v),
        ),
      ]),
    );
  }
}

class _LeftClip extends CustomClipper<Rect> {
  _LeftClip(this.f);
  final double f;
  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width * f, size.height);
  @override
  bool shouldReclip(_LeftClip old) => old.f != f;
}

void _placeholder(Canvas canvas, Rect r, String label, ChartStyle s) {
  canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(6)),
      Paint()..color = s.line.withValues(alpha: 0.4));
  _text(canvas, label, r.center, r.width - 8, 12, s.muted,
      align: TextAlign.center);
}

void paintBeforeAfter(Canvas canvas, Rect r, BeforeAfter m, ChartStyle s) {
  var top = r.top;
  if (m.title.isNotEmpty) {
    _text(canvas, m.title, Offset(r.left + 4, r.top + 12), r.width, 15, s.fg,
        bold: true);
    top += 28;
  }
  final w = (r.width - 10) / 2;
  _placeholder(
      canvas, Rect.fromLTWH(r.left, top, w, r.bottom - top), m.beforeLabel, s);
  _placeholder(canvas, Rect.fromLTWH(r.left + w + 10, top, w, r.bottom - top),
      m.afterLabel, s);
}

class AnnotatedView extends StatefulWidget {
  const AnnotatedView({super.key, required this.m, required this.ctx});
  final Annotated m;
  final BlockCtx ctx;

  @override
  State<AnnotatedView> createState() => _AnnotatedViewState();
}

class _AnnotatedViewState extends State<AnnotatedView> {
  int? _on;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final style = ChartStyle.of(context);
    final cs = Theme.of(context).colorScheme;
    final m = widget.m;
    Widget dot(int i, {double size = 26}) => Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: style.tc(m.markers[i].color),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black38)],
          ),
          child: Text('${i + 1}',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12)),
        );
    return _frame(
      context,
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (m.title.isNotEmpty) _title(context, m.title),
        if (m.image == null)
          Text(t.annotateNoImage)
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(children: [
              BlockImage(
                  image: m.image!, label: m.alt.isEmpty ? m.title : m.alt),
              Positioned.fill(
                child: LayoutBuilder(builder: (context, c) {
                  return Stack(children: [
                    for (var i = 0; i < m.markers.length; i++)
                      Positioned(
                        left: c.maxWidth * m.markers[i].x / 100 - 18,
                        top: c.maxHeight * m.markers[i].y / 100 - 18,
                        child: Semantics(
                          label: '${i + 1}: ${m.markers[i].text}',
                          button: true,
                          child: GestureDetector(
                            onTap: () => setState(() => _on = i),
                            child: SizedBox(
                              width: 36,
                              height: 36,
                              child: Center(
                                  child: AnimatedScale(
                                      scale: _on == i ? 1.25 : 1,
                                      duration:
                                          const Duration(milliseconds: 150),
                                      curve: Curves.easeOut,
                                      child: dot(i))),
                            ),
                          ),
                        ),
                      ),
                  ]);
                }),
              ),
            ]),
          ),
        const SizedBox(height: 8),
        for (var i = 0; i < m.markers.length; i++)
          InkWell(
            onTap: () => setState(() => _on = i),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              decoration: BoxDecoration(
                  color: _on == i ? cs.surfaceContainerHighest : null,
                  borderRadius: BorderRadius.circular(6)),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ExcludeSemantics(child: dot(i, size: 22)),
                const SizedBox(width: 10),
                Expanded(child: _markerText(context, m.markers[i].text)),
              ]),
            ),
          ),
      ]),
    );
  }

  /// The marker's text with @entries as links to their pages.
  Widget _markerText(BuildContext context, String text) {
    final cs = Theme.of(context).colorScheme;
    final spans = <InlineSpan>[];
    var last = 0;
    for (final mt in RegExp(r'(^|[^\w@./-])@([a-z0-9]+(?:-[a-z0-9]+)*)')
        .allMatches(text)) {
      final at = mt.start + mt[1]!.length;
      spans.add(TextSpan(text: text.substring(last, at)));
      final slug = mt[2]!;
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: GestureDetector(
          onTap: widget.ctx.project.isEmpty
              ? null
              : () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      EntityPage(project: widget.ctx.project, entity: slug))),
          child: Text('@$slug',
              style: TextStyle(
                  color: cs.primary, decoration: TextDecoration.underline)),
        ),
      ));
      last = mt.end;
    }
    spans.add(TextSpan(text: text.substring(last)));
    return Text.rich(TextSpan(children: spans));
  }
}

void paintAnnotated(Canvas canvas, Rect r, Annotated m, ChartStyle s) {
  var top = r.top;
  if (m.title.isNotEmpty) {
    _text(canvas, m.title, Offset(r.left + 4, r.top + 12), r.width, 15, s.fg,
        bold: true);
    top += 28;
  }
  final listH = (m.markers.length > 5 ? 5 : m.markers.length) * 18.0 + 6;
  final img = Rect.fromLTRB(r.left, top, r.right, r.bottom - listH);
  _placeholder(canvas, img, m.alt.isEmpty ? m.title : m.alt, s);
  for (var i = 0; i < m.markers.length; i++) {
    final mk = m.markers[i];
    final c = Offset(
        img.left + img.width * mk.x / 100, img.top + img.height * mk.y / 100);
    canvas.drawCircle(c, 11, Paint()..color = s.tc(mk.color));
    canvas.drawCircle(
        c,
        11,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white);
    _text(canvas, '${i + 1}', c, 30, 11, Colors.white,
        bold: true, align: TextAlign.center);
    if (i < 5) {
      _text(canvas, '${i + 1}  ${mk.text}',
          Offset(r.left + 4, img.bottom + 12 + i * 18), r.width - 8, 12, s.fg);
    }
  }
}
