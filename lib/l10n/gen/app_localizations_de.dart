// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get projects => 'Projekte';

  @override
  String get scan => 'Scannen';

  @override
  String get signInTitle => 'Mit Phoedox verbinden';

  @override
  String get signInHint =>
      'Adresse deiner Instanz und ein API-Token aus Einstellungen → API-Tokens & MCP.';

  @override
  String get instance => 'Adresse der Instanz';

  @override
  String get token => 'API-Token';

  @override
  String get connect => 'Verbinden';

  @override
  String get signOut => 'Abmelden';

  @override
  String get signInFailed =>
      'Verbindung fehlgeschlagen. Prüfe Adresse und Token.';

  @override
  String get offline => 'Offline – zuletzt geladener Stand';

  @override
  String get notCached => 'Offline und noch nicht geladen.';

  @override
  String get noProjects => 'Keine Projekte.';

  @override
  String get search => 'Suchen';

  @override
  String get noResults => 'Nichts gefunden.';

  @override
  String get uncategorized => 'Ohne Kategorie';

  @override
  String get decisions => 'Entscheidungen';

  @override
  String get openLink => 'Link öffnen';

  @override
  String get context => 'Kontext';

  @override
  String get decision => 'Entscheidung';

  @override
  String get consequences => 'Folgen';

  @override
  String get alternatives => 'Alternativen';

  @override
  String get attributes => 'Attribute';

  @override
  String get relations => 'Beziehungen';

  @override
  String get mentionedIn => 'Erwähnt in';

  @override
  String get scanTitle => 'Etikett scannen';

  @override
  String get scanHint => 'QR-Code an Dose oder Gerät in den Rahmen halten.';

  @override
  String get scanManual => 'Link oder Kurzname eingeben';

  @override
  String get scanUnknown => 'Kein Phoedox-Etikett.';

  @override
  String scanOtherInstance(String host) {
    return 'Dieses Etikett gehört zu $host.';
  }

  @override
  String get open => 'Öffnen';

  @override
  String get retry => 'Erneut versuchen';

  @override
  String get error => 'Etwas ist schiefgegangen.';
}
