# Phoedox App

Flutter-App für [Phoedox](https://github.com/phoedox/phoedox) auf iOS, Android, Windows, macOS und Linux.

Erste Funktionen: QR-/NFC-Etiketten scannen und den Eintrag öffnen, Gerät mit Foto und
Typenschild erfassen, Doku offline lesen und bearbeiten, Alarme mit Ein-Klick-Aktionen.

## Einrichten

Die Plattform-Ordner werden von Flutter erzeugt und sind noch nicht im Repo:

```bash
flutter create . --org com.phoedox --platforms=ios,android,windows,macos,linux
flutter pub get
flutter run
```

## Aufbau

- `lib/` – Dart/Flutter
- `native/phoedox_sync` – Rust-Crate mit yrs (Yjs) für Offline-Bearbeitung; Anbindung an Dart per FFI
- 3D nativ (flutter_scene/Filament), dadurch auch AR

## Lizenz

AGPL-3.0 – siehe [LICENSE](LICENSE).
