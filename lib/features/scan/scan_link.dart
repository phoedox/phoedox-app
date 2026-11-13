/// A scanned Phoedox label: `https://<instance>/e/<project>/<slug>` or `phx://e/<project>/<slug>`.
class ScanLink {
  const ScanLink(
      {required this.instance, required this.project, required this.slug});

  final String? instance;
  final String project;
  final String slug;
}

final _slug = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');

/// Parses a QR/NFC payload. Returns null for anything that is not a Phoedox label.
ScanLink? parseScanLink(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null) return null;
  final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  List<String> rest;
  String? instance;
  if (uri.scheme == 'phx' && uri.host == 'e') {
    rest = segs;
  } else if ((uri.scheme == 'https' || uri.scheme == 'http') &&
      segs.isNotEmpty &&
      segs.first == 'e') {
    instance = uri.host;
    rest = segs.sublist(1);
  } else {
    return null;
  }
  if (rest.length != 2 ||
      !_slug.hasMatch(rest[0]) ||
      !_slug.hasMatch(rest[1])) {
    return null;
  }
  return ScanLink(instance: instance, project: rest[0], slug: rest[1]);
}
