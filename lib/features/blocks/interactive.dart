// Helpers for block sources and the state key of a block. The interactive
// blocks (poll, decision matrix, calculator, quiz) are plugins (ADR-0087).

/// Lines of a block: trimmed, without empty lines and # comments.
List<String> blockLines(String src) => [
      for (final l in src.replaceAll('\r\n', '\n').split('\n'))
        if (l.trim().isNotEmpty && !l.trim().startsWith('#')) l.trim()
    ];

/// "key: value" at the start of a line, for known keys only.
(String, String)? keyValue(String line, List<String> keys) {
  final m = RegExp(r'^([A-Za-z]+)\s*:\s*(.*)$').firstMatch(line);
  if (m == null || !keys.contains(m[1]!.toLowerCase())) return null;
  return (m[1]!.toLowerCase(), m[2]!.trim());
}

/// The state key of a block: its own id, else a hash of its source (FNV-1a
/// over UTF-16 code units, like hashText in web/src/blocks/registry.ts).
String blockKey(String source, [String? id]) {
  if (id != null && RegExp(r'^[A-Za-z0-9-]{1,40}$').hasMatch(id)) return id;
  var h = 2166136261;
  for (final c in source.trim().codeUnits) {
    h = ((h ^ c) * 16777619) & 0xFFFFFFFF;
  }
  return 'h${h.toRadixString(36)}';
}
