import 'dart:convert';
import 'dart:math';

import 'package:material_ui/material_ui.dart';

/// Charts in pages (```chart blocks) and on whiteboards: the same JSON and
/// the same drawing rules as the web (web/src/chart.ts) – line, area, bar
/// and scatter charts, numbered points with title and text, phases as
/// bands, time-axis segments with their own scale, words as y ticks.

/// The palette as text colours (lines, markers) and highlights (bands, areas),
/// light and dark, like the web's --tc-* and --tb-* tokens.
const _tcLight = {
  'gray': Color(0xFF6B6159),
  'red': Color(0xFFB4372F),
  'orange': Color(0xFFB84A0C),
  'yellow': Color(0xFF8A6A00),
  'green': Color(0xFF2C8A4B),
  'blue': Color(0xFF2F5BC0),
  'purple': Color(0xFF7A3EB8),
  'pink': Color(0xFFB0306F),
};
const _tbLight = {
  'gray': Color(0xFFEBE7E3),
  'red': Color(0xFFF9DEDB),
  'orange': Color(0xFFFBE4D4),
  'yellow': Color(0xFFF8ECBF),
  'green': Color(0xFFDCEFE1),
  'blue': Color(0xFFDDE6F8),
  'purple': Color(0xFFEBE0F6),
  'pink': Color(0xFFF7DDE9),
};
const _tcDark = {
  'gray': Color(0xFFA69B92),
  'red': Color(0xFFEF7A70),
  'orange': Color(0xFFF5904F),
  'yellow': Color(0xFFE9C75B),
  'green': Color(0xFF6FCF8C),
  'blue': Color(0xFF8AA8F5),
  'purple': Color(0xFFC29BF0),
  'pink': Color(0xFFEF8FBD),
};
const _tbDark = {
  'gray': Color(0xFF2E2824),
  'red': Color(0xFF3F201D),
  'orange': Color(0xFF3D2416),
  'yellow': Color(0xFF3A3115),
  'green': Color(0xFF1D3324),
  'blue': Color(0xFF1E2A44),
  'purple': Color(0xFF2F2240),
  'pink': Color(0xFF3C1F2E),
};
const chartColors = [
  'gray',
  'red',
  'orange',
  'yellow',
  'green',
  'blue',
  'purple',
  'pink'
];
const _seriesColors = [
  'blue',
  'orange',
  'green',
  'purple',
  'red',
  'pink',
  'yellow',
  'gray'
];
final _dateRe = RegExp(r'^(\d{1,4})(?:-(\d{2})(?:-(\d{2}))?)?$');

class ChartPoint {
  ChartPoint(this.x, this.y, {this.label, this.title, this.text, this.color});
  final Object x;
  final double? y;
  final String? label, title, text, color;
}

class ChartSeries {
  ChartSeries(this.points,
      {this.name, this.color, this.curve, this.dashed = false});
  final List<ChartPoint> points;
  final String? name, color, curve;
  final bool dashed;
}

class ChartBand {
  ChartBand(this.from, this.to, {this.label, this.color});
  final Object from, to;
  final String? label, color;
}

class ChartTick {
  ChartTick(this.value, this.label);
  final double value;
  final String label;
}

/// One numbered point for the list under the chart.
class ChartItem {
  ChartItem(this.series, this.point, this.n, this.title, this.text, this.color);
  final int series, point;
  final String n, title, text, color;
}

/// A parsed chart (or the reason it cannot be drawn).
class Chart {
  Chart._(this.raw);

  final Map<String, dynamic> raw;
  String type = 'line';
  String? title, description, xLabel, yLabel, unit;
  double height = 300;
  bool? list;
  double? yMin, yMax;
  List<ChartTick> yTicks = [];
  List<({Object from, Object to, double weight, String? label})> segments = [];
  List<ChartBand> bands = [];
  List<ChartSeries> series = [];
  List<({Object x, double y, String text, String? color})> notes = [];
  String? xType;

