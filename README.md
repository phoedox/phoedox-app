# Phoedox App

Flutter-App für [Phoedox](https://github.com/phoedox/phoedox) auf iOS, Android, Windows, macOS und Linux.

Erste Funktionen: QR-/NFC-Etiketten scannen und den Eintrag öffnen, Gerät mit Foto und
Typenschild erfassen, Doku offline lesen und bearbeiten, Alarme mit Ein-Klick-Aktionen.

## Stand

- Anmelden mit Adresse der Instanz und API-Token (Einstellungen → API-Tokens & MCP); das Token liegt im
  sicheren Speicher des Geräts.
- Projekte, Seiten nach Ordnern, Suche, Entscheidungen, Links und Boards (nur lesen), Einträge mit
  Attributen, Beziehungen und Erwähnungen.
- Offline lesen: Jede geladene Antwort wird auf dem Gerät gespeichert und ohne Netz angezeigt.
- QR-Etiketten scannen (`https://<instanz>/e/<projekt>/<slug>`, `phx://e/<projekt>/<slug>`).
- Als Nächstes: Offline bearbeiten über `native/phoedox_sync` (yrs), NFC, Gerät mit Foto erfassen.

## Entwickeln

```bash
flutter pub get
flutter run
flutter analyze && flutter test
```

## Aufbau

- `lib/` – Dart/Flutter
- `native/phoedox_sync` – Rust-Crate mit yrs (Yjs) für Offline-Bearbeitung; Anbindung an Dart per FFI
- 3D nativ (flutter_scene/Filament), dadurch auch AR

## Lizenz

AGPL-3.0 – siehe [LICENSE](LICENSE).
