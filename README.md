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
- Next: offline editing via `native/phoedox_sync` (yrs), NFC, recording a device with a photo.

## Development

```bash
flutter pub get
flutter run
flutter analyze && flutter test
```

## Structure

- `lib/` – Dart/Flutter
- `native/phoedox_sync` – Rust crate with yrs (Yjs) for offline editing; connected to Dart via FFI
- Native 3D (flutter_scene/Filament), which also enables AR

## License

AGPL-3.0 – see [LICENSE](LICENSE).
