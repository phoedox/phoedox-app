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
  String get signInHint => 'Adresse deiner Instanz, z. B. app.phoedox.com.';

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

  @override
  String get signInBrowser => 'Im Browser anmelden';

  @override
  String get signInBrowserHint =>
      'Du meldest dich auf der Seite deiner Instanz an (auch mit Passkey oder SSO) und erlaubst der App den Zugriff. Sie bekommt ein eigenes Token, das du unter API-Tokens widerrufen kannst.';

  @override
  String get signInWithToken => 'Stattdessen mit API-Token verbinden';

  @override
  String get appAccessTitle => 'Diese App bittet um Zugriff';

  @override
  String get appLevel1 =>
      'Sie möchte die Projektdaten lesen, die ihr Autor angegeben hat (z. B. Einträge oder ein Board). Deine Anmeldung sieht sie nie.';

  @override
  String get appLevel2 =>
      'Sie möchte die angegebenen Projektdaten lesen und eigene Daten speichern (gemeinsam oder nur für dich).';

  @override
  String get appLevel3 =>
      'Sie möchte Projektdaten lesen, eigene Daten speichern und Änderungen vorschlagen – jede Änderung fragt dich vorher.';

  @override
  String get appAllow => 'Erlauben';

  @override
  String get appNotNow => 'Nicht jetzt';

  @override
  String get appProposeTitle => 'Die App schlägt eine Änderung vor';

  @override
  String appProposeTask(Object board, Object title) {
    return 'Neue Karte „$title“ auf Board $board.';
  }

  @override
  String appProposeComment(Object body, Object document) {
    return 'Kommentar zu $document: $body';
  }

  @override
  String appProposeEntity(Object kind, Object name) {
    return 'Neuer Eintrag „$name“ ($kind).';
  }

  @override
  String get appConfirm => 'Übernehmen';

  @override
  String get appOffline =>
      'Diese App wurde auf diesem Gerät noch nicht geöffnet; beim ersten Mal braucht sie das Netz.';

  @override
  String get appUnavailable =>
      'Die App lässt sich nicht öffnen (ausgeschaltet oder kein Zugriff).';

  @override
  String get appOfflineNote =>
      'Offline: Du siehst die App wie zuletzt geladen; ihre Speicheränderungen werden später gesendet.';

  @override
  String get wbText => 'Text';

  @override
  String get wbOffline =>
      'Offline: Deine Änderungen an der Tafel werden gesendet, sobald wieder Netz da ist.';

  @override
  String get wbSending => 'Änderungen werden gesendet …';

  @override
  String get wbHand => 'Verschieben und zoomen';

  @override
  String get wbSelect => 'Auswählen und bewegen (lange drücken: Text ändern)';

  @override
  String get wbPen => 'Stift';

  @override
  String get wbRect => 'Rechteck';

  @override
  String get wbEllipse => 'Ellipse';

  @override
  String get wbArrow => 'Pfeil';

  @override
  String get wbSticky => 'Haftnotiz';

  @override
  String get wbTextTool => 'Text';

  @override
  String get wbEraser => 'Radierer';

  @override
  String get protoPlay => 'Abspielen';

  @override
  String get protoOffline =>
      'Dieser Prototyp wurde auf diesem Gerät noch nicht abgespielt; beim ersten Mal braucht er das Netz.';

  @override
  String get protoUnavailable => 'Der Prototyp lässt sich nicht öffnen.';

  @override
  String get protoOfflineNote =>
      'Offline: Du spielst den Prototyp, wie er zuletzt geladen wurde.';

  @override
  String get appDeviceCamera => 'die Kamera';

  @override
  String get appDeviceMicrophone => 'das Mikrofon';

  @override
  String get appDeviceLocation => 'deinen Standort';

  @override
  String get appDeviceMotion => 'die Bewegungssensoren';

  @override
  String appDeviceTitle(String what) {
    return 'Darf diese App $what verwenden?';
  }

  @override
  String get appDeviceBody =>
      'Nur diese App, nur für dich. Du kannst es später in den Berechtigungen der App in Phoedox ändern; dein Telefon fragt eventuell zusätzlich.';

  @override
  String get appDeviceDeny => 'Nicht erlauben';

  @override
  String get appDownloadTitle => 'Datei aus der App speichern?';

  @override
  String appDownloadBody(String name, int kb) {
    return 'Die App gibt dir „$name“ ($kb KB).';
  }

  @override
  String get appDownloadSave => 'Speichern oder teilen';

  @override
  String get appSelfSaveTitle => 'Änderungen der App speichern?';

  @override
  String appSelfSaveBody(String files) {
    return 'Die App möchte ihre eigenen Dateien ändern ($files). Das ergibt eine neue Version für alle.';
  }

  @override
  String get appSelfSaveConfirm => 'Neue Version speichern';

  @override
  String get blockOffline =>
      'Ohne Verbindung nicht möglich. Versuche es gleich noch einmal.';

  @override
  String get blockSaveFailed => 'Das konnte nicht gespeichert werden.';

  @override
  String get pollClosed => 'Abgeschlossen';

  @override
  String pollVoters(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Personen haben abgestimmt',
      one: '1 Person hat abgestimmt',
      zero: 'Noch keine Stimmen',
    );
    return '$_temp0';
  }

  @override
  String get pollChooseOne => 'Wähle eine Antwort';

  @override
  String get pollChooseMany => 'Wähle eine oder mehrere Antworten';

  @override
  String get pollUndo => 'Stimme zurückziehen';

  @override
  String get matrixOption => 'Option';

  @override
  String get matrixTotal => 'Gesamt';

  @override
  String get matrixTune => 'Gewichte ausprobieren';

  @override
  String get matrixTuneDone => 'Fertig';

  @override
  String get matrixReset => 'Zurücksetzen';

  @override
  String get matrixNotSaved => 'Nur für dich, wird nicht gespeichert.';

  @override
  String matrixWeightLess(String name) {
    return 'Gewicht von $name verringern';
  }

  @override
  String matrixWeightMore(String name) {
    return 'Gewicht von $name erhöhen';
  }

  @override
  String get matrixToDecision => 'Als offene Entscheidung anlegen';

  @override
  String get matrixDecisionTitle => 'Entscheidung';

  @override
  String get matrixDecisionContext =>
      'Angelegt aus einer Entscheidungsmatrix; die Bewertungen stehen bei den Optionen.';

  @override
  String get matrixDecisionMade => 'Offene Entscheidung angelegt';

  @override
  String get matrixDecisionFailed =>
      'Die Entscheidung konnte nicht angelegt werden.';

  @override
  String get calcReset => 'Zurücksetzen';

  @override
  String get calcNotSaved => 'Deine Eingaben werden nicht gespeichert.';

  @override
  String quizScore(int right, int all) {
    return '$right von $all richtig';
  }

  @override
  String get quizAgain => 'Nochmal';

  @override
  String get quizShow => 'Antwort zeigen';

  @override
  String get quizKnew => 'Gewusst';

  @override
  String get quizMissed => 'Nicht gewusst';

  @override
  String get quizRight => 'richtig';

  @override
  String get quizWrong => 'falsch';

  @override
  String get mindmapExpandAll => 'Alles aufklappen';

  @override
  String get beforeAfterBefore => 'Vorher';

  @override
  String get beforeAfterAfter => 'Nachher';

  @override
  String get beforeAfterMissing => 'Es fehlen noch Fotos.';

  @override
  String beforeAfterValue(int n, String before) {
    return '$n % $before';
  }

  @override
  String get annotateNoImage => 'Noch kein Bild.';

  @override
  String get statusOk => 'In Ordnung';

  @override
  String get statusWarn => 'Warnung';

  @override
  String get statusDown => 'Gestört';

  @override
  String get blockLoadFailed => 'Konnte nicht geladen werden.';

  @override
  String treeMissing(String root) {
    return 'Den Eintrag „$root“ gibt es nicht.';
  }

  @override
  String treeEmpty(String relation) {
    return 'Nichts hängt über „$relation“ an der Wurzel. Stimmen Beziehung und Richtung?';
  }

  @override
  String rackMissing(String rack) {
    return 'Den Eintrag „$rack“ gibt es nicht.';
  }

  @override
  String rackUnits(int units) {
    return '$units HE';
  }

  @override
  String get rackConflict => 'Zwei Geräte belegen dieselben Höheneinheiten.';

  @override
  String rackUnplaced(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Geräte ohne Position',
      one: '1 Gerät ohne Position',
    );
    return '$_temp0';
  }

  @override
  String get rackEmpty => 'Noch keine Geräte in diesem Schrank.';

  @override
  String floorplanMissing(String plan) {
    return 'Den Grundriss „$plan“ gibt es nicht.';
  }

  @override
  String floorplanNoRoom(String room, String plan) {
    return 'Im Grundriss „$plan“ gibt es keinen Raum „$room“.';
  }

  @override
  String get pluginBlockFailed => 'Das Plugin konnte den Block nicht zeichnen.';

  @override
  String get pluginBlockOpen => 'Interaktiv öffnen';

  @override
  String pluginBlockLine(int line) {
    return 'Zeile $line:';
  }

  @override
  String pluginBlockNeeds(String plugin) {
    return 'braucht das Plugin $plugin';
  }

  @override
  String get pluginBlockNeedsHint =>
      'Ein Projektinhaber oder Administrator kann es im Browser aktivieren.';
}