  /// Reads the JSON of a chart block or element; throws [FormatException]
  /// with a short reason.
  static Chart parse(Object? src) {
    final m = src is String ? jsonDecode(src) : src;
    if (m is! Map) throw const FormatException('not a JSON object');
    final c = Chart._(Map<String, dynamic>.from(m));
    String? s(Object? v) => v == null ? null : '$v';
    double? d(Object? v) => v is num ? v.toDouble() : null;
    c.type = s(m['type']) ?? 'line';
    if (!['line', 'area', 'bar', 'scatter'].contains(c.type)) {
      throw FormatException('unknown type ${c.type}');
    }
    c.title = s(m['title']);
    c.description = s(m['description']);
    c.height = (d(m['height']) ?? 300).clamp(160, 800).toDouble();
    c.list = m['list'] as bool?;
    final x = m['x'] is Map ? m['x'] as Map : const {};
    c.xLabel = s(x['label']);
    c.xType = s(x['type']);
    for (final g in (x['segments'] as List? ?? const [])) {
      if (g is! Map) continue;
      final w = d(g['weight']);
      c.segments.add((
        from: g['from'] as Object,
        to: g['to'] as Object,
        weight: w != null && w > 0 ? w : 1,
        label: s(g['label'])
      ));
    }
    final y = m['y'] is Map ? m['y'] as Map : const {};
    c.yLabel = s(y['label']);
    c.unit = s(y['unit']);
    c.yMin = d(y['min']);
    c.yMax = d(y['max']);
    for (final t in (y['ticks'] as List? ?? const [])) {
      if (t is num) c.yTicks.add(ChartTick(t.toDouble(), _fmt(t.toDouble())));
      if (t is Map && t['value'] is num) {
        c.yTicks.add(ChartTick(
            (t['value'] as num).toDouble(), '${t['label'] ?? t['value']}'));
      }
    }
    for (final b in (m['bands'] as List? ?? const [])) {
      if (b is Map) {
        c.bands.add(ChartBand(b['from'] as Object, b['to'] as Object,
            label: s(b['label']), color: s(b['color'])));
      }
    }
    ChartPoint pt(Object? p, int si, int pi) {
      if (p is! Map) {
        throw FormatException(
            'series ${si + 1}, point ${pi + 1} is not an object');
      }
      if (p['y'] != null && p['y'] is! num) {
        throw FormatException(
            'series ${si + 1}, point ${pi + 1}: y must be a number');
      }
      if (p['x'] == null || p['x'] == '') {
        throw FormatException(
            'series ${si + 1}, point ${pi + 1}: x is missing');
      }
      return ChartPoint(p['x'] as Object, d(p['y']),
          label: s(p['label']),
          title: s(p['title']),
          text: s(p['text']),
          color: s(p['color']));
    }

    final rawSeries = m['series'] is List && (m['series'] as List).isNotEmpty
        ? m['series'] as List
        : m['points'] is List
            ? [
                {'points': m['points']}
              ]
            : const [];
    for (var i = 0; i < rawSeries.length; i++) {
      final r = rawSeries[i];
      if (r is! Map) continue;
      final ps = (r['points'] as List? ?? const []);
      c.series.add(ChartSeries(
          [for (var j = 0; j < ps.length; j++) pt(ps[j], i, j)],
          name: s(r['name']),
          color: s(r['color']),
          curve: s(r['curve']),
          dashed: r['dashed'] == true));
    }
    if (c.series.every((x) => x.points.isEmpty)) {
      throw const FormatException('no points');
    }
    for (final n in (m['notes'] as List? ?? const [])) {
      if (n is Map && n['y'] is num) {
        c.notes.add((
          x: n['x'] as Object,
          y: (n['y'] as num).toDouble(),
          text: '${n['text'] ?? ''}',
          color: s(n['color'])
        ));
      }
    }
    final colors = [
      ...c.series.map((x) => x.color),
      ...c.series.expand((x) => x.points.map((p) => p.color)),
      ...c.bands.map((b) => b.color),
      ...c.notes.map((n) => n.color)
    ];
    for (final col in colors) {
      if (col != null && !chartColors.contains(col)) {
        throw FormatException('unknown colour $col');
      }
    }
    final k = c.xKind;
    if (k != 'category') {
      for (final v in c._allX) {
        if (xNum(v, k) == null) {
          throw FormatException('$v does not fit the x axis');
        }
      }
    }
    return c;
  }

