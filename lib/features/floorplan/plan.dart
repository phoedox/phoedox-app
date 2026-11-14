import 'dart:math';
import 'dart:ui';

// Floor plans (server: internal/core/floorplan.go, ADR-0034) are JSON in
// millimetres, y pointing down: rooms are polygons ("points": [[x, y], …]),
// walls go from "a" to "b", devices and photos are points ("x", "y"). A
// photo is {"id", "file", "x", "y", "caption"?}; it has no direction.

/// Ids on a plan: letters, digits, "_" and "-", at most 40 (planIDRe).
final planIdPattern = RegExp(r'^[A-Za-z0-9_-]{1,40}$');

List<Map<String, dynamic>> planList(Map<String, dynamic> plan, String key) =>
    (plan[key] as List? ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();

Offset? _pt(Object? p) {
  if (p is List && p.length >= 2 && p[0] is num && p[1] is num) {
    return Offset((p[0] as num).toDouble(), (p[1] as num).toDouble());
  }
  return null;
}

/// The points of a room polygon.
List<Offset> roomPoints(Map<String, dynamic> room) =>
    (room['points'] as List? ?? const []).map(_pt).whereType<Offset>().toList();

Offset? itemPoint(Map<String, dynamic> item) {
  final x = item['x'], y = item['y'];
  return x is num && y is num ? Offset(x.toDouble(), y.toDouble()) : null;
}

/// Every id used on the plan (rooms, devices, walls, openings, photos, cables
/// share one id space on the server).
Set<String> planIds(Map<String, dynamic> plan) => {
      for (final k in [
        'rooms',
        'devices',
        'walls',
        'openings',
        'photos',
        'cables'
      ])
        for (final e in planList(plan, k))
          if (e['id'] is String) e['id'] as String,
    };

/// The drawing area in millimetres: the plan's width × height from the
/// origin, grown to everything drawn outside it.
Rect planBounds(Map<String, dynamic> plan) {
  final w = (plan['width'] as num?)?.toDouble() ?? 0;
  final h = (plan['height'] as num?)?.toDouble() ?? 0;
  var r = Rect.fromLTWH(0, 0, w > 0 ? w : 20000, h > 0 ? h : 15000);
  void add(Offset? p) {
    if (p != null) r = r.expandToInclude(Rect.fromLTWH(p.dx, p.dy, 0, 0));
  }

  for (final room in planList(plan, 'rooms')) {
    roomPoints(room).forEach(add);
  }
  for (final w in planList(plan, 'walls')) {
    add(_pt(w['a']));
    add(_pt(w['b']));
  }
  for (final d in [...planList(plan, 'devices'), ...planList(plan, 'photos')]) {
    add(itemPoint(d));
  }
  return r;
}

/// Maps between millimetres on the plan and pixels of a view of [size]: the
/// whole plan fits, centred, with [padding] pixels around it.
class PlanTransform {
  PlanTransform(this.plan, this.size, {this.padding = 12}) {
    final w = max(size.width - 2 * padding, 1.0);
    final h = max(size.height - 2 * padding, 1.0);
    scale = min(w / max(plan.width, 1), h / max(plan.height, 1));
    origin = Offset(
      (size.width - plan.width * scale) / 2,
      (size.height - plan.height * scale) / 2,
    );
  }

  final Rect plan;
  final Size size;
  final double padding;

  /// Pixels per millimetre.
  late final double scale;

  /// Where the plan's top left corner is drawn.
  late final Offset origin;

  Offset toView(Offset mm) => origin + (mm - plan.topLeft) * scale;

  /// The plan position (mm, rounded) of a point in the view.
  Offset toPlan(Offset px) {
    final p = plan.topLeft + (px - origin) / scale;
    return Offset(p.dx.roundToDouble(), p.dy.roundToDouble());
  }

  /// Whether a point of the view lies on the plan.
  bool contains(Offset px) =>
      plan.contains(plan.topLeft + (px - origin) / scale);
}

/// Area of a polygon (shoelace formula).
double polygonArea(List<Offset> pts) {
  var a = 0.0;
  for (var i = 0; i < pts.length; i++) {
    final p = pts[i], q = pts[(i + 1) % pts.length];
    a += p.dx * q.dy - q.dx * p.dy;
  }
  return a.abs() / 2;
}

/// Whether the point lies inside the polygon (ray casting).
bool inPolygon(Offset p, List<Offset> pts) {
  var inside = false;
  for (var i = 0, j = pts.length - 1; i < pts.length; j = i++) {
    final a = pts[i], b = pts[j];
    if ((a.dy > p.dy) != (b.dy > p.dy) &&
        p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
      inside = !inside;
    }
  }
  return inside;
}

/// The room at a point; the smallest wins when rooms overlap (as on the server).
Map<String, dynamic>? roomAt(Map<String, dynamic> plan, Offset p) {
  Map<String, dynamic>? best;
  var bestArea = double.infinity;
  for (final r in planList(plan, 'rooms')) {
    final pts = roomPoints(r);
    if (pts.length >= 3 && inPolygon(p, pts)) {
      final a = polygonArea(pts);
      if (a < bestArea) {
        best = r;
        bestArea = a;
      }
    }
  }
  return best;
}

/// A new plan id like "ph3k9x0b1a" that is not used on [taken].
String newPlanId(String prefix, Set<String> taken, [Random? random]) {
  final rnd = random ?? Random.secure();
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  while (true) {
    final id = prefix + List.generate(8, (_) => chars[rnd.nextInt(36)]).join();
    if (!taken.contains(id)) return id;
  }
}

/// The plan with one more photo. Everything else stays as it is. If a photo
/// with [id] and the same file is already there (an earlier attempt went
/// through), [plan] itself is returned; if [id] is taken otherwise, the
/// photo gets a new id.
Map<String, dynamic> withPhoto(
  Map<String, dynamic> plan, {
  required String id,
  required String file,
  required double x,
  required double y,
  String caption = '',
  Random? random,
}) {
  final photos = planList(plan, 'photos');
  if (photos.any((p) => p['id'] == id && p['file'] == file)) return plan;
  final taken = planIds(plan);
  final photoId = taken.contains(id) || !planIdPattern.hasMatch(id)
      ? newPlanId('ph', taken, random)
      : id;
  final text = caption.trim();
  return {
    ...plan,
    'photos': [
      ...photos,
      {
        'id': photoId,
        'file': file,
        'x': x.roundToDouble(),
        'y': y.roundToDouble(),
        if (text.isNotEmpty)
          'caption': text.length > 500 ? text.substring(0, 500) : text,
      },
    ],
  };
}
