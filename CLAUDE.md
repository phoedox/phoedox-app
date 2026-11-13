# Phoedox App (Flutter)

Gesamtentscheidungen: `phoedox/phoedox` → `docs/decisions.md` (Abschnitte Entscheidungen Runde 3).

## Aufbau

- `lib/app` – App-Gerüst, Theme (Primärfarbe = Logo-Orange, pro Projekt überschreibbar), Navigation
- `lib/features/*` – Funktionen; `scan/scan_link.dart` erkennt Phoedox-Etiketten (`https://<instanz>/e/<projekt>/<slug>`, `phx://e/<projekt>/<slug>`)
- `native/phoedox_sync` – yrs (Rust) per FFI; dieselbe Datenschicht wie Server und Web, offline bearbeitbar
- Plattform-Ordner per `flutter create` erzeugen (siehe README), dann committen

## Regeln

- Texte Deutsch + Englisch über Flutter-Lokalisierung (noch einzurichten, `flutter gen-l10n`).
- Icons: Lucide (Paket `lucide_icons`), Material-Icons nur als Übergang.
- Offline zuerst: Lesen und Bearbeiten müssen ohne Netz funktionieren; Aktionen an Geräten (Schalten, Agent) nur online und mit Bestätigung.
- `dart format`, `flutter analyze`, `flutter test`; Rust: `cargo test` in `native/phoedox_sync`.
- Commits nach Conventional Commits. Code und Kommentare Englisch.