  List<Object> get _allX => [
        ...series.expand((s) => s.points.map((p) => p.x)),
        ...bands.expand((b) => [b.from, b.to]),
        ...notes.map((n) => n.x),
      ];

  /// time (dates), number or category – like the web.
  String get xKind {
    if (xType != null) return xType!;
    final xs = _allX;
    if (xs.every((v) => v is num)) return 'number';
    if (type == 'bar') return 'category';
    if (xs.every((v) => v is String && _dateRe.hasMatch(v.trim()))) {
      return 'time';
    }
    return 'category';
  }

  String seriesColor(int i) {
    final s = series[i];
    if (s.color != null) return s.color!;
    if (bands.isNotEmpty) return 'gray';
    return _seriesColors[i % _seriesColors.length];
  }

  /// A point's colour: its own, else its phase's, else its series'.
  String pointColor(int si, ChartPoint p) {
    if (p.color != null) return p.color!;
    final k = xKind;
    if (k != 'category' && bands.isNotEmpty) {
      final v = xNum(p.x, k);
      if (v != null) {
        for (final b in bands) {
          final a = xNum(b.from, k), z = xNum(b.to, k);
          if (a != null && z != null && v >= a && v <= z && b.color != null) {
            return b.color!;
          }
        }
      }
    }
    return seriesColor(si);
  }

  List<ChartItem> get items {
    final out = <ChartItem>[];
    var k = 0;
    for (var si = 0; si < series.length; si++) {
      for (var pi = 0; pi < series[si].points.length; pi++) {
        final p = series[si].points[pi];
        if ((p.title ?? '').isEmpty && (p.text ?? '').isEmpty) continue;
        k++;
        out.add(ChartItem(si, pi, p.label ?? '$k', p.title ?? '', p.text ?? '',
            pointColor(si, p)));
      }
    }
    return out;
  }
}

String _fmt(double v) => v == v.roundToDouble()
    ? v.toInt().toString()
    : (v * 100).round() / 100 == v
        ? '$v'
        : v.toStringAsFixed(2);

/// A value on a time (milliseconds, UTC) or number axis.
double? xNum(Object v, String kind) {
  if (kind == 'number') {
    return v is num ? v.toDouble() : double.tryParse('$v'.trim());
  }
  if (kind != 'time') return null;
  if (v is num) {
    return DateTime.utc(v.toInt()).millisecondsSinceEpoch.toDouble();
  }
  final m = _dateRe.firstMatch('$v'.trim());
  if (m == null) return null;
  final mo = m.group(2) != null ? int.parse(m.group(2)!) : 1,
      d = m.group(3) != null ? int.parse(m.group(3)!) : 1;
  if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
  return DateTime.utc(int.parse(m.group(1)!), mo, d)
      .millisecondsSinceEpoch
      .toDouble();
}

/// Places x values: segments side by side, each with its own scale.
class XScale {
  XScale(this.kind, Chart c, this.left, this.right) {
    if (kind == 'category') {
      for (final v in c._allX) {
        if (!cats.contains('$v')) cats.add('$v');
      }
      return;
    }
    var parts = [
      for (final s in c.segments)
        if (xNum(s.from, kind) != null &&
            xNum(s.to, kind) != null &&
            xNum(s.to, kind)! > xNum(s.from, kind)!)
          (
            a: xNum(s.from, kind)!,
            b: xNum(s.to, kind)!,
            w: s.weight,
            label: s.label
          )
    ]..sort((p, q) => p.a.compareTo(q.a));
    if (parts.isEmpty) {
      final xs = c._allX.map((v) => xNum(v, kind)).whereType<double>().toList();
      var a = xs.isEmpty ? 0.0 : xs.reduce(min),
          b = xs.isEmpty ? 1.0 : xs.reduce(max);
      if (a == b) {
        final pad = kind == 'time' ? 15768e6 : 1.0;
        a -= pad;
        b += pad;
      }
      parts = [(a: a, b: b, w: 1.0, label: null)];
    }
    final total = parts.fold(0.0, (s, p) => s + p.w);
    var x = left;
    for (final p in parts) {
      final w = (right - left) * p.w / total;
      segs.add((a: p.a, b: p.b, x0: x, x1: x + w, label: p.label));
      x += w;
    }
  }

  final String kind;
  final double left, right;
  final segs = <({double a, double b, double x0, double x1, String? label})>[];
  final cats = <String>[];

