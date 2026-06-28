# fluttmacs

`fluttmacs` is an experiment to run real GNU Emacs on iOS, iPadOS, Android, and macOS as a cross-platform Flutter application.

Flutter owns the cross-platform application shell and terminal surface, while platform backends handle running/embedding GNU Emacs and connecting terminal bytes.

> [!NOTE]
> The original native Swift/Objective-C implementation has been moved to the [999_old/](file:///Users/seijiro/by-llms/iosmacs/999_old) directory and marked as obsolete.

## Documentation

- [ARCHITECTURE.md](file:///Users/seijiro/by-llms/iosmacs/ARCHITECTURE.md) - High-level shape, backend specifications, and implementation details.
- [PLAN.md](file:///Users/seijiro/by-llms/iosmacs/PLAN.md) - Project timeline and implementation roadmap.
- [LOG.md](file:///Users/seijiro/by-llms/iosmacs/LOG.md) - Workstream logs and diagnostic history.

## Getting Started

To prepare development tools, make sure you have Flutter SDK installed, then bootstrap the project:

```sh
make bootstrap
```

### Running on Emulators and Simulators

#### 1. macOS (Desktop)
Run the application natively on macOS:
```sh
flutter run -d macos
```
Or use the Makefile shortcut:
```sh
make flutter-macos-smoke
```

#### 2. iOS & iPadOS (Simulator)
- Open the iOS Simulator:
  ```sh
  open -a Simulator
  ```
- Run on the booted iOS Simulator:
  ```sh
  flutter run -d ios
  ```
- Launch specifically on an iPad simulator:
  ```sh
  make flutter-ipad-launch
  ```

#### 3. Android (Emulator)
- List your local Android Virtual Devices (AVD):
  ```sh
  emulator -list-avds
  ```
- Boot an emulator (e.g. `fluttmacs_pixel`):
  ```sh
  emulator -avd fluttmacs_pixel
  ```
- Run on the booted Android Emulator:
  ```sh
  flutter run -d android
  ```
- Run integrated emulator parity tests:
  ```sh
  make flutter-android-emulator-smoke
  ```

## Common Makefile Tasks

- `make flutter-doctor`: Check environment health.
- `make flutter-analyze`: Run static analysis.
- `make flutter-fake-smoke`: Run unit/widget tests with a fake backend.
- `make flutter-verify`: Run all verification tests locally.

For details on building platform-specific runtimes (like macOS, iOS, or Android NDK), see `ARCHITECTURE.md`.
