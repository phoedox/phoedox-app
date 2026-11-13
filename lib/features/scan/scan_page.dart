import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../app/session.dart';
import '../../l10n/gen/app_localizations.dart';
import '../entity/entity_page.dart';
import 'scan_link.dart';

/// Scans a QR label (`https://<instance>/e/<project>/<slug>` or `phx://e/…`) and
/// opens the entry. Without a camera, a link can be typed in.
class ScanPage extends ConsumerStatefulWidget {
  const ScanPage({super.key});

  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<ScanPage> {
  final _manual = TextEditingController();
  String? _message;
  bool _opening = false;

  void _handle(String raw) {
    if (_opening) return;
    final t = AppLocalizations.of(context);
    final link = parseScanLink(raw);
    final session = ref.read(sessionProvider).value;
    if (link == null) {
      setState(() => _message = t.scanUnknown);
      return;
    }
    if (link.instance != null &&
        session != null &&
        link.instance != session.base.host) {
      setState(() => _message = t.scanOtherInstance(link.instance!));
      return;
    }
    _opening = true;
    Navigator.of(context)
        .push(MaterialPageRoute(
            builder: (_) =>
                EntityPage(project: link.project, entity: link.slug)))
        .then((_) => _opening = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(t.scanTitle, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(t.scanHint),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 1,
            child: MobileScanner(
              onDetect: (capture) {
                for (final b in capture.barcodes) {
                  final v = b.rawValue;
                  if (v != null) {
                    _handle(v);
                    break;
                  }
                }
              },
              errorBuilder: (context, error) =>
                  Center(child: Text(error.errorDetails?.message ?? t.error)),
            ),
          ),
        ),
        if (_message != null) ...[
          const SizedBox(height: 12),
          Text(_message!,
              style: TextStyle(color: Theme.of(context).colorScheme.error))
        ],
        const SizedBox(height: 16),
        TextField(
          controller: _manual,
          decoration: InputDecoration(
              labelText: t.scanManual, hintText: 'phx://e/haus/router-flur'),
          onSubmitted: _handle,
        ),
      ],
    );
  }
}
