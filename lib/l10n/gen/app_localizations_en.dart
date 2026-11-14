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

  @override
  String get edit => 'Edit';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get discard => 'Discard';

  @override
  String get editHint =>
      'Markdown. Works offline: the change stays on this device and is merged with changes on the server when it is sent.';

  @override
  String get editDiscard => 'Discard your changes?';

  @override
  String get editSynced => 'Saved.';

  @override
  String get editMerged => 'Saved and merged with changes on the server.';

  @override
  String get editQueued =>
      'Saved on this device – sent as soon as there is a connection.';

  @override
  String get pendingNote => 'Changed on this device – not sent yet.';

  @override
  String pendingRefused(String key) {
    return 'The server refused the change ($key).';
  }

  @override
  String get syncNow => 'Send now';

  @override
  String get syncOffline => 'Still offline – changes stay on the device.';

  @override
  String syncFailed(int count) {
    return '$count changes were refused.';
  }

  @override
  String syncDone(int count) {
    return '$count changes sent.';
  }

  @override
  String get nameplateAction => 'Photo of type plate';

  @override
  String get nameplateReading => 'Uploading and reading the type plate …';

  @override
  String get nameplateOffline =>
      'Needs a connection – the photo was not saved.';

  @override
  String get nameplateNothing =>
      'Photo saved. No values recognised (is text recognition enabled on the server?).';

  @override
  String get nameplateFound => 'Found on the type plate';

  @override
  String nameplateReplaces(String value) {
    return 'replaces $value';
  }

  @override
  String nameplateSaved(int count) {
    return '$count values saved.';
  }

  @override
  String get nfcRead => 'Read NFC tag';

  @override
  String get nfcWrite => 'Write NFC tag';

  @override
  String get nfcHold => 'Hold the tag to the phone.';

  @override
  String get nfcUnavailable => 'NFC is not available or switched off.';

  @override
  String get nfcWritten => 'Tag written.';

  @override
  String get nfcReadonly => 'The tag is write-protected.';

  @override
  String get nfcWriteFailed => 'Could not write the tag.';

  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String get voiceNotes => 'Voice notes';

  @override
  String get voiceNone => 'No voice notes yet.';

  @override
  String get voiceRecord => 'Record voice note';

  @override
  String get voiceMicTitle => 'Microphone';

  @override
  String get voiceMicRationale =>
      'Phoedox uses the microphone only while you record a voice note. The recording is attached to this entry.';

  @override
  String get voiceMicDenied =>
      'No access to the microphone. Allow it in the system settings.';

  @override
  String get voiceRecordFailed => 'Could not record.';

  @override
  String get voiceRecording => 'Recording';

  @override
  String voiceLimit(int minutes) {
    return 'Up to $minutes minutes; the recording then stops by itself.';
  }

  @override
  String get voiceStop => 'Stop';

  @override
  String get voiceSent => 'Voice note attached.';

  @override
  String get voiceQueued =>
      'Voice note saved on this device – sent as soon as there is a connection.';

  @override
  String get notSentYet => 'Not sent yet';

  @override
  String uploadRefused(String key) {
    return 'The server refused the file ($key).';
  }

  @override
  String get loadFailed => 'Could not be loaded.';

  @override
  String get planPhoto => 'Place photo';

  @override
  String get planPhotoTap =>
      'Tap the spot on the plan where you took the photo.';

  @override
  String get planPhotoCaption => 'Caption';

  @override
  String get planPhotoDraft =>
      'Photo saved in the plan\'s draft. It appears on the plan once someone publishes the draft in the web app.';

  @override
  String get planPhotoQueued =>
      'Photo saved on this device – it goes into the plan\'s draft as soon as there is a connection.';

  @override
  String get planPhotoDone => 'Photo saved on the plan.';

  @override
  String planPhotosPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos not in the draft yet',
      one: '1 photo not in the draft yet',
    );
    return '$_temp0';
  }

  @override
  String get planDraftNote =>
      'New photos go into the plan\'s draft and show here only once it is published.';

  @override
  String get voiceMicContinue => 'Continue';
}
