import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:phoedox/features/whiteboard/board.dart';

void main() {
  test('operations merge, survive a restart and apply on the server board',
      () async {
    final dir = await Directory.systemTemp.createTemp('phx');
    final file = File('${dir.path}/b.json');
    final server = <El>[
      {
        'id': 'a',
        'type': 'rect',
        'x': 0,
        'y': 0,
        'w': 10,
        'h': 10,
        'order': 'a'
      },
      {
        'id': 'b',
        'type': 'text',
        'x': 50,
        'y': 50,
        'w': 40,
        'h': 20,
        'order': 'b',
        'text': 'hi'
      },
    ];
    final ops = BoardOps(file);
    await ops.add({
      'id': 'n',
      'type': 'sticky',
      'x': 5,
      'y': 5,
      'w': 20,
      'h': 20,
      'order': 'c'
    });
    await ops.update('n', {'text': 'note'});
    await ops.update('a', {'x': 3});
    await ops.update('a', {'y': 4});
    await ops.update('b', {'text': null});
    // An add followed by updates stays one add; updates of one element merge.
    expect(ops.pending.map((o) => o['op']), ['add', 'update', 'update']);
    expect(ops.pending[0]['element']['text'], 'note');
    expect(ops.pending[1]['element'], {'x': 3, 'y': 4});

    final again = BoardOps(file);
    await again.load();
    final els = again.apply(server);
    expect(els.map((e) => e['id']), ['a', 'b', 'n']);
    expect((els[0]['x'], els[0]['y']), (3, 4));
    expect(els[1].containsKey('text'), isFalse);
    expect(server[0]['x'], 0, reason: 'the server list is not changed');

    // Deleting a new element drops it entirely; deleting an old one is sent.
    await again.delete('n');
    await again.delete('b');
    expect(again.pending.map((o) => '${o['op']}:${o['id']}'),
        ['update:a', 'delete:b']);

    // Others deleted "a" meanwhile: its update is not sent.
    List<Map<String, dynamic>>? sent;
    await again.flush((list) async => sent = list, {'b'});
    expect(sent!.map((o) => o['id']), ['b']);
    expect(again.pending, isEmpty);
    expect(await file.exists(), isFalse);
  });

  test('hit tests find the front-most element', () {
    final els = sorted([
      {
        'id': 'f',
        'type': 'frame',
        'x': 0,
        'y': 0,
        'w': 400,
        'h': 300,
        'order': 'a'
      },
      {
        'id': 'r',
        'type': 'rect',
        'x': 100,
        'y': 100,
        'w': 50,
        'h': 50,
        'order': 'c'
      },
      {
        'id': 'p',
        'type': 'pen',
        'order': 'b',
        'points': [
          [0, 200],
          [200, 200]
        ]
      },
    ]);
    expect(elementAt(els, const Offset(120, 120), 2)?['id'], 'r');
    expect(elementAt(els, const Offset(80, 201), 2)?['id'], 'p');
    // Frames are hit by their title strip only.
    expect(elementAt(els, const Offset(300, 10), 2)?['id'], 'f');
    expect(elementAt(els, const Offset(300, 250), 2), isNull);
    expect(boundsOf(els[1]), const Rect.fromLTRB(0, 200, 200, 200));
  });
}
