import 'dart:typed_data';
import 'dart:io';

import 'package:nfc_manager/nfc_manager.dart';
import 'package:ndef_record/ndef_record.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';

import 'ndef_uri.dart';

/// NFC exists on phones only (Android, iOS).
Future<bool> nfcAvailable() async {
  if (!(Platform.isAndroid || Platform.isIOS)) return false;
  try {
    return await NfcManager.instance.checkAvailability() ==
        NfcAvailability.enabled;
  } catch (_) {
    return false;
  }
}

/// Waits for one tag and returns the first link on it (null: none).
Future<String?> readNfcLink({required String prompt}) async {
  String? found;
  var done = false;
  await NfcManager.instance.startSession(
    pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
    alertMessageIos: prompt,
    onDiscovered: (tag) async {
      final ndef = Ndef.from(tag);
      final msg = ndef?.cachedMessage ?? await ndef?.read();
      for (final r in msg?.records ?? const <NdefRecord>[]) {
        found = readNdefUri(r.typeNameFormat.index, r.type, r.payload);
        if (found != null) break;
      }
      done = true;
      await NfcManager.instance.stopSession();
    },
  );
  // The session reports through the callback; wait for it (up to a minute).
  for (var i = 0; i < 600 && !done; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  if (!done) await NfcManager.instance.stopSession();
  return found;
}

/// Writes a link as an NDEF URI record onto the next tag held to the phone.
/// Returns null on success or a reason ("readonly", "nondef", "failed").
Future<String?> writeNfcLink(String uri, {required String prompt}) async {
  String? result = 'failed';
  var done = false;
  final rec = ndefUriRecord(uri);
  await NfcManager.instance.startSession(
    pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
    alertMessageIos: prompt,
    invalidateAfterFirstReadIos: false,
    onDiscovered: (tag) async {
      final ndef = Ndef.from(tag);
      if (ndef == null) {
        result = 'nondef';
      } else if (!ndef.isWritable) {
        result = 'readonly';
      } else {
        try {
          await ndef.write(
              message: NdefMessage(records: [
            NdefRecord(
                typeNameFormat: TypeNameFormat.wellKnown,
                type: rec.type,
                identifier: Uint8List(0),
                payload: rec.payload),
          ]));
          result = null;
        } catch (_) {
          result = 'failed';
        }
      }
      done = true;
      await NfcManager.instance.stopSession();
    },
  );
  for (var i = 0; i < 600 && !done; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  if (!done) await NfcManager.instance.stopSession();
  return result;
}
