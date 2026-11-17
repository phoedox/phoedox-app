// Blocks from the knowledge graph (tree, rack, floor plan excerpt): the same
// source format as the web (web/src/blocks/{tree,rackblock,floorplanblock}.ts).
// Parsing and layout only, no widgets.

import 'interactive.dart' show blockLines, keyValue;

final _slug = RegExp(r'^@?([a-z0-9]+(?:-[a-z0-9]+)*)$');

class TreeSpec {
  TreeSpec(this.root, this.relation, this.direction, this.depth, this.title);
  final String root, relation, direction, title;
  final int depth;

  static TreeSpec parse(String src) {
    var root = '', rel = '', dir = 'in', title = '';
    var depth = 4;
    for (final l in blockLines(src)) {
      final kv = keyValue(l, [
        'root', 'wurzel', 'relation', 'beziehung', 'direction', 'richtung', //
        'depth', 'tiefe', 'title', 'titel'
      ]);
      if (kv == null) {
        final s = _slug.firstMatch(l);
        if (s != null && root.isEmpty) {
          root = s[1]!;
          continue;
        }
        throw const FormatException('tree.err_line');
      }
      switch (kv.$1) {
        case 'root' || 'wurzel':
          final s = _slug.firstMatch(kv.$2);
          if (s == null) throw const FormatException('tree.err_root');
          root = s[1]!;
        case 'relation' || 'beziehung':
          rel = kv.$2;
        case 'direction' || 'richtung':
          if (RegExp(r'^(in|ein|eingehend|up)$', caseSensitive: false)
              .hasMatch(kv.$2)) {
            dir = 'in';
          } else if (RegExp(r'^(out|aus|ausgehend|down)$', caseSensitive: false)
              .hasMatch(kv.$2)) {
            dir = 'out';
          } else {
            throw const FormatException('tree.err_direction');
          }
        case 'depth' || 'tiefe':
          depth = (int.tryParse(kv.$2) ?? 4).clamp(1, 8);
        default:
          title = kv.$2;
      }
    }
    if (root.isEmpty) throw const FormatException('tree.err_root');
    return TreeSpec(root, rel, dir, depth, title);
  }
}

class TreeNode {
  TreeNode(this.id, this.slug, this.name, this.kind);
  final String id, slug, name, kind;
  final children = <TreeNode>[];
}

/// Builds the tree from traverse hops (each knows the entry it came from).
TreeNode buildTree(Map<String, dynamic> root, List<Map<String, dynamic>> hops) {
  TreeNode node(Map e) => TreeNode('${e['id']}', '${e['slug']}',
      '${e['name'] ?? e['slug']}', '${e['kind'] ?? ''}');
  final top = node(root);
  final byId = {top.id: top};
  for (final h in hops) {
    final n = node(h['entity'] as Map);
    byId[n.id] = n;
  }
  for (final h in hops) {
    (byId['${h['parent'] ?? ''}'] ?? top)
        .children
        .add(byId['${(h['entity'] as Map)['id']}']!);
  }
  void sort(TreeNode n) {
    n.children.sort((a, b) => a.name.compareTo(b.name));
    n.children.forEach(sort);
  }

  sort(top);
  return top;
}

class TreeBox {
  TreeBox(this.node, this.y, this.parent);
  final TreeNode node;
  double x = 0;
  final double y;
  final TreeBox? parent;
  static const w = 150.0, h = 44.0;
}

/// Top-down layout: leaves side by side, parents centred over their children.
({List<TreeBox> boxes, double width, double height}) layoutTree(TreeNode root) {
  const gapX = 16.0, gapY = 46.0;
  final boxes = <TreeBox>[];
  var next = 0.0;
  var maxDepth = 0;
  TreeBox place(TreeNode n, int depth, TreeBox? parent) {
    if (depth > maxDepth) maxDepth = depth;
    final b = TreeBox(n, depth * (TreeBox.h + gapY), parent);
    boxes.add(b);
    if (n.children.isEmpty) {
      b.x = next;
      next += TreeBox.w + gapX;
    } else {
      final kids = [for (final c in n.children) place(c, depth + 1, b)];
      b.x = (kids.first.x + kids.last.x) / 2;
    }
    return b;
  }

  place(root, 0, null);
  return (
    boxes: boxes,
    width: next - gapX < TreeBox.w ? TreeBox.w : next - gapX,
    height: (maxDepth + 1) * (TreeBox.h + gapY) - gapY,
  );
}

