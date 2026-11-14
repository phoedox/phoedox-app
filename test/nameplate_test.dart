import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:phoedox/features/entity/nameplate.dart';
import 'package:phoedox/features/scan/ndef_uri.dart';
import 'package:phoedox/features/scan/scan_link.dart';

void main() {
  test('type plate text becomes attributes', () {
    const ocr = '''
AVM FRITZ!Box 7590
Hersteller: AVM GmbH
Modell: FRITZ!Box 7590
S/N: J251.123.45.678.901
CWMP-Account: 00040E-123456789
MAC LAN 3C:A6:2F:12:34:56
12V ⎓ 2.0A  24W
''';
    final a = parseNameplate(ocr);
    expect(a['manufacturer'], 'AVM GmbH');
    expect(a['model'], 'FRITZ!Box 7590');
    expect(a['serial'], 'J251.123.45.678.901');
    expect(a['mac'], '3C:A6:2F:12:34:56');
    expect(a['power'], '24W');
    expect(a['voltage'], '12V');
  });

  test('labels in other spellings; nothing guessed', () {
    final a = parseNameplate(
        'Type: DS920+\nSerial No. 2040ABC123\nP/N: 9001-22\nMAC 001132ABCDEF');
    expect(a, {
      'model': 'DS920+',
      'serial': '2040ABC123',
      'part_number': '9001-22',
      'mac': '00:11:32:AB:CD:EF'
    });
    expect(parseNameplate('Made in Germany\n0123456789AB'), isEmpty);
  });

  test('NDEF URI records round-trip and become scan links', () {
    const url = 'https://app.phoedox.com/e/haus/router-flur';
    final r = ndefUriRecord(url);
    expect(r.payload.first, 4); // https://
    expect(utf8.decode(r.payload.sublist(1)),
        'app.phoedox.com/e/haus/router-flur');
    final back = readNdefUri(1, r.type, r.payload)!;
    expect(back, url);
    expect(parseScanLink(back)?.slug, 'router-flur');
    expect(
        readNdefUri(1, Uint8List.fromList([0x55]),
            Uint8List.fromList([0, ...utf8.encode('phx://e/haus/nas')])),
        'phx://e/haus/nas');
    // Text record "en" + link.
    final text = Uint8List.fromList(
        [2, ...utf8.encode('en'), ...utf8.encode('phx://e/haus/nas')]);
    expect(
        readNdefUri(1, Uint8List.fromList([0x54]), text), 'phx://e/haus/nas');
    expect(readNdefUri(2, Uint8List.fromList([1]), Uint8List.fromList([1])),
        isNull);
  });
}
