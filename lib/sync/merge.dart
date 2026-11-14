import 'native.dart';

/// Merges an offline edit ([mine]) with what changed on the server
/// ([theirs]) since the edit started ([base]). Changes in different places
/// all survive.
String merge3(String base, String mine, String theirs) {
  if (mine == base || mine == theirs) return theirs;
  if (theirs == base) return mine;
  try {
    return nativeMerge3(base, mine, theirs);
  } catch (_) {
    // Without the native library (should not happen in release builds):
    // keep both versions rather than lose one.
    return '$theirs\n\n---\n\n$mine';
  }
}
