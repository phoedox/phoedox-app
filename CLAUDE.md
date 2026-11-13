# Phoedox App (Flutter)

Gesamtentscheidungen: in Phoedox (https://app.phoedox.com, Projekt `phoedox`), v. a. ADR-0002 (Flutter-App) und ADR-0015 (Live-Bearbeitung); per MCP lesen, neue mit `create_decision` anlegen.

## Aufbau

- `lib/app` – App-Gerüst, Theme (Primärfarbe = Logo-Orange, pro Projekt überschreibbar), Navigation
- `lib/features/*` – Funktionen; `scan/scan_link.dart` erkennt Phoedox-Etiketten (`https://<instanz>/e/<projekt>/<slug>`, `phx://e/<projekt>/<slug>`)
- Zustand mit Riverpod; Sync-Streams als StreamProvider
- `native/phoedox_sync` – yrs (Rust), angebunden mit flutter_rust_bridge (Version gepinnt); dieselbe Datenschicht wie Server und Web, offline bearbeitbar
- Plattform-Ordner per `flutter create` erzeugen (siehe README), dann committen

## Regeln

- Texte Deutsch + Englisch über Flutter-Lokalisierung (noch einzurichten, `flutter gen-l10n`).
- Icons: Lucide (Paket `lucide_icons`), Material-Icons nur als Übergang.
- Offline zuerst: Lesen und Bearbeiten müssen ohne Netz funktionieren; Aktionen an Geräten (Schalten, Agent) nur online und mit Bestätigung.
- `dart format`, `flutter analyze`, `flutter test`; Rust: `cargo test` in `native/phoedox_sync`.
- Commits nach Conventional Commits. Code und Kommentare Englisch. Lizenz AGPL-3.0.
