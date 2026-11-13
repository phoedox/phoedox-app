import 'package:flutter/material.dart';

import 'scan_link.dart';

/// QR/NFC scanning. Camera and NFC plugins are added in the next step;
/// [parseScanLink] already decides which entry a scanned label opens.
class ScanPage extends StatelessWidget {
  const ScanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.qr_code_scanner, size: 64),
          const SizedBox(height: 12),
          Text('Etikett scannen', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text('QR-Code oder NFC-Tag an Dose oder Gerät'),
        ],
      ),
    );
  }
}