  double get step => cats.isEmpty ? 0 : (right - left) / cats.length;

  double at(Object v) {
    if (kind == 'category') {
      return left + (max(0, cats.indexOf('$v')) + 0.5) * step;
    }
    final n = xNum(v, kind);
    return n == null ? left : num(n);
  }

  double num(double n) {
    if (n <= segs.first.a) return segs.first.x0;
    for (final g in segs) {
      if (n <= g.b) {
        return n < g.a ? g.x0 : g.x0 + (n - g.a) / (g.b - g.a) * (g.x1 - g.x0);
      }
    }
    return segs.last.x1;
  }
}

const _monthsDe = [
  'Jan',
  'Feb',
  'Mär',
  'Apr',
  'Mai',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Okt',
  'Nov',
  'Dez'
];
const _monthsEn = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec'
];

double _niceStep(double range, int count) {
  final raw = range / max(1, count);
  final p = pow(10, (log(raw == 0 ? 1 : raw) / ln10).floor()).toDouble();
  for (final n in [1, 2, 2.5, 5, 10]) {
    if (n * p >= raw) return n * p;
  }
  return 10 * p;
}

/// Ticks of the x axis, as many per segment as fit.
List<({double x, String label})> xTicks(XScale sc,
    {String lang = 'en', double gap = 54}) {
  final out = <({double x, String label})>[];
  if (sc.kind == 'category') {
    final every = max(1, (gap / max(1, sc.step)).ceil());
    for (var i = 0; i < sc.cats.length; i += every) {
      out.add((x: sc.left + (i + 0.5) * sc.step, label: sc.cats[i]));
    }
    return out;
  }
  final months = lang == 'de' ? _monthsDe : _monthsEn;
  for (final g in sc.segs) {
    final fits = max(1, ((g.x1 - g.x0) / gap).floor());
    if (sc.kind == 'number') {
      final st = _niceStep(g.b - g.a, fits);
      for (var v = (g.a / st).ceil() * st; v <= g.b + st * 1e-9; v += st) {
        out.add((x: sc.num(v), label: _fmt((v * 1e6).round() / 1e6)));
      }
      continue;
    }
    final a = DateTime.fromMillisecondsSinceEpoch(g.a.toInt(), isUtc: true),
        b = DateTime.fromMillisecondsSinceEpoch(g.b.toInt(), isUtc: true);
    final span = (b.year - a.year) * 12 + b.month - a.month;
    final st = [1, 2, 3, 6, 12, 24, 60, 120, 240, 600, 1200, 6000]
        .firstWhere((m) => span / m <= fits, orElse: () => 6000);
    var y = a.year, m = a.month - 1;
    if (st >= 12) {
      final ys = st ~/ 12;
      if (m > 0 || a.day > 1) y++;
      y = (y / ys).ceil() * ys;
      m = 0;
    } else {
      if (a.day > 1) m++;
      m = (m / st).ceil() * st;
    }
    var first = true;
    while (true) {
      final d = DateTime.utc(y + m ~/ 12, m % 12 + 1);
      final t = d.millisecondsSinceEpoch.toDouble();
      if (t > g.b) break;
      final label = st >= 12
          ? '${d.year}'
          : (d.month == 1 || first)
              ? '${months[d.month - 1]} ${'${d.year}'.substring(max(0, '${d.year}'.length - 2))}'
              : months[d.month - 1];
      out.add((x: sc.num(t), label: label));
      first = false;
      m += st;
    }
  }
  return out;
}

