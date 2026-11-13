import 'package:flutter_test/flutter_test.dart';
import 'package:phoedox/features/scan/scan_link.dart';

void main() {
  test('parses https labels', () {
    final l = parseScanLink('https://app.phoedox.com/e/lindenstrasse/lan-az-1');
    expect(l?.instance, 'app.phoedox.com');
    expect(l?.project, 'lindenstrasse');
    expect(l?.slug, 'lan-az-1');
  });
  test('parses phx labels', () {
    expect(parseScanLink('phx://e/homelab/pve-01')?.slug, 'pve-01');
  });
  test('rejects other codes', () {
    expect(parseScanLink('https://example.com/menu'), isNull);
    expect(parseScanLink('phx://e/only-one'), isNull);
    expect(parseScanLink('WIFI:S:Gast;P:secret;;'), isNull);
  });
}
