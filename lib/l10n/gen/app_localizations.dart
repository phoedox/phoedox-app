import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en')
  ];

  /// No description provided for @projects.
  ///
  /// In de, this message translates to:
  /// **'Projekte'**
  String get projects;

  /// No description provided for @scan.
  ///
  /// In de, this message translates to:
  /// **'Scannen'**
  String get scan;

  /// No description provided for @signInTitle.
  ///
  /// In de, this message translates to:
  /// **'Mit Phoedox verbinden'**
  String get signInTitle;

  /// No description provided for @signInHint.
  ///
  /// In de, this message translates to:
  /// **'Adresse deiner Instanz und ein API-Token aus Einstellungen → API-Tokens & MCP.'**
  String get signInHint;

  /// No description provided for @instance.
  ///
  /// In de, this message translates to:
  /// **'Adresse der Instanz'**
  String get instance;

  /// No description provided for @token.
  ///
  /// In de, this message translates to:
  /// **'API-Token'**
  String get token;

  /// No description provided for @connect.
  ///
  /// In de, this message translates to:
  /// **'Verbinden'**
  String get connect;

  /// No description provided for @signOut.
  ///
  /// In de, this message translates to:
  /// **'Abmelden'**
  String get signOut;

  /// No description provided for @signInFailed.
  ///
  /// In de, this message translates to:
  /// **'Verbindung fehlgeschlagen. Prüfe Adresse und Token.'**
  String get signInFailed;

  /// No description provided for @offline.
  ///
  /// In de, this message translates to:
  /// **'Offline – zuletzt geladener Stand'**
  String get offline;

  /// No description provided for @notCached.
  ///
  /// In de, this message translates to:
  /// **'Offline und noch nicht geladen.'**
  String get notCached;

  /// No description provided for @noProjects.
  ///
  /// In de, this message translates to:
  /// **'Keine Projekte.'**
  String get noProjects;

  /// No description provided for @search.
  ///
  /// In de, this message translates to:
  /// **'Suchen'**
  String get search;

  /// No description provided for @noResults.
  ///
  /// In de, this message translates to:
  /// **'Nichts gefunden.'**
  String get noResults;

  /// No description provided for @uncategorized.
  ///
  /// In de, this message translates to:
  /// **'Ohne Kategorie'**
  String get uncategorized;

  /// No description provided for @decisions.
  ///
  /// In de, this message translates to:
  /// **'Entscheidungen'**
  String get decisions;

  /// No description provided for @openLink.
  ///
  /// In de, this message translates to:
  /// **'Link öffnen'**
  String get openLink;

  /// No description provided for @context.
  ///
  /// In de, this message translates to:
  /// **'Kontext'**
  String get context;

  /// No description provided for @decision.
  ///
  /// In de, this message translates to:
  /// **'Entscheidung'**
  String get decision;

  /// No description provided for @consequences.
  ///
  /// In de, this message translates to:
  /// **'Folgen'**
  String get consequences;

  /// No description provided for @alternatives.
  ///
  /// In de, this message translates to:
  /// **'Alternativen'**
  String get alternatives;

  /// No description provided for @attributes.
  ///
  /// In de, this message translates to:
  /// **'Attribute'**
  String get attributes;

  /// No description provided for @relations.
  ///
  /// In de, this message translates to:
  /// **'Beziehungen'**
  String get relations;

  /// No description provided for @mentionedIn.
  ///
  /// In de, this message translates to:
  /// **'Erwähnt in'**
  String get mentionedIn;

  /// No description provided for @scanTitle.
  ///
  /// In de, this message translates to:
  /// **'Etikett scannen'**
  String get scanTitle;

  /// No description provided for @scanHint.
  ///
  /// In de, this message translates to:
  /// **'QR-Code an Dose oder Gerät in den Rahmen halten.'**
  String get scanHint;

  /// No description provided for @scanManual.
  ///
  /// In de, this message translates to:
  /// **'Link oder Kurzname eingeben'**
  String get scanManual;

  /// No description provided for @scanUnknown.
  ///
  /// In de, this message translates to:
  /// **'Kein Phoedox-Etikett.'**
  String get scanUnknown;

  /// No description provided for @scanOtherInstance.
  ///
  /// In de, this message translates to:
  /// **'Dieses Etikett gehört zu {host}.'**
  String scanOtherInstance(String host);

  /// No description provided for @open.
  ///
  /// In de, this message translates to:
  /// **'Öffnen'**
  String get open;

  /// No description provided for @retry.
  ///
  /// In de, this message translates to:
  /// **'Erneut versuchen'**
  String get retry;

  /// No description provided for @error.
  ///
  /// In de, this message translates to:
  /// **'Etwas ist schiefgegangen.'**
  String get error;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
