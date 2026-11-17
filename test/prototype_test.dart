import 'package:flutter_test/flutter_test.dart';
import 'package:phoedox/features/whiteboard/prototype_page.dart';

void main() {
  test('the prototypes of a board are read from its content', () {
    expect(
        prototypesOf({
          'content': {
            'prototypes': [
              {'id': 'p1', 'name': 'Checkout'},
              {'id': 'p2'},
              'junk'
            ]
          }
        }),
        [('p1', 'Checkout'), ('p2', 'p2')]);
    expect(prototypesOf({'content': {}}), isEmpty);
    expect(prototypesOf({}), isEmpty);
  });
}
