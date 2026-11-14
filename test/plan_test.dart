import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:phoedox/features/floorplan/floorplan_view.dart';
import 'package:phoedox/features/floorplan/plan.dart';

Map<String, dynamic> plan() => {
      'width': 10000,
      'height': 5000,
      'rooms': [
        {
          'id': 'r1',
          'name': 'Flat',
          'points': [
            [0, 0],
            [10000, 0],
            [10000, 5000],
            [0, 5000]
          ]
        },
        {
          'id': 'r2',
          'name': 'Kitchen',
          'entity': 'kitchen',
          'points': [
            [0, 0],
            [4000, 0],
            [4000, 5000],
            [0, 5000]
          ]
        },
      ],
      'devices': [
        {'id': 'd1', 'entity': 'router', 'x': 2000, 'y': 1000}
      ],
      'walls': [
        {
          'id': 'w1',
          'a': [0, 0],
          'b': [10000, 0],
          'thickness': 120
        }
      ],
    };

void main() {
  test('a tap maps to plan millimetres and back', () {
    // 10 m × 5 m in a 520 × 400 view with 10 px padding: 0.05 px/mm,
    // centred vertically (plan 250 px high → 75 px above).
    final tf =
        PlanTransform(planBounds(plan()), const Size(520, 400), padding: 10);
    expect(tf.scale, closeTo(0.05, 1e-9));
    expect(tf.toView(Offset.zero), const Offset(10, 75));
    expect(tf.toPlan(const Offset(10, 75)), Offset.zero);
    expect(tf.toPlan(const Offset(110, 125)), const Offset(2000, 1000));
    expect(tf.toPlan(const Offset(110.01, 125.02)), const Offset(2000, 1000));
    expect(tf.contains(const Offset(110, 125)), isTrue);
    expect(tf.contains(const Offset(5, 20)), isFalse);
  });

  test('bounds grow to items outside the drawing area', () {
    final p = plan()
      ..['photos'] = [
        {'id': 'p1', 'file': 'f', 'x': -500, 'y': 6000}
      ];
    expect(planBounds(p), const Rect.fromLTRB(-500, 0, 10000, 6000));
    expect(planBounds({}), const Rect.fromLTWH(0, 0, 20000, 15000));
  });

  test('the smallest room wins where rooms overlap', () {
    expect(roomAt(plan(), const Offset(1000, 1000))!['name'], 'Kitchen');
    expect(roomAt(plan(), const Offset(8000, 1000))!['name'], 'Flat');
    expect(roomAt(plan(), const Offset(12000, 1000)), isNull);
  });

  test('withPhoto adds the photo and keeps the rest of the plan', () {
    final before = plan();
    final after = withPhoto(before,
        id: 'phabc',
        file: '01JFILE',
        x: 1234.4,
        y: 99.6,
        caption: ' Fuse box ');
    expect(after['rooms'], before['rooms']);
    expect(after['devices'], before['devices']);
    expect(after['walls'], before['walls']);
    expect(after['width'], 10000);
    expect(after['photos'], [
      {
        'id': 'phabc',
        'file': '01JFILE',
        'x': 1234.0,
        'y': 100.0,
        'caption': 'Fuse box'
      }
    ]);
    expect(before.containsKey('photos'), isFalse, reason: 'input unchanged');
  });

  test('withPhoto is idempotent and avoids id clashes', () {
    final once = withPhoto(plan(), id: 'ph1', file: 'F', x: 1, y: 2);
    expect(identical(withPhoto(once, id: 'ph1', file: 'F', x: 1, y: 2), once),
        isTrue);
    // "d1" is a device: the photo gets a fresh id.
    final clash =
        withPhoto(plan(), id: 'd1', file: 'F', x: 1, y: 2, random: Random(1));
    final id = (clash['photos'] as List).single['id'] as String;
    expect(id, isNot('d1'));
    expect(planIdPattern.hasMatch(id), isTrue);
    expect(id, startsWith('ph'));
    expect((clash['photos'] as List).single.containsKey('caption'), isFalse);
  });

  test('new plan ids are valid and unused', () {
    final taken = planIds(plan());
    expect(taken, {'r1', 'r2', 'd1', 'w1'});
    for (var i = 0; i < 50; i++) {
      final id = newPlanId('ph', taken);
      expect(planIdPattern.hasMatch(id), isTrue);
      expect(taken.contains(id), isFalse);
    }
  });

  test('taps find the nearest device or photo', () {
    final p = withPhoto(plan(), id: 'ph1', file: 'F', x: 2400, y: 1000);
    final tf = PlanTransform(planBounds(p), const Size(520, 400), padding: 10);
    // Device at 110,125 px, photo at 130,125 px.
    expect(hitItem(p, tf, const Offset(112, 126))!.$1, 'device');
    expect(hitItem(p, tf, const Offset(128, 125))!.$1, 'photo');
    expect(hitItem(p, tf, const Offset(400, 300)), isNull);
  });
}
