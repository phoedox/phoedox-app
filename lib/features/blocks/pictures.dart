// Mind maps, schedules (Gantt), before/after and annotated images: the same
// source format as the web (web/src/blocks/{mindmap,gantt,beforeafter,annotate}.ts).
// Parsing and layout only, no widgets.

import 'interactive.dart' show blockLines, keyValue;

const blockColors = [
  'gray', 'red', 'orange', 'yellow', 'green', 'blue', 'purple', 'pink' //
];

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
