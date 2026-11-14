# Phoedox App (Flutter)

Gesamtentscheidungen: in Phoedox (https://app.phoedox.com, Projekt `phoedox`), v. a. ADR-0002 (Flutter-App) und ADR-0015 (Live-Bearbeitung); per MCP lesen, neue mit `create_decision` anlegen.

## Aufbau

- `lib/app` – App-Gerüst, Theme (Primärfarbe = Logo-Orange, pro Projekt überschreibbar), Navigation
- `lib/features/*` – Funktionen; `scan/scan_link.dart` erkennt Phoedox-Etiketten (`https://<instanz>/e/<projekt>/<slug>`, `phx://e/<projekt>/<slug>`)
- Zustand mit Riverpod; Sync-Streams als StreamProvider
- `native/phoedox_sync` – yrs (Rust), angebunden über eine kleine C-Schnittstelle und `dart:ffi` (`lib/sync/native.dart`), gebaut vom Dart-Build-Hook `hook/build.dart` (native_toolchain_rust, Toolchain in `rust-toolchain.toml` gepinnt); dieselbe CRDT wie Server und Web
- `lib/sync` – Offline-Bearbeitung: Outbox, Zusammenführen mit yrs, Senden
- Plattform-Ordner per `flutter create` erzeugen (siehe README), dann committen

## Regeln

- **Dokumentation und Aufgaben auf Englisch:** README, `docs/`, Phoedox-Seiten, Entscheidungen (ADRs) und Karten auf dem Board „Roadmap“ immer auf Englisch schreiben; Deutsch nur als Übersetzung (Projekt `phoedox` hat Englisch als Hauptsprache).
- Texte Deutsch + Englisch über Flutter-Lokalisierung (noch einzurichten, `flutter gen-l10n`).
- Icons: Lucide (Paket `lucide_icons`), Material-Icons nur als Übergang.
- Offline zuerst: Lesen und Bearbeiten müssen ohne Netz funktionieren; Aktionen an Geräten (Schalten, Agent) nur online und mit Bestätigung.
- `dart format`, `flutter analyze`, `flutter test`; Rust: `cargo test` in `native/phoedox_sync`.
- Commits nach Conventional Commits. Code und Kommentare Englisch. Lizenz AGPL-3.0.
