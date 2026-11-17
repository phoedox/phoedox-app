// Mind maps, schedules (Gantt), before/after and annotated images: the same
// source format as the web (web/src/blocks/{mindmap,gantt,beforeafter,annotate}.ts).
// Parsing and layout only, no widgets.

import 'interactive.dart' show blockLines, keyValue;

const blockColors = [
  'gray', 'red', 'orange', 'yellow', 'green', 'blue', 'purple', 'pink' //
];

// --- mind map ---------------------------------------------------------------------

class MindNode {
  MindNode(this.text, this.id);
  final String text, id;
  final children = <MindNode>[];

  int get count => 1 + children.fold(0, (s, c) => s + c.count);
}

MindNode parseMindmap(String src) {
  final lines = [
    for (final l in src.replaceAll('\r\n', '\n').split('\n'))
      if (l.trim().isNotEmpty && !l.trim().startsWith('#')) l
  ];
  if (lines.isEmpty) throw const FormatException('mindmap.err_empty');
  int indent(String l) =>
      RegExp(r'^ *').firstMatch(l.replaceAll('\t', '  '))!.group(0)!.length;
  String clean(String l) => l.trim().replaceFirst(RegExp(r'^[-*+]\s+'), '');
  final root = MindNode(clean(lines.first), '0');
  final stack = <(MindNode, int)>[(root, -1)];
  for (final l in lines.skip(1)) {
    final ind = indent(l);
    while (stack.length > 1 && stack.last.$2 >= ind) {
      stack.removeLast();
    }
    final parent = stack.last.$1;
    final n = MindNode(clean(l), '${parent.id}.${parent.children.length}');
    parent.children.add(n);
    stack.add((n, ind));
  }
  if (root.count > 400) throw const FormatException('mindmap.err_too_many');
  return root;
}

class MindPlaced {
  MindPlaced(this.node, this.x, this.y, this.w, this.h, this.side, this.color,
      this.depth, this.parent, this.hidden);
  final MindNode node;
  double x, y;
  final double w, h;
  final int side, depth, hidden;
  final String color;
  final MindPlaced? parent;
}

const _branch = ['blue', 'green', 'orange', 'purple', 'pink', 'red', 'yellow'];

/// A rough text width, like the web's (no font metrics needed).
double textWidth(String s, [double size = 13]) {
  var w = 0.0;
  for (final ch in s.runes.map(String.fromCharCode)) {
    w += RegExp(r'[MWmw@%]').hasMatch(ch)
        ? 0.9
        : RegExp(r'[A-ZÄÖÜ0-9]').hasMatch(ch)
            ? 0.68
            : RegExp(r"[iljtf.,:;'|!]").hasMatch(ch)
                ? 0.3
                : 0.55;
  }
  return w * size;
}

/// The root in the middle, branches split by size to the right and left.
({List<MindPlaced> nodes, double width, double height}) layoutMindmap(
    MindNode root,
    [Set<String> collapsed = const {}]) {
  const row = 30.0, gap = 36.0;
  List<MindNode> kids(MindNode n) =>
      collapsed.contains(n.id) ? const [] : n.children;
  int leaves(MindNode n) =>
      kids(n).isEmpty ? 1 : kids(n).fold(0, (s, c) => s + leaves(c));
  final branches = root.children;
  final total = branches.fold(0, (s, b) => s + leaves(b));
  final right = <MindNode>[], left = <MindNode>[];
  var acc = 0;
  for (final b in branches) {
    if (acc < total / 2 || right.isEmpty) {
      right.add(b);
      acc += leaves(b);
    } else {
      left.add(b);
    }
  }
  double boxW(MindNode n, int d) {
    final w = textWidth(n.text, d == 0 ? 16 : 13) + (d == 0 ? 32 : 20);
    return w > 240 ? 240 : w;
  }

  final colW = <String, double>{};
  void measure(MindNode n, int d, int side) {
    final k = '$side:$d', w = boxW(n, d);
    if ((colW[k] ?? 0) < w) colW[k] = w;
    for (final c in kids(n)) {
      measure(c, d + 1, side);
    }
  }

  for (final b in right) {
    measure(b, 1, 1);
  }
  for (final b in left) {
    measure(b, 1, -1);
  }
  final rootW = boxW(root, 0);
  double colX(int side, int d) {
    var x = rootW / 2 + gap;
    for (var i = 1; i < d; i++) {
      x += (colW['$side:$i'] ?? 0) + gap;
    }
    return x;
  }

  final nodes = <MindPlaced>[];
  final rp =
      MindPlaced(root, -rootW / 2, -20, rootW, 40, 0, 'gray', 0, null, 0);
  nodes.add(rp);
  double place(MindNode n, int d, int side, double top, String color,
      MindPlaced parent) {
    final h = leaves(n) * row, w = boxW(n, d), off = colX(side, d);
    final p = MindPlaced(n, side == 1 ? off : -off - w, top + h / 2 - 12, w, 24,
        side, color, d, parent, collapsed.contains(n.id) ? n.count - 1 : 0);
    nodes.add(p);
    var y = top;
    for (final c in kids(n)) {
      y += place(c, d + 1, side, y, color, p);
    }
    return h;
  }

  for (final (list, side) in [(right, 1), (left, -1)]) {
    final h = list.fold(0.0, (s, b) => s + leaves(b) * row);
    var y = -h / 2;
    for (final b in list) {
      y += place(
          b, 1, side, y, _branch[branches.indexOf(b) % _branch.length], rp);
    }
  }
  var minX = double.infinity, minY = double.infinity;
  var maxX = -double.infinity, maxY = -double.infinity;
  for (final n in nodes) {
    if (n.x < minX) minX = n.x;
    if (n.y < minY) minY = n.y;
    if (n.x + n.w > maxX) maxX = n.x + n.w;
    if (n.y + n.h > maxY) maxY = n.y + n.h;
  }
  // 28 px each side for the "+n" badges of collapsed branches.
  minX -= 28;
  maxX += 28;
  minY -= 8;
  maxY += 8;
  for (final n in nodes) {
    n.x -= minX;
    n.y -= minY;
  }
  return (nodes: nodes, width: maxX - minX, height: maxY - minY);
}

