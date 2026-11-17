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
  /// **'Adresse deiner Instanz, z. B. app.phoedox.com.'**
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

  /// No description provided for @edit.
  ///
  /// In de, this message translates to:
  /// **'Bearbeiten'**
  String get edit;

  /// No description provided for @save.
  ///
  /// In de, this message translates to:
  /// **'Speichern'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In de, this message translates to:
  /// **'Abbrechen'**
  String get cancel;

  /// No description provided for @discard.
  ///
  /// In de, this message translates to:
  /// **'Verwerfen'**
  String get discard;

  /// No description provided for @editHint.
  ///
  /// In de, this message translates to:
  /// **'Markdown. Geht auch offline: Die Änderung bleibt auf dem Gerät und wird beim Senden mit Änderungen auf dem Server zusammengeführt.'**
  String get editHint;

  /// No description provided for @editDiscard.
  ///
  /// In de, this message translates to:
  /// **'Änderungen verwerfen?'**
  String get editDiscard;

  /// No description provided for @editSynced.
  ///
  /// In de, this message translates to:
  /// **'Gespeichert.'**
  String get editSynced;

  /// No description provided for @editMerged.
  ///
  /// In de, this message translates to:
  /// **'Gespeichert und mit Änderungen auf dem Server zusammengeführt.'**
  String get editMerged;

  /// No description provided for @editQueued.
  ///
  /// In de, this message translates to:
  /// **'Auf dem Gerät gespeichert – wird gesendet, sobald eine Verbindung besteht.'**
  String get editQueued;

  /// No description provided for @pendingNote.
  ///
  /// In de, this message translates to:
  /// **'Auf diesem Gerät geändert – noch nicht gesendet.'**
  String get pendingNote;

  /// No description provided for @pendingRefused.
  ///
  /// In de, this message translates to:
  /// **'Der Server hat die Änderung abgelehnt ({key}).'**
  String pendingRefused(String key);

  /// No description provided for @syncNow.
  ///
  /// In de, this message translates to:
  /// **'Jetzt senden'**
  String get syncNow;

  /// No description provided for @syncOffline.
  ///
  /// In de, this message translates to:
  /// **'Weiter offline – Änderungen bleiben auf dem Gerät.'**
  String get syncOffline;

  /// No description provided for @syncFailed.
  ///
  /// In de, this message translates to:
  /// **'{count} Änderungen wurden abgelehnt.'**
  String syncFailed(int count);

  /// No description provided for @syncDone.
  ///
  /// In de, this message translates to:
  /// **'{count} Änderungen gesendet.'**
  String syncDone(int count);

  /// No description provided for @nameplateAction.
  ///
  /// In de, this message translates to:
  /// **'Typenschild fotografieren'**
  String get nameplateAction;

  /// No description provided for @nameplateReading.
  ///
  /// In de, this message translates to:
  /// **'Typenschild wird hochgeladen und gelesen …'**
  String get nameplateReading;

  /// No description provided for @nameplateOffline.
  ///
  /// In de, this message translates to:
  /// **'Braucht eine Verbindung – das Foto wurde nicht gespeichert.'**
  String get nameplateOffline;

  /// No description provided for @nameplateNothing.
  ///
  /// In de, this message translates to:
  /// **'Foto gespeichert. Keine Werte erkannt (ist die Texterkennung auf dem Server an?).'**
  String get nameplateNothing;

  /// No description provided for @nameplateFound.
  ///
  /// In de, this message translates to:
  /// **'Auf dem Typenschild gefunden'**
  String get nameplateFound;

  /// No description provided for @nameplateReplaces.
  ///
  /// In de, this message translates to:
  /// **'ersetzt {value}'**
  String nameplateReplaces(String value);

  /// No description provided for @nameplateSaved.
  ///
  /// In de, this message translates to:
  /// **'{count} Werte gespeichert.'**
  String nameplateSaved(int count);

  /// No description provided for @nfcRead.
  ///
  /// In de, this message translates to:
  /// **'NFC-Tag lesen'**
  String get nfcRead;

  /// No description provided for @nfcWrite.
  ///
  /// In de, this message translates to:
  /// **'NFC-Tag beschreiben'**
  String get nfcWrite;

  /// No description provided for @nfcHold.
  ///
  /// In de, this message translates to:
  /// **'Tag ans Telefon halten.'**
  String get nfcHold;

  /// No description provided for @nfcUnavailable.
  ///
  /// In de, this message translates to:
  /// **'NFC ist nicht verfügbar oder ausgeschaltet.'**
  String get nfcUnavailable;

  /// No description provided for @nfcWritten.
  ///
  /// In de, this message translates to:
  /// **'Tag beschrieben.'**
  String get nfcWritten;

  /// No description provided for @nfcReadonly.
  ///
  /// In de, this message translates to:
  /// **'Der Tag ist schreibgeschützt.'**
  String get nfcReadonly;

  /// No description provided for @nfcWriteFailed.
  ///
  /// In de, this message translates to:
  /// **'Der Tag konnte nicht beschrieben werden.'**
  String get nfcWriteFailed;

  /// No description provided for @play.
  ///
  /// In de, this message translates to:
  /// **'Abspielen'**
  String get play;

  /// No description provided for @pause.
  ///
  /// In de, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @voiceNotes.
  ///
  /// In de, this message translates to:
  /// **'Sprachnotizen'**
  String get voiceNotes;

  /// No description provided for @voiceNone.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Sprachnotizen.'**
  String get voiceNone;

  /// No description provided for @voiceRecord.
  ///
  /// In de, this message translates to:
  /// **'Sprachnotiz aufnehmen'**
  String get voiceRecord;

  /// No description provided for @voiceMicTitle.
  ///
  /// In de, this message translates to:
  /// **'Mikrofon'**
  String get voiceMicTitle;

  /// No description provided for @voiceMicRationale.
  ///
  /// In de, this message translates to:
  /// **'Phoedox braucht das Mikrofon nur, während du eine Sprachnotiz aufnimmst. Die Aufnahme wird an diesen Eintrag angehängt.'**
  String get voiceMicRationale;

  /// No description provided for @voiceMicDenied.
  ///
  /// In de, this message translates to:
  /// **'Kein Zugriff auf das Mikrofon. Erlaube ihn in den Systemeinstellungen.'**
  String get voiceMicDenied;

  /// No description provided for @voiceRecordFailed.
  ///
  /// In de, this message translates to:
  /// **'Aufnahme nicht möglich.'**
  String get voiceRecordFailed;

  /// No description provided for @voiceRecording.
  ///
  /// In de, this message translates to:
  /// **'Aufnahme läuft'**
  String get voiceRecording;

  /// No description provided for @voiceLimit.
  ///
  /// In de, this message translates to:
  /// **'Höchstens {minutes} Minuten; die Aufnahme endet dann von selbst.'**
  String voiceLimit(int minutes);

  /// No description provided for @voiceStop.
  ///
  /// In de, this message translates to:
  /// **'Stopp'**
  String get voiceStop;

  /// No description provided for @voiceSent.
  ///
  /// In de, this message translates to:
  /// **'Sprachnotiz angehängt.'**
  String get voiceSent;

  /// No description provided for @voiceQueued.
  ///
  /// In de, this message translates to:
  /// **'Sprachnotiz auf dem Gerät gespeichert – wird gesendet, sobald eine Verbindung besteht.'**
  String get voiceQueued;

  /// No description provided for @notSentYet.
  ///
  /// In de, this message translates to:
  /// **'Noch nicht gesendet'**
  String get notSentYet;

  /// No description provided for @uploadRefused.
  ///
  /// In de, this message translates to:
  /// **'Der Server hat die Datei abgelehnt ({key}).'**
  String uploadRefused(String key);

  /// No description provided for @loadFailed.
  ///
  /// In de, this message translates to:
  /// **'Konnte nicht geladen werden.'**
  String get loadFailed;

  /// No description provided for @planPhoto.
  ///
  /// In de, this message translates to:
  /// **'Foto platzieren'**
  String get planPhoto;

  /// No description provided for @planPhotoTap.
  ///
  /// In de, this message translates to:
  /// **'Tippe auf die Stelle im Plan, an der du das Foto aufgenommen hast.'**
  String get planPhotoTap;

  /// No description provided for @planPhotoCaption.
  ///
  /// In de, this message translates to:
  /// **'Beschriftung'**
  String get planPhotoCaption;

  /// No description provided for @planPhotoDraft.
  ///
  /// In de, this message translates to:
  /// **'Foto im Entwurf des Plans gespeichert. Es erscheint im Plan, sobald jemand den Entwurf in der Web-App veröffentlicht.'**
  String get planPhotoDraft;

  /// No description provided for @planPhotoQueued.
  ///
  /// In de, this message translates to:
  /// **'Foto auf dem Gerät gespeichert – es kommt in den Entwurf des Plans, sobald eine Verbindung besteht.'**
  String get planPhotoQueued;

  /// No description provided for @planPhotoDone.
  ///
  /// In de, this message translates to:
  /// **'Foto im Plan gespeichert.'**
  String get planPhotoDone;

  /// No description provided for @planPhotosPending.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Foto noch nicht im Entwurf} other{{count} Fotos noch nicht im Entwurf}}'**
  String planPhotosPending(int count);

  /// No description provided for @planDraftNote.
  ///
  /// In de, this message translates to:
  /// **'Neue Fotos landen im Entwurf des Plans und erscheinen hier erst nach dem Veröffentlichen.'**
  String get planDraftNote;

  /// No description provided for @voiceMicContinue.
  ///
  /// In de, this message translates to:
  /// **'Weiter'**
  String get voiceMicContinue;

  /// No description provided for @signInBrowser.
  ///
  /// In de, this message translates to:
  /// **'Im Browser anmelden'**
  String get signInBrowser;

  /// No description provided for @signInBrowserHint.
  ///
  /// In de, this message translates to:
  /// **'Du meldest dich auf der Seite deiner Instanz an (auch mit Passkey oder SSO) und erlaubst der App den Zugriff. Sie bekommt ein eigenes Token, das du unter API-Tokens widerrufen kannst.'**
  String get signInBrowserHint;

  /// No description provided for @signInWithToken.
  ///
  /// In de, this message translates to:
  /// **'Stattdessen mit API-Token verbinden'**
  String get signInWithToken;

  /// No description provided for @appAccessTitle.
  ///
  /// In de, this message translates to:
  /// **'Diese App bittet um Zugriff'**
  String get appAccessTitle;

  /// No description provided for @appLevel1.
  ///
  /// In de, this message translates to:
  /// **'Sie möchte die Projektdaten lesen, die ihr Autor angegeben hat (z. B. Einträge oder ein Board). Deine Anmeldung sieht sie nie.'**
  String get appLevel1;

  /// No description provided for @appLevel2.
  ///
  /// In de, this message translates to:
  /// **'Sie möchte die angegebenen Projektdaten lesen und eigene Daten speichern (gemeinsam oder nur für dich).'**
  String get appLevel2;

  /// No description provided for @appLevel3.
  ///
  /// In de, this message translates to:
  /// **'Sie möchte Projektdaten lesen, eigene Daten speichern und Änderungen vorschlagen – jede Änderung fragt dich vorher.'**
  String get appLevel3;

  /// No description provided for @appAllow.
  ///
  /// In de, this message translates to:
  /// **'Erlauben'**
  String get appAllow;

  /// No description provided for @appNotNow.
  ///
  /// In de, this message translates to:
  /// **'Nicht jetzt'**
  String get appNotNow;

  /// No description provided for @appProposeTitle.
  ///
  /// In de, this message translates to:
  /// **'Die App schlägt eine Änderung vor'**
  String get appProposeTitle;

  /// No description provided for @appProposeTask.
  ///
  /// In de, this message translates to:
  /// **'Neue Karte „{title}“ auf Board {board}.'**
  String appProposeTask(Object board, Object title);

  /// No description provided for @appProposeComment.
  ///
  /// In de, this message translates to:
  /// **'Kommentar zu {document}: {body}'**
  String appProposeComment(Object body, Object document);

  /// No description provided for @appProposeEntity.
  ///
  /// In de, this message translates to:
  /// **'Neuer Eintrag „{name}“ ({kind}).'**
  String appProposeEntity(Object kind, Object name);

  /// No description provided for @appConfirm.
  ///
  /// In de, this message translates to:
  /// **'Übernehmen'**
  String get appConfirm;

  /// No description provided for @appOffline.
  ///
  /// In de, this message translates to:
  /// **'Diese App wurde auf diesem Gerät noch nicht geöffnet; beim ersten Mal braucht sie das Netz.'**
  String get appOffline;

  /// No description provided for @appUnavailable.
  ///
  /// In de, this message translates to:
  /// **'Die App lässt sich nicht öffnen (ausgeschaltet oder kein Zugriff).'**
  String get appUnavailable;

  /// No description provided for @appOfflineNote.
  ///
  /// In de, this message translates to:
  /// **'Offline: Du siehst die App wie zuletzt geladen; ihre Speicheränderungen werden später gesendet.'**
  String get appOfflineNote;

  /// No description provided for @wbText.
  ///
  /// In de, this message translates to:
  /// **'Text'**
  String get wbText;

  /// No description provided for @wbOffline.
  ///
  /// In de, this message translates to:
  /// **'Offline: Deine Änderungen an der Tafel werden gesendet, sobald wieder Netz da ist.'**
  String get wbOffline;

  /// No description provided for @wbSending.
  ///
  /// In de, this message translates to:
  /// **'Änderungen werden gesendet …'**
  String get wbSending;

  /// No description provided for @wbHand.
  ///
  /// In de, this message translates to:
  /// **'Verschieben und zoomen'**
  String get wbHand;

  /// No description provided for @wbSelect.
  ///
  /// In de, this message translates to:
  /// **'Auswählen und bewegen (lange drücken: Text ändern)'**
  String get wbSelect;

  /// No description provided for @wbPen.
  ///
  /// In de, this message translates to:
  /// **'Stift'**
  String get wbPen;

  /// No description provided for @wbRect.
  ///
  /// In de, this message translates to:
  /// **'Rechteck'**
  String get wbRect;

  /// No description provided for @wbEllipse.
  ///
  /// In de, this message translates to:
  /// **'Ellipse'**
  String get wbEllipse;

  /// No description provided for @wbArrow.
  ///
  /// In de, this message translates to:
  /// **'Pfeil'**
  String get wbArrow;

  /// No description provided for @wbSticky.
  ///
  /// In de, this message translates to:
  /// **'Haftnotiz'**
  String get wbSticky;

  /// No description provided for @wbTextTool.
  ///
  /// In de, this message translates to:
  /// **'Text'**
  String get wbTextTool;

  /// No description provided for @wbEraser.
  ///
  /// In de, this message translates to:
  /// **'Radierer'**
  String get wbEraser;

  /// No description provided for @protoPlay.
  ///
  /// In de, this message translates to:
  /// **'Abspielen'**
  String get protoPlay;

  /// No description provided for @protoOffline.
  ///
  /// In de, this message translates to:
  /// **'Dieser Prototyp wurde auf diesem Gerät noch nicht abgespielt; beim ersten Mal braucht er das Netz.'**
  String get protoOffline;

  /// No description provided for @protoUnavailable.
  ///
  /// In de, this message translates to:
  /// **'Der Prototyp lässt sich nicht öffnen.'**
  String get protoUnavailable;

  /// No description provided for @protoOfflineNote.
  ///
  /// In de, this message translates to:
  /// **'Offline: Du spielst den Prototyp, wie er zuletzt geladen wurde.'**
  String get protoOfflineNote;

  /// No description provided for @appDeviceCamera.
  ///
  /// In de, this message translates to:
  /// **'die Kamera'**
  String get appDeviceCamera;

  /// No description provided for @appDeviceMicrophone.
  ///
  /// In de, this message translates to:
  /// **'das Mikrofon'**
  String get appDeviceMicrophone;

  /// No description provided for @appDeviceLocation.
  ///
  /// In de, this message translates to:
  /// **'deinen Standort'**
  String get appDeviceLocation;

  /// No description provided for @appDeviceMotion.
  ///
  /// In de, this message translates to:
  /// **'die Bewegungssensoren'**
  String get appDeviceMotion;

  /// No description provided for @appDeviceTitle.
  ///
  /// In de, this message translates to:
  /// **'Darf diese App {what} verwenden?'**
  String appDeviceTitle(String what);

  /// No description provided for @appDeviceBody.
  ///
  /// In de, this message translates to:
  /// **'Nur diese App, nur für dich. Du kannst es später in den Berechtigungen der App in Phoedox ändern; dein Telefon fragt eventuell zusätzlich.'**
  String get appDeviceBody;

  /// No description provided for @appDeviceDeny.
  ///
  /// In de, this message translates to:
  /// **'Nicht erlauben'**
  String get appDeviceDeny;

  /// No description provided for @appDownloadTitle.
  ///
  /// In de, this message translates to:
  /// **'Datei aus der App speichern?'**
  String get appDownloadTitle;

  /// No description provided for @appDownloadBody.
  ///
  /// In de, this message translates to:
  /// **'Die App gibt dir „{name}“ ({kb} KB).'**
  String appDownloadBody(String name, int kb);

  /// No description provided for @appDownloadSave.
  ///
  /// In de, this message translates to:
  /// **'Speichern oder teilen'**
  String get appDownloadSave;

  /// No description provided for @appSelfSaveTitle.
  ///
  /// In de, this message translates to:
  /// **'Änderungen der App speichern?'**
  String get appSelfSaveTitle;

  /// No description provided for @appSelfSaveBody.
  ///
  /// In de, this message translates to:
  /// **'Die App möchte ihre eigenen Dateien ändern ({files}). Das ergibt eine neue Version für alle.'**
  String appSelfSaveBody(String files);

  /// No description provided for @appSelfSaveConfirm.
  ///
  /// In de, this message translates to:
  /// **'Neue Version speichern'**
  String get appSelfSaveConfirm;

  /// No description provided for @blockOffline.
  ///
  /// In de, this message translates to:
  /// **'Ohne Verbindung nicht möglich. Versuche es gleich noch einmal.'**
  String get blockOffline;

  /// No description provided for @blockSaveFailed.
  ///
  /// In de, this message translates to:
  /// **'Das konnte nicht gespeichert werden.'**
  String get blockSaveFailed;

  /// No description provided for @pollClosed.
  ///
  /// In de, this message translates to:
  /// **'Abgeschlossen'**
  String get pollClosed;

  /// No description provided for @pollVoters.
  ///
  /// In de, this message translates to:
  /// **'{n, plural, =0{Noch keine Stimmen} =1{1 Person hat abgestimmt} other{{n} Personen haben abgestimmt}}'**
  String pollVoters(int n);

  /// No description provided for @pollChooseOne.
  ///
  /// In de, this message translates to:
  /// **'Wähle eine Antwort'**
  String get pollChooseOne;

  /// No description provided for @pollChooseMany.
  ///
  /// In de, this message translates to:
  /// **'Wähle eine oder mehrere Antworten'**
  String get pollChooseMany;

  /// No description provided for @pollUndo.
  ///
  /// In de, this message translates to:
  /// **'Stimme zurückziehen'**
  String get pollUndo;

  /// No description provided for @matrixOption.
  ///
  /// In de, this message translates to:
  /// **'Option'**
  String get matrixOption;

  /// No description provided for @matrixTotal.
  ///
  /// In de, this message translates to:
  /// **'Gesamt'**
  String get matrixTotal;

  /// No description provided for @matrixTune.
  ///
  /// In de, this message translates to:
  /// **'Gewichte ausprobieren'**
  String get matrixTune;

  /// No description provided for @matrixTuneDone.
  ///
  /// In de, this message translates to:
  /// **'Fertig'**
  String get matrixTuneDone;

  /// No description provided for @matrixReset.
  ///
  /// In de, this message translates to:
  /// **'Zurücksetzen'**
  String get matrixReset;

  /// No description provided for @matrixNotSaved.
  ///
  /// In de, this message translates to:
  /// **'Nur für dich, wird nicht gespeichert.'**
  String get matrixNotSaved;

  /// No description provided for @matrixWeightLess.
  ///
  /// In de, this message translates to:
  /// **'Gewicht von {name} verringern'**
  String matrixWeightLess(String name);

  /// No description provided for @matrixWeightMore.
  ///
  /// In de, this message translates to:
  /// **'Gewicht von {name} erhöhen'**
  String matrixWeightMore(String name);

  /// No description provided for @matrixToDecision.
  ///
  /// In de, this message translates to:
  /// **'Als offene Entscheidung anlegen'**
  String get matrixToDecision;

  /// No description provided for @matrixDecisionTitle.
  ///
  /// In de, this message translates to:
  /// **'Entscheidung'**
  String get matrixDecisionTitle;

  /// No description provided for @matrixDecisionContext.
  ///
  /// In de, this message translates to:
  /// **'Angelegt aus einer Entscheidungsmatrix; die Bewertungen stehen bei den Optionen.'**
  String get matrixDecisionContext;

  /// No description provided for @matrixDecisionMade.
  ///
  /// In de, this message translates to:
  /// **'Offene Entscheidung angelegt'**
  String get matrixDecisionMade;

  /// No description provided for @matrixDecisionFailed.
  ///
  /// In de, this message translates to:
  /// **'Die Entscheidung konnte nicht angelegt werden.'**
  String get matrixDecisionFailed;

  /// No description provided for @calcReset.
  ///
  /// In de, this message translates to:
  /// **'Zurücksetzen'**
  String get calcReset;

  /// No description provided for @calcNotSaved.
  ///
  /// In de, this message translates to:
  /// **'Deine Eingaben werden nicht gespeichert.'**
  String get calcNotSaved;

  /// No description provided for @quizScore.
  ///
  /// In de, this message translates to:
  /// **'{right} von {all} richtig'**
  String quizScore(int right, int all);

  /// No description provided for @quizAgain.
  ///
  /// In de, this message translates to:
  /// **'Nochmal'**
  String get quizAgain;

  /// No description provided for @quizShow.
  ///
  /// In de, this message translates to:
  /// **'Antwort zeigen'**
  String get quizShow;

  /// No description provided for @quizKnew.
  ///
  /// In de, this message translates to:
  /// **'Gewusst'**
  String get quizKnew;

  /// No description provided for @quizMissed.
  ///
  /// In de, this message translates to:
  /// **'Nicht gewusst'**
  String get quizMissed;

  /// No description provided for @quizRight.
  ///
  /// In de, this message translates to:
  /// **'richtig'**
  String get quizRight;

  /// No description provided for @quizWrong.
  ///
  /// In de, this message translates to:
  /// **'falsch'**
  String get quizWrong;

  /// No description provided for @mindmapExpandAll.
  ///
  /// In de, this message translates to:
  /// **'Alles aufklappen'**
  String get mindmapExpandAll;

  /// No description provided for @ganttDone.
  ///
  /// In de, this message translates to:
  /// **'erledigt'**
  String get ganttDone;

  /// No description provided for @ganttToday.
  ///
  /// In de, this message translates to:
  /// **'heute'**
  String get ganttToday;

  /// No description provided for @beforeAfterBefore.
  ///
  /// In de, this message translates to:
  /// **'Vorher'**
  String get beforeAfterBefore;

  /// No description provided for @beforeAfterAfter.
  ///
  /// In de, this message translates to:
  /// **'Nachher'**
  String get beforeAfterAfter;

  /// No description provided for @beforeAfterMissing.
  ///
  /// In de, this message translates to:
  /// **'Es fehlen noch Fotos.'**
  String get beforeAfterMissing;

  /// No description provided for @beforeAfterValue.
  ///
  /// In de, this message translates to:
  /// **'{n} % {before}'**
  String beforeAfterValue(int n, String before);

  /// No description provided for @annotateNoImage.
  ///
  /// In de, this message translates to:
  /// **'Noch kein Bild.'**
  String get annotateNoImage;

  /// No description provided for @statusOk.
  ///
  /// In de, this message translates to:
  /// **'In Ordnung'**
  String get statusOk;

  /// No description provided for @statusWarn.
  ///
  /// In de, this message translates to:
  /// **'Warnung'**
  String get statusWarn;

  /// No description provided for @statusDown.
  ///
  /// In de, this message translates to:
  /// **'Gestört'**
  String get statusDown;

  /// No description provided for @blockLoadFailed.
  ///
  /// In de, this message translates to:
  /// **'Konnte nicht geladen werden.'**
  String get blockLoadFailed;

  /// No description provided for @treeMissing.
  ///
  /// In de, this message translates to:
  /// **'Den Eintrag „{root}“ gibt es nicht.'**
  String treeMissing(String root);

  /// No description provided for @treeEmpty.
  ///
  /// In de, this message translates to:
  /// **'Nichts hängt über „{relation}“ an der Wurzel. Stimmen Beziehung und Richtung?'**
  String treeEmpty(String relation);

  /// No description provided for @rackMissing.
  ///
  /// In de, this message translates to:
  /// **'Den Eintrag „{rack}“ gibt es nicht.'**
  String rackMissing(String rack);

  /// No description provided for @rackUnits.
  ///
  /// In de, this message translates to:
  /// **'{units} HE'**
  String rackUnits(int units);

  /// No description provided for @rackConflict.
  ///
  /// In de, this message translates to:
  /// **'Zwei Geräte belegen dieselben Höheneinheiten.'**
  String get rackConflict;

  /// No description provided for @rackUnplaced.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Gerät ohne Position} other{{count} Geräte ohne Position}}'**
  String rackUnplaced(int count);

  /// No description provided for @rackEmpty.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Geräte in diesem Schrank.'**
  String get rackEmpty;

  /// No description provided for @floorplanMissing.
  ///
  /// In de, this message translates to:
  /// **'Den Grundriss „{plan}“ gibt es nicht.'**
  String floorplanMissing(String plan);

  /// No description provided for @floorplanNoRoom.
  ///
  /// In de, this message translates to:
  /// **'Im Grundriss „{plan}“ gibt es keinen Raum „{room}“.'**
  String floorplanNoRoom(String room, String plan);
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
