import 'package:material_ui/material_ui.dart';

import '../charts/chart.dart';

/// Content blocks (ADR-0085): each kind has a native view for pages and a
/// painter for whiteboards, with the same source as on the web.
class BlockKind {
  const BlockKind({required this.view, required this.paint});

  /// The interactive view in a page.
  final Widget Function(String source) view;

  /// Draws the block into a rectangle of a whiteboard; throws
  /// [FormatException] when the source cannot be drawn.
  final void Function(Canvas canvas, Rect r, String source, ChartStyle style)
      paint;
}

final Map<String, BlockKind> blockKinds = {
  'chart': BlockKind(
    view: (src) => ChartView(source: src),
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
};

/// Splits page Markdown into text and registered blocks (kind "md" for text).
List<({String kind, String text})> splitBlocks(String md) {
  final out = <({String kind, String text})>[];
  final buf = <String>[];
  String? kind;
  final body = <String>[];
  for (final line in md.replaceAll('\r\n', '\n').split('\n')) {
    final open = RegExp(r'^\s{0,3}```(\w+)\s*$').firstMatch(line);
    if (kind == null && open != null && blockKinds.containsKey(open.group(1))) {
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
