import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phoedox/app/theme.dart';

void main() {
  test('tokens of the effective theme become the colour scheme', () {
    final catalog = {
      'defaults': {
        'light': {
          'bg': '#f6f4f2',
          'surface': '#ffffff',
          'fg': '#1f1a17',
          'accent': '#b84a0c',
          'on-color': '#ffffff',
          'line': '#ddd5ce'
        },
        'dark': {
          'bg': '#14110f',
          'surface': '#1c1815',
          'fg': '#eee7e1',
          'accent': '#f26a1b',
          'on-color': '#ffffff'
        },
      },
      'effective': {
        'source': 'project',
        'theme': {
          'data': {
            'light': {'accent': '#1d4ed8', 'bad': 'nope'},
            'dark': {},
            'body': {'family': 'Inter'},
            'radius': 4,
            'density': 'compact',
          }
        }
      }
    };
    final t = PhxThemeTokens.fromCatalog(catalog)!;
    expect(t.light['accent'], const Color(0xFF1D4ED8));
    expect(t.light['bg'], const Color(0xFFF6F4F2)); // default kept
    expect(t.light.containsKey('bad'), isFalse); // invalid colours ignored
    final light = phxTheme(Brightness.light, tokens: t);
    expect(light.colorScheme.primary, const Color(0xFF1D4ED8));
    expect(light.scaffoldBackgroundColor, const Color(0xFFF6F4F2));
    expect(light.visualDensity, VisualDensity.compact);
    expect(light.textTheme.bodyMedium?.fontFamily, 'Inter');
    final dark = phxTheme(Brightness.dark, tokens: t);
    expect(dark.colorScheme.primary, const Color(0xFFF26A1B));
  });

  test("without a theme Phoedox's own look stays", () {
    expect(
        PhxThemeTokens.fromCatalog({
          'effective': {'theme': null}
        }),
        isNull);
    expect(phxTheme(Brightness.light).colorScheme.brightness, Brightness.light);
  });
}
