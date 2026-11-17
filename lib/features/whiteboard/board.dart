import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

/// Whiteboards (ADR-0068): the element model shared with the server and the
/// web editor. Elements stay maps so fields the app does not know survive.
typedef El = Map<String, dynamic>;

const palette = [
  'gray',
  'red',
  'orange',
  'yellow',
  'green',
  'blue',
  'purple',
  'pink'
];

/// Stroke and fill colours of the palette (as the web editor draws them).
const strokeColors = {
  'gray': Color(0xFF1E1E1E),
  'red': Color(0xFFE03131),
  'orange': Color(0xFFF08C00),
  'yellow': Color(0xFFE8B800),
  'green': Color(0xFF2F9E44),
  'blue': Color(0xFF1971C2),
  'purple': Color(0xFF9C36B5),
  'pink': Color(0xFFC2255C),
};
const fillColors = {
  'gray': Color(0xFFE9ECEF),
  'red': Color(0xFFFFC9C9),
  'orange': Color(0xFFFFD8A8),
  'yellow': Color(0xFFFFF3BF),
  'green': Color(0xFFB2F2BB),
  'blue': Color(0xFFA5D8FF),
  'purple': Color(0xFFEEBEFA),
  'pink': Color(0xFFFCC2D7),
};

double _n(Object? v) => (v as num?)?.toDouble() ?? 0;

List<Offset> pointsOf(El e) => [
      for (final p in (e['points'] as List?) ?? const [])
        if (p is List && p.length == 2) Offset(_n(p[0]), _n(p[1]))
    ];

bool isLinear(El e) =>
    e['type'] == 'line' || e['type'] == 'arrow' || e['type'] == 'pen';

/// The element's box in board coordinates.
Rect boundsOf(El e) {
  if (isLinear(e)) {
    final pts = pointsOf(e);
    if (pts.isEmpty) return Rect.zero;
    var r = Rect.fromPoints(pts.first, pts.first);
    for (final p in pts) {
      r = r.expandToInclude(Rect.fromPoints(p, p));
    }
    return r;
  }
  return Rect.fromLTWH(_n(e['x']), _n(e['y']), _n(e['w']), _n(e['h']));
}

double _distToSegment(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final len = ab.distanceSquared;
  if (len == 0) return (p - a).distance;
  final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len).clamp(0.0, 1.0);
  return (p - (a + ab * t)).distance;
}

/// Whether a point (board coordinates) touches the element; tol in board units.
bool hits(El e, Offset p, double tol) {
  if (isLinear(e)) {
    final pts = pointsOf(e);
    for (var i = 0; i + 1 < pts.length; i++) {
      if (_distToSegment(p, pts[i], pts[i + 1]) <= tol + _n(e['width'] ?? 2)) {
        return true;
      }
    }
    return pts.length == 1 && (pts.first - p).distance <= tol;
  }
  return boundsOf(e).inflate(tol).contains(p);
}

/// The front-most element at a point (frames only by their title strip).
El? elementAt(List<El> els, Offset p, double tol) {
  for (final e in els.reversed) {
    if (e['type'] == 'frame') {
      final b = boundsOf(e);
      if (Rect.fromLTWH(b.left, b.top, b.width, 28).inflate(tol).contains(p)) {
        return e;
      }
      continue;
    }
    if (hits(e, p, tol)) return e;
  }
  return null;
}

/// Elements back to front (by their fractional order, then id).
List<El> sorted(Iterable<El> els) => els.toList()
  ..sort((a, b) {
    final c = '${a['order'] ?? ''}'.compareTo('${b['order'] ?? ''}');
    return c != 0 ? c : '${a['id']}'.compareTo('${b['id']}');
  });

final _rnd = Random.secure();
String newElementId() =>
    'm${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}${_rnd.nextInt(1 << 30).toRadixString(36)}';

/// Drawing on a board: changes are applied at once and sent as element
/// operations (add, update with the changed fields, delete). Operations
/// waiting to be sent are kept per board on disk, so drawing works offline;
/// later changes to the same element are merged into one operation.
class BoardOps {
  BoardOps(this.file);

  final File file;
  List<Map<String, dynamic>> pending = [];

  Future<void> load() async {
    if (!await file.exists()) return;
    try {
      pending = (jsonDecode(await file.readAsString()) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      pending = [];
    }
  }

  Future<void> _save() async {
    if (pending.isEmpty) {
      if (await file.exists()) await file.delete();
      return;
    }
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(pending));
  }

  int _find(String id) => pending.indexWhere((o) => o['id'] == id);

  Future<void> add(El e) async {
    pending.add({'op': 'add', 'id': e['id'], 'element': e});
    await _save();
  }

  /// Records changed fields (null removes a field).
  Future<void> update(String id, Map<String, dynamic> fields) async {
    final i = _find(id);
    if (i >= 0 && pending[i]['op'] == 'add') {
      final el = Map<String, dynamic>.from(pending[i]['element'] as Map);
      fields.forEach((k, v) => v == null ? el.remove(k) : el[k] = v);
      pending[i] = {'op': 'add', 'id': id, 'element': el};
    } else if (i >= 0 && pending[i]['op'] == 'update') {
      pending[i] = {
        'op': 'update',
        'id': id,
        'element': {
          ...Map<String, dynamic>.from(pending[i]['element'] as Map),
          ...fields
        }
      };
    } else {
      pending.add({'op': 'update', 'id': id, 'element': fields});
    }
    await _save();
  }

  Future<void> delete(String id) async {
    final i = _find(id);
    final wasAdded = i >= 0 && pending[i]['op'] == 'add';
    pending.removeWhere((o) => o['id'] == id);
    if (!wasAdded) pending.add({'op': 'delete', 'id': id});
    await _save();
  }

  /// The server's elements with the waiting operations applied on top.
  List<El> apply(List<El> server) {
    final byId = {
      for (final e in server) '${e['id']}': Map<String, dynamic>.from(e)
    };
    for (final o in pending) {
      final id = '${o['id']}';
      switch (o['op']) {
        case 'add':
          byId[id] = Map<String, dynamic>.from(o['element'] as Map);
        case 'update':
          final cur = byId[id];
          if (cur != null) {
            (o['element'] as Map)
                .forEach((k, v) => v == null ? cur.remove(k) : cur[k] = v);
          }
        case 'delete':
          byId.remove(id);
      }
    }
    return sorted(byId.values);
  }

  /// Sends what waits; [send] posts the operations. Operations about
  /// elements others deleted meanwhile are dropped.
  Future<void> flush(Future<void> Function(List<Map<String, dynamic>> ops) send,
      Set<String> serverIds) async {
    if (pending.isEmpty) return;
    final ops = pending
        .where((o) => o['op'] == 'add' || serverIds.contains(o['id']))
        .toList();
    if (ops.isNotEmpty) await send(ops);
    pending = [];
    await _save();
  }
}