class RackSpec {
  RackSpec(this.rack, this.title);
  final String rack, title;

  static RackSpec parse(String src) {
    var rack = '', title = '';
    for (final l in blockLines(src)) {
      final kv = keyValue(l, ['rack', 'title', 'titel']);
      if (kv != null && kv.$1 != 'rack') {
        title = kv.$2;
        continue;
      }
      final s = _slug.firstMatch((kv?.$2 ?? l).trim());
      if (s == null || rack.isNotEmpty) {
        throw const FormatException('rack.err_line');
      }
      rack = s[1]!;
    }
    if (rack.isEmpty) throw const FormatException('rack.err_missing');
    return RackSpec(rack, title);
  }
}

class Mounted {
  Mounted(this.slug, this.name, this.u, this.height);
  final String slug, name;
  final int? u;
  final int height;
}

class RackSlot {
  RackSlot(this.top, this.bottom, [this.device, this.conflict = false]);
  final int top, bottom;
  final Mounted? device;
  final bool conflict;
}

/// Units from top to bottom with the devices in them (web/src/rack.ts).
({List<RackSlot> slots, List<Mounted> unplaced, Set<String> conflicts})
    rackSlots(int units, List<Mounted> devices) {
  final placed = devices
      .where((d) => d.u != null && d.u! >= 1 && d.u! + d.height - 1 <= units)
      .toList()
    ..sort((a, b) => b.u!.compareTo(a.u!));
  final unplaced = devices.where((d) => !placed.contains(d)).toList();
  final taken = <int, Mounted>{};
  final conflicts = <String>{};
  for (final d in placed) {
    for (var u = d.u!; u < d.u! + d.height; u++) {
      final other = taken[u];
      if (other != null) {
        conflicts
          ..add(d.slug)
          ..add(other.slug);
      } else {
        taken[u] = d;
      }
    }
  }
  final slots = <RackSlot>[];
  for (var u = units; u >= 1;) {
    final d = taken[u];
    if (d != null) {
      final bottom = d.u! > u - d.height + 1 ? d.u! : u - d.height + 1;
      slots.add(RackSlot(u, bottom, d, conflicts.contains(d.slug)));
      u = bottom - 1;
    } else {
      slots.add(RackSlot(u, u));
      u--;
    }
  }
  return (slots: slots, unplaced: unplaced, conflicts: conflicts);
}

class PlanSpec {
  PlanSpec(this.plan, this.room, this.title, this.devices);
  final String plan, room, title;
  final bool devices;

  static PlanSpec parse(String src) {
    var plan = '', room = '', title = '';
    var devices = true;
    final doc = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');
    for (final l in blockLines(src)) {
      final kv = keyValue(l, [
        'plan', 'grundriss', 'room', 'raum', 'title', 'titel', 'devices', //
        'geraete'
      ]);
      if (kv == null) {
        if (doc.hasMatch(l) && plan.isEmpty) {
          plan = l;
          continue;
        }
        throw const FormatException('floorplan.err_line');
      }
      switch (kv.$1) {
        case 'plan' || 'grundriss':
          if (!doc.hasMatch(kv.$2)) {
            throw const FormatException('floorplan.err_plan');
          }
          plan = kv.$2;
        case 'room' || 'raum':
          room = kv.$2;
        case 'devices' || 'geraete':
          devices =
              !RegExp(r'^(no|nein|false|off|0|aus)$', caseSensitive: false)
                  .hasMatch(kv.$2);
        default:
          title = kv.$2;
      }
    }
    if (plan.isEmpty) throw const FormatException('floorplan.err_plan');
    return PlanSpec(plan, room, title, devices);
  }
}

/// The room a block names (by name, case-insensitive, or by its entry).
Map<String, dynamic>? findRoom(List<Map<String, dynamic>> rooms, String name) {
  final n = name.trim().toLowerCase().replaceFirst('@', '');
  for (final r in rooms) {
    if ('${r['name'] ?? ''}'.toLowerCase() == n) return r;
  }
  for (final r in rooms) {
    if (r['entity'] == n) return r;
  }
  return null;
}
