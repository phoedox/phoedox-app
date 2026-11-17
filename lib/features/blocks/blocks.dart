import 'package:material_ui/material_ui.dart';

import '../charts/chart.dart';
import 'interactive.dart';
import 'interactive_views.dart';
import 'graph.dart';
import 'graph_views.dart';
import 'picture_views.dart';
import 'pictures.dart';
import 'plugin_blocks.dart';

/// Where a block is shown: its project and page (or whiteboard) and, on
/// whiteboards, the element id as the key of its per-reader state.
class BlockCtx {
  const BlockCtx({this.project = '', this.doc = '', this.key});
  final String project, doc;
  final String? key;
}

/// Content blocks (ADR-0085): each kind has a native view for pages and a
/// painter for whiteboards, with the same source as on the web.
class BlockKind {
  const BlockKind({required this.view, this.paint});

  /// The interactive view in a page; throws [FormatException] when the
  /// source cannot be shown.
  final Widget Function(String source, BlockCtx ctx) view;

  /// Draws the block into a rectangle of a whiteboard; throws
  /// [FormatException] when the source cannot be drawn. Null for kinds
  /// that only live in pages (quiz).
  final void Function(Canvas canvas, Rect r, String source, ChartStyle style)?
      paint;
}

/// The view of a block, or a short notice with the source when it cannot be
/// shown (the web shows the problem in detail).
Widget blockView(String kind, String source, BlockCtx ctx) {
  final def = blockKinds[kind];
  // Kinds the core does not know may come from a plugin (ADR-0086).
  if (def == null && ctx.project.isNotEmpty) {
    return PluginBlockView(kind: kind, source: source, project: ctx.project);
  }
  if (def == null) return _BlockError(kind: kind, source: source);
  try {
    return def.view(source, ctx);
  } on FormatException {
    return _BlockError(kind: kind, source: source);
  }
}

class _BlockError extends StatelessWidget {
  const _BlockError({required this.kind, required this.source});
  final String kind, source;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: cs.error, width: 3)),
        color: cs.surfaceContainerHighest,
      ),
      child: Text('```$kind\n$source\n```',
          style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: cs.onSurfaceVariant)),
    );
  }
}

final Map<String, BlockKind> blockKinds = {
  'chart': BlockKind(
    view: (src, _) => ChartView(source: src),
    paint: (canvas, r, src, style) {
      final c = Chart.parse(src);
      var rect = r;
      if (c.title != null) {
        final tp = TextPainter(
            text: TextSpan(
                text: c.title,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: style.fg)),
            textDirection: TextDirection.ltr,
            maxLines: 1,
            ellipsis: '…')
          ..layout(maxWidth: r.width - 12);
        tp.paint(canvas, r.topLeft + const Offset(6, 2));
        rect = Rect.fromLTRB(r.left, r.top + 28, r.right, r.bottom);
      }
      paintChart(canvas, rect, c, style);
    },
  ),
  'poll': BlockKind(
    view: (src, ctx) => PollView(poll: Poll.parse(src), ctx: ctx, source: src),
    paint: (canvas, r, src, style) =>
        paintPoll(canvas, r, Poll.parse(src), style),
  ),
  'matrix': BlockKind(
    view: (src, ctx) => MatrixView(matrix: Matrix.parse(src), ctx: ctx),
    paint: (canvas, r, src, style) =>
        paintMatrix(canvas, r, Matrix.parse(src), style),
  ),
  'calc': BlockKind(
    view: (src, ctx) => CalcView(calc: Calc.parse(src), ctx: ctx),
    paint: (canvas, r, src, style) =>
        paintCalc(canvas, r, Calc.parse(src), style),
  ),
  'mindmap': BlockKind(
    view: (src, _) => MindmapView(root: parseMindmap(src)),
    paint: (canvas, r, src, style) =>
        paintMindmap(canvas, r, parseMindmap(src), style),
  ),
  'beforeafter': BlockKind(
    view: (src, _) => BeforeAfterView(m: BeforeAfter.parse(src)),
    paint: (canvas, r, src, style) =>
        paintBeforeAfter(canvas, r, BeforeAfter.parse(src), style),
  ),
  'annotate': BlockKind(
    view: (src, ctx) => AnnotatedView(m: Annotated.parse(src), ctx: ctx),
    paint: (canvas, r, src, style) =>
        paintAnnotated(canvas, r, Annotated.parse(src), style),
  ),
  'tree': BlockKind(
    view: (src, ctx) => TreeView(spec: TreeSpec.parse(src), ctx: ctx),
    paint: (canvas, r, src, style) {
      final t = TreeSpec.parse(src);
      paintGraphSketch(canvas, r, t.title.isEmpty ? '@${t.root}' : t.title,
          '@${t.root} · ${t.relation.isEmpty ? '*' : t.relation}', style);
    },
  ),
  'rack': BlockKind(
    view: (src, ctx) => RackView(spec: RackSpec.parse(src), ctx: ctx),
    paint: (canvas, r, src, style) {
      final t = RackSpec.parse(src);
      paintGraphSketch(canvas, r, t.title.isEmpty ? '@${t.rack}' : t.title,
          '@${t.rack}', style);
    },
  ),
  'floorplan': BlockKind(
    view: (src, ctx) => PlanView(spec: PlanSpec.parse(src), ctx: ctx),
    paint: (canvas, r, src, style) {
      final t = PlanSpec.parse(src);
      paintGraphSketch(canvas, r, t.title.isEmpty ? t.plan : t.title,
          [t.plan, if (t.room.isNotEmpty) t.room].join(' · '), style);
    },
  ),
  'quiz': BlockKind(
    view: (src, ctx) => QuizView(quiz: Quiz.parse(src), ctx: ctx, source: src),
  ),
};

/// Splits page Markdown into text and registered blocks (kind "md" for text);
/// [extra] are block kinds of the project's plugins.
List<({String kind, String text})> splitBlocks(String md,
    [Set<String> extra = const {}]) {
  final out = <({String kind, String text})>[];
  final buf = <String>[];
  String? kind;
  final body = <String>[];
  for (final line in md.replaceAll('\r\n', '\n').split('\n')) {
    final open = RegExp(r'^\s{0,3}```(\w+)\s*$').firstMatch(line);
    if (kind == null &&
        open != null &&
        (blockKinds.containsKey(open.group(1)) ||
            extra.contains(open.group(1)))) {
      if (buf.isNotEmpty) out.add((kind: 'md', text: buf.join('\n')));
      buf.clear();
      kind = open.group(1);
      body.clear();
    } else if (kind != null && RegExp(r'^\s{0,3}```\s*$').hasMatch(line)) {
      out.add((kind: kind, text: body.join('\n')));
      kind = null;
    } else if (kind != null) {
      body.add(line);
    } else {
      buf.add(line);
    }
  }
  if (kind != null) buf.addAll(['```$kind', ...body]);
  if (buf.isNotEmpty) out.add((kind: 'md', text: buf.join('\n')));
  return out;
}
