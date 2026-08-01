# Brothers Coffee POS

Offline-first Android point-of-sale application for a single coffee shop and tablet.

## Current foundation

- Flutter/Dart Android application with portrait and landscape layouts
- French localization with Arabic/RTL resources prepared
- Drift/SQLite schema for accounts, catalogue, business days, sales, audit, and metadata
- Argon2id manager/employee PIN hashing
- Exact TND arithmetic using integer millimes
- Local account and catalogue repositories
- Responsive point-of-sale shell

The agreed product scope is in [Product requirements](docs/PRODUCT_REQUIREMENTS.md), and the technical boundaries are in [Architecture](docs/ARCHITECTURE.md).

## Local toolchain

- Flutter: `C:\src\flutter`
- Android SDK: `C:\Users\Admin\AppData\Local\Android\Sdk`
- JDK: `C:\Program Files\Microsoft\jdk-17.0.20.8-hotspot`

The installer configured the corresponding user environment variables and `PATH`. Open a new terminal if the commands are not yet visible in an existing shell.

## Development commands

```powershell
flutter pub get
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
dart format .
flutter analyze
flutter test
flutter build apk --debug
```

The MVP must remain fully usable without a network connection after installation. Server synchronization, inventory, card payments, printers, and automatic cloud upload are later phases.