/// The y range and its ticks.
({double min, double max, List<ChartTick> ticks}) yScale(Chart c) {
  final ys = [
    ...c.series.expand((s) => s.points.map((p) => p.y)).whereType<double>(),
    ...c.notes.map((n) => n.y),
    ...c.yTicks.map((t) => t.value),
  ];
  var lo = c.yMin ?? (ys.isEmpty ? 0 : ys.reduce(min)),
      hi = c.yMax ?? (ys.isEmpty ? 1 : ys.reduce(max));
  if (c.yMin == null &&
      lo > 0 &&
      (c.type == 'bar' || c.type == 'area' || lo < hi * 0.5)) {
    lo = 0;
  }
  if (hi == lo) hi = lo + 1;
  if (c.yTicks.isNotEmpty) return (min: lo, max: hi, ticks: c.yTicks);
  final st = _niceStep(hi - lo, 5);
  if (c.yMin == null) lo = (lo / st).floor() * st;
  if (c.yMax == null) hi = (hi / st).ceil() * st;
  final ticks = <ChartTick>[];
  for (var v = lo; v <= hi + st * 1e-9; v += st) {
    final r = (v * 1e9).round() / 1e9;
    ticks.add(ChartTick(r, '${_fmt(r)}${c.unit != null ? ' ${c.unit}' : ''}'));
  }
  return (min: lo, max: hi, ticks: ticks);
}

/// A smooth path through the points that does not overshoot (monotone cubic).
Path smoothPath(List<Offset> p) {
  final path = Path()..moveTo(p.first.dx, p.first.dy);
  final n = p.length;
  var increasing = true;
  for (var i = 0; i < n - 1; i++) {
    if (p[i + 1].dx <= p[i].dx) increasing = false;
  }
  if (n < 3 || !increasing) {
    for (final q in p.skip(1)) {
      path.lineTo(q.dx, q.dy);
    }
    return path;
  }
  final dx = [for (var i = 0; i < n - 1; i++) p[i + 1].dx - p[i].dx];
  final m = [for (var i = 0; i < n - 1; i++) (p[i + 1].dy - p[i].dy) / dx[i]];
  final t = List<double>.filled(n, 0);
  t[0] = m[0];
  t[n - 1] = m[n - 2];
  for (var i = 1; i < n - 1; i++) {
    t[i] = m[i - 1] * m[i] <= 0
        ? 0
        : 3 *
            (dx[i - 1] + dx[i]) /
            ((2 * dx[i] + dx[i - 1]) / m[i - 1] +
                (dx[i] + 2 * dx[i - 1]) / m[i]);
  }
  for (var i = 0; i < n - 1; i++) {
    final h = dx[i] / 3;
    path.cubicTo(p[i].dx + h, p[i].dy + t[i] * h, p[i + 1].dx - h,
        p[i + 1].dy - t[i + 1] * h, p[i + 1].dx, p[i + 1].dy);
  }
  return path;
}

/// Colours for drawing: the palette and the page's own colours.
class ChartStyle {
  const ChartStyle(
      {required this.dark,
      required this.fg,
      required this.muted,
      required this.line,
      required this.surface,
      this.lang = 'en'});
  final bool dark;
  final Color fg, muted, line, surface;
  final String lang;
  Color tc(String c) =>
      (dark ? _tcDark : _tcLight)[c] ?? (dark ? _tcDark : _tcLight)['gray']!;
  Color tb(String c) =>
      (dark ? _tbDark : _tbLight)[c] ?? (dark ? _tbDark : _tbLight)['gray']!;

  factory ChartStyle.of(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ChartStyle(
        dark: Theme.of(context).brightness == Brightness.dark,
        fg: cs.onSurface,
        muted: cs.onSurfaceVariant,
        line: cs.outlineVariant,
        surface: cs.surface,
        lang: Localizations.localeOf(context).languageCode);
  }
}

