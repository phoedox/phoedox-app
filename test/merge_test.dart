import 'package:flutter_test/flutter_test.dart';
import 'package:phoedox/sync/merge.dart';

void main() {
  test('offline edit and server change both survive (yrs)', () {
    const base = '# Router\n\nSteht im Flur.\n\nPort 4 ist frei.\n';
    const mine = '# Router\n\nSteht im Flur, oben links.\n\nPort 4 ist frei.\n';
    const theirs = '# Router\n\nSteht im Flur.\n\nPort 4 und 5 sind frei.\n';
    expect(merge3(base, mine, theirs),
        '# Router\n\nSteht im Flur, oben links.\n\nPort 4 und 5 sind frei.\n');
    expect(merge3('Küche', 'Küche 🍳', 'Große Küche'), 'Große Küche 🍳');
  });

  test('one side unchanged', () {
    expect(merge3('a', 'a', 'b'), 'b');
    expect(merge3('a', 'c', 'a'), 'c');
  });
}
