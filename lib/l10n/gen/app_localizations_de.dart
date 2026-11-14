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

  @override
  String get edit => 'Bearbeiten';

  @override
  String get save => 'Speichern';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get discard => 'Verwerfen';

  @override
  String get editHint =>
      'Markdown. Geht auch offline: Die Änderung bleibt auf dem Gerät und wird beim Senden mit Änderungen auf dem Server zusammengeführt.';

  @override
  String get editDiscard => 'Änderungen verwerfen?';

  @override
  String get editSynced => 'Gespeichert.';

  @override
  String get editMerged =>
      'Gespeichert und mit Änderungen auf dem Server zusammengeführt.';

  @override
  String get editQueued =>
      'Auf dem Gerät gespeichert – wird gesendet, sobald eine Verbindung besteht.';

  @override
  String get pendingNote => 'Auf diesem Gerät geändert – noch nicht gesendet.';

  @override
  String pendingRefused(String key) {
    return 'Der Server hat die Änderung abgelehnt ($key).';
  }

  @override
  String get syncNow => 'Jetzt senden';

  @override
  String get syncOffline =>
      'Weiter offline – Änderungen bleiben auf dem Gerät.';

  @override
  String syncFailed(int count) {
    return '$count Änderungen wurden abgelehnt.';
  }

  @override
  String syncDone(int count) {
    return '$count Änderungen gesendet.';
  }

  @override
  String get nameplateAction => 'Typenschild fotografieren';

  @override
  String get nameplateReading => 'Typenschild wird hochgeladen und gelesen …';

  @override
  String get nameplateOffline =>
      'Braucht eine Verbindung – das Foto wurde nicht gespeichert.';

  @override
  String get nameplateNothing =>
      'Foto gespeichert. Keine Werte erkannt (ist die Texterkennung auf dem Server an?).';

  @override
  String get nameplateFound => 'Auf dem Typenschild gefunden';

  @override
  String nameplateReplaces(String value) {
    return 'ersetzt $value';
  }

  @override
  String nameplateSaved(int count) {
    return '$count Werte gespeichert.';
  }

  @override
  String get nfcRead => 'NFC-Tag lesen';

  @override
  String get nfcWrite => 'NFC-Tag beschreiben';

  @override
  String get nfcHold => 'Tag ans Telefon halten.';

  @override
  String get nfcUnavailable => 'NFC ist nicht verfügbar oder ausgeschaltet.';

  @override
  String get nfcWritten => 'Tag beschrieben.';

  @override
  String get nfcReadonly => 'Der Tag ist schreibgeschützt.';

  @override
  String get nfcWriteFailed => 'Der Tag konnte nicht beschrieben werden.';

  @override
  String get play => 'Abspielen';

  @override
  String get pause => 'Pause';

  @override
  String get voiceNotes => 'Sprachnotizen';

  @override
  String get voiceNone => 'Noch keine Sprachnotizen.';

  @override
  String get voiceRecord => 'Sprachnotiz aufnehmen';

  @override
  String get voiceMicTitle => 'Mikrofon';

  @override
  String get voiceMicRationale =>
      'Phoedox braucht das Mikrofon nur, während du eine Sprachnotiz aufnimmst. Die Aufnahme wird an diesen Eintrag angehängt.';

  @override
  String get voiceMicDenied =>
      'Kein Zugriff auf das Mikrofon. Erlaube ihn in den Systemeinstellungen.';

  @override
  String get voiceRecordFailed => 'Aufnahme nicht möglich.';

  @override
  String get voiceRecording => 'Aufnahme läuft';

  @override
  String voiceLimit(int minutes) {
    return 'Höchstens $minutes Minuten; die Aufnahme endet dann von selbst.';
  }

  @override
  String get voiceStop => 'Stopp';

  @override
  String get voiceSent => 'Sprachnotiz angehängt.';

  @override
  String get voiceQueued =>
      'Sprachnotiz auf dem Gerät gespeichert – wird gesendet, sobald eine Verbindung besteht.';

  @override
  String get notSentYet => 'Noch nicht gesendet';

  @override
  String uploadRefused(String key) {
    return 'Der Server hat die Datei abgelehnt ($key).';
  }

  @override
  String get loadFailed => 'Konnte nicht geladen werden.';

  @override
  String get planPhoto => 'Foto platzieren';

  @override
  String get planPhotoTap =>
      'Tippe auf die Stelle im Plan, an der du das Foto aufgenommen hast.';

  @override
  String get planPhotoCaption => 'Beschriftung';

  @override
  String get planPhotoDraft =>
      'Foto im Entwurf des Plans gespeichert. Es erscheint im Plan, sobald jemand den Entwurf in der Web-App veröffentlicht.';

  @override
  String get planPhotoQueued =>
      'Foto auf dem Gerät gespeichert – es kommt in den Entwurf des Plans, sobald eine Verbindung besteht.';

  @override
  String get planPhotoDone => 'Foto im Plan gespeichert.';

  @override
  String planPhotosPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Fotos noch nicht im Entwurf',
      one: '1 Foto noch nicht im Entwurf',
    );
    return '$_temp0';
  }

  @override
  String get planDraftNote =>
      'Neue Fotos landen im Entwurf des Plans und erscheinen hier erst nach dem Veröffentlichen.';

  @override
  String get voiceMicContinue => 'Weiter';
}
