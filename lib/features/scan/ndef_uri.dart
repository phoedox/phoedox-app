import 'dart:convert';
import 'dart:typed_data';

/// URI prefixes of NFC Forum URI records (code → prefix).
const _prefixes = [
  '',
  'http://www.',
  'https://www.',
  'http://',
  'https://',
  'tel:',
  'mailto:',
  'ftp://anonymous:anonymous@',
  'ftp://ftp.',
  'ftps://',
  'sftp://',
  'smb://',
  'nfs://',
  'ftp://',
  'dav://',
  'news:',
  'telnet://',
  'imap:',
  'rtsp://',
  'urn:',
  'pop:',
  'sip:',
  'sips:',
  'tftp:',
  'btspp://',
  'btl2cap://',
  'btgoep://',
  'tcpobex://',
  'irdaobex://',
  'file://',
  'urn:epc:id:',
  'urn:epc:tag:',
  'urn:epc:pat:',
  'urn:epc:raw:',
  'urn:epc:',
  'urn:nfc:',
];

/// Reads a URI (well-known "U"), text (well-known "T") or absolute-URI record.
/// [tnf] is the type name format: 1 = well-known, 3 = absolute URI.
String? readNdefUri(int tnf, Uint8List type, Uint8List payload) {
  if (payload.isEmpty && tnf != 3) return null;
  if (tnf == 1 && type.length == 1 && type[0] == 0x55) {
    final code = payload[0];
    final prefix = code < _prefixes.length ? _prefixes[code] : '';
    return prefix + utf8.decode(payload.sublist(1), allowMalformed: true);
  }
  if (tnf == 1 && type.length == 1 && type[0] == 0x54) {
    // Text: status byte (bit 7 = UTF-16, bits 0-5 = language length), language, text.
    final status = payload[0];
    final start = 1 + (status & 0x3f);
    if (start > payload.length) return null;
    final body = payload.sublist(start);
    return (status & 0x80) != 0
        ? String.fromCharCodes(Uint16List.view(Uint8List.fromList(body).buffer))
        : utf8.decode(body, allowMalformed: true);
  }
  if (tnf == 3) return utf8.decode(type, allowMalformed: true);
  return null;
}

/// A URI record for writing: type "U" and the payload with the shortest prefix code.
({Uint8List type, Uint8List payload}) ndefUriRecord(String uri) {
  var code = 0;
  for (var i = 1; i < _prefixes.length; i++) {
    if (uri.startsWith(_prefixes[i]) &&
        _prefixes[i].length > _prefixes[code].length) {
      code = i;
    }
  }
  final rest = utf8.encode(uri.substring(_prefixes[code].length));
  return (
    type: Uint8List.fromList([0x55]),
    payload: Uint8List.fromList([code, ...rest])
  );
}