// --- images ---------------------------------------------------------------------------

/// An image of a block: a project file (`/api/v1/files/<id>`, or the id) or an
/// https address. Returns the file id or the URL.
({String? fileId, String? url})? blockImage(String v) {
  final s = v.trim().split(RegExp(r'\s+')).first;
  final f =
      RegExp(r'^/api/v1/files/([A-Za-z0-9]+)(/[^\s"<>]*)?$').firstMatch(s);
  if (f != null) return (fileId: f[1], url: null);
  if (RegExp(r'^[0-9A-HJKMNP-TV-Z]{26}$').hasMatch(s)) {
    return (fileId: s, url: null);
  }
  if (RegExp(r'^https://[^\s"<>]+$').hasMatch(s)) return (fileId: null, url: s);
  return null;
}

String _label(String v) {
  final parts = v.trim().split(RegExp(r'\s+'));
  return parts.length > 1 ? parts.skip(1).join(' ') : '';
}

class BeforeAfter {
  BeforeAfter(this.title, this.before, this.after, this.beforeLabel,
      this.afterLabel, this.start);
  final String title, beforeLabel, afterLabel;
  final ({String? fileId, String? url})? before, after;
  final double start;

  static BeforeAfter parse(String src) {
    var title = '', bl = '', al = '';
    ({String? fileId, String? url})? b, a;
    var start = 50.0;
    final md = <(({String? fileId, String? url})?, String)>[];
    for (final l in blockLines(src)) {
      final kv = keyValue(l,
          ['title', 'titel', 'before', 'vorher', 'after', 'nachher', 'start']);
      if (kv != null) {
        switch (kv.$1) {
          case 'title' || 'titel':
            title = kv.$2;
          case 'start':
            start = (double.tryParse(kv.$2.replaceAll('%', '')) ?? 50)
                .clamp(0, 100)
                .toDouble();
          default:
            if (kv.$2.isEmpty) continue;
            final img = blockImage(kv.$2);
            if (img == null) throw const FormatException('image.err_src');
            if (kv.$1 == 'before' || kv.$1 == 'vorher') {
              b = img;
              bl = _label(kv.$2);
            } else {
              a = img;
              al = _label(kv.$2);
            }
        }
        continue;
      }
      final im = RegExp(r'^!\[([^\]]*)\]\(([^)\s]+)\)$').firstMatch(l);
      if (im != null) {
        final img = blockImage(im[2]!);
        if (img == null) throw const FormatException('image.err_src');
        md.add((img, im[1]!));
        continue;
      }
      throw const FormatException('beforeafter.err_line');
    }
    if (b == null && md.isNotEmpty) {
      (b, bl) = (md[0].$1, bl.isEmpty ? md[0].$2 : bl);
    }
    if (a == null && md.length > 1) {
      (a, al) = (md[1].$1, al.isEmpty ? md[1].$2 : al);
    }
    return BeforeAfter(title, b, a, bl, al, start);
  }
}

class Marker {
  Marker(this.x, this.y, this.text, this.color);
  final double x, y;
  final String text, color;
}

class Annotated {
  Annotated(this.title, this.image, this.alt, this.markers);
  final String title, alt;
  final ({String? fileId, String? url})? image;
  final List<Marker> markers;

  static Annotated parse(String src) {
    var title = '', alt = '';
    ({String? fileId, String? url})? image;
    final markers = <Marker>[];
    for (final l in blockLines(src)) {
      final kv = keyValue(l, ['title', 'titel', 'image', 'bild']);
      if (kv != null) {
        if (kv.$1 == 'title' || kv.$1 == 'titel') {
          title = kv.$2;
        } else if (kv.$2.isNotEmpty) {
          image = blockImage(kv.$2);
          if (image == null) throw const FormatException('image.err_src');
          alt = _label(kv.$2);
        }
        continue;
      }
      final m = RegExp(
              r'^[-*+]?\s*(\d+(?:[.,]\d+)?)\s*%?\s*[,;]\s*(\d+(?:[.,]\d+)?)\s*%?(?:\s+([a-z]+))?\s*:\s*(.*)$',
              caseSensitive: false)
          .firstMatch(l);
      if (m == null) throw const FormatException('annotate.err_line');
      final x = double.parse(m[1]!.replaceAll(',', '.')),
          y = double.parse(m[2]!.replaceAll(',', '.'));
      if (x > 100 || y > 100) throw const FormatException('annotate.err_pos');
      final c = (m[3] ?? '').toLowerCase();
      if (c.isNotEmpty && !blockColors.contains(c)) {
        throw const FormatException('annotate.err_color');
      }
      markers.add(Marker(x, y, m[4]!.trim(), c.isEmpty ? 'red' : c));
    }
    if (image == null && markers.isEmpty) {
      throw const FormatException('annotate.err_image');
    }
    return Annotated(title, image, alt, markers);
  }
}