/// Draws a chart into [r]; returns where the markers are (for taps).
List<({Rect box, int series, int point})> paintChart(
    Canvas canvas, Rect r, Chart c, ChartStyle st) {
  final hits = <({Rect box, int series, int point})>[];
  void text(String s, Offset at,
      {double size = 10.5,
      Color? color,
      TextAlign align = TextAlign.center,
      FontWeight? weight,
      FontStyle? style,
      bool vertical = false}) {
    final tp = TextPainter(
        text: TextSpan(
            text: s,
            style: TextStyle(
                fontSize: size,
                color: color ?? st.muted,
                fontWeight: weight,
                fontStyle: style)),
        textDirection: TextDirection.ltr)
      ..layout();
    final dx = align == TextAlign.center
        ? -tp.width / 2
        : align == TextAlign.right
            ? -tp.width
            : 0.0;
    if (vertical) {
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(-pi / 2);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    } else {
      tp.paint(canvas, at + Offset(dx, -tp.height / 2));
    }
  }

  final kind = c.xKind;
  final ys = yScale(c);
  final longest = ys.ticks.fold(1, (m, t) => max(m, t.label.length));
  final left =
          r.left + min(140, 14 + longest * 6.4 + (c.yLabel != null ? 18 : 0)),
      right = r.right - 16,
      top = r.top + 18;
  final segLabels = c.segments.any((s) => s.label != null);
  final bottom =
      r.bottom - 30 - (c.xLabel != null ? 18 : 0) - (segLabels ? 16 : 0);
  final sc = XScale(kind, c, left, right);
  double yAt(double v) =>
      bottom - (v - ys.min) / (ys.max - ys.min) * (bottom - top);

  // Bands.
  if (kind != 'category') {
    for (final b in c.bands) {
      final x0 = sc.at(b.from), x1 = sc.at(b.to);
      if (x1 - x0 < 0.5) continue;
      canvas.drawRect(Rect.fromLTRB(x0, top, x1, bottom),
          Paint()..color = st.tb(b.color ?? 'gray').withValues(alpha: 0.75));
      if (b.label != null && x1 - x0 > b.label!.length * 5.6 + 8) {
        text(b.label!, Offset((x0 + x1) / 2, bottom - 9),
            weight: FontWeight.w600);
      }
    }
  }
  // Grid, y axis.
  final grid = Paint()
    ..color = st.line
    ..strokeWidth = 1;
  for (final t in ys.ticks) {
    final y = yAt(t.value);
    if (y < top - 0.5 || y > bottom + 0.5) continue;
    canvas.drawLine(Offset(left, y), Offset(right, y), grid);
    text(t.label, Offset(left - 6, y), align: TextAlign.right);
  }
  if (c.yLabel != null) {
    text(c.yLabel!, Offset(r.left + 12, (top + bottom) / 2), vertical: true);
  }
  final mutedLine = Paint()
    ..color = st.muted
    ..strokeWidth = 1;
  for (final g in sc.segs.skip(1)) {
    for (var y = top; y < bottom; y += 5) {
      canvas.drawLine(
          Offset(g.x0, y), Offset(g.x0, min(bottom, y + 2)), mutedLine);
    }
  }
  canvas.drawLine(Offset(left, bottom), Offset(right, bottom), mutedLine);
  var lastX = -1e9;
  for (final t in xTicks(sc, lang: st.lang)) {
    final w = t.label.length * 5.8;
    if (t.x - w / 2 < lastX + 4) continue;
    lastX = t.x + w / 2;
    canvas.drawLine(Offset(t.x, bottom), Offset(t.x, bottom + 4), mutedLine);
    text(t.label, Offset(t.x, bottom + 14));
  }
  var below = bottom + 30;
  if (segLabels) {
    for (final g in sc.segs) {
      if (g.label != null) {
        text(g.label!, Offset((g.x0 + g.x1) / 2, below),
            size: 10, style: FontStyle.italic);
      }
    }
    below += 16;
  }
  if (c.xLabel != null) text(c.xLabel!, Offset((left + right) / 2, below));

  if (c.type == 'bar') {
    final n = c.series.length;
    final step = kind == 'category'
        ? sc.step
        : max(
            8.0,
            (right - left) /
                max(1, c.series.map((s) => s.points.length).reduce(max)));
    final bw = max(3.0, min(40.0, step * 0.7 / n));
    final base = yAt(max(ys.min, min(ys.max, 0)));
    for (var si = 0; si < n; si++) {
      for (var pi = 0; pi < c.series[si].points.length; pi++) {
        final p = c.series[si].points[pi];
        if (p.y == null) continue;
        final cx = sc.at(p.x) + (si - (n - 1) / 2) * bw, y = yAt(p.y!);
        final box = Rect.fromLTRB(cx - bw / 2, min(y, base), cx + bw / 2 - 1,
            max(y, base) + (y == base ? 1 : 0));
        canvas.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(2)),
            Paint()..color = st.tc(p.color ?? c.seriesColor(si)));
        hits.add((box: box, series: si, point: pi));
      }
    }
  } else {
    for (var si = 0; si < c.series.length; si++) {
      final s = c.series[si];
      final color = st.tc(c.seriesColor(si));
      final runs = <List<Offset>>[[]];
      for (final p in s.points) {
        if (p.y == null) {
          if (runs.last.isNotEmpty) runs.add([]);
          continue;
        }
        runs.last.add(Offset(sc.at(p.x), yAt(p.y!)));
      }
      for (final run in runs) {
        if (run.length < 2 || c.type == 'scatter') continue;
        Path path;
        if (s.curve == 'straight' || s.curve == 'step') {
          path = Path()..moveTo(run.first.dx, run.first.dy);
          for (var i = 1; i < run.length; i++) {
            if (s.curve == 'step') path.lineTo(run[i].dx, run[i - 1].dy);
            path.lineTo(run[i].dx, run[i].dy);
          }
        } else {
          path = smoothPath(run);
        }
        if (c.type == 'area') {
          final area = Path.from(path)
            ..lineTo(run.last.dx, bottom)
            ..lineTo(run.first.dx, bottom)
            ..close();
          canvas.drawPath(area,
              Paint()..color = st.tb(c.seriesColor(si)).withValues(alpha: 0.8));
        }
        final paint = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round;
        if (s.dashed) {
          for (final m in path.computeMetrics()) {
            for (var d = 0.0; d < m.length; d += 11) {
              canvas.drawPath(m.extractPath(d, min(m.length, d + 6)), paint);
            }
          }
        } else {
          canvas.drawPath(path, paint);
        }
      }
    }
    for (var si = 0; si < c.series.length; si++) {
      for (var pi = 0; pi < c.series[si].points.length; pi++) {
        final p = c.series[si].points[pi];
        if (p.y == null) continue;
        final big = p.label != null;
        final noted = (p.title ?? '').isNotEmpty || (p.text ?? '').isNotEmpty;
        if (c.type != 'scatter' && !big && !noted) continue;
        final at = Offset(sc.at(p.x), yAt(p.y!));
        final double rad = big ? min(10.0, 6.0 + p.label!.length * 2) : 4.5;
        canvas.drawCircle(at, rad + 1.5, Paint()..color = st.surface);
        canvas.drawCircle(at, rad, Paint()..color = st.tc(c.pointColor(si, p)));
        if (big) {
          text(p.label!, at,
              size: p.label!.length > 2 ? 8.5 : 10,
              color: st.surface,
              weight: FontWeight.w700);
        }
        hits.add((
          box: Rect.fromCircle(center: at, radius: max(rad, 12.0)),
          series: si,
          point: pi
        ));
      }
    }
  }
  for (final n in c.notes) {
    final at = Offset(sc.at(n.x), yAt(n.y));
    final end = at.dx > right - 80;
    text(n.text, at + Offset(end ? -4 : 4, 0),
        align: end ? TextAlign.right : TextAlign.left,
        style: FontStyle.italic,
        color: n.color != null ? st.tc(n.color!) : st.tc('green'));
  }
  return hits;
}

