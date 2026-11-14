Sync layer: Dart bindings to `native/phoedox_sync` (Rust, yrs) via FFI
(flutter_rust_bridge). Offline edits are merged when the device reconnects.

`uploads.dart` queues files made on the device (voice notes of entries, photos placed on a
floor plan) until the server has them; plan photos are then written into the plan's draft.
