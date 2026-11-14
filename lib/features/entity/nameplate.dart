/// Values read from a type plate photo (OCR text), as entry attributes.
/// Only clearly labelled values are taken; nothing is guessed.
Map<String, String> parseNameplate(String text) {
  final out = <String, String>{};
  final rules = <String, RegExp>{
    'serial': RegExp(
        r'^(?:s\s*/\s*n|sn|ser(?:ial)?(?:\s*(?:no|nr|number|-?nr))?\.?|seriennummer|serien-?nr\.?)\s*[:.#]?\s*([A-Z0-9][A-Z0-9\-/.]{2,})',
        caseSensitive: false),
    'model': RegExp(
        r'^(?:model(?:l)?(?:\s*(?:no|nr)\.?)?|mod\.?|type|typ)\s*[:.#]?\s*([A-Za-z0-9][\w\-/.!+ ]{1,40})',
        caseSensitive: false),
    'manufacturer': RegExp(
        r'^(?:manufacturer|hersteller|mfr|mfg)\.?\s*[:.]?\s*(.{2,60})',
        caseSensitive: false),
    'part_number': RegExp(
        r'^(?:p\s*/\s*n|part\s*(?:no|nr|number)|art\.?\s*-?\s*nr\.?|artikelnummer)\s*[:.#]?\s*([A-Z0-9][A-Z0-9\-/.]{2,})',
        caseSensitive: false),
    'mac': RegExp(r'\b((?:[0-9A-F]{2}[:-]){5}[0-9A-F]{2}|[0-9A-F]{12})\b',
        caseSensitive: false),
    'power': RegExp(r'\b(\d{1,4}(?:[.,]\d+)?\s?W)\b'),
    'voltage': RegExp(
        r'\b(\d{1,3}(?:[.,]\d+)?\s?(?:-\s?\d{1,3}\s?)?V(?:\s?(?:AC|DC))?)\b'),
  };
  for (final raw in text.split(RegExp(r'\r?\n'))) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    for (final r in rules.entries) {
      if (out.containsKey(r.key)) continue;
      final m = r.value.firstMatch(line);
      if (m == null) continue;
      var v = m.group(1)!.trim();
      // A MAC only counts on a line that says so, or in its usual colon form.
      if (r.key == 'mac' &&
          !RegExp(r'mac|lan|wlan|ethernet', caseSensitive: false)
              .hasMatch(line) &&
          !v.contains(RegExp('[:-]'))) {
        continue;
      }
      if (r.key == 'mac') v = _mac(v);
      out[r.key] = v;
    }
  }
  return out;
}

String _mac(String v) {
  final hex = v.replaceAll(RegExp('[:-]'), '').toUpperCase();
  return [for (var i = 0; i < 12; i += 2) hex.substring(i, i + 2)].join(':');
}