/// A chart block in a page: title, the plot (tap a point for its text),
/// the phases and series, and the numbered list.
class ChartView extends StatefulWidget {
  const ChartView({super.key, required this.source});
  final String source;

  @override
  State<ChartView> createState() => _ChartViewState();
}

class _ChartViewState extends State<ChartView> {
  Chart? _chart;
  String? _error;
  ({int series, int point})? _picked;
  List<({Rect box, int series, int point})> _hits = [];

  @override
  void initState() {
    super.initState();
    _read();
  }

  @override
  void didUpdateWidget(ChartView old) {
    super.didUpdateWidget(old);
    if (old.source != widget.source) _read();
  }

  void _read() {
    try {
      _chart = Chart.parse(widget.source);
      _error = null;
    } on FormatException catch (e) {
      _chart = null;
      _error = e.message;
    }
  }

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context), cs = th.colorScheme;
    final c = _chart;
    final box = BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(12),
        color: cs.surface);
    if (c == null) {
      return Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.all(12),
          decoration: box.copyWith(
              border: Border(left: BorderSide(color: cs.error, width: 3))),
          child: Text('Chart: $_error', style: TextStyle(color: cs.error)));
    }
    final st = ChartStyle.of(context);
    final items = c.items;
    final picked = _picked == null
        ? null
        : c.series[_picked!.series].points[_picked!.point];
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: box,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (c.title != null) Text(c.title!, style: th.textTheme.titleMedium),
        if (c.description != null)
          Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(c.description!,
                  style: th.textTheme.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant))),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (context, lc) {
          final size = Size(lc.maxWidth, c.height);
          return GestureDetector(
            onTapUp: (d) {
              final hit = _hits
                  .where((h) => h.box.contains(d.localPosition))
                  .firstOrNull;
              setState(() => _picked =
                  hit == null ? null : (series: hit.series, point: hit.point));
            },
            child: CustomPaint(
                size: size,
                painter: _ChartPainter(c, st, (h) => _hits = h),
                child: Semantics(
                    label: c.title ?? 'Chart',
                    child: SizedBox.fromSize(size: size))),
          );
        }),
        if (picked != null)
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: cs.inverseSurface,
                borderRadius: BorderRadius.circular(8)),
            child: Text.rich(TextSpan(
                style: TextStyle(color: cs.onInverseSurface),
                children: [
                  TextSpan(
                      text: [picked.label, picked.title]
                          .whereType<String>()
                          .join(' · '),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  if ((picked.text ?? '').isNotEmpty)
                    TextSpan(text: '\n${picked.text}'),
                  if ((picked.title ?? '').isEmpty &&
                      (picked.text ?? '').isEmpty)
                    TextSpan(text: ' ${picked.x}: ${picked.y}'),
                ])),
          ),
        if (c.bands.any((b) => b.label != null) ||
            c.series.any((s) => s.name != null))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(spacing: 14, runSpacing: 6, children: [
              for (final b in c.bands.where((b) => b.label != null))
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                          color: st.tb(b.color ?? 'gray'),
                          border: Border.all(color: st.tc(b.color ?? 'gray')),
                          borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 6),
                  Text(b.label!,
                      style: th.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant)),
                ]),
              for (var i = 0; i < c.series.length; i++)
                if (c.series[i].name != null)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                        width: 16, height: 3, color: st.tc(c.seriesColor(i))),
                    const SizedBox(width: 6),
                    Text(c.series[i].name!,
                        style: th.textTheme.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant)),
                  ]),
            ]),
          ),
        if ((c.list ?? items.isNotEmpty) && items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(children: [
              for (final i in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          constraints: const BoxConstraints(minWidth: 22),
                          height: 22,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              color: st.tc(i.color),
                              borderRadius: BorderRadius.circular(11)),
                          child: Text(i.n,
                              style: TextStyle(
                                  color: st.surface,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text.rich(TextSpan(
                                style: th.textTheme.bodyMedium,
                                children: [
                              if (i.title.isNotEmpty)
                                TextSpan(
                                    text: i.title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                              if (i.title.isNotEmpty && i.text.isNotEmpty)
                                const TextSpan(text: ': '),
                              TextSpan(text: i.text),
                            ]))),
                      ]),
                ),
            ]),
          ),
      ]),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.chart, this.style, this.onHits);
  final Chart chart;
  final ChartStyle style;
  final void Function(List<({Rect box, int series, int point})>) onHits;

  @override
  void paint(Canvas canvas, Size size) =>
      onHits(paintChart(canvas, Offset.zero & size, chart, style));

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.chart != chart || old.style.dark != style.dark;
}

/// Splits page Markdown into text and ```chart blocks (kind "md" or "chart").
List<({String kind, String text})> splitCharts(String md) {
  final out = <({String kind, String text})>[];
  final buf = <String>[];
  List<String>? chart;
  for (final line in md.replaceAll('\r\n', '\n').split('\n')) {
    if (chart == null && RegExp(r'^\s{0,3}```chart\s*$').hasMatch(line)) {
      if (buf.isNotEmpty) out.add((kind: 'md', text: buf.join('\n')));
      buf.clear();
      chart = [];
    } else if (chart != null && RegExp(r'^\s{0,3}```\s*$').hasMatch(line)) {
      out.add((kind: 'chart', text: chart.join('\n')));
      chart = null;
    } else if (chart != null) {
      chart.add(line);
    } else {
      buf.add(line);
    }
  }
  if (chart != null) buf.addAll(['```chart', ...chart]);
  if (buf.isNotEmpty) out.add((kind: 'md', text: buf.join('\n')));
  return out;
}
