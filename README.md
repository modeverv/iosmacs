# fluttmacs

`fluttmacs` is an experiment to run real GNU Emacs on iOS, iPadOS, Android, macOS, Linux, and Windows as a cross-platform Flutter application.

Flutter owns the cross-platform application shell and terminal surface, while platform backends handle running GNU Emacs and connecting terminal bytes via PTY or JNI bridges.

> [!NOTE]
> The original native Swift/Objective-C implementation has been moved to [999_old/](999_old/) and is no longer maintained.

## Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md) — High-level shape, backend specifications, and implementation details.
- [PLAN.md](PLAN.md) — Project timeline and implementation roadmap.

## Prerequisites

| Tool | Version | Notes |
|---|---|---|
| Flutter SDK | 3.x stable | Install under `~/work/flutter` — **do not use the snap package** |
| Dart | bundled with Flutter | |
| Xcode | 15+ | macOS/iOS targets only |
| Android SDK | API 35+ | Android target only |
| MSYS2 + MinGW-w64 | latest | Windows target only — see [Windows section](#windows-desktop) |

### Installing Flutter (Linux)

**Do not install Flutter via `snap install flutter`.** The snap package bundles an old linker (`ld`) that cannot link against Ubuntu 24.04+'s glibc and produces a `.relr.dyn` error. Install from the official tarball instead:

```sh
git clone https://github.com/flutter/flutter.git ~/work/flutter -b stable --depth 1
export PATH="$HOME/work/flutter/bin:$PATH"   # add to ~/.bashrc or ~/.zshrc
flutter doctor
```

If you already have the snap version installed, remove it first:

```sh
sudo snap remove flutter
```

After installing Flutter, bootstrap the platform runners:

```sh
make bootstrap
```

---

## Running the App

### macOS (Desktop)

The macOS backend starts a bundled GNU Emacs child process via `forkpty(3)`.

**First, build the bundled Emacs runtime** (one-time, ~5 min):

```sh
make flutter-macos-emacs-runtime
```

Then run:

```sh
flutter run -d macos
```

Or smoke-test with logs:

```sh
make flutter-macos-native-smoke
```

---

### Linux (Desktop)

The Linux backend starts a bundled GNU Emacs child process via `forkpty(3)`.  
System Emacs is not used; the binary is built from `wasmacs/vendor/emacs` and bundled into the app.

**Prerequisites** (Ubuntu/Debian):

```sh
sudo apt-get install -y libncurses-dev autoconf automake texinfo
```

> `texinfo` provides `makeinfo`. If it is unavailable, the build script falls back to a stub automatically.

**Step 1 — build the bundled Emacs runtime** (one-time, ~10 min):

```sh
make flutter-linux-emacs-runtime
```

This builds GNU Emacs into `build/emacs-linux/runtime/`. The Flutter CMake build copies that runtime into the app bundle under `data/iosmacs-emacs/` automatically on the next `flutter build linux`.

**Step 2 — run the app**:

```sh
flutter run -d linux
```

**Smoke tests**:

```sh
# Basic launch/alive check
make flutter-linux-smoke

# Full native smoke: verifies bundled Emacs starts, input/resize/workspace/stop
make flutter-linux-native-smoke
```

The native smoke requires a display (X11 or Wayland). On headless systems, install `xvfb` and the smoke script uses it automatically:

```sh
sudo apt-get install -y xvfb
make flutter-linux-native-smoke
```

**Debug override** — point to a different Emacs binary without rebuilding:

```sh
IOSMACS_FLUTTER_EMACS=/path/to/emacs flutter run -d linux
```

---

### iOS & iPadOS (Simulator)

The iOS backend links a static GNU Emacs archive directly into the Flutter Runner.

**Build the static Emacs archive** (one-time, requires macOS + Xcode):

```sh
make flutter-emacs-static
make flutter-emacs-pdmp
```

**Open Simulator and run**:

```sh
open -a Simulator
```

Launch specifically on a booted iPad simulator:

```sh
make flutter-ipad-launch
```

Verify the full native smoke (requires a booted simulator):

```sh
make flutter-ios-native-smoke
```

To reproduce a clean iOS simulator build from generated artifacts removed:

```sh
make clean
make flutter-emacs-pdmp
make flutter-ios-native-smoke
```

---

### Android (Emulator)

The Android backend runs a GNU Emacs NW binary (`libemacs_nw.so`) via `forkpty(3)` inside the app process.

**Build the Android Emacs runtime and NW pdumper binary** (one-time, requires Android SDK + NDK):

```sh
make flutter-android-emacs-runtime
make flutter-android-emacs-nw-pdumper-build
```

**Create and boot the local AVD** (one-time):

```sh
avdmanager create avd -n fluttmacs_pixel -k "system-images;android-36;google_apis;arm64-v8a"
emulator -avd fluttmacs_pixel &
```

**Run on the booted emulator**:

```sh
flutter run -d android
```

Run the integrated emulator parity smoke (requires a booted emulator):

```sh
make flutter-android-emulator-smoke

# Full parity check including pdump, network, workspace, and pointer
make flutter-android-parity-smoke
```

To reproduce a clean Android emulator build from generated artifacts removed:

```sh
make clean
make flutter-android-emacs-runtime
make flutter-android-emacs-nw-pdumper-build
make flutter-android-emulator-smoke
```

The Android runtime target prepares any host-side Emacs tools it needs. The emulator smoke builds the debug APK, installs and launches it on the booted emulator, verifies the NW Emacs PTY route, and writes a screenshot under `build/android-emulator-smoke/`.

---

### Windows (Desktop)

The Windows backend starts a bundled GNU Emacs child process using the Windows
[ConPTY](https://devblogs.microsoft.com/commandline/windows-command-line-introducing-the-windows-pseudo-console-conpty/)
API (`CreatePseudoConsole`). This requires Windows 10 version 1809 (SDK 10.0.17763) or later.

**Step 0 — install MSYS2** (one-time):

Download and install [MSYS2](https://www.msys2.org/), then install the MinGW-w64 toolchain inside MSYS2:

```sh
# Run in MSYS2 MinGW64 shell
pacman -S --noconfirm mingw-w64-x86_64-toolchain autoconf automake make pkg-config
```

**Step 1 — build the bundled Emacs runtime** (one-time, ~15 min):

```powershell
.\scripts\build-emacs-windows-runtime.ps1
```

This builds GNU Emacs into `build/emacs-windows/runtime/`. The Flutter CMake build copies that runtime into the app bundle under `data/iosmacs-emacs/` automatically on the next `flutter build windows`.

**Step 2 — run the app**:

```powershell
flutter run -d windows
```

**Smoke tests**:

```powershell
# Full native smoke: verifies bundled Emacs starts, input/resize/workspace/stop
.\scripts\run-flutter-windows-native-smoke.ps1
# Or via Make (from Git Bash or MSYS2):
make flutter-windows-native-smoke
```

**Debug override** — point to a different Emacs binary without rebuilding:

```powershell
$env:IOSMACS_FLUTTER_EMACS = "C:\path\to\emacs.exe"
flutter run -d windows
```

---

### Web

The Web backend is a placeholder. A real WASM-based Emacs backend (`wasmacs`) is the intended future route.

```sh
flutter run -d chrome
```

---

## Common Makefile Targets

| Target | Description |
|---|---|
| `make flutter-doctor` | Check environment health |
| `make flutter-analyze` | Run Dart static analysis |
| `make flutter-fake-smoke` | Run unit/widget tests with fake backend |
| `make flutter-linux-emacs-runtime` | Build bundled GNU Emacs for Linux |
| `make flutter-macos-emacs-runtime` | Build bundled GNU Emacs for macOS |
| `make flutter-windows-emacs-runtime` | Build bundled GNU Emacs for Windows via MSYS2 |
| `make flutter-linux-smoke` | Build and launch Flutter Linux app briefly |
| `make flutter-linux-native-smoke` | Full Linux native Emacs smoke test |
| `make flutter-macos-smoke` | Build and launch Flutter macOS app briefly |
| `make flutter-macos-native-smoke` | Full macOS native Emacs smoke test |
| `make flutter-windows-native-smoke` | Full Windows native Emacs smoke test |
| `make flutter-ios-smoke` | Verify Flutter iOS Runner bundle resources |
| `make flutter-ios-launch-smoke` | Install and launch on iOS simulator |
| `make flutter-ios-native-smoke` | Full iOS native Emacs smoke test |
| `make flutter-android-smoke` | Build Flutter Android debug APK |
| `make flutter-android-emulator-smoke` | Full Android emulator Emacs smoke test |
| `make flutter-verify` | Run all verification checks sequentially |

---

## Backend Architecture

Each platform uses an independent backend behind the shared `EmacsBackend` Dart interface:

| Platform | Backend | Transport |
|---|---|---|
| macOS | `NativeEmacsBackend` | MethodChannel → `MacOSNativeEmacsBridge.swift` → `forkpty` |
| Linux | `NativeEmacsBackend` | MethodChannel → `linux_native_emacs_bridge.cc` → `forkpty` |
| Windows | `NativeEmacsBackend` | MethodChannel → `windows_native_emacs_bridge.cc` → ConPTY |
| iOS / iPadOS | `NativeEmacsBackend` | MethodChannel → `FlutterNativeEmacsBridge.swift` → static archive |
| Android | `AndroidEmacsBackend` → `NativeEmacsBackend` | MethodChannel → `AndroidNativeEmacsBridge.kt` → JNI/`forkpty` |
| Web | `WebWasmEmacsBackend` | placeholder (future WASM route) |

See [ARCHITECTURE.md](ARCHITECTURE.md) for full details.
