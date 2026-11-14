// FFI bindings to native/phoedox_sync (built by hook/build.dart).
import 'dart:ffi';

import 'package:ffi/ffi.dart';

@Native<Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>)>(
    symbol: 'phx_merge3')
external Pointer<Utf8> _merge3(
    Pointer<Utf8> base, Pointer<Utf8> mine, Pointer<Utf8> theirs);

@Native<Void Function(Pointer<Utf8>)>(symbol: 'phx_free_string')
external void _free(Pointer<Utf8> s);

/// Three-way merge with yrs (Yjs), the CRDT the server and web editor use.
String nativeMerge3(String base, String mine, String theirs) {
  final b = base.toNativeUtf8();
  final m = mine.toNativeUtf8();
  final t = theirs.toNativeUtf8();
  try {
    final out = _merge3(b, m, t);
    try {
      return out.toDartString();
    } finally {
      _free(out);
    }
  } finally {
    malloc.free(b);
    malloc.free(m);
    malloc.free(t);
  }
}
