/// Turns Phoedox page extensions (ADR-0031) into plain Markdown for the
/// app's reader: callouts become quotes with a bold label, colored text and
/// underline lose their markers, dates show their text, special fences
/// become readable blocks. Code stays untouched.
String toPlainMarkdown(String md) {
  final out = <String>[];
  var inFence = false;
  for (final line in md.replaceAll('\r\n', '\n').split('\n')) {
    final fence = RegExp(r'^\s{0,3}(```|~~~)(\w*)').firstMatch(line);
    if (fence != null) {
      if (!inFence) {
        inFence = true;
        final lang = fence.group(2);
        if (lang == 'embed' || lang == 'iframe') {
          out.add('```');
          continue;
        }
        if (lang == 'board') {
          out.add('```');
          continue;
        }
      } else {
        inFence = false;
      }
      out.add(line);
      continue;
    }
    if (inFence) {
      out.add(line);
      continue;
    }
    final callout = RegExp(r'^> \[!([a-z]+)[^\]]*\]\s*$').firstMatch(line);
    if (callout != null) {
      final kind = callout.group(1)!;
      out.add('> **${kind[0].toUpperCase()}${kind.substring(1)}**');
      continue;
    }
    out.add(_inline(line));
  }
  return out.join('\n');
}

String _inline(String line) {
  final parts = <String>[];
  var last = 0;
  for (final m in RegExp(r'(`+)[^`]*?\1').allMatches(line)) {
    parts.add(_text(line.substring(last, m.start)));
    parts.add(m.group(0)!);
    last = m.end;
  }
  parts.add(_text(line.substring(last)));
  return parts.join();
}

String _text(String s) => s
    .replaceAllMapped(
        RegExp(
            r'\[((?:\\.|[^\]\\\n])+)\]\{(?:color|bg)=[a-z]+(?: (?:color|bg)=[a-z]+)?\}'),
        (m) => m.group(1)!)
    .replaceAllMapped(
        RegExp(r'\+\+(\S(?:[^+\n]*?\S)?)\+\+'), (m) => m.group(1)!)
    .replaceAllMapped(
        RegExp(
            r'<time datetime="[^"]*"(?: data-kind="[a-z]+")?>([^<]*)</time>'),
        (m) => m.group(1)!);
