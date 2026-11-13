// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get projects => 'Projects';

  @override
  String get scan => 'Scan';

  @override
  String get signInTitle => 'Connect to Phoedox';

  @override
  String get signInHint =>
      'Address of your instance and an API token from Settings → API tokens & MCP.';

  @override
  String get instance => 'Instance address';

  @override
  String get token => 'API token';

  @override
  String get connect => 'Connect';

  @override
  String get signOut => 'Sign out';

  @override
  String get signInFailed => 'Could not connect. Check address and token.';

  @override
  String get offline => 'Offline – last loaded state';

  @override
  String get notCached => 'Offline and not loaded yet.';

  @override
  String get noProjects => 'No projects.';

  @override
  String get search => 'Search';

  @override
  String get noResults => 'Nothing found.';

  @override
  String get uncategorized => 'No category';

  @override
  String get decisions => 'Decisions';

  @override
  String get openLink => 'Open link';

  @override
  String get context => 'Context';

  @override
  String get decision => 'Decision';

  @override
  String get consequences => 'Consequences';

  @override
  String get alternatives => 'Alternatives';

  @override
  String get attributes => 'Attributes';

  @override
  String get relations => 'Relations';

  @override
  String get mentionedIn => 'Mentioned in';

  @override
  String get scanTitle => 'Scan a label';

  @override
  String get scanHint => 'Hold the QR code on a socket or device in the frame.';

  @override
  String get scanManual => 'Enter a link or short name';

  @override
  String get scanUnknown => 'Not a Phoedox label.';

  @override
  String scanOtherInstance(String host) {
    return 'This label belongs to $host.';
  }

  @override
  String get open => 'Open';

  @override
  String get retry => 'Try again';

  @override
  String get error => 'Something went wrong.';
}
