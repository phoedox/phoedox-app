import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'session.dart';

/// Phoedox colours. The project primary colour can override [brand].
class PhxColors {
  static const brand = Color(0xFFF26A1B); // logo orange
  static const brandOnLight = Color(0xFFB84A0C); // >= 4.5:1 on white
}

/// The effective UI theme of the instance (GET /themes): colour tokens per
/// mode, fonts, corner radius and density – the same tokens the web app
/// uses, so a person's, project's, organization's or instance's theme looks
/// alike in the app.
class PhxThemeTokens {
  const PhxThemeTokens(
      {required this.light,
      required this.dark,
      this.bodyFont = '',
      this.displayFont = '',
      this.radius = 0,
      this.density = ''});

  final Map<String, Color> light;
  final Map<String, Color> dark;
  final String bodyFont;
  final String displayFont;
  final int radius;
  final String density;

  static Color? _color(Object? v) {
    if (v is! String || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(v)) return null;
    return Color(int.parse('FF${v.substring(1)}', radix: 16));
  }

  static Map<String, Color> _tokens(Object? defaults, Object? own) {
    final out = <String, Color>{};
    for (final m in [defaults, own]) {
      if (m is Map) {
        m.forEach((k, v) {
          final c = _color(v);
          if (k is String && c != null) out[k] = c;
        });
      }
    }
    return out;
  }

  /// Reads a theme catalog (GET /themes); null when the instance uses
  /// Phoedox's own look.
  static PhxThemeTokens? fromCatalog(Object? catalog) {
    if (catalog is! Map) return null;
    final theme = (catalog['effective'] as Map?)?['theme'];
    if (theme is! Map) return null;
    final data = theme['data'];
    if (data is! Map) return null;
    final defaults = catalog['defaults'] as Map? ?? const {};
    String family(Object? f) =>
        f is Map ? (f['family'] as String? ?? '').trim() : '';
    return PhxThemeTokens(
      light: _tokens(defaults['light'], data['light']),
      dark: _tokens(defaults['dark'], data['dark']),
      bodyFont: family(data['body']),
      displayFont: family(data['display']),
      radius: (data['radius'] as num?)?.toInt() ?? 0,
      density: data['density'] as String? ?? '',
    );
  }
}

ThemeData phxTheme(Brightness b,
    {Color seed = PhxColors.brand, PhxThemeTokens? tokens}) {
  final t = tokens == null
      ? null
      : (b == Brightness.dark ? tokens.dark : tokens.light);
  if (t == null || t['accent'] == null) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: b);
    return ThemeData(colorScheme: scheme, useMaterial3: true);
  }
  final base = ColorScheme.fromSeed(seedColor: t['accent']!, brightness: b);
  final fg = t['fg'] ?? base.onSurface;
  final scheme = base.copyWith(
    primary: t['accent'],
    onPrimary: t['on-color'],
    primaryContainer: t['accent-soft'],
    onPrimaryContainer: fg,
    secondary: t['accent'],
    onSecondary: t['on-color'],
    tertiary: t['good'],
    error: t['bad'],
    onError: t['on-color'],
    surface: t['surface'],
    onSurface: fg,
    onSurfaceVariant: t['muted'],
    surfaceContainerLowest: t['bg'],
    surfaceContainerLow: t['surface'],
    surfaceContainer: t['surface2'],
    surfaceContainerHigh: t['surface2'],
    surfaceContainerHighest: t['surface2'],
    outline: t['line'],
    outlineVariant: t['line'],
  );
  final r = tokens!.radius > 0 ? tokens.radius.toDouble() : null;
  final shape = r == null
      ? null
      : RoundedRectangleBorder(borderRadius: BorderRadius.circular(r));
  final density = switch (tokens.density) {
    'compact' => VisualDensity.compact,
    'comfortable' => VisualDensity.comfortable,
    _ => VisualDensity.standard,
  };
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: t['bg'],
    visualDensity: density,
    fontFamily: tokens.bodyFont.isEmpty ? null : tokens.bodyFont,
    cardTheme: shape == null ? null : CardThemeData(shape: shape),
    filledButtonTheme: shape == null
        ? null
        : FilledButtonThemeData(style: FilledButton.styleFrom(shape: shape)),
    outlinedButtonTheme: shape == null
        ? null
        : OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(shape: shape)),
    inputDecorationTheme: r == null
        ? null
        : InputDecorationTheme(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(r))),
  );
}

/// The theme outside projects (the person's, organization's or instance's;
/// cached for offline use). Null: Phoedox's own look.
final appThemeProvider = FutureProvider<PhxThemeTokens?>((ref) async {
  if (ref.watch(sessionProvider).value == null) return null;
  try {
    final r = await ref.watch(apiProvider('/themes').future);
    return PhxThemeTokens.fromCatalog(r.data);
  } catch (_) {
    return null;
  }
});

/// The theme inside a project (its own theme or what applies there).
final projectThemeProvider =
    FutureProvider.family<PhxThemeTokens?, String>((ref, project) async {
  try {
    final r = await ref.watch(
        apiProvider('/themes?project=${Uri.encodeQueryComponent(project)}')
            .future);
    return PhxThemeTokens.fromCatalog(r.data);
  } catch (_) {
    return null;
  }
});
