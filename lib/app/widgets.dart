import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/client.dart';
import '../l10n/gen/app_localizations.dart';
import 'session.dart';

/// Loads an API path and shows loading, error, offline note and the data.
class ApiView extends ConsumerWidget {
  const ApiView({super.key, required this.path, required this.builder});

  final String path;
  final Widget Function(BuildContext context, dynamic data) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final v = ref.watch(apiProvider(path));
    return v.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                  e is OfflineException
                      ? LucideIcons.wifiOff
                      : LucideIcons.circleAlert,
                  size: 40),
              const SizedBox(height: 12),
              Text(e is OfflineException ? t.notCached : t.error,
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
                  onPressed: () => ref.invalidate(apiProvider(path)),
                  child: Text(t.retry)),
            ],
          ),
        ),
      ),
      data: (r) => Column(
        children: [
          if (r.offline)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(children: [
                const Icon(LucideIcons.wifiOff, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(t.offline))
              ]),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(apiProvider(path).future),
              child: builder(context, r.data),
            ),
          ),
        ],
      ),
    );
  }
}

/// Parses "#F26A1B".
Color hexColor(String? hex, Color fallback) {
  if (hex == null || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)) {
    return fallback;
  }
  return Color(int.parse('FF${hex.substring(1)}', radix: 16));
}
