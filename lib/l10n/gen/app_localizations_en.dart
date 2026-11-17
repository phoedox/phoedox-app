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
  String get signInHint => 'Address of your instance, e.g. app.phoedox.com.';

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

  @override
  String get signInBrowser => 'Sign in with the browser';

  @override
  String get signInBrowserHint =>
      'You sign in on your instance\'s page (passkeys and SSO work too) and allow the app. It gets its own token, which you can revoke under API tokens.';

  @override
  String get signInWithToken => 'Connect with an API token instead';

  @override
  String get appAccessTitle => 'This app asks for access';

  @override
  String get appLevel1 =>
      'It wants to read the project data its author named (e.g. entries or a board). It never sees your sign-in.';

  @override
  String get appLevel2 =>
      'It wants to read the named project data and keep its own data (shared or just for you).';

  @override
  String get appLevel3 =>
      'It wants to read project data, keep its own data and propose changes – every change asks you first.';

  @override
  String get appAllow => 'Allow';

  @override
  String get appNotNow => 'Not now';

  @override
  String get appProposeTitle => 'The app proposes a change';

  @override
  String appProposeTask(Object board, Object title) {
    return 'New card “$title” on board $board.';
  }

  @override
  String appProposeComment(Object body, Object document) {
    return 'Comment on $document: $body';
  }

  @override
  String appProposeEntity(Object kind, Object name) {
    return 'New entry “$name” ($kind).';
  }

  @override
  String get appConfirm => 'Apply';

  @override
  String get appOffline =>
      'This app has not been opened on this device yet; it needs the network the first time.';

  @override
  String get appUnavailable =>
      'The app cannot be opened (switched off, or no access).';

  @override
  String get appOfflineNote =>
      'Offline: you see the app as last loaded; its storage changes are sent later.';

  @override
  String get wbText => 'Text';

  @override
  String get wbOffline =>
      'Offline: your changes to the board are sent once you are back online.';

  @override
  String get wbSending => 'Sending changes …';

  @override
  String get wbHand => 'Pan and zoom';

  @override
  String get wbSelect => 'Select and move (long press: edit text)';

  @override
  String get wbPen => 'Pen';

  @override
  String get wbRect => 'Rectangle';

  @override
  String get wbEllipse => 'Ellipse';

  @override
  String get wbArrow => 'Arrow';

  @override
  String get wbSticky => 'Sticky note';

  @override
  String get wbTextTool => 'Text';

  @override
  String get wbEraser => 'Eraser';

  @override
  String get protoPlay => 'Play';

  @override
  String get protoOffline =>
      'This prototype has not been played on this device yet; the first time it needs the network.';

  @override
  String get protoUnavailable => 'The prototype cannot be opened.';

  @override
  String get protoOfflineNote =>
      'Offline: you are playing the prototype as it was last loaded.';

  @override
  String get appDeviceCamera => 'the camera';

  @override
  String get appDeviceMicrophone => 'the microphone';

  @override
  String get appDeviceLocation => 'your location';

  @override
  String get appDeviceMotion => 'the motion sensors';

  @override
  String appDeviceTitle(String what) {
    return 'Allow this app to use $what?';
  }

  @override
  String get appDeviceBody =>
      'Only this app, only for you. You can change it later in the app\'s permissions in Phoedox; your phone may ask as well.';

  @override
  String get appDeviceDeny => 'Don\'t allow';

  @override
  String get appDownloadTitle => 'Save a file from the app?';

  @override
  String appDownloadBody(String name, int kb) {
    return 'The app gives you “$name” ($kb KB).';
  }

  @override
  String get appDownloadSave => 'Save or share';

  @override
  String get appSelfSaveTitle => 'Save the app\'s changes?';

  @override
  String appSelfSaveBody(String files) {
    return 'The app wants to change its own files ($files). This makes a new version for everyone.';
  }

  @override
  String get appSelfSaveConfirm => 'Save new version';

  @override
  String get blockOffline =>
      'Not possible without a connection. Try again in a moment.';

  @override
  String get blockSaveFailed => 'This could not be saved.';

  @override
  String get pollClosed => 'Closed';

  @override
  String pollVoters(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n people voted',
      one: '1 person voted',
      zero: 'No votes yet',
    );
    return '$_temp0';
  }

  @override
  String get pollChooseOne => 'Choose one answer';

  @override
  String get pollChooseMany => 'Choose one or more answers';

  @override
  String get pollUndo => 'Take back my vote';

  @override
  String get matrixOption => 'Option';

  @override
  String get matrixTotal => 'Total';

  @override
  String get matrixTune => 'Try other weights';

  @override
  String get matrixTuneDone => 'Done';

  @override
  String get matrixReset => 'Reset';

  @override
  String get matrixNotSaved => 'Just for you, not saved.';

  @override
  String matrixWeightLess(String name) {
    return 'Lower the weight of $name';
  }

  @override
  String matrixWeightMore(String name) {
    return 'Raise the weight of $name';
  }

  @override
  String get matrixToDecision => 'Make it an open decision';

  @override
  String get matrixDecisionTitle => 'Decision';

  @override
  String get matrixDecisionContext =>
      'Made from a decision matrix; the scores are listed with the options.';

  @override
  String get matrixDecisionMade => 'Open decision created';

  @override
  String get matrixDecisionFailed => 'The decision could not be created.';

  @override
  String get calcReset => 'Reset';

  @override
  String get calcNotSaved => 'Your inputs are not saved.';

  @override
  String quizScore(int right, int all) {
    return '$right of $all right';
  }

  @override
  String get quizAgain => 'Again';

  @override
  String get quizShow => 'Show the answer';

  @override
  String get quizKnew => 'Knew it';

  @override
  String get quizMissed => 'Didn\'t know';

  @override
  String get quizRight => 'right';

  @override
  String get quizWrong => 'wrong';
}
