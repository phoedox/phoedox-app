# Phoedox App

Flutter app for [Phoedox](https://github.com/phoedox/phoedox) on iOS, Android, Windows, macOS and Linux.

First features: scan QR/NFC labels and open the entry, record a device with a photo and
its type plate, read and edit docs offline, alarms with one-click actions.

## Status

- Sign in with the address of the instance and an API token (Settings → API tokens & MCP); the token is stored in the
  device's secure storage.
- Projects, pages by folder, search, decisions, links and boards (read only), entries with
  attributes, relations and mentions.
- Offline reading: every loaded response is stored on the device and shown without a network.
- Scan QR labels (`https://<instance>/e/<project>/<slug>`, `phx://e/<project>/<slug>`).
- NFC labels (Android, iOS): read a tag to open its entry; write an entry's link onto a tag
  (NDEF URI record).
- Offline editing of Markdown pages: changes stay on the device (outbox) and are sent at start,
  when the app comes back and every two minutes. If the page changed on the server meanwhile
  (or has an open draft), both are merged with yrs (`native/phoedox_sync`), so changes in
  different places all survive.
- Type plate photo: the photo is attached to the entry; the server's text recognition reads it
  and the app offers labelled values (manufacturer, model, serial number, MAC, part number,
  power, voltage) as attributes. Needs OCR enabled on the instance.
- Voice notes on entries: record up to 5 minutes (AAC in `.m4a`, WAV where AAC is missing),
  play them back and attach them to the entry. Recordings wait in the device's upload queue
  (`lib/sync/uploads.dart`) and are sent with the next sync, so they work offline too. Notes
  already on the server are downloaded once and then play offline.
- Floor plans (read only): rooms, walls, devices and photos drawn from the plan; tap a device
  to open its entry, a photo to see it. Editors take a photo and tap the spot where it was
  taken: the photo is uploaded as a file of the plan and written into the plan's **draft**
  (`POST …/draft`, then the plan with the new photo). The app never publishes – the photo
  appears on the plan once someone publishes the draft in the web app. Offline, the photo and
  its position wait in the upload queue. The server's photo shape has a position and a caption,
  no viewing direction, so the compass is not used.

### AR

Placing photos with AR (ARCore/ARKit anchors) is not built. There is no maintained Flutter
package for both platforms: `ar_flutter_plugin` was last released in 2022,
`arcore_flutter_plugin` in early 2023, the forks have single releases; only `arkit_plugin`
(iOS only) is maintained. A plan photo also has no height, direction or anchor to store an AR
pose in. Revisit with native 3D (flutter_scene/Filament) or when the plan format gets anchors.

## Development

Needs [rustup](https://rustup.rs): `hook/build.dart` builds `native/phoedox_sync` for the
target platform (toolchain and targets pinned in `native/phoedox_sync/rust-toolchain.toml`).

```bash
flutter pub get
flutter run
flutter analyze && flutter test
cd native/phoedox_sync && cargo test
```

## Structure

- `lib/` – Dart/Flutter
- `native/phoedox_sync` – Rust crate with yrs (Yjs) for offline editing; a small C interface
  (`phx_merge3`) called from Dart via `dart:ffi` (`lib/sync/native.dart`), built by the Dart
  build hook in `hook/build.dart`
- Native 3D (flutter_scene/Filament), which also enables AR

## License

AGPL-3.0 – see [LICENSE](LICENSE).
