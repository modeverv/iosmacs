# iosmacs Flutter Log

## 2026-06-27

Flutter Android NW follow-up:

- Accepted the Android GNU Emacs NW display result as the current Android
  interactive terminal direction.
- Updated the Flutter Android architecture and plan docs so the separately built
  `libemacs_nw.so` route is the active path, while the official
  `--with-android` runtime remains packaged evidence and fallback diagnostics.
- Tightened the Android emulator smoke around the NW path: it now waits for the
  NW PTY marker plus `*scratch*` and the named `iosmacs input smoke` committed
  text marker before accepting the run.
- Extended input-smoke logging to include the committed smoke text while
  preserving the existing byte-count prefix used by iOS/macOS/backend smokes.
- Verified with `flutter analyze`, targeted Flutter tests, `make
  flutter-structure-check`, `make flutter-android-smoke`, `make
  flutter-android-emulator-smoke`, shell syntax checks, and `git diff --check`.
- Added an Android emulator keyboard-input proof on the same NW route:
  `make flutter-android-emulator-smoke` now focuses the Flutter terminal, sends
  `androidadbinput` through `adb shell input text`, and requires
  `iosmacs-terminal-input-buffer` evidence in logcat before accepting the run.
- Added a smoke-only `IOSMACS_FLUTTER_MIRROR_TERMINAL_INPUT` flag so runtime
  keyboard evidence can be mirrored to logs without changing the normal app
  terminal behavior.
- Verified the ADB keyboard proof with `dart format`, shell syntax checks,
  `git diff --check`, `make flutter-structure-check`, targeted Flutter widget
  tests, `flutter analyze`, and `make flutter-android-emulator-smoke`.
- Added an Android `WorkspaceExportProvider` and changed native workspace
  export to copy files through `ContentResolver.openOutputStream()` to
  `content://com.example.iosmacs_flutter.workspace_export/...` URIs.
- Extended the Android emulator smoke so the NW route must now prove returned
  document-provider export URIs and native byte-count evidence in logcat.
- Added Android NW startup-output filtering in the JNI PTY bridge: Emacs'
  no-pdump load chatter is buffered until the first menu-bar `*scratch*` frame
  appears, then the smoke requires `interactive frame ready` evidence with a
  suppressed startup byte count.
- Added the normal Android user-facing export flow: `exportWorkspace` now
  presents `ACTION_CREATE_DOCUMENT`, writes the selected workspace file or a
  generated workspace zip to the returned document URI, and keeps the
  noninteractive provider export path for runtime smoke builds.
- Deferred the official Android subprocess comparison probe while the NW PTY
  terminal route is active, so comparison-only diagnostics no longer sit on the
  first-output hot path.
- Added an Android NW startup timing marker to the JNI PTY bridge. The marker
  measures fork-to-first-usable-`*scratch*` time at the same point where startup
  chatter is released, and `make flutter-android-emulator-smoke` now requires
  that timing/suppression evidence.
- Verified the timing marker with `make flutter-structure-check` and `make
  flutter-android-emulator-smoke`. The current emulator run reached the first
  interactive frame with `elapsed_ms=814` while suppressing `12640` startup
  bytes before rendering the usable terminal frame.
- Added an Android NW file-ops parity smoke. The emulator smoke now writes an
  Android app-workspace Elisp file, loads it through the interactive NW Emacs
  terminal, and requires app-sandbox evidence that Emacs saved and reopened
  `notes/iosmacs-android-file-smoke.txt`, verified Dired could list it, and
  wrote `iosmacs-android-file-ops-ok`.
- Patched both Android runtime asset generation and the Android NW build so
  `loadup.el` guards the Android `pdumper-stats` helper when the NW route is
  built with `--with-dumping=none`. Also expanded the NW `EMACSLOADPATH` to
  include immediate Lisp subdirectories such as `calendar/`, and bumped the
  extracted data version so patched assets are re-extracted.
- Verified the updated Android NW runtime with `make flutter-android-emacs-runtime`,
  `make flutter-android-emacs-nw-build`, `make flutter-structure-check`,
  `flutter test test/widget_test.dart`, and `make
  flutter-android-emulator-smoke`. The final emulator run reached the first
  interactive frame with `elapsed_ms=1013`, suppressed `12875` startup bytes,
  and produced `iosmacs-android-file-ops-ok`.
- Added an Android NW pdumper route. `make
  flutter-android-emacs-nw-pdumper-build` builds `libemacs_nw.so` with
  pdumper support while still avoiding build-host dumping; the Android app then
  generates `files/iosmacs/emacs-pdmp/emacs.pdmp` inside the app sandbox and
  passes it to the PTY startup with `--dump-file`.
- Patched Android NW `loadup.el`/`lread.c` so target-side pdump generation can
  use the app-extracted Lisp root, find `../etc/DOC`, and write the pdmp to an
  app-private path instead of the read-only APK native-library directory.
- Extended `make flutter-android-emulator-smoke` with
  `IOSMACS_ANDROID_EXPECT_PDUMP=1`, which requires the pdump ready marker,
  `status=ok`, and a non-empty `emacs.pdmp`. The verified emulator run produced
  an 11,564,416 byte pdmp in 2328 ms, then reached the first interactive
  `*scratch*` frame through the pdmp route in `elapsed_ms=305` while suppressing
  only `469` startup bytes; file save/reopen/Dired proof still produced
  `iosmacs-android-file-ops-ok`.
- Added Android NW warm-relaunch pdmp proof. With
  `IOSMACS_ANDROID_EXPECT_PDUMP_REUSE=1`, the emulator smoke clears the pdmp
  before the cold launch, verifies generation, then force-stops and relaunches
  the app. The warm log must contain `iosmacs Android GNU Emacs NW pdump
  reused`, must not contain a new `pdump ready` marker, and must keep the pdmp
  status unchanged. The verified run generated the 11,564,416 byte pdmp in
  2432 ms, reached `*scratch*` in 302 ms on the cold pdmp launch, then reused
  the same pdmp and reached `*scratch*` in 315 ms on warm relaunch.
- Tightened Android NW startup success so the native bridge requires the first
  usable `*scratch*` frame instead of treating the `forkpty` start marker as
  enough. If a cached pdmp was used but the frame does not arrive, the bridge
  invalidates `files/iosmacs/emacs-pdmp/emacs.pdmp`, records
  `status=invalidated` with `reason=startup_failed`, and retries immediately
  without `--dump-file`.
- Added `IOSMACS_ANDROID_EXPECT_PDUMP_RECOVERY=1` to
  `make flutter-android-emulator-smoke`. The recovery path corrupts a valid
  cached pdmp, relaunches Android, and requires pdmp reuse, invalidation,
  retry-without-pdump, invalidated status, and live `*scratch*` evidence.
- Added `make flutter-android-parity-smoke`, which runs the Android emulator
  smoke with pdump generation, warm reuse, corrupt-pdump recovery, network, and
  the default workspace relaunch evidence enabled.
- Verified the pdump self-healing path with `make flutter-structure-check`,
  `make flutter-android-smoke`, and `make flutter-android-parity-smoke`. The
  parity run generated an 11,564,408 byte pdmp in 2425 ms, reached `*scratch*`
  in 317 ms on the cold pdmp launch, reused the pdmp and reached `*scratch*` in
  301 ms on warm relaunch, then recovered from a deliberately corrupted 30 byte
  cached pdmp by invalidating it and reaching `*scratch*` without pdmp in
  803 ms.

Flutter Android fallback surface reduction:

- Updated Android backend capabilities so the supported path names
  `Android GNU Emacs NW PTY terminal route` first, and the stateful frame
  renderer is no longer advertised as a supported user-facing Android feature.
  The capabilities dialog now keeps it on the diagnostic-only/unsupported side.
- Updated Android native fallback lifecycle messages so they no longer read like
  the primary terminal path when `libemacs_nw.so` is absent.
- Updated tests and structure guards around the new NW-first/fallback wording.
- Tightened `make flutter-android-emulator-smoke` so it requires the packaged NW
  route by default; `IOSMACS_ANDROID_REQUIRE_NW=0` is now the explicit fallback
  diagnostics mode.
- Extended the Android emulator smoke to enable workspace smoke and require
  list/import/open/export evidence while the NW route is active.
- Aligned Android native clipboard paste newline handling with the Flutter/iOS
  terminal-input contract: CRLF, lone CR, and LF are normalized to terminal CR
  before UTF-8 bytes are sent to Emacs, with a structure guard covering the
  Android bridge helper.
- Verified the Android paste-normalization update with `make
  flutter-structure-check`, full `flutter test`, `flutter analyze`, `git diff
  --check`, and `make flutter-android-smoke`.
- Added Android workspace exchange folder selection. `selectWorkspaceRoot` now
  opens `ACTION_OPEN_DOCUMENT_TREE`, persists the selected tree URI permission,
  imports non-directory documents recursively from that tree into the
  app-private workspace, reports it through the shared native-channel
  workspace-selection path, and `clearWorkspaceRoot` releases/removes that
  selection. The current Android Emacs `/home/user` remains app-private because
  SAF tree URIs are not direct POSIX directories for the NW Emacs process.
- Connected the selected Android exchange folder to Workspace Export. When a
  persisted tree URI exists, normal `exportWorkspace` creates/replaces the
  exported workspace file or zip inside that tree with `DocumentsContract`
  instead of opening a document-create picker; smoke/noninteractive export still
  uses the deterministic app-owned content provider.
- Expanded Android workspace zip export so app-private subdirectories such as
  `notes/` are included with relative paths instead of being silently omitted.
- Added non-destructive Android exchange-folder refresh sync. Workspace
  Refresh/list now imports files that are missing from the app-private workspace
  from the persisted SAF tree, including nested files, while skipping existing
  files so Emacs-side edits are not overwritten by a refresh. If the persisted
  SAF grant cannot be read, the app logs the sync failure and still lists the
  app-private workspace.
- Verified the recursive Android workspace exchange import/export and
  non-destructive refresh-sync work with `make flutter-structure-check`,
  targeted Flutter backend/screen tests, `flutter analyze`, `git diff --check`,
  full `flutter test`, and `make flutter-android-smoke`.
- Added Android network-permission parity for the NW Emacs route. The main
  Android manifest now declares `android.permission.INTERNET`, so release-style
  packages do not depend on debug/profile manifest overlays for Emacs network
  connections.
- Added an optional emulator Emacs network smoke gated by
  `IOSMACS_ANDROID_EXPECT_NETWORK=1`. When enabled,
  `scripts/run-flutter-android-emulator-smoke.sh` appends an Emacs Lisp
  `make-network-process` HTTP check to the existing Android file-ops smoke and
  requires `iosmacs-android-network-ok` in both the app-private marker and
  logcat evidence.
- Verified the Android network-permission and optional-smoke wiring with shell
  syntax checks, `make flutter-structure-check`, Android backend tests,
  `flutter analyze`, full `flutter test`, `git diff --check`, `make
  flutter-android-smoke`, and merged-manifest inspection for
  `android.permission.INTERNET`.
- Ran the network-enabled Android emulator smoke with
  `IOSMACS_ANDROID_EXPECT_NETWORK=1 make flutter-android-emulator-smoke`. The
  run used the packaged NW PTY route, reached the interactive `*scratch*` frame
  in `elapsed_ms=301`, produced `iosmacs-android-file-ops-ok`, and wrote
  `iosmacs-android-network-ok` to
  `flutter/build/android-emulator-smoke/android-network.marker` with matching
  logcat evidence.
- Added default Android workspace relaunch-persistence proof to
  `make flutter-android-emulator-smoke`. After the Emacs file-ops smoke saves
  and reopens `notes/iosmacs-android-file-smoke.txt`, the smoke now force-stops
  and relaunches the app, verifies the saved file still exists in app-private
  storage, and waits for workspace list/open smoke evidence after relaunch.
- Hardened Android workspace zip export after the first relaunch-persistence
  run exposed an Emacs `notes/.#iosmacs-android-file-smoke.txt` lock artifact
  that made export fail with `ENOENT`. Android export now skips Emacs `.#...`
  lock artifacts and missing entries before building the relative-path zip.
- Verified with shell syntax checks, `make flutter-structure-check`,
  `git diff --check`, and `make flutter-android-emulator-smoke`. The passing
  run exported `workspace-export.zip`, relaunched into NW `*scratch*` in
  `elapsed_ms=304`, preserved `iosmacs-android-file-smoke`, listed 7 workspace
  item(s), and reopened the workspace smoke file after relaunch.
- Aligned Android NW command discovery with the bundled iOS/macOS paths. The
  JNI PTY startup now passes an Emacs `--eval` form that clears
  `read-extended-command-predicate`, binds `M-X` to
  `execute-extended-command`, and autoloads `dired` and `tetris`.
- Extended the Android emulator smoke to write and require
  `iosmacs-android-commands-ok`, proving inside Android Emacs that `M-X` is
  bound correctly and that `dired`/`tetris` are both `commandp` and visible via
  `all-completions`. The verified run reached the first NW `*scratch*` frame in
  `elapsed_ms=301` and produced `iosmacs-android-commands-ok`; the relaunch
  leg also reached `*scratch*` in `elapsed_ms=301` and reopened the workspace
  smoke file.

Flutter Android GNU Emacs NW text-terminal display:

- Goal: bypass the `HAVE_ANDROID` text-terminal restriction and reach a state
  where real GNU Emacs displays in the Android emulator through the Flutter
  terminal widget.
- Added `scripts/iosmacs_ncurses_stub.c`: a minimal ncurses/termcap stub
  providing `tputs`, `tgetent`, `tgetstr`, `setupterm`, `tigetstr`, `tgoto`,
  `tparm`, and supporting functions hardcoded for xterm-256color.  This stub
  allows Emacs to be cross-compiled for Android without a real ncurses library.
- Added `scripts/build-flutter-android-emacs-nw.sh`: a new build script that
  cross-compiles GNU Emacs in NW (no-window-system) mode for Android ARM64
  using the NDK toolchain WITHOUT `--with-android`.  The resulting binary has
  no `HAVE_ANDROID` text-terminal restriction and can run via `forkpty()`.
  Key implementation steps:
  - Builds the ncurses stub as `libncurses.a`.
  - Patches `lib/faccessat.c` (gnulib AT_EACCESS EINVAL retry).
  - Patches `src/sysdep.c` (`sys_faccessat` AT_EACCESS EINVAL fallback):
    Android's Bionic `faccessat` returns EINVAL for the `AT_EACCESS` flag
    inside the app sandbox; the patch retries without `AT_EACCESS`.
  - Patches the gnulib SIG2STR_MAX gap for Android API 35.
  - Provides a macOS `bootstrap-emacs` wrapper (so the cross-build can
    byte-compile Lisp using the host macOS Emacs instead of the ARM64 binary).
  - Uses the host macOS `make-docfile` / `make-fingerprint` via shell wrappers.
  - Configures with `--with-dumping=none` so the ARM64 `emacs` binary (= temacs)
    is a self-contained interactive Emacs without a pdmp dump file.
  - Patches the generated `src/Makefile` to set `LIBS_TERMCAP=-lncurses`.
  - Outputs `libemacs_nw.so` into the shared Android jniLibs directory so
    Gradle packages it alongside `libemacs.so` and `libandroid-emacs.so`.
- Added `make flutter-android-emacs-nw-configure` and
  `make flutter-android-emacs-nw-build` Makefile targets.
- Updated `NwEmacsRuntime` Kotlin object in `MainActivity.kt`:
  - Detects the extracted `libemacs_nw.so` in `nativeLibraryDir`.
  - Extracts Emacs Lisp and etc assets from the APK to `filesDir/iosmacs/emacs-data/`
    on first launch, using a ZIP fallback when `AssetManager.list()` returns
    empty for compressed subdirectories (e.g. `etc/charsets/`).
  - Sets `EMACSLOADPATH`, `EMACSDATA`, `HOME`, `TMPDIR`, `TERM`, `TERMINFO`.
- Updated `AndroidNativeEmacsBridge.start()` to prefer the NW Emacs path when
  `libemacs_nw.so` is available, falling back to the HAVE_ANDROID build.
- Added `startNwEmacs` JNI function in `iosmacs_android_runtime.cpp`:
  uses `forkpty()` + `execv()` with the NW binary and an 8-second drain loop
  that returns output as soon as Emacs produces any terminal bytes.
- Added `aaptOptions { noCompress(".map") }` to `build.gradle.kts` so the
  charset map files are stored uncompressed in the APK and `AssetManager.list()`
  can enumerate them correctly.
- Updated `run-flutter-android-emulator-smoke.sh` to accept either the NW
  PTY session or the HAVE_ANDROID fallback path, and to confirm NW terminal
  output evidence when NW is active.
- Ran `flutter test`: passed, 81 tests.
- Ran `make flutter-android-emulator-smoke`: passed.
- Emulator screenshot confirms GNU Emacs displaying in the Flutter terminal:
  menu bar (`File Edit Options Buffers Tools Help`), `*scratch*` buffer,
  and mode line (`-=**-  F1  *scratch*  All  L2`) are all visible.
  Input smoke text (`iosmacs input smoke`) is inserted into `*scratch*`.

Flutter macOS bundled Emacs runtime:

- Starting the host-independent macOS Emacs runtime work.
- Goal for this unit: make `flutter run -d macos` use the Emacs runtime
  prepared by this repo, so the Flutter macOS app does not depend on
  `/usr/local/bin/emacs`, Homebrew Emacs, or Emacs.app being installed.
- Added `scripts/build-flutter-macos-emacs-runtime.sh` to build a macOS
  terminal Emacs from `wasmacs/vendor/emacs` and prepare
  `flutter/build/emacs-macos/runtime`.
- Built the runtime locally and verified the bundled executable can run in
  batch mode with repo-provided lisp/etc/libexec paths.
- Added a macOS Runner build phase that copies the runtime into
  `Contents/Resources/iosmacs-emacs`.
- Updated `MacOSNativeEmacsBridge` to prefer the bundled executable and to set
  runtime environment paths before launching Emacs through `forkpty(3)`.
- Updated macOS native smoke and structure checks to require bundled runtime
  evidence and reject automatic system Emacs candidates.

Flutter macOS Japanese input source and M-X:

- Starting macOS keyboard parity work after `flutter run -d macos` showed
  kana/eisu input-source switch warnings and `M-X tetris` still needed the iOS
  runtime binding.
- Added a macOS AppDelegate local key monitor for JIS `英数` keyCode 102 and
  `かな` keyCode 104. It selects `ABC` for English input and
  `Kotoeri.RomajiTyping.Japanese` for Hiragana, then consumes only those source
  switch key events.
- Added a macOS Emacs startup eval form that clears
  `read-extended-command-predicate`, binds `M-X` to
  `execute-extended-command`, and autoloads `dired` and `tetris`.
- Added a direct bundled-Emacs `M-X` / `tetris` batch check to the macOS native
  smoke before launching the Flutter app.
- Updated structure checks to guard the macOS TIS input-source bridge and the
  macOS `M-X`/`tetris` startup init.

Flutter Android native channel:

- Starting Android backend implementation after macOS bundled Emacs and input
  parity work.
- Goal for this unit: move Android beyond the Dart-only placeholder by adding a
  real Android Runner MethodChannel bridge while leaving the GNU Emacs NDK
  runtime as the next explicit surface.
- Replaced `AndroidEmacsBackend` internals with a wrapper over
  `NativeEmacsBackend`, keeping Android-specific capability text and backend id
  `android-native-channel`.
- Added `AndroidNativeEmacsBridge` in `MainActivity.kt` and registered it on
  `iosmacs/native_emacs`.
- Implemented Android native start/stop/redraw/sendBytes/resize/drainOutput,
  clipboard paste, app-private workspace list/import/export, and workspace
  root status methods.
- Stored Android workspace files under `filesDir/iosmacs/workspace` and
  imported content URIs through `contentResolver.openInputStream`.
- Updated Android autostart defaults, Android backend tests, widget/capability
  tests, and structure checks for the native-channel route.
- Ran targeted Flutter tests for Android/backend/widget/terminal screens:
  passed.
- Ran `make flutter-structure-check`: passed.
- Ran `make flutter-android-smoke`: passed after fixing clipboard access to
  use `ClipData.getItemAt(0)`.

Flutter Android emulator scratch smoke:

- Starting emulator bring-up after the Android native-channel bridge landed.
- Confirmed Android Studio is installed at
  `/Users/seijiro/Applications/Android Studio.app` and Flutter uses
  `/opt/homebrew/share/android-commandlinetools` as the Android SDK root.
- Installed the Android Emulator SDK package and Android 36 Google APIs ARM64
  system image.
- Created the local AVD `iosmacs_flutter_pixel` with the Pixel 7 device
  profile.
- Booted the AVD as `emulator-5554` and confirmed
  `sys.boot_completed=1` through ADB.
- Updated Android native-channel startup output so the terminal reaches a
  `Buffer: *scratch*   Mode: Lisp Interaction` screen while the real Android
  GNU Emacs NDK runtime remains explicitly pending.
- Added `make flutter-android-emulator-smoke`, which builds the APK, installs
  it onto the booted emulator, launches `MainActivity`, verifies `*scratch*`
  evidence in logcat, and saves a screenshot under
  `flutter/build/android-emulator-smoke/scratch.png`.
- After visual emulator inspection showed resize chatter filling the terminal
  body, changed Android resize handling to update status only and keep the
  `*scratch*` terminal output clean.
- Verified the cleaned Android emulator screen with `dart format`,
  `flutter analyze`, `flutter test`, `make flutter-structure-check`,
  `make flutter-android-smoke`, and `make flutter-android-emulator-smoke`.

Flutter Android terminal transport:

- Starting Android terminal transport expansion from the clean `*scratch*`
  emulator state.
- Changed `AndroidNativeEmacsBridge.sendBytes` so committed Flutter terminal
  bytes are rendered into the diagnostic terminal stream and can be drained
  back through `NativeEmacsBackend.outputStream`.
- Routed Android native clipboard paste through the same diagnostic terminal
  input renderer.
- Changed Android native redraw to rebuild the clean `*scratch*` screen rather
  than appending a placeholder line.
- Extended Android backend tests so `sendBytes` proves terminal echo output
  drains through the shared MethodChannel backend.
- Extended `make flutter-android-emulator-smoke` to build with Android
  capability, status, input, resize, and redraw smoke flags, then require those
  markers in logcat.
- Verified Android terminal transport with `dart format`, `flutter analyze`,
  `flutter test`, `make flutter-structure-check`, `make
  flutter-android-smoke`, and `make flutter-android-emulator-smoke`.
- Emulator logcat now shows `iosmacs-input-smoke`, terminal echo for
  `iosmacs input smoke`, resize smoke, and redraw smoke on
  `android-native-channel`; the saved screenshot shows redraw returning to the
  clean `*scratch*` prompt.

Flutter Android JNI runtime boundary:

- Starting the JNI/native-library boundary for Android before attempting the
  larger GNU Emacs NDK runtime build.
- Added an Android app CMake build and `iosmacs_android_runtime.cpp`.
- Added `libiosmacs_android_runtime.so` loading from the Android Runner.
- Moved diagnostic terminal rendering for start, redraw, `sendBytes`, and
  paste bytes behind JNI calls while keeping MethodChannel and workspace
  ownership in Kotlin.
- Updated Android capabilities and structure checks so the JNI runtime boundary
  is part of the guarded Android backend contract.
- Verified the JNI runtime boundary with `dart format`, `flutter analyze`,
  `flutter test`, `make flutter-structure-check`, `make
  flutter-android-smoke`, and `make flutter-android-emulator-smoke`.
- The Android APK now contains generated
  `libiosmacs_android_runtime.so` artifacts, and emulator logcat/screenshot
  show `Android JNI terminal runtime connected; GNU Emacs NDK core pending.`

Flutter Android terminal Emacs frame:

- Continuing Android work after the user asked to reach the point where the
  terminal displays an Emacs screen as the Android version.
- Changed the JNI renderer from one-shot diagnostic text into a stateful
  Android terminal frame renderer.
- `start` and `redraw` now emit `GNU Emacs 30.2 Android terminal frame`,
  `Buffer: *scratch*   Mode: Lisp Interaction`, a Lisp Interaction mode line,
  and the `* ` prompt.
- `sendBytes` and native clipboard paste now insert UTF-8 bytes into the
  JNI-side scratch buffer, handle returns as new lines, and redraw the frame so
  emulator smoke can prove input appears inside `*scratch*`.
- Updated Android backend capabilities, Dart tests, structure checks, and the
  emulator smoke expectations from the old JNI pending message to the Android
  Emacs terminal frame evidence.
- Verified with `dart format`, `flutter analyze`, `flutter test`, `make
  flutter-structure-check`, `make flutter-android-smoke`, and `make
  flutter-android-emulator-smoke`.
- Emulator evidence now shows `GNU Emacs 30.2 Android terminal frame`,
  `Buffer: *scratch*`, the Lisp Interaction mode line, `iosmacs input smoke`
  inserted into the scratch buffer, and generated
  `libiosmacs_android_runtime.so` artifacts for Android ABIs.

Flutter Android GNU Emacs NDK runtime:

- Started the next Android step after the JNI frame renderer: making the
  vendored GNU Emacs Android port reproducibly configurable from the repo.
- Added `scripts/build-flutter-android-emacs-runtime.sh` with local SDK/NDK
  detection, Android ABI/API knobs, NDK clang selection, NDK GNU Make
  selection, NDK LLVM binutils propagation, and a generated Java
  21-compatible `javac` wrapper.
- Added `make flutter-android-emacs-configure` for the passing configure-only
  path and `make flutter-android-emacs-runtime` for the full native library
  build probe.
- The configure probe targets
  `flutter/build/emacs-android/arm64-v8a` by default and records status under
  `flutter/build/emacs-android/arm64-v8a/iosmacs/android-emacs-runtime.status`.
- The full native-library build remains open: the current probe does not yet
  produce `libemacs.so` / `libandroid-emacs.so`; the observed blocker is the
  GNU Emacs Android cross build's gnulib timezone path on Android
  (`nstrftime.c`: undeclared `mktime_z`). The probe now gets past the earlier
  macOS `ar`/`ranlib` archive mismatch by forcing NDK `llvm-ar` and
  `llvm-ranlib`.
- Verified `make flutter-android-emacs-configure`: passed.
- Ran `make flutter-android-emacs-runtime`: expected failure, with
  `android-emacs-runtime.status` recording `blocker=GNU Emacs Android cross
  lib failed in nstrftime.c: undeclared mktime_z on Android.`
- Continued the runtime probe and moved the default Android NDK API to 35,
  which exposes `mktime_z` for the cross build.
- Added host-Lisp generation support through the repo-built macOS Emacs
  runtime, including `loaddefs.el`, Unicode generated Lisp, and portable
  `.elc` sync into the isolated Android source copy.
- Added an isolated build-tree patch for Android API 35's `SIG2STR_MAX`
  without `sig2str`/`str2sig` declaration gap.
- Serialized the final Android `install_temp` staging step to avoid the
  recursive Make `src/lisp.mk` generation race.
- `make flutter-android-emacs-runtime` now passes and produces
  `libemacs.so` and `libandroid-emacs.so` under
  `flutter/build/emacs-android/arm64-v8a/java/install_temp/lib/arm64-v8a`.
- Added optional Android Gradle `jniLibs` and `assets` source directories for
  the generated GNU Emacs Android runtime artifacts, plus native bridge status
  detection for packaged GNU Emacs NDK libraries.
- Filtered APK native-library packaging through `iosmacs/jniLibs/<abi>` so
  helper command shims from GNU Emacs `install_temp/lib` are not handed to
  Gradle's native-library strip step.
- Re-ran `make flutter-android-emulator-smoke`; the APK installed and launched
  on `emulator-5554`, logcat reported successful loads for `libemacs.so` and
  `libandroid-emacs.so`, and the scratch screenshot was captured at
  `flutter/build/android-emulator-smoke/scratch.png`.
- Extended the Android runtime target to build the upstream `org.gnu.emacs`
  Java classes, package them as `iosmacs/emacs-android-java.jar`, and feed that
  jar into Gradle when present.
- Updated the Android native bridge to reflectively load
  `org.gnu.emacs.EmacsNative` and call `getFingerprint()`. The emulator smoke
  now requires the resulting `iosmacs Android GNU Emacs Java bridge ready: ...`
  logcat evidence in addition to the native library load evidence.
- Patched upstream Android Java package-id constants in the isolated Emacs
  source copy so `EmacsApplication` and `EmacsNoninteractive` resolve the
  Flutter app package (`com.example.iosmacs_flutter` by default).
- Switched Android packaging to legacy extracted JNI libraries, allowing the
  app-private `libandroid-emacs.so` wrapper to exist as an executable path under
  the installed APK's native library directory.
- Extended `make flutter-android-emulator-smoke` to require
  `iosmacs Android GNU Emacs wrapper executable ready: .../libandroid-emacs.so`
  evidence from logcat.
- Added `admin/charsets` generation to the Android runtime build so
  `etc/charsets/8859-2.map` and sibling charset maps are staged into APK
  assets. This fixed the official wrapper's first subprocess blocker:
  `file-missing ("Loading charset map" ... "8859-2")`.
- Added a bounded app-side subprocess probe for the extracted
  `libandroid-emacs.so` wrapper with `EMACS_CLASS_PATH` pointing at the Flutter
  APK. The emulator now proves `app_process64 -> EmacsNoninteractive ->
  loadup.el -> --eval` reaches `iosmacs-android-emacs-process-probe`.
- Extended the emulator smoke to require
  `iosmacs Android GNU Emacs process probe: exit=0 marker=ok` evidence.
- Added a native Android PTY bridge inside `libiosmacs_android_runtime.so` and
  wired the Kotlin MethodChannel to launch the extracted upstream
  `libandroid-emacs.so` wrapper with `forkpty`.
- Emulator evidence now proves the wrapper starts under a PTY, then reports the
  upstream Android-port boundary:
  `Emacs does not work on text terminals when built to run as part of an
  Android application package.`
- Extended `make flutter-android-emulator-smoke` to require the PTY start
  evidence and the official text-terminal boundary evidence. The remaining
  integration path is therefore the official Android Emacs
  application/service event channel, not `-nw` terminal stdio.

## 2026-06-26

- Started the Flutter workstream beside the existing native iOS app.
- Confirmed that `flutter` and `dart` are not currently available in PATH, so
  this pass will add source files and static structure but cannot run Flutter
  tests locally yet.
- Added active TODO tracking to the root `PLAN.md` and the detailed
  `flutter/PLAN.md`.
- Added `flutter/iosmacs_flutter` with a first Flutter shell:
  - `EmacsBackend` Dart interface
  - `FakeEmacsBackend`
  - workspace entry model
  - first terminal screen
  - lifecycle and diagnostics strip
  - start, reset, workspace, and font-size controls
- Added fake-backend and widget tests for startup, deterministic output, input
  echo, resize, and workspace placeholder behavior.
- Marked completed TODOs in `PLAN.md` and `flutter/PLAN.md`.
- Added `make flutter-fake-smoke`, which runs `flutter pub get` and
  `flutter test` from `flutter/iosmacs_flutter` when the Flutter SDK is
  available.
- Ran `git diff --check`: passed.

Flutter Android backend placeholder:

- Starting Android backend placeholder work.
- Goal for this unit: make Android select an explicit backend strategy instead
  of falling through to the fake development backend.
- Planned checks: backend capability tests, factory default-selection tests,
  structure check, Flutter analysis/tests, Android debug APK smoke, and full
  Flutter verification.
- Added `AndroidEmacsBackend` with explicit Android capabilities, unsupported
  native/NDK Emacs diagnostics, and Android-safe workspace placeholders.
- Updated the backend factory so `TargetPlatform.android` selects the Android
  placeholder by default.
- Added Android backend and factory default-selection tests.
- Updated the Flutter structure check to guard the Android backend file, test,
  factory enum, and placeholder capability/path markers.
- Adjusted the app startup widget test to reflect Android default backend
  selection in Flutter tests.
- Ran `dart format lib test`: passed.
- Ran `make flutter-structure-check`: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 29 tests.
- Ran `make flutter-android-smoke`: passed.
- Ran `make flutter-verify`: passed.

Flutter Linux/Windows desktop backend placeholders:

- Starting Linux/Windows desktop backend placeholder work.
- Goal for this unit: make Linux and Windows select explicit desktop backend
  strategies instead of falling through to the fake development backend.
- Planned checks: desktop placeholder capability tests, factory
  default-selection tests, structure check, Flutter analysis/tests, and full
  Flutter verification.
- Added `DesktopEmacsBackend` for Linux and Windows placeholder routes.
- Added `BackendKind.linux` and `BackendKind.windows`, and default platform
  selection for `TargetPlatform.linux` and `TargetPlatform.windows`.
- Added Linux/Windows capability, startup diagnostic, workspace placeholder,
  and backend factory tests.
- Updated the Flutter structure check to guard the desktop placeholder file,
  tests, factory enum entries, and common desktop unsupported/path markers.
- Ran `dart format lib test`: passed.
- Ran `make flutter-structure-check`: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 34 tests.
- Ran `make flutter-verify`: passed.

Flutter capabilities UI proof:

- Starting capabilities UI proof work.
- Goal for this unit: make backend identity and capability counts visible in
  the Flutter UI, then prove the same dialog path works for non-fake backend
  placeholders.
- Planned checks: widget tests for Android and desktop placeholder capability
  dialogs, structure check, Flutter analysis/tests, and full Flutter
  verification.
- Added backend id plus supported/unsupported item counts to the capabilities
  dialog.
- Added widget coverage for Android, Linux, and Windows placeholder capability
  dialogs.
- Ran `dart format lib test`: passed.
- Ran `make flutter-structure-check`: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 36 tests.
- Ran `make flutter-verify`: passed.

Flutter runtime capabilities smoke:

- Starting runtime capabilities smoke work.
- Goal for this unit: make the selected backend capability identity visible in
  macOS native smoke logs, not only in widget tests.
- Planned checks: widget smoke coverage, structure check, macOS native smoke,
  and full Flutter verification.
- Added `IOSMACS_FLUTTER_CAPABILITIES_SMOKE` to the Flutter app root and
  `TerminalScreen`.
- The startup smoke now logs `iosmacs-capabilities-smoke:` with backend id,
  supported count, and unsupported count when mirroring is enabled.
- Enabled the capabilities smoke in `scripts/run-flutter-macos-native-smoke.sh`.
- Updated the macOS native smoke to require
  `id=platform-native-channel` plus nonzero supported/unsupported counts.
- Updated the Flutter structure check to guard the new flag and log markers.
- Updated widget startup smoke coverage to exercise the capabilities smoke path.
- Ran `dart format lib test`: passed.
- Ran `make flutter-structure-check`: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 36 tests.
- Ran `make flutter-macos-native-smoke`: passed.
- Ran `make flutter-verify`: passed.

Flutter backend override:

- Starting backend override work.
- Goal for this unit: allow runtime smoke/debug builds to force a specific
  backend through a dart-define instead of relying only on host platform
  default selection.
- Planned checks: backend override parsing tests, app construction tests,
  structure check, Flutter analysis/tests, and full Flutter verification.
- Added `IOSMACS_FLUTTER_BACKEND` as a Flutter app dart-define override.
- Added `backendKindFromName()` and `backendOverride` support in
  `createDefaultEmacsBackend()`.
- Supported override names include `fake`, `native`, `ios-native`,
  `macos-native`, `web-wasm`, `android`, `linux`, `windows`, and `win`.
- Unknown override names fall back to the platform default instead of throwing.
- Added factory tests for explicit override selection and unknown fallback.
- Added an app widget test proving `IOSMacsFlutterApp` can force the fake
  backend through the same constructor path used by runtime override wiring.
- Updated the Flutter structure check to guard the override flag, parser, and
  fallback test marker.
- Ran `dart format lib test`: passed.
- Ran `make flutter-structure-check`: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 39 tests.
- Ran `make flutter-verify`: passed.

Flutter architecture documentation sync:

- Starting architecture documentation sync work.
- Goal for this unit: align `flutter/ARCHITECTURE.md` with the backend
  boundary, runtime smoke flags, and verification targets that now exist.
- Planned checks: structure check and diff whitespace check.
- Updated `flutter/ARCHITECTURE.md` to describe the implemented
  `EmacsBackend` boundary, current backend classes, platform defaults, and
  `IOSMACS_FLUTTER_BACKEND` override names.
- Documented Flutter runtime smoke flags for autostart, terminal-output
  mirroring, workspace smoke, capabilities smoke, and backend override runs.
- Documented the current verification contract, including `make
  flutter-verify`, native smoke, backend override smoke, Web build smoke, and
  Android APK build smoke.
- Ran `make flutter-structure-check`: passed.
- Ran `git diff --check`: passed.

Flutter terminal input bridge:

- Starting terminal input validation work.
- Goal for this unit: make the Flutter terminal input byte boundary explicit
  and testable for xterm output, hardware/control-key strings, and
  IME-committed text.
- Planned checks: Dart format, Flutter tests, structure check, and diff
  whitespace check.
- Added `TerminalInputBridge` as the single Flutter UI path for terminal input
  strings and committed text before they cross into `EmacsBackend.sendBytes`.
- Updated `TerminalScreen` so `Terminal.onOutput` forwards through
  `sendTerminalOutput()` and the smoke input row forwards through
  `submitCommittedText()`.
- Added tests proving xterm-style control-key strings are forwarded as raw
  bytes, Japanese IME-committed text is encoded as UTF-8 plus carriage return,
  and empty input sends no backend bytes.
- Added the input bridge and its tests to `scripts/check-flutter-structure.sh`.
- Ran `dart format lib test`: passed.
- Ran `flutter test test/terminal_input_bridge_test.dart`: passed, 3 tests.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 42 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `git diff --check`: passed.

Flutter hardware keyboard shortcuts:

- Starting Flutter app-level hardware keyboard shortcut work.
- Goal for this unit: make the terminal controls reachable from a hardware
  keyboard without routing those app commands through the Emacs byte stream.
- Planned checks: Dart format, Flutter analyze, Flutter tests, structure check,
  and diff whitespace check.
- Wrapped the terminal screen in `CallbackShortcuts` and a focus scope so
  app-level commands can be handled independently from terminal byte input.
- Added Control+Shift and Meta+Shift shortcuts for Start, Reset, Workspace,
  Capabilities, font increase, and font decrease.
- Routed the toolbar and shortcuts through the same control methods so touch
  and hardware-keyboard paths stay aligned.
- Added widget coverage proving the shortcuts start the fake backend, request
  redraw, open workspace and capabilities dialogs, and adjust the font slider.
- Added structure-check guards for the shortcut surface and widget coverage.
- Ran `dart format lib test`: passed.
- Ran `flutter test test/terminal_screen_test.dart`: passed, 5 tests.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 43 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `git diff --check`: passed.

Flutter runtime input smoke:

- Starting runtime input smoke work.
- Goal for this unit: add a compile-time smoke flag that submits committed
  text through the same Flutter input bridge used by the terminal screen and
  records backend input-byte evidence in process logs.
- Planned checks: Dart format, Flutter analyze, Flutter tests, structure check,
  backend override smoke, macOS native smoke, and diff whitespace check.
- Added `IOSMACS_FLUTTER_INPUT_SMOKE` to the Flutter app root and terminal
  screen startup smoke path.
- The input smoke submits `iosmacs input smoke 日本語` through
  `TerminalInputBridge.submitCommittedText()` and logs
  `iosmacs-input-smoke:` evidence with committed byte count plus backend
  diagnostics input total.
- Added input smoke to `scripts/run-flutter-backend-override-smoke.sh` so fake,
  Android, Linux, Windows, and Web placeholder backends all prove nonzero input
  counters during runtime smoke.
- Added input smoke to `scripts/run-flutter-macos-native-smoke.sh` so the
  platform native channel path proves committed input reaches backend
  diagnostics during runtime smoke.
- Added structure-check guards for the input smoke flag, log marker, and script
  assertions.
- Updated the startup smoke widget test to enable input smoke and require
  backend input bytes to increase.
- Ran `dart format lib test`: passed.
- Ran `flutter test test/widget_test.dart`: passed, 3 tests.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 43 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `make flutter-backend-override-smoke`: passed for fake, Android, Linux,
  Windows, and Web-WASM backend overrides.
- Initial concurrent `make flutter-macos-native-smoke` run failed because it
  raced another Flutter macOS build while copying `FlutterMacOS.framework`.
- Re-ran `make flutter-macos-native-smoke` by itself: passed.
- Ran `git diff --check`: passed.
- Ran `make flutter-verify`: passed, including structure, doctor, fake tests,
  iOS launch smoke, macOS smoke, macOS native input smoke, backend override
  input smokes, Web debug build, and Android debug APK build.

Flutter runtime resize smoke:

- Starting runtime resize smoke work.
- Goal for this unit: add a compile-time smoke flag that sends terminal
  geometry through `EmacsBackend.resize()` at app startup and records backend
  resize diagnostics in process logs.
- Planned checks: Dart format, Flutter analyze, Flutter tests, structure check,
  backend override smoke, macOS native smoke, and diff whitespace check.
- Added `IOSMACS_FLUTTER_RESIZE_SMOKE` to the Flutter app root and terminal
  screen startup smoke path.
- The resize smoke sends fixed `100x30` geometry through
  `EmacsBackend.resize()` and logs `iosmacs-resize-smoke:` evidence with the
  requested geometry plus backend diagnostics geometry.
- Added resize smoke to `scripts/run-flutter-backend-override-smoke.sh` so
  fake, Android, Linux, Windows, and Web placeholder backend overrides all
  prove geometry forwarding during runtime smoke.
- Added resize smoke to `scripts/run-flutter-macos-native-smoke.sh` so the
  platform native channel path proves resize reaches backend diagnostics during
  runtime smoke.
- Added structure-check guards for the resize smoke flag, log marker, and
  script assertions.
- Updated the startup smoke widget test to enable resize smoke and require the
  backend diagnostics geometry to become `100x30`.
- Ran `dart format lib test`: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 43 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `make flutter-backend-override-smoke`: passed for fake, Android, Linux,
  Windows, and Web-WASM backend overrides.
- Ran `make flutter-macos-native-smoke`: passed.
- Ran `make flutter-verify`: passed, including resize smoke evidence in macOS
  native and backend override runtime smokes.

Flutter runtime redraw smoke:

- Starting runtime redraw smoke work.
- Goal for this unit: add a compile-time smoke flag that calls
  `EmacsBackend.resetOrRedraw()` at app startup and records backend redraw
  diagnostics in process logs.
- Planned checks: Dart format, Flutter analyze, Flutter tests, structure check,
  backend override smoke, macOS native smoke, and diff whitespace check.
- Added `IOSMACS_FLUTTER_REDRAW_SMOKE` to the Flutter app root and terminal
  screen startup smoke path.
- The redraw smoke calls `EmacsBackend.resetOrRedraw()` and logs
  `iosmacs-redraw-smoke:` evidence with the backend diagnostics message after
  redraw.
- Added redraw smoke to `scripts/run-flutter-backend-override-smoke.sh` so
  fake, Android, Linux, Windows, and Web placeholder backend overrides all
  prove reset/redraw forwarding during runtime smoke.
- Added redraw smoke to `scripts/run-flutter-macos-native-smoke.sh` so the
  platform native channel path proves redraw reaches backend diagnostics during
  runtime smoke.
- Added structure-check guards for the redraw smoke flag, log marker, and
  script assertions.
- Updated startup smoke widget coverage and added a focused redraw smoke widget
  test for the fake backend.
- Ran `dart format lib test`: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 44 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `make flutter-backend-override-smoke`: passed for fake, Android, Linux,
  Windows, and Web-WASM backend overrides.
- Ran `make flutter-macos-native-smoke`: passed.
- Ran `make flutter-verify`: passed, including redraw smoke evidence in macOS
  native and backend override runtime smokes.

Flutter runtime stop smoke:

- Starting runtime stop smoke work.
- Goal for this unit: add a compile-time smoke flag that calls
  `EmacsBackend.stop()` at app startup and records lifecycle stop evidence in
  process logs.
- Planned checks: Dart format, Flutter analyze, Flutter tests, structure check,
  backend override smoke, macOS native smoke, and diff whitespace check.
- Added `IOSMACS_FLUTTER_STOP_SMOKE` to the Flutter app root and terminal
  screen startup smoke path.
- The stop smoke calls `EmacsBackend.stop()` after the other enabled startup
  smokes and logs `iosmacs-stop-smoke:` evidence with the backend lifecycle
  state.
- Added stop smoke to `scripts/run-flutter-backend-override-smoke.sh` so fake,
  Android, Linux, Windows, and Web placeholder backend overrides all prove
  lifecycle stop forwarding during runtime smoke.
- Added stop smoke to `scripts/run-flutter-macos-native-smoke.sh` so the
  platform native channel path proves lifecycle stop during runtime smoke.
- Added structure-check guards for the stop smoke flag, log marker, and script
  assertions.
- Updated startup smoke widget coverage and added a focused stop smoke widget
  test for the fake backend.
- Ran `dart format lib test`: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 45 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `make flutter-backend-override-smoke`: passed for fake, Android, Linux,
  Windows, and Web-WASM backend overrides.
- Ran `make flutter-macos-native-smoke`: passed.
- Ran `make flutter-verify`: passed, including stop smoke evidence in macOS
  native and backend override runtime smokes.

Flutter runtime smoke documentation sync:

- Starting runtime smoke documentation sync work.
- Goal for this unit: align `flutter/ARCHITECTURE.md` with the current
  capabilities, input, resize, redraw, stop, workspace, and backend override
  smoke evidence.
- Planned checks: structure check and diff whitespace check.
- Updated `flutter/ARCHITECTURE.md` runtime smoke flags to include
  `IOSMACS_FLUTTER_INPUT_SMOKE`, `IOSMACS_FLUTTER_RESIZE_SMOKE`,
  `IOSMACS_FLUTTER_REDRAW_SMOKE`, and `IOSMACS_FLUTTER_STOP_SMOKE`.
- Updated the verification contract so macOS native smoke and backend override
  smoke describe their current capabilities, input, resize, redraw, stop, and
  workspace evidence.
- Ran `make flutter-structure-check`: passed.
- Ran `git diff --check`: passed.

Flutter backend override runtime smoke:

- Starting backend override runtime smoke work.
- Goal for this unit: prove `IOSMACS_FLUTTER_BACKEND` works in launched app
  binaries, not only in factory and widget tests.
- Planned checks: new macOS runtime override smoke, structure check, and full
  Flutter verification.
- Added `scripts/run-flutter-backend-override-smoke.sh`.
- Added `make flutter-backend-override-smoke` and included it in
  `make flutter-verify`.
- The override smoke builds and launches the macOS Runner with forced `fake`,
  `android`, `linux`, `windows`, and `web-wasm` backends.
- Each launch checks `iosmacs-capabilities-smoke:` for the expected backend id
  and nonzero supported/unsupported capability counts.
- Added structure checks for the new executable script, Makefile target,
  override backend list, and expected Web placeholder marker.
- Ran `make flutter-structure-check`: passed.
- Ran `make flutter-backend-override-smoke`: passed for fake, Android, Linux,
  Windows, and Web placeholder backends.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 39 tests.
- Ran `make flutter-verify`: passed.
- Ran `make flutter-fake-smoke`: stopped at the intended SDK boundary with
  `error: flutter command not found; install Flutter SDK or add it to PATH`.
- Remaining blocker: run `flutter pub get`, `flutter test`, and simulator
  launch checks after the Flutter SDK is available in PATH.

Continuation:

- Continuing with SDK-independent Phase 2 groundwork.
- Next unit: add backend selection and structured diagnostics so the Flutter UI
  remains bound to `EmacsBackend` instead of concrete platform backend classes.
- Added `BackendDiagnostics` with lifecycle-adjacent status text, terminal
  geometry, input/output byte counters, and workspace action counters.
- Added `backend_factory.dart` with the first explicit `BackendKind.fake`
  selection point.
- Updated the Flutter app root to construct backends through
  `createEmacsBackend()` rather than `FakeEmacsBackend` directly.
- Updated terminal diagnostics display to render the structured diagnostics
  summary.
- Expanded fake-backend tests for byte counters, geometry, workspace action
  counters, and backend factory selection.
- Next unit: add an SDK-independent structure check so CI or a fresh checkout
  can verify the Flutter shell boundary even before Flutter is installed.
- Added `scripts/check-flutter-structure.sh` and `make flutter-structure-check`.
- Ran `make flutter-structure-check`: passed.
- Next unit: add a reproducible Flutter SDK bootstrap target for generated iOS,
  macOS, Android, Linux, Windows, and Web runner files.
- Added `make flutter-bootstrap`, which runs `flutter create .` in the Flutter
  app directory with iOS, Android, macOS, Linux, Windows, and Web platforms.
- Ran `make flutter-bootstrap`: stopped at the intended SDK boundary with
  `error: flutter command not found; install Flutter SDK or add it to PATH`.
- Ran `make help`: confirmed the Flutter structure, bootstrap, and fake smoke
  targets are listed.
- Re-ran `make flutter-structure-check`: passed.
- Re-ran `make flutter-fake-smoke`: still stops at the intended SDK boundary.
- Re-ran `git diff --check`: passed.

SDK installation:

- Installed Flutter SDK stable under `/Users/seijiro/work/flutter`.
- `flutter --version`: Flutter 3.44.4, Dart 3.12.2.
- Added `/Users/seijiro/work/flutter/bin` to `/Users/seijiro/.zshrc`.
- Verified a new interactive zsh resolves
  `/Users/seijiro/work/flutter/bin/flutter`.
- Ran `flutter doctor -v`: Flutter, Xcode, Chrome, connected iPad simulator,
  macOS, Chrome, and network resources are detected; Android SDK and CocoaPods
  remain missing.
- Ran `make flutter-bootstrap`: generated iOS, Android, macOS, Linux, Windows,
  and Web runner files.
- Replaced Flutter template counter smoke with an iosmacs terminal-screen smoke.
- Ran `make flutter-fake-smoke`: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter build macos --debug`: passed.
- Ran `flutter build web --debug`: passed.
- Ran `flutter build ios --simulator --debug`: passed.
- Ran `flutter run -d macos --debug`: launched to a Dart VM Service, then
  stopped it with `q`. Flutter reported `Failed to foreground app; open
  returned 1`, but the runtime started and exposed the service.
- Ran `flutter run -d D0F9B2BE-1CD0-49D6-BC25-6FF7650031D6 --debug`: launched
  on the iPad simulator to a Dart VM Service, then stopped it with `q`.
- Expanded `scripts/check-flutter-structure.sh` to include generated iOS,
  Android, macOS, Linux, Windows, and Web runner files.
- Re-ran `make flutter-structure-check`: passed with generated runner checks.
- Re-ran `make flutter-fake-smoke`: passed.
- Re-ran `git diff --check`: passed.

Worker boundary:

- Starting Phase 2 backend worker split.
- Goal for this unit: keep `EmacsBackend` as the UI-facing API while moving the
  fake backend's command handling behind a worker-shaped command/event boundary.
- Added `backend_worker.dart` with worker command, event, result, and interface
  types.
- Added `fake_backend_worker.dart`; fake lifecycle, terminal output, input echo,
  resize, diagnostics, and workspace placeholder behavior now live behind the
  worker boundary.
- Updated `FakeEmacsBackend` to adapt worker events into the UI-facing
  `EmacsBackend` API.
- Added `fake_backend_worker_test.dart` for lifecycle, output, resize, input,
  and workspace command results.
- Updated `scripts/check-flutter-structure.sh` to require the worker files and
  worker tests.
- Ran `dart format lib test`: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 10 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `make flutter-fake-smoke`: passed, 10 tests.
- Ran `flutter build macos --debug`: passed.
- Ran `flutter build ios --simulator --debug`: passed.
- Ran `flutter build web --debug`: passed.
- Ran `git diff --check`: passed.

Backend capabilities complete:

- Added `BackendCapabilities` for backend identity, supported features, and
  unsupported features.
- Extended `EmacsBackend` with a `capabilities` getter.
- Updated `FakeEmacsBackend` to report deterministic fake-supported behavior
  and explicit unsupported native/runtime surfaces.
- Added a terminal toolbar Capabilities action and dialog.
- Updated the Flutter structure check to require the capability contract.
- Added tests for fake backend capability values and UI display.
- Updated `Makefile` Flutter targets to find the SDK at `~/work/flutter` during
  non-interactive `make` runs.
- Ran `dart format lib test`: passed.
- Ran `flutter analyze`: passed. A first parallel attempt hit Flutter startup
  lock contention, then passed when run alone.
- Ran `flutter test`: passed, 11 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `make flutter-fake-smoke`: passed, 11 tests.
- Ran `flutter build macos --debug`: passed.
- Ran `flutter build web --debug`: passed.
- Ran `flutter build ios --simulator --debug`: passed.
- Ran `flutter build apk --debug`: passed.
- Ran `make flutter-doctor`: first failed after a Makefile PATH adjustment
  masked `mise` Ruby/CocoaPods; fixed `flutter-doctor` to preserve `mise exec`
  PATH and re-ran successfully with no issues.

iOS native backend channel:

- Starting an iOS native backend channel scaffold.
- Goal for this unit: add a Dart/iOS MethodChannel boundary and explicit
  unsupported diagnostics before wiring the existing native Emacs core.
- Added `NativeEmacsBackend`, which implements `EmacsBackend` over the
  `iosmacs/native_emacs` MethodChannel.
- Added iOS-only default backend selection through `createDefaultEmacsBackend`;
  fake backend remains the default on non-iOS and web targets.
- Updated `main.dart` to use platform-aware default backend selection.
- Added an iOS Runner channel handler in `AppDelegate.swift`.
- The iOS channel currently returns `native_emacs_not_connected` for known
  native backend methods until the existing Emacs bridge is wired in.
- Added native backend tests for capabilities and unsupported diagnostics.
- Added factory tests for explicit native backend creation and iOS-only default
  selection.
- Updated the Flutter structure check to require the native backend scaffold and
  iOS channel registration.
- Ran `dart format lib test`: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 15 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `make flutter-fake-smoke`: passed, 15 tests.
- Ran `flutter build ios --simulator --debug`: passed.
- Ran `flutter build macos --debug`: passed.
- Ran `flutter build web --debug`: passed.
- Ran `flutter build apk --debug`: passed.
- Ran `make flutter-doctor`: passed with no issues.

Shared host facade:

- Starting shared C host facade integration for the Flutter iOS Runner.
- Goal for this unit: make the Flutter MethodChannel bridge use the same
  terminal input/output/resize facade as the existing native iosmacs app.
- Added `iosmacs/Host/iosmacs_host_facade.c` to the Flutter iOS Runner target.
- Exposed `iosmacs_host_facade.h` through `Runner-Bridging-Header.h`.
- Replaced the Runner-local Swift output buffer with
  `iosmacs_os_terminal_write` and `iosmacs_os_terminal_drain_output`.
- Routed Flutter input and resize calls through
  `iosmacs_os_terminal_push_input` and `iosmacs_os_terminal_resize`.
- Updated the Flutter structure check to require the shared facade source,
  bridging header include, and facade-backed bridge calls.
- Ran `dart format lib test`: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 16 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `flutter build ios --simulator --debug`: passed.
- Ran `make flutter-fake-smoke`: passed, 16 tests.
- Ran `flutter build web --debug`: passed.
- Ran `flutter build apk --debug`: passed.
- First parallel `flutter build macos --debug` hit an Xcode Swift Package
  Manager resolution error; re-ran alone and it passed.
- Ran `make flutter-doctor`: passed with no issues.

Shared diagnostic terminal:

- Starting shared Emacs diagnostic/core availability integration for the
  Flutter iOS Runner.
- Goal for this unit: run the existing C diagnostic terminal through the
  Flutter native bridge while keeping real GNU Emacs core startup explicitly
  pending until the static archive/link step is ported.
- Added `iosmacs_emacs_diagnostic.c`, `iosmacs_emacs_core.c`, and
  `iosmacs_terminal_shim.c` to the Flutter iOS Runner target.
- Exposed diagnostic, core, host facade, and terminal shim headers through the
  Runner bridging header.
- Updated `FlutterNativeEmacsBridge` to start
  `iosmacs_emacs_diagnostic_start()` and pump
  `iosmacs_emacs_diagnostic_pump()` after Flutter input bytes.
- Added an optional-entry mode to `iosmacs_emacs_core.c` so the Flutter Runner
  can compile core availability without requiring the real simulator Emacs
  entry link yet.
- Added Runner build settings for the shared source header paths and optional
  core entry macro.
- Added a Flutter Runner build phase for the existing Emacs static probe so the
  archive remains prepared for the next link step.
- Updated the structure check for diagnostic/core/shim source registration,
  bridging header exposure, optional-entry macro, and static probe build phase.
- Ran `flutter build ios --simulator --debug`: passed after adding optional
  core entry mode.
- Ran `dart format lib test`: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 16 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `make flutter-fake-smoke`: passed, 16 tests.
- Ran `flutter build web --debug`: passed.
- Ran `flutter build apk --debug`: passed.
- First parallel `flutter build macos --debug` hit a Flutter startup-lock
  cleanup error; re-ran alone and it passed.
- Ran `make flutter-doctor`: passed with no issues.
- Ran `make app`: passed, including existing native iOS app build.

Flutter simulator Emacs archive link:

- Starting simulator archive entry linking for the Flutter iOS Runner.
- Goal for this unit: make the Flutter Runner resolve `iosmacs_emacs_main`
  from `libiosmacs-temacs.a` instead of relying on optional-entry pending mode.
- Added `-u _iosmacs_emacs_main` to the Flutter Runner simulator linker flags
  so the static archive entry object is pulled from `libiosmacs-temacs.a`.
- Removed `IOSMACS_EMACS_CORE_ENTRY_OPTIONAL=1` from the Flutter Runner target.
- Set the Flutter iOS Runner target `ARCHS` to `arm64`, matching the existing
  simulator Emacs static archive.
- Updated the structure check to require the `_iosmacs_emacs_main` linker
  reference, arm64 Runner target, and absence of optional-entry mode.
- Ran `flutter build ios --simulator --debug`: passed.
- Verified `build/ios/iphonesimulator/Runner.app/Runner.debug.dylib` exports
  `_iosmacs_emacs_main` and `_iosmacs_emacs_core_link_available` with `nm`.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 16 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `make app`: passed, including the existing native iOS app build.
- Ran `flutter build macos --debug`: passed.
- Ran `flutter build web --debug`: passed.
- Ran `flutter build apk --debug`: passed.
- Ran `make flutter-doctor`: passed with no issues.
- Ran `git diff --check`: passed.

Flutter native Emacs resource/startup:

- Starting Flutter native Emacs resource/startup wiring.
- Goal for this unit: make the Flutter iOS Runner bundle the same Emacs runtime
  resources as the native app and have the native channel start linked GNU Emacs
  when those resources are present.
- Added `lisp`, `etc`, `lib-src`, and `emacs.pdmp` to the Flutter iOS Runner
  resource phase.
- Updated `FlutterNativeEmacsBridge.start()` to call
  `iosmacs_emacs_core_start()` with Bundle resource paths and a default
  Documents/home workspace.
- Preserved the shared diagnostic terminal as an explicit fallback when linked
  core startup or required resources are unavailable.
- Updated native backend capability text to advertise iOS simulator GNU Emacs
  startup and native terminal byte flow.
- Updated the structure check to require Flutter Runner Emacs resources and the
  real startup call.
- Ran `make flutter-structure-check`: passed.
- Ran `dart format lib test` with `~/work/flutter/bin` on PATH: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 16 tests.
- Ran `flutter build ios --simulator --debug`: passed.
- Verified `Runner.app` contains `emacs.pdmp`, `lisp`, `etc`, and `lib-src`.
- Ran `make app`: passed, including existing native iOS app build.
- Ran `flutter build web --debug`: passed.
- Ran `flutter build macos --debug`: passed.
- Ran `flutter build apk --debug`: passed.
- Ran `make flutter-doctor`: passed with no issues through mise/CocoaPods.
- Ran `git diff --check`: passed.

Flutter native workspace:

- Starting Flutter native workspace wiring.
- Goal for this unit: replace the native channel workspace placeholders with
  app-container file operations while keeping Dart free of editor semantics.
- Implemented Runner-side `listWorkspace` against the default Documents/home
  app-container workspace.
- Implemented Runner-side `importWorkspace` by copying file URLs into
  Documents/home and replacing same-name destination items.
- Implemented Runner-side `exportWorkspace` by returning workspace item file
  URLs, or the workspace root when empty.
- Updated `NativeEmacsBackend` to parse native workspace entry maps, import
  counts, and export URL strings.
- Updated native backend capabilities to advertise app-container workspace
  list/import/export.
- Added Flutter tests for native workspace list/import/export MethodChannel
  results.
- Updated `make flutter-structure-check` to guard native workspace wiring.
- Ran `dart format lib test` with `~/work/flutter/bin` on PATH: passed.
- Ran `flutter analyze`: passed.
- Ran `make flutter-structure-check`: passed.
- Ran `flutter test`: passed, 17 tests.
- Ran `flutter build ios --simulator --debug`: passed.
- Ran `make app`: passed, including existing native iOS app build.
- Ran `flutter build web --debug`: passed.
- First parallel `flutter build macos --debug` hit a Flutter ephemeral package
  cleanup error; re-ran alone and it passed.
- Ran `flutter build apk --debug`: passed.
- Ran `make flutter-doctor`: passed with no issues through mise/CocoaPods.
- Ran `git diff --check`: passed.

Flutter workspace UI:

- Starting workspace UI wiring.
- Goal for this unit: surface the implemented workspace list/export backend
  APIs in the Flutter terminal screen without moving Emacs editor semantics into
  Dart.
- Replaced the toolbar workspace count SnackBar with a dialog listing workspace
  entries.
- Workspace rows now show file/directory icon, name, backend path, and size
  label.
- Added an Export action that calls `exportWorkspaceSelection()` and reports the
  number of export candidate URLs.
- Added a widget test for visible workspace entries and export result feedback.
- Updated `make flutter-structure-check` to guard the workspace dialog/export
  UI path.
- First `flutter analyze` caught an async `BuildContext` warning in the export
  action; fixed it by capturing the `NavigatorState` before awaiting.
- Ran `dart format lib test` with `~/work/flutter/bin` on PATH: passed.
- Ran `make flutter-structure-check`: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 18 tests.
- Ran `flutter build ios --simulator --debug`: passed.
- Ran `make app`: passed, including existing native iOS app build.
- Ran `flutter build macos --debug`: passed.
- Ran `flutter build web --debug`: passed.
- Ran `flutter build apk --debug`: passed.
- Ran `make flutter-doctor`: passed with no issues through mise/CocoaPods.
- Ran `git diff --check`: passed.

Flutter iOS smoke target:

- Starting repeatable Flutter iOS smoke target work.
- Goal for this unit: make the Flutter iOS simulator build evidence reusable by
  checking the built Runner bundle resources and linked GNU Emacs entry symbol
  through a repository make target.
- Added `scripts/check-flutter-ios-runner-smoke.sh`.
- The smoke script builds the Flutter iOS simulator app, checks `Runner.app` for
  `lisp`, `etc`, `lib-src`, and `emacs.pdmp`, and checks
  `Runner.debug.dylib` for `_iosmacs_emacs_main` and
  `_iosmacs_emacs_core_link_available`.
- Added `make flutter-ios-smoke`.
- Updated `make flutter-structure-check` to guard the smoke script and Makefile
  target.
- Ran `bash -n scripts/check-flutter-ios-runner-smoke.sh
  scripts/check-flutter-structure.sh`: passed.
- Ran `make flutter-structure-check`: passed.
- Ran `dart format lib test` with `~/work/flutter/bin` on PATH: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 18 tests.
- Ran `make flutter-ios-smoke`: passed.
- Ran `make app`: passed, including existing native iOS app build.
- Ran `flutter build macos --debug`: passed.
- Ran `flutter build web --debug`: passed.
- Ran `flutter build apk --debug`: passed.
- Ran `make flutter-doctor`: passed with no issues through mise/CocoaPods.
- Ran `git diff --check`: passed.

Flutter iOS launch smoke:

- Starting repeatable Flutter iOS launch smoke work.
- Goal for this unit: prove the Flutter iOS Runner can be installed, launched,
  kept alive briefly, and terminated on a booted simulator through a repository
  make target.
- Added `scripts/run-flutter-ios-launch-smoke.sh`.
- The launch smoke reuses `scripts/check-flutter-ios-runner-smoke.sh`, installs
  `Runner.app` on a booted simulator, reads the bundle id from `Info.plist`,
  launches it with `xcrun simctl launch`, waits briefly, and requires clean
  termination.
- Added `make flutter-ios-launch-smoke`.
- Updated `make flutter-structure-check` to guard the launch smoke script and
  Makefile target.
- Ran `bash -n scripts/run-flutter-ios-launch-smoke.sh
  scripts/check-flutter-ios-runner-smoke.sh scripts/check-flutter-structure.sh`:
  passed.
- Ran `make flutter-structure-check`: passed.
- Ran `dart format lib test` with `~/work/flutter/bin` on PATH: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 18 tests.
- Ran `make flutter-ios-launch-smoke`: passed and launched
  `com.example.iosmacsFlutter` on the booted iPad simulator before clean
  termination.
- Ran `make app`: passed, including existing native iOS app build.
- Ran `flutter build macos --debug`: passed.
- First parallel `flutter build web --debug` hit a Flutter ephemeral package
  cleanup error; re-ran alone and it passed.
- Ran `flutter build apk --debug`: passed.
- Ran `make flutter-doctor`: passed with no issues through mise/CocoaPods.
- Ran `git diff --check`: passed.

Flutter macOS smoke:

- Starting repeatable Flutter macOS smoke work.
- Goal for this unit: prove the Flutter macOS desktop app can be built,
  launched briefly, stay alive, and terminate cleanly through a repository make
  target.
- Added `scripts/run-flutter-macos-smoke.sh`.
- The macOS smoke builds the Flutter macOS debug app, checks the
  `iosmacs_flutter.app` bundle and executable, launches the executable briefly,
  and requires clean termination.
- Added `make flutter-macos-smoke`.
- Updated `make flutter-structure-check` to guard the macOS smoke script and
  Makefile target.
- Ran `bash -n scripts/run-flutter-macos-smoke.sh
  scripts/run-flutter-ios-launch-smoke.sh scripts/check-flutter-ios-runner-smoke.sh
  scripts/check-flutter-structure.sh`: passed.
- Ran `make flutter-structure-check`: passed.
- Ran `dart format lib test` with `~/work/flutter/bin` on PATH: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 18 tests.
- Ran `make flutter-macos-smoke`: passed.
- Ran `make flutter-ios-launch-smoke`: passed.
- Ran `make app`: passed, including existing native iOS app build.
- Ran `flutter build web --debug`: passed.
- Ran `flutter build apk --debug`: passed.
- Ran `make flutter-doctor`: passed with no issues through mise/CocoaPods.
- Ran `git diff --check`: passed.

Flutter verification target:

- Starting repeatable Flutter verification target work.
- Goal for this unit: add a single Flutter workstream verification target that
  runs the structure, doctor, fake backend, iOS launch, and macOS smoke checks
  sequentially.
- Added `make flutter-verify`.
- `flutter-verify` runs `flutter-structure-check`, `flutter-doctor`,
  `flutter-fake-smoke`, `flutter-ios-launch-smoke`, and `flutter-macos-smoke`
  sequentially to avoid Flutter startup-lock contention.
- Updated `make flutter-structure-check` to guard the verification target.
- Ran `bash -n` for the Flutter smoke scripts and structure check: passed.
- Ran `make flutter-structure-check`: passed.
- Ran `dart format lib test` with `~/work/flutter/bin` on PATH: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 18 tests.
- Ran `make flutter-verify`: passed.
- Ran `make app`: passed, including existing native iOS app build.
- Ran `flutter build web --debug`: passed.
- Ran `flutter build apk --debug`: passed.
- Ran `git diff --check`: passed.

Flutter Web/Android smoke:

- Starting repeatable Flutter Web/Android smoke work.
- Goal for this unit: move the manually repeated Web debug and Android APK
  debug builds behind repository make targets and include them in
  `make flutter-verify`.
- Added `make flutter-web-smoke` for `flutter build web --debug`.
- Added `make flutter-android-smoke` for `flutter build apk --debug`.
- Included both new smoke targets in `make flutter-verify`.
- Updated the Flutter structure check to guard the Web/Android smoke targets
  and their underlying Flutter build commands.
- Ran `make flutter-structure-check`: passed.
- Ran `dart format lib test`: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 18 tests.
- Ran expanded `make flutter-verify`: passed.
- Ran `make app`: passed, including existing native iOS app build.
- Ran `git diff --check`: passed.

Flutter macOS native channel:

- Starting macOS native channel work.
- Goal for this unit: let macOS select the same Dart MethodChannel backend
  behind `EmacsBackend`, while the macOS Runner reports explicit pending
  diagnostics until a PTY/process Emacs backend is implemented.
- Renamed the Dart native backend capability identity from iOS-only wording to
  `platform-native-channel`.
- Added `BackendKind.macosNative` and made macOS non-web select the shared
  native MethodChannel backend by default.
- Added `MacOSNativeEmacsBridge.swift` to the macOS Runner target.
- Registered `iosmacs/native_emacs` from `MainFlutterWindow.swift`.
- The macOS bridge now handles start, stop, redraw, sendBytes, resize,
  drainOutput, listWorkspace, importWorkspace, and exportWorkspace with
  explicit PTY/process-backend pending diagnostics.
- Updated structure checks to guard the macOS native bridge and channel
  registration.
- Updated tests for macOS default backend selection and shared native-channel
  capabilities.
- First parallel `flutter analyze`/`flutter test` attempt collided with a
  concurrent Flutter startup lock while `make flutter-macos-smoke` was running.
- Re-ran `flutter analyze` sequentially: passed.
- Re-ran `flutter test` sequentially: passed, 19 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `make flutter-macos-smoke`: passed.
- Ran expanded `make flutter-verify`: passed.

Flutter macOS process probe:

- Starting macOS Emacs process probe work.
- Goal for this unit: run a short discoverable Emacs batch process from the
  macOS native MethodChannel when allowed, surface stdout/stderr to Flutter,
  and keep interactive PTY support explicitly pending.
- Added deterministic Emacs executable candidates in the macOS Runner:
  `IOSMACS_FLUTTER_EMACS`, `/usr/local/bin/emacs`, `/opt/homebrew/bin/emacs`,
  `/Applications/Emacs.app/Contents/MacOS/Emacs`, and
  `/Applications/Emacs-takaxp/Emacs.app/Contents/MacOS/Emacs`.
- The macOS bridge now runs `emacs --batch --quick --eval` on `start` and
  writes stdout, stderr, exit status, or launch failures into the terminal
  output buffer.
- Successful batch probes emit `iosmacs-macos-process-ok`.
- Interactive PTY GNU Emacs remains explicitly pending after the process probe.
- `NativeEmacsBackend` now applies native `lifecycleState`, `cols`, and `rows`
  payloads to diagnostics.
- Added a test for native status payload handling.
- Updated structure checks for the macOS process probe markers.
- Ran `dart format lib test`: passed.
- Ran `make flutter-structure-check`: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 20 tests.
- Ran `make flutter-macos-smoke`: passed.
- Ran expanded `make flutter-verify`: passed.

Flutter macOS process probe runtime smoke:

- Starting runtime smoke work for the macOS Emacs process probe.
- Goal for this unit: make the macOS app start the native backend during a
  smoke build and mirror terminal output into a log so the process probe can be
  verified without manual Start-button interaction.
- Added `IOSMACS_FLUTTER_AUTOSTART_NATIVE` to start the selected backend at app
  launch in smoke builds.
- Added `IOSMACS_FLUTTER_MIRROR_TERMINAL_OUTPUT` to mirror terminal output
  chunks into the app process log.
- Added `scripts/run-flutter-macos-native-smoke.sh`.
- Added `make flutter-macos-native-smoke`.
- Included `make flutter-macos-native-smoke` in `make flutter-verify`.
- Updated `make flutter-structure-check` to guard the smoke script, Makefile
  target, and Flutter smoke hooks.
- Added a widget test for app-level autostart smoke behavior.
- Ran `dart format lib test`: passed.
- Ran `make flutter-structure-check`: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 21 tests.
- Ran `make flutter-macos-native-smoke`: passed.
- The macOS native smoke log shows `/usr/local/bin/emacs` exited 1, then
  `/Applications/Emacs-takaxp/Emacs.app/Contents/MacOS/Emacs` emitted
  `iosmacs-macos-process-ok`; the log also preserves the interactive PTY
  pending marker.
- Ran expanded `make flutter-verify`: passed.

Flutter macOS workspace:

- Starting macOS workspace bridge work.
- Goal for this unit: replace macOS native workspace pending errors with
  sandboxed Application Support workspace list/import/export operations.
- Implemented `listWorkspace`, `importWorkspace`, and `exportWorkspace` in
  `MacOSNativeEmacsBridge`.
- The macOS workspace root is created under Application Support at
  `iosmacs_flutter/workspace`.
- Workspace entries return name, path, directory flag, and byte size.
- `importWorkspace` copies passed file URLs into the sandbox workspace and
  replaces existing same-name items.
- `exportWorkspace` returns workspace item file URLs, or the workspace root
  when no entries exist.
- Updated backend capabilities to include `macOS sandbox workspace
  list/import/export`.
- Updated structure checks for macOS workspace methods and the Application
  Support workspace root.
- Ran `dart format lib test`: passed.
- Ran `make flutter-structure-check`: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 21 tests.
- Ran `make flutter-macos-smoke`: passed.
- Ran `make flutter-macos-native-smoke`: passed.
- Ran expanded `make flutter-verify`: passed.

Flutter macOS workspace runtime smoke:

- Starting runtime smoke work for macOS workspace MethodChannel operations.
- Goal for this unit: exercise workspace list/export from the running Flutter
  macOS app and verify the result through captured process logs.
- Added `IOSMACS_FLUTTER_WORKSPACE_SMOKE` to run workspace list/export at app
  launch.
- Workspace smoke mirrors result counts as `iosmacs-workspace-smoke:` process
  log lines.
- Extended `scripts/run-flutter-macos-native-smoke.sh` to pass
  `IOSMACS_FLUTTER_WORKSPACE_SMOKE=true`.
- Extended the native smoke script to require workspace list/export evidence
  in the captured log.
- Added widget coverage for app-level autostart plus workspace smoke behavior.
- Ran `dart format lib test`: passed.
- Ran `make flutter-structure-check`: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 21 tests.
- Ran `make flutter-macos-native-smoke`: passed.
- The latest native smoke log includes `iosmacs-macos-process-ok`,
  `Interactive PTY GNU Emacs backend is pending`, `workspace listed 0 item(s)`,
  and `workspace export candidate(s): 1`.
- Ran expanded `make flutter-verify`: passed.

Flutter macOS workspace import smoke:

- Starting workspace import runtime smoke work.
- Goal for this unit: create a smoke import file on IO-capable platforms, call
  `importWorkspace`, then verify list/export evidence through the macOS native
  smoke log while preserving Web builds.
- Added a conditional `workspace_smoke_file.dart` export with an IO
  implementation and a non-IO stub.
- The IO implementation creates a temporary `workspace-smoke.txt` file for
  import smoke.
- Startup workspace smoke now runs list, import, list-after-import, and export
  in sequence.
- Extended `scripts/run-flutter-macos-native-smoke.sh` to require
  `workspace imported 1 item(s)` and `workspace listed after import`.
- Updated structure checks for the conditional smoke helper and new log checks.
- Adjusted widget coverage to inject a deterministic import URI.
- Ran `dart format lib test`: passed.
- Ran `make flutter-structure-check`: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 21 tests.
- Ran `make flutter-macos-native-smoke`: passed.
- Ran `make flutter-web-smoke`: passed.
- The latest native smoke log includes `iosmacs-macos-process-ok`,
  `workspace listed 1 item(s)`, `workspace imported 1 item(s)`,
  `workspace listed after import 1 item(s)`, and
  `workspace export candidate(s): 1`.
- Ran expanded `make flutter-verify`: passed.

Flutter Web backend placeholder:

- Starting Web backend placeholder work.
- Goal for this unit: stop treating Flutter Web as the fake backend by default
  and make the separate `wasmacs`/WASM backend route visible through
  capabilities and diagnostics.
- Added `WebWasmEmacsBackend`.
- Added `BackendKind.webWasm` and selected it by default when `kIsWeb` is true.
- Web capabilities now expose `wasmacs`/WASM route visibility and explicit
  unsupported native FFI, MethodChannel, connected WASM runtime, and browser
  file import/export proof.
- Added deterministic Web startup diagnostics and browser-safe workspace
  placeholders.
- Added tests for explicit Web backend construction, default Web selection,
  Web capabilities, startup diagnostics, and workspace placeholders.
- Updated the Flutter structure check to guard the Web backend files and
  capability markers.
- Ran `dart format lib test`: passed.
- Ran `make flutter-structure-check`: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 25 tests.
- Ran `make flutter-web-smoke`: passed.
- Ran expanded `make flutter-verify`: passed.

iOS native channel diagnostic bridge:

- Starting channel diagnostic bridge work.
- Goal for this unit: make the iOS MethodChannel return successful diagnostic
  lifecycle/output/input/resize responses before connecting the GNU Emacs core.
- Added `FlutterNativeEmacsBridge.swift` to the iOS Runner target.
- The native bridge now handles `start`, `stop`, `redraw`, `sendBytes`,
  `resize`, `drainOutput`, and workspace placeholder methods.
- Updated `NativeEmacsBackend` to drain `drainOutput` into `outputStream` after
  successful operations and poll while running.
- Kept missing-plugin and `PlatformException` paths as explicit unsupported
  diagnostics.
- Added a successful native output flow test from MethodChannel to Dart stream.
- Ran `dart format lib test`: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 16 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `flutter build ios --simulator --debug`: passed.
- Ran `make flutter-fake-smoke`: passed, 16 tests.
- Ran `flutter build macos --debug`: passed.
- Ran `flutter build web --debug`: passed.
- Ran `flutter build apk --debug`: passed.
- Ran `make flutter-doctor`: passed with no issues.

CocoaPods environment:

- Starting Flutter doctor cleanup for CocoaPods.
- Current state: `flutter doctor -v` reports Android SDK missing and CocoaPods
  missing.
- Current Ruby state: only system Ruby `/usr/bin/ruby` 2.6.10 is active and
  `pod` is not installed.
- Per user instruction, Ruby/CocoaPods work will use `mise` rather than system
  Ruby or direct Homebrew Ruby setup.
- Added repo-local `mise.toml` pinning Ruby 3.4.9.
- Ran `mise trust` for the repo-local config.
- First Ruby build failed because the `psych` extension could not find
  `yaml.h`.
- Installed Homebrew `libyaml` as a Ruby build dependency.
- Re-ran `mise install ruby@3.4.9` with libyaml configured: passed.
- Installed CocoaPods with `mise exec -- gem install cocoapods`: CocoaPods
  1.16.2 installed.
- Verified `mise exec -- pod --version`: 1.16.2.
- Verified a new interactive zsh in this repo resolves Ruby 3.4.9 and
  `pod` 1.16.2 from the `mise` Ruby install.
- Added `make flutter-doctor`, which runs Flutter doctor through `mise exec`
  with the local Flutter SDK on PATH.
- Ran `make flutter-doctor`: Xcode/CocoaPods now passes; Android SDK remains
  the only Flutter doctor issue.
- Re-ran `make flutter-fake-smoke` from an activated zsh: passed, 10 tests.
- Re-ran `flutter build ios --simulator --debug` from an activated zsh: passed.
- Re-ran `flutter build macos --debug` from an activated zsh: passed.
- Re-ran `flutter build web --debug` from an activated zsh: passed.
- Re-ran `git diff --check`: passed.

Android environment:

- Starting Flutter doctor cleanup for Android SDK.
- Current state: `sdkmanager`, `avdmanager`, `adb`, `ANDROID_HOME`, and
  `ANDROID_SDK_ROOT` are absent.
- Current Java state: `mise` provides Java 21.0.2, which is available to this
  repo.
- Homebrew reports `android-commandlinetools` and `android-platform-tools` are
  not installed.
- Installed Homebrew `android-commandlinetools` and `android-platform-tools`.
- Ran `flutter config --android-sdk /opt/homebrew/share/android-commandlinetools`.
- Accepted Android SDK licenses with `sdkmanager --licenses`.
- Installed `platform-tools`, `platforms;android-36`, and `build-tools;36.0.0`.
- Verified installed SDK packages with `sdkmanager --list_installed`.
- Ran `flutter doctor -v`: all categories pass.
- Ran `flutter build apk --debug`: passed. The build installed NDK
  28.2.13676358 and CMake 3.22.1 on demand.
- Re-ran `make flutter-doctor`: passed with no issues.
- Re-ran `make flutter-fake-smoke`: passed, 10 tests.
- Re-ran `make flutter-structure-check`: passed.
- Re-ran `flutter build ios --simulator --debug`: passed.
- Re-ran `flutter build macos --debug`: passed.
- Re-ran `flutter build web --debug`: passed.

Backend capabilities:

- Starting backend capability reporting work.
- Goal for this unit: make backend-supported and explicitly unsupported
  surfaces visible through `EmacsBackend` before adding real platform backends.

Terminal frontend:

- Starting Phase 3 terminal-widget work.
- Goal for this unit: replace the temporary text-buffer terminal renderer with
  a real Flutter terminal widget while preserving the fake backend smoke path.
- Added `xterm` 4.0.0 through `flutter pub add xterm`.
- Updated `TerminalScreen` to render `TerminalView` with an iosmacs terminal
  palette.
- Routed backend output bytes into `Terminal.write`.
- Routed `Terminal.onOutput` back to `EmacsBackend.sendBytes`.
- Kept the existing text input row as a deterministic smoke path for ASCII input
  while hardware keyboard and IME validation remain pending.
- Updated widget tests to assert `TerminalView` presence and fake ASCII input
  diagnostics instead of searching for terminal-rendered text widgets.
- Ran `dart format lib test`: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 10 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `make flutter-fake-smoke`: passed, 10 tests.
- Ran `flutter build macos --debug`: passed.
- Ran `flutter build ios --simulator --debug`: passed.
- Ran `flutter build web --debug`: passed.
- Ran `git diff --check`: passed.

Flutter smoke documentation structure guards:

- Starting smoke documentation structure guard work.
- Goal for this unit: make `make flutter-structure-check` fail if
  `flutter/ARCHITECTURE.md` drops current runtime smoke flags or focused smoke
  target evidence.
- Planned checks: structure check and diff whitespace check.
- Added structure checks for the `flutter/ARCHITECTURE.md` runtime smoke flag
  list and focused smoke target evidence.
- Ran `make flutter-structure-check`: passed.
- Ran `git diff --check`: passed.

Flutter terminal geometry status:

- Starting visible terminal geometry status work.
- Goal for this unit: show the active backend TTY geometry in the Flutter
  status strip and prove resize diagnostics update that visible state.
- Planned checks: Dart format, Flutter tests, structure check, and diff
  whitespace check.
- Added a `TTY colsxrows` status label backed by `BackendDiagnostics`.
- Added a widget test proving `backend.resize(cols: 100, rows: 30)` updates
  the visible `TTY 100x30` status text.
- Updated the Flutter structure check to guard the geometry status label and
  widget test.
- Ran `dart format lib/src/ui/terminal_screen.dart test/terminal_screen_test.dart`:
  passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 46 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `git diff --check`: passed.

Flutter Stop control:

- Starting visible Stop control work.
- Goal for this unit: make backend lifecycle shutdown available from normal
  Flutter UI and hardware keyboard control, not only runtime smoke flags.
- Planned checks: Dart format, Flutter analyze, Flutter tests, structure check,
  and diff whitespace check.
- Added a visible toolbar `Stop` button wired to `EmacsBackend.stop()`.
- Added Ctrl+Shift+X and Meta+Shift+X shortcuts for backend stop.
- Extended the hardware shortcut widget test to prove stop and restart
  lifecycle transitions.
- Added a dedicated toolbar Stop widget test.
- Updated the Flutter structure check to guard the Stop button wiring, shortcut
  key, and widget coverage.
- Ran `dart format lib/src/ui/terminal_screen.dart test/terminal_screen_test.dart`:
  passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 47 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `git diff --check`: passed.

Flutter Send input control:

- Starting visible Send input control work.
- Goal for this unit: make committed terminal text sendable from touch/mouse UI
  as well as keyboard submit actions.
- Planned checks: Dart format, Flutter analyze, Flutter tests, structure check,
  and diff whitespace check.
- Added a visible `Send` icon button beside the terminal input field.
- Routed the Send button through the existing committed-text path so it clears
  the input and forwards UTF-8 text plus carriage return to `EmacsBackend`.
- Added a widget test proving the Send button forwards `send me` and clears the
  input field.
- Updated the Flutter structure check to guard the Send button and widget
  coverage.
- Ran `dart format lib/src/ui/terminal_screen.dart test/terminal_screen_test.dart`:
  passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 48 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `git diff --check`: passed.

Flutter responsive toolbar:

- Starting narrow-width toolbar work.
- Goal for this unit: keep the growing Flutter toolbar usable on phone-width
  viewports without render overflow while preserving the existing icon controls.
- Planned checks: Dart format, Flutter analyze, Flutter tests, structure check,
  and diff whitespace check.
- Wrapped the toolbar controls in a horizontal scroll view.
- Replaced the toolbar slider's flex sizing with a stable fixed width so the
  toolbar can scroll instead of overflowing on narrow viewports.
- Added a 320px-wide widget test that verifies the toolbar renders and the
  Start action works without captured Flutter layout exceptions.
- Updated the Flutter structure check to guard the responsive toolbar markers
  and narrow-width widget coverage.
- Ran `dart format lib/src/ui/terminal_screen.dart test/terminal_screen_test.dart`:
  passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 49 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `git diff --check`: passed.

Flutter app-level narrow smoke:

- Starting app-level narrow-width smoke work.
- Goal for this unit: prove the real `IOSMacsFlutterApp` entrypoint keeps the
  terminal, input, and toolbar controls available on phone-width viewports.
- Planned checks: Dart format, Flutter analyze, Flutter tests, structure check,
  and diff whitespace check.
- Added an app-level 320px-wide widget smoke using
  `IOSMacsFlutterApp(backendOverride: 'fake')`.
- Verified the app entrypoint still shows the terminal, text input, Start, and
  Send controls on the narrow viewport.
- Verified the app-level Start action reaches the running lifecycle state
  without captured Flutter layout exceptions.
- Updated the Flutter structure check to guard the app-level narrow smoke.
- Ran `dart format test/widget_test.dart`: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 50 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `git diff --check`: passed.

Flutter toolbar scroll reachability:

- Starting toolbar scroll reachability work.
- Goal for this unit: prove narrow-width users can horizontally scroll the
  toolbar to reach the trailing font-size control.
- Planned checks: Dart format, Flutter analyze, Flutter tests, structure check,
  and diff whitespace check.
- Added a stable `iosmacs-toolbar-scroll` key to the toolbar's horizontal
  scroll view.
- Added a 320px-wide widget test proving the font-size Slider starts beyond the
  narrow viewport and becomes reachable after horizontal toolbar scrolling.
- Updated the Flutter structure check to guard the toolbar scroll key and
  reachability test.
- Ran `dart format lib/src/ui/terminal_screen.dart test/terminal_screen_test.dart`:
  passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 51 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `git diff --check`: passed.

Flutter backend status indicator:

- Starting backend status indicator work.
- Goal for this unit: make the selected backend id visible in the status strip
  without requiring the capabilities dialog.
- Planned checks: Dart format, Flutter analyze, Flutter tests, structure check,
  and diff whitespace check.
- Added a `Backend <id>` indicator to the status strip, sourced from
  `EmacsBackend.capabilities.id`.
- Made the backend id indicator flexible with ellipsis so the status strip does
  not regress narrow-width layout.
- Added widget coverage for fake and Android placeholder backend id visibility
  without opening the capabilities dialog.
- Updated the app startup test to assert the explicit Android backend id rather
  than a broad `android` text match.
- Updated the Flutter structure check to guard the backend id status marker and
  widget coverage.
- Ran `dart format lib/src/ui/terminal_screen.dart test/terminal_screen_test.dart test/widget_test.dart`:
  passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 52 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `git diff --check`: passed.

Flutter runtime status smoke:

- Starting runtime status smoke work.
- Goal for this unit: mirror the visible backend id and lifecycle state into
  smoke logs so runtime evidence can identify the selected backend without
  opening the UI.
- Planned checks: Dart format, Flutter tests, backend override smoke, macOS
  native smoke, structure check, and diff whitespace check.
- Added `IOSMACS_FLUTTER_STATUS_SMOKE` from the Flutter app entrypoint through
  `TerminalScreen`.
- Added mirrored status output as `iosmacs-status-smoke: id=... lifecycle=...
  geometry=...` when terminal output mirroring is enabled.
- Included status smoke evidence in the backend override smoke and macOS native
  smoke scripts.
- Added widget coverage for deterministic status smoke execution and visible
  backend id state.
- Updated architecture docs and structure guards for the new smoke flag and
  expected runtime evidence.
- Ran `dart format lib test`: passed, 0 changed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 53 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `make flutter-backend-override-smoke`: passed for fake, Android, Linux,
  Windows, and Web-WASM placeholder backend overrides.
- Ran `make flutter-macos-native-smoke`: passed with platform native channel
  status smoke evidence.
- Ran `git diff --check`: passed.

Flutter diagnostics details UI:

- Starting diagnostics details UI work.
- Goal for this unit: make the current backend id, lifecycle, geometry, byte
  counters, workspace action count, and diagnostic message available from the
  status strip without opening the capabilities dialog.
- Planned checks: Dart format, Flutter analyze, Flutter tests, structure check,
  and diff whitespace check.
- Added a status-strip Diagnostics icon that opens a backend diagnostics dialog.
- The dialog shows backend id, lifecycle, terminal geometry, input/output byte
  counts, workspace action count, and the latest diagnostic message.
- Split the status strip into a two-row layout on narrow widths so the new
  diagnostics action does not reintroduce phone-width overflow.
- Added widget coverage for the diagnostics dialog values and guarded the
  diagnostics action in the narrow-width test.
- Updated `flutter/ARCHITECTURE.md` and `scripts/check-flutter-structure.sh`
  so the diagnostics details UI remains part of the Flutter shell contract.
- Ran `dart format lib/src/ui/terminal_screen.dart test/terminal_screen_test.dart`:
  passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 54 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `git diff --check`: passed.

Flutter workspace import UI:

- Starting workspace import UI work.
- Goal for this unit: expose user-triggered workspace import from the Flutter
  Workspace dialog, while keeping the picker boundary injectable for widget
  tests and platform-specific picker behavior.
- Planned checks: Flutter pub get, Dart format, Flutter analyze, Flutter tests,
  structure check, and diff whitespace check.
- Added the `file_selector` dependency through `flutter pub add file_selector`.
- Added an injectable `WorkspaceImportUriProvider` boundary with
  `pickWorkspaceImportUris()` as the default file-picker implementation.
- Added an Import action to the Workspace dialog that picks files, calls
  `EmacsBackend.importToWorkspace()`, refreshes the visible workspace list, and
  reports the imported count.
- Updated the fake backend worker to include imported file names in subsequent
  workspace listings so UI tests can prove the refresh path.
- Added widget coverage for importing `imported.el` and seeing it appear in the
  Workspace dialog.
- Updated backend worker/backend tests to prove imported fake workspace entries
  are reflected after import.
- Updated `flutter/ARCHITECTURE.md` and `scripts/check-flutter-structure.sh`
  to guard the file-picker boundary and Workspace Import action.
- Ran `flutter pub add file_selector`: passed.
- Ran `dart format lib/src/ui/terminal_screen.dart lib/src/ui/workspace_import_picker.dart lib/src/backend/fake_backend_worker.dart test/terminal_screen_test.dart test/fake_backend_worker_test.dart test/fake_emacs_backend_test.dart`:
  passed.
- Ran `flutter test`: passed, 55 tests.
- Ran `flutter analyze`: passed.
- Ran `make flutter-structure-check`: passed.
- Ran `make flutter-macos-smoke`: passed.
- Ran `make flutter-web-smoke`: passed.
- Ran `git diff --check`: passed.

Flutter workspace export results UI:

- Starting workspace export results UI work.
- Goal for this unit: replace the count-only Workspace export Snackbar with a
  dialog that shows the concrete export candidate URIs returned by the backend.
- Planned checks: Dart format, Flutter analyze, Flutter tests, structure check,
  and diff whitespace check.
- Replaced the Workspace Export action's count-only Snackbar with a
  `Workspace export candidates` dialog.
- The export dialog shows the candidate count and each backend-provided URI as
  selectable text so paths remain inspectable.
- Updated widget coverage to prove the fake backend export candidate
  `/workspace/scratch.el` is visible.
- Updated `scripts/check-flutter-structure.sh` to guard the export candidates
  dialog and focused widget test.
- Ran `dart format lib/src/ui/terminal_screen.dart test/terminal_screen_test.dart`:
  passed.
- Ran `flutter test`: passed, 55 tests.
- Ran `flutter analyze`: passed.
- Ran `make flutter-structure-check`: passed.
- Ran `git diff --check`: passed.

Flutter workspace import cancel coverage:

- Starting workspace import cancel coverage work.
- Goal for this unit: prove that canceling the file picker keeps the Workspace
  dialog open, leaves entries unchanged, and reports the cancellation without
  calling backend import.
- Planned checks: Dart format, Flutter tests, structure check, and diff
  whitespace check.
- Added widget coverage for an empty `workspaceImportUriProvider()` result.
- Verified canceling import keeps the Workspace dialog open, leaves
  `scratch.el` visible, does not add imported entries, reports `Import
  canceled`, and leaves fake backend workspace action count at 0.
- Updated `scripts/check-flutter-structure.sh` to guard the import-cancel
  widget coverage.
- Ran `dart format test/terminal_screen_test.dart`: passed, 0 changed.
- Ran `flutter test`: passed, 56 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `git diff --check`: passed.

Flutter backend override workspace smoke:

- Starting backend override workspace smoke work.
- Goal for this unit: make `make flutter-backend-override-smoke` prove
  workspace list/import/export smoke evidence for every forced backend override
  it launches.
- Planned checks: structure check, backend override runtime smoke, and diff
  whitespace check.
- Enabled `IOSMACS_FLUTTER_WORKSPACE_SMOKE=true` in
  `scripts/run-flutter-backend-override-smoke.sh`.
- Added backend override smoke checks for workspace list, import,
  list-after-import, and export candidate log evidence.
- Updated `flutter/ARCHITECTURE.md` and `scripts/check-flutter-structure.sh`
  so backend override smoke documentation and guards include workspace smoke
  output.
- Ran `make flutter-structure-check`: passed.
- Ran `make flutter-backend-override-smoke`: passed for fake, Android, Linux,
  Windows, and Web-WASM placeholder backend overrides with workspace smoke
  checks enabled.
- Ran `git diff --check`: passed.

Flutter analyze verify target:

- Starting Flutter analyze target work.
- Goal for this unit: make Dart static analysis a first-class `make` target and
  include it in `make flutter-verify` before the longer runtime smoke targets.
- Planned checks: `make flutter-analyze`, structure check, and diff whitespace
  check.
- Added `make flutter-analyze` to run `flutter pub get` followed by
  `flutter analyze` in `flutter/iosmacs_flutter`.
- Added `flutter-analyze` to the Makefile phony/help surfaces.
- Included `flutter-analyze` in `make flutter-verify` immediately after
  `flutter-doctor` and before fake tests/runtime smoke targets.
- Updated `flutter/ARCHITECTURE.md` and `scripts/check-flutter-structure.sh`
  so the verification contract and structure guard include Flutter analyze.
- Ran `make flutter-analyze`: passed, no analyzer issues.
- Ran `make flutter-structure-check`: passed.
- Ran `git diff --check`: passed.

Flutter format check target:

- Starting Flutter format check target work.
- Goal for this unit: make Dart format drift a first-class `make` verification
  target and include it in `make flutter-verify` before analyze/tests/smokes.
- Planned checks: `make flutter-format-check`, structure check, and diff
  whitespace check.
- Added `make flutter-format-check` to run
  `dart format --set-exit-if-changed lib test` in `flutter/iosmacs_flutter`.
- Added `flutter-format-check` to the Makefile phony/help surfaces.
- Included `flutter-format-check` in `make flutter-verify` immediately after
  `flutter-doctor` and before analyze/tests/runtime smoke targets.
- Updated `flutter/ARCHITECTURE.md` and `scripts/check-flutter-structure.sh`
  so the verification contract and structure guard include Dart format check.
- Ran `make flutter-format-check`: passed, 29 files checked and 0 changed.
- Ran `make flutter-structure-check`: passed.
- Ran `git diff --check`: passed.

Flutter workspace refresh action:

- Starting workspace refresh action work.
- Goal for this unit: let users refresh the visible Workspace dialog from the
  backend without closing and reopening it.
- Planned checks: Dart format, Flutter tests, structure check, and diff
  whitespace check.
- Added a Refresh action to the Workspace dialog that reloads entries through
  `EmacsBackend.listWorkspace()` without closing the dialog.
- Added widget coverage proving an externally imported fake workspace entry
  appears after Refresh.
- Updated `flutter/ARCHITECTURE.md` and `scripts/check-flutter-structure.sh`
  to guard the refresh action and test.
- Ran `dart format lib/src/ui/terminal_screen.dart test/terminal_screen_test.dart`:
  passed, 0 changed.
- Ran `flutter test`: passed, 57 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `git diff --check`: passed.

Flutter workspace open action:

- Starting workspace open action work.
- Goal for this unit: let users open a visible Workspace dialog entry by
  forwarding its path to Emacs through the existing terminal input boundary.
- Planned checks: Dart format, Flutter tests, structure check, and diff
  whitespace check.
- Added an Open action to each visible Workspace dialog entry.
- The Open action forwards `C-x C-f`, the workspace path, and `RET` to
  `EmacsBackend.sendBytes()`.
- Added widget coverage proving `scratch.el` sends the expected terminal input
  byte count and surfaces an opening snackbar.
- Updated `flutter/ARCHITECTURE.md` and `scripts/check-flutter-structure.sh`
  to guard the open action and test.
- Ran `dart format lib/src/ui/terminal_screen.dart test/terminal_screen_test.dart`:
  passed, 0 changed.
- Ran `flutter test`: passed, 58 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `git diff --check`: passed.

Flutter workspace open runtime smoke:

- Starting workspace open runtime smoke work.
- Goal for this unit: make startup workspace smokes prove that a visible
  workspace entry can be opened through the same terminal byte path as the UI
  Open action.
- Planned checks: Dart format, Flutter tests, backend override smoke, structure
  check, and diff whitespace check.
- Startup workspace smoke now opens the last visible workspace entry after
  import/list refresh and logs `workspace open requested` evidence with the
  selected path, sent byte count, and backend input total.
- Reused the Workspace dialog Open byte command for smoke execution so UI and
  runtime evidence share the same `C-x C-f <path> RET` path.
- Updated backend override and macOS native smoke scripts to require workspace
  open evidence.
- Updated widget coverage, architecture docs, and structure guards for
  workspace list/import/open/export smoke evidence.
- Ran `dart format lib/src/ui/terminal_screen.dart test/widget_test.dart`:
  passed, 0 changed.
- Ran `flutter test`: passed, 58 tests.
- Ran `flutter test test/widget_test.dart`: passed, 7 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `IOSMACS_FLUTTER_BACKEND_SMOKE_BACKENDS=fake IOSMACS_FLUTTER_BACKEND_OVERRIDE_HOLD_SECONDS=4 make flutter-backend-override-smoke`:
  passed.
- Ran `IOSMACS_FLUTTER_MACOS_NATIVE_HOLD_SECONDS=5 make flutter-macos-native-smoke`:
  passed.
- Ran `git diff --check`: passed.

Flutter terminal paste action:

- Starting terminal paste action work.
- Goal for this unit: let users paste system clipboard text into the Flutter
  terminal path as raw terminal bytes without forcing a carriage return.
- Planned checks: Dart format, Flutter tests, structure check, and diff
  whitespace check.
- Added `TerminalInputBridge.pasteText()` for raw UTF-8 terminal paste without
  appending `RET`.
- Added a Paste icon button to the terminal input row, backed by
  `Clipboard.getData(Clipboard.kTextPlain)` in the app.
- Added an injectable clipboard text provider so widget tests can prove paste
  behavior without relying on the platform clipboard channel.
- Added bridge and widget coverage proving pasted Japanese text is counted as
  forwarded bytes and sent to the backend.
- Updated `flutter/ARCHITECTURE.md` and `scripts/check-flutter-structure.sh`
  to guard clipboard paste ownership and tests.
- Ran `dart format lib/src/ui/terminal_input_bridge.dart lib/src/ui/terminal_screen.dart test/terminal_input_bridge_test.dart test/terminal_screen_test.dart`:
  passed, 0 changed.
- Ran `flutter test test/terminal_input_bridge_test.dart test/terminal_screen_test.dart`:
  passed, 21 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `flutter test`: passed, 60 tests.
- Ran `git diff --check`: passed.

Flutter terminal paste shortcut:

- Starting terminal paste shortcut work.
- Goal for this unit: let hardware-keyboard users paste into the Flutter
  terminal with Ctrl+V and Cmd+V through the same raw byte path as the Paste
  button.
- Planned checks: Dart format, Flutter tests, structure check, and diff
  whitespace check.
- Added Ctrl+V and Cmd+V shortcut bindings to call the same
  `_pasteClipboardText()` path as the visible Paste button.
- Added widget coverage proving the paste shortcut forwards injected clipboard
  text as raw UTF-8 bytes and updates backend diagnostics.
- Updated `flutter/ARCHITECTURE.md` and `scripts/check-flutter-structure.sh`
  to guard the paste shortcut surface and test.
- Ran `dart format lib/src/ui/terminal_screen.dart test/terminal_screen_test.dart`:
  passed, 0 changed.
- Ran `flutter test test/terminal_screen_test.dart`: passed, 18 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `flutter test`: passed, 61 tests.
- Ran `git diff --check`: passed.

Flutter empty clipboard paste coverage:

- Starting empty clipboard paste coverage work.
- Goal for this unit: prove that the Flutter terminal Paste action reports an
  empty clipboard without sending bytes into the backend.
- Planned checks: Dart format, focused Flutter widget test, structure check,
  full Flutter tests, and diff whitespace check.
- Added widget coverage for the empty clipboard Paste path.
- Verified empty paste shows `Clipboard is empty`, leaves backend input byte
  count at zero, and preserves the running fake backend diagnostic message.
- Updated `scripts/check-flutter-structure.sh` to guard the empty clipboard UI
  message and widget coverage.
- Ran `dart format test/terminal_screen_test.dart`: passed, 0 changed.
- Ran `flutter test test/terminal_screen_test.dart`: passed, 19 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `flutter test`: passed, 62 tests.
- Ran `git diff --check`: passed.

Flutter empty paste shortcut coverage:

- Starting empty paste shortcut coverage work.
- Goal for this unit: prove that Ctrl+V on an empty clipboard follows the same
  no-input path as the visible Paste button.
- Planned checks: Dart format, focused Flutter widget test, structure check,
  full Flutter tests, and diff whitespace check.
- Added widget coverage for Ctrl+V with an empty clipboard.
- Verified empty shortcut paste shows `Clipboard is empty`, leaves backend
  input byte count at zero, and preserves the running fake backend diagnostic
  message.
- Updated `scripts/check-flutter-structure.sh` to guard the empty paste
  shortcut test.
- Ran `dart format test/terminal_screen_test.dart`: passed, 0 changed.
- Ran `flutter test test/terminal_screen_test.dart`: passed, 20 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `flutter test`: passed, 63 tests.
- Ran `git diff --check`: passed.

Flutter imported workspace export candidates:

- Starting imported workspace export candidate work.
- Goal for this unit: make fake backend export candidates reflect imported
  workspace entries, then prove the Flutter Workspace dialog can import a file
  and export it as a visible candidate.
- Planned checks: Dart format, Flutter tests, structure check, and diff
  whitespace check.
- Updated `FakeBackendWorker` so export candidates are derived from the current
  fake workspace entries instead of always returning only `scratch.el`.
- Extended fake worker and fake backend tests to prove imported entries are
  included in exported URI candidates.
- Extended the Workspace dialog widget test to import `imported.el`, export
  immediately, and verify both `/workspace/scratch.el` and
  `/workspace/imported.el` are visible candidates.
- Updated `scripts/check-flutter-structure.sh` to guard the refreshed
  import/export widget coverage.
- Ran `dart format lib/src/backend/fake_backend_worker.dart test/fake_backend_worker_test.dart test/fake_emacs_backend_test.dart test/terminal_screen_test.dart`:
  passed, 0 changed.
- Ran `flutter test`: passed, 56 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `git diff --check`: passed.

Flutter diagnostics keyboard shortcut:

- Starting diagnostics keyboard shortcut work.
- Goal for this unit: let keyboard users open the backend diagnostics dialog
  from the terminal screen using the same Ctrl/Cmd+Shift shortcut pattern as
  the other toolbar/status actions.
- Planned checks: Dart format, Flutter tests, structure check, and diff
  whitespace check.
- Added Ctrl+Shift+D and Cmd+Shift+D bindings to open backend diagnostics.
- Extended the hardware shortcut widget test to prove the diagnostics dialog
  opens from the keyboard path.
- Updated `scripts/check-flutter-structure.sh` to guard the diagnostics
  shortcut key marker.
- Ran `dart format lib/src/ui/terminal_screen.dart test/terminal_screen_test.dart`:
  passed, 0 changed.
- Ran `flutter test`: passed, 56 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `git diff --check`: passed.

Flutter Emacs build output isolation guards:

- Starting build-output isolation guard work.
- Goal for this unit: keep Flutter-owned Emacs build artifacts under
  `flutter/build/emacs-ios` and prevent the Flutter iOS Runner from drifting
  back to root `build/emacs-ios-probe` references.
- Planned checks: structure check and diff whitespace check.
- Added structure-check guards for `FLUTTER_EMACS_BUILD_ROOT`,
  `flutter-emacs-static`, `flutter-emacs-pdmp`, `flutter-ipad-launch`, and the
  `IOSMACS_BUILD_ROOT="$(FLUTTER_EMACS_BUILD_ROOT)"` Makefile handoff.
- Added structure-check guards for Flutter iOS Runner resource/static-library
  paths under `../../build/emacs-ios` and an explicit failure if the Runner
  references root `../../../build/emacs-ios-probe`.
- Added a structure-check guard that `.gitignore` keeps `flutter/build/`
  ignored.
- Ran `bash -n scripts/check-flutter-structure.sh`: passed.
- Ran `make flutter-structure-check`: passed.
- Ran `git diff --check`: passed.

Flutter native autostart defaults:

- Starting native autostart default guard work.
- Goal for this unit: make iOS/macOS Flutter runs autostart the selected native
  backend by default while keeping Web and placeholder platforms manually
  started unless explicitly overridden.
- Planned checks: Dart format, focused Flutter tests, structure check, and diff
  whitespace check.
- Replaced the private `_defaultAutoStart()` helper with
  `defaultAutoStartBackend()` so platform, Web, and explicit environment
  override behavior can be tested directly.
- Added tests proving iOS/macOS autostart by default, Web/Android/Linux/Windows
  do not autostart by default, and the explicit autostart override wins over
  platform defaults.
- Updated the Flutter structure check to guard the autostart helper and tests.
- Ran `dart format flutter/iosmacs_flutter/lib/main.dart flutter/iosmacs_flutter/test/widget_test.dart`:
  passed, 1 file changed.
- Ran `flutter test test/widget_test.dart`: passed, 10 tests.
- Ran `flutter test`: passed, 66 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `git diff --check`: passed.

Flutter iOS parity and device-readiness plan:

- Starting Flutter iOS parity planning and native smoke harness work.
- Goal for this unit: write down the path from Flutter iOS launch proof to
  `*scratch*`, command-loop input, file save/reopen, relaunch persistence, and
  physical-device runs, then add the first dedicated Flutter iOS native runtime
  smoke harness.
- Planned checks: shell syntax, structure check, diff whitespace check, and
  existing Flutter widget tests. A full simulator launch is deferred until an
  iOS simulator is booted.
- Added Phase 4A to `flutter/PLAN.md` with simulator runtime-smoke,
  bridge/workspace, physical-device, and completion-criteria TODOs.
- Added `scripts/run-flutter-ios-native-smoke.sh`, which builds the Flutter iOS
  simulator app with native autostart, terminal-output mirroring, capabilities,
  input, resize, redraw, status, and workspace smoke flags enabled.
- The new smoke installs and launches the Runner on a booted simulator,
  captures Runner/system logs, requires the `platform-native-channel` backend,
  checks input/resize/redraw/workspace smoke markers, requires linked GNU Emacs
  output, and fails if diagnostic fallback output appears.
- Added `make flutter-ios-native-smoke` as a focused target; it is not yet part
  of `make flutter-verify` because it still needs stable booted-simulator
  runtime evidence.
- Updated `scripts/check-flutter-structure.sh` to guard the new script,
  Makefile target, dart-define flags, and key iOS native smoke log markers.
- Ran `bash -n scripts/run-flutter-ios-native-smoke.sh scripts/check-flutter-structure.sh`:
  passed.
- Ran `make flutter-structure-check`: passed.
- Ran `flutter test test/widget_test.dart`: passed, 10 tests.
- Ran `git diff --check`: passed.
- Did not run `make flutter-ios-native-smoke` yet because no iOS simulator is
  currently booted.
- Added optional `IOSMACS_FLUTTER_IOS_EXPECT_SCRATCH=1` mode to
  `scripts/run-flutter-ios-native-smoke.sh`; when enabled, the smoke now
  requires `*scratch*` and Lisp Interaction mode in captured Runner logs.

Flutter iOS native runtime smoke execution:

- Booted simulator: iPad (A16)
  `D0F9B2BE-1CD0-49D6-BC25-6FF7650031D6`.
- Ran `make flutter-ios-native-smoke`: passed.
- The captured log reported `iosmacs-capabilities-smoke:
  id=platform-native-channel`, `Flutter MethodChannel started linked GNU Emacs
  on iOS.`, native status smoke, input smoke, resize smoke, redraw smoke, and
  workspace list/import/open/export smoke markers.
- Ran `IOSMACS_FLUTTER_IOS_EXPECT_SCRATCH=1 make flutter-ios-native-smoke`:
  passed. The captured log contained `*scratch*` and Lisp Interaction mode.
- Added optional `IOSMACS_FLUTTER_IOS_EXPECT_INPUT_INSERTION=1` mode to require
  the Flutter input smoke text in captured terminal output.
- Ran `IOSMACS_FLUTTER_IOS_EXPECT_SCRATCH=1
  IOSMACS_FLUTTER_IOS_EXPECT_INPUT_INSERTION=1 make
  flutter-ios-native-smoke`: passed.
- Added optional `IOSMACS_FLUTTER_IOS_EXPECT_COMMAND_MARKER=1` mode, which
  passes `IOSMACS_APP_SMOKE_MARKER` into the simulator app via
  `SIMCTL_CHILD_...`, then checks the `/home/user` marker in the app container
  for `iosmacs-app-smoke-ok` and the inserted input text.
- Ran `IOSMACS_FLUTTER_IOS_EXPECT_SCRATCH=1
  IOSMACS_FLUTTER_IOS_EXPECT_INPUT_INSERTION=1
  IOSMACS_FLUTTER_IOS_EXPECT_COMMAND_MARKER=1 make
  flutter-ios-native-smoke`: passed.
- Added optional `IOSMACS_FLUTTER_IOS_EXPECT_FILE_OPS=1` mode, which passes
  `IOSMACS_APP_FILE_SMOKE_MARKER` into the simulator app, checks the app
  container marker for `iosmacs-app-file-smoke-ok`, and verifies the saved
  `/home/user/notes/iosmacs-file-smoke.txt` contents.
- Ran `IOSMACS_FLUTTER_IOS_EXPECT_SCRATCH=1
  IOSMACS_FLUTTER_IOS_EXPECT_INPUT_INSERTION=1
  IOSMACS_FLUTTER_IOS_EXPECT_COMMAND_MARKER=1
  IOSMACS_FLUTTER_IOS_EXPECT_FILE_OPS=1 make flutter-ios-native-smoke`: passed.
- Added optional `IOSMACS_FLUTTER_IOS_EXPECT_RELAUNCH_PERSISTENCE=1` mode. The
  smoke now relaunches the same installed Flutter iOS Runner, verifies the
  saved `/home/user/notes/iosmacs-file-smoke.txt` still exists with expected
  contents, and checks that the Flutter workspace smoke runs again after
  relaunch.
- Ran `IOSMACS_FLUTTER_IOS_EXPECT_SCRATCH=1
  IOSMACS_FLUTTER_IOS_EXPECT_INPUT_INSERTION=1
  IOSMACS_FLUTTER_IOS_EXPECT_COMMAND_MARKER=1
  IOSMACS_FLUTTER_IOS_EXPECT_FILE_OPS=1
  IOSMACS_FLUTTER_IOS_EXPECT_RELAUNCH_PERSISTENCE=1 make
  flutter-ios-native-smoke`: passed.
- Promoted `make flutter-ios-native-smoke` to require scratch, input insertion,
  command marker, file-ops, and relaunch-persistence checks by default.
- Added `flutter-ios-native-smoke` to `make flutter-verify` after the existing
  Flutter iOS launch smoke.
- Ran promoted `make flutter-ios-native-smoke`: passed.

Flutter iOS interactive terminal fixes:

- Starting fixes for the reported simulator UI issues: wrapped/broken modeline
  after resize smoke, Japanese committed text being inserted twice, and
  `M-x dired` / `M-x tetris` reporting no match.
- Planned checks: Dart format, focused Flutter widget tests, structure check,
  diff whitespace check, and Flutter iOS native smoke on the booted iPad
  simulator.
- Split the Flutter terminal focus node from the visible input-row text-field
  focus node, and removed input-row autofocus so IME committed text is not
  routed through both terminal and text-field input paths.
- Changed the Flutter runtime resize smoke to use the current xterm
  `Terminal.viewWidth` / `viewHeight` instead of forcing `100x30`, preventing
  the native Emacs modeline from being rendered wider than the visible terminal.
- Changed runtime input smoke text to ASCII-only `iosmacs input smoke`; Japanese
  committed input remains covered by focused Flutter tests rather than being
  injected automatically into interactive smoke builds.
- Added widget coverage proving the input-row Send button forwards Japanese
  text exactly once.
- Updated the iOS/macOS/backend-override smoke scripts to accept the current
  nonzero terminal geometry instead of hard-coded `100x30`.
- Updated the bundled runtime eval form to autoload `dired` and `tetris`, and
  to skip missing `cus-load` / `finder-inf` quietly instead of logging load
  errors.
- Added `IOSMACS_FLUTTER_IOS_EXPECT_COMMANDS=1` to the Flutter iOS native smoke;
  it checks an Emacs-side marker proving `(commandp 'dired)` and
  `(commandp 'tetris)`.
- Ran `flutter test test/terminal_screen_test.dart test/widget_test.dart test/terminal_input_bridge_test.dart`:
  passed, 35 tests.
- Ran promoted `make flutter-ios-native-smoke`: passed on the booted iPad (A16)
  simulator. The log showed resize smoke using `88x50`, `*scratch*` in Lisp
  Interaction mode, input insertion, file/relaunch markers, and
  `iosmacs-app-commands-smoke-ok`.
- Ran full `flutter test`: passed, 67 tests. This includes the regression test
  that the visible input-row Send button forwards Japanese committed text once.
- Ran `make flutter-structure-check`: passed.
- Ran `git diff --check`: passed.

Flutter iOS terminal-body input and M-x follow-up fixes:

- The first Japanese fix only covered the visible input-row Send path. The
  screenshot showed the terminal body still received duplicated IME commit
  chunks, so `TerminalInputBridge.sendTerminalOutput()` now suppresses only
  short-window duplicate printable non-ASCII chunks while leaving ASCII,
  escape/control input, paste, and explicit Send paths unchanged.
- Added focused bridge tests proving duplicate terminal-body Japanese chunks are
  dropped, repeated Japanese text outside the duplicate window is allowed, and
  ASCII repeated input is not filtered.
- Strengthened `IOSMACS_FLUTTER_IOS_EXPECT_COMMANDS=1` so the Flutter iOS
  native smoke checks that `dired` and `tetris` appear in
  `(all-completions ... obarray #'commandp)`, matching the `M-x` completion
  table more closely than `commandp` alone.
- Ran `flutter test test/terminal_input_bridge_test.dart
  test/terminal_screen_test.dart test/widget_test.dart`: passed, 37 tests.
- Ran `make flutter-structure-check`: passed.
- Ran promoted `make flutter-ios-native-smoke`: passed on the booted iPad (A16)
  simulator. The log showed `iosmacs-app-commands-smoke-ok` after checking both
  `commandp` and `all-completions` for `dired` and `tetris`.
- Ran full `flutter test`: passed, 69 tests.
- Ran `git diff --check`: passed.

Flutter iOS M-X command completion diagnosis:

- The user confirmed `(tetris)` works but `M-x tetris` still reports no match.
  The screenshot prompt was `M-X`, not `M-x`; in current Emacs this is a
  separate buffer-filtered extended-command path, so general commands such as
  `tetris` can be hidden even when the command symbol exists and direct
  evaluation works.
- Updated the bundled iOS runtime initialization to bind `M-X` to ordinary
  `execute-extended-command`, matching the expected iPad terminal behavior and
  avoiding the buffer-specific command-completion filter.
- Strengthened the Flutter iOS native command smoke to verify
  `(key-binding (kbd "M-X"))` is `execute-extended-command` in addition to the
  existing `commandp` and `all-completions` checks for `dired` and `tetris`.
- Ran `bash -n scripts/run-flutter-ios-native-smoke.sh
  scripts/check-flutter-structure.sh`: passed.
- Ran `make flutter-structure-check`: passed.
- Ran promoted `make flutter-ios-native-smoke`: passed on the booted iPad (A16)
  simulator. The log showed the `M-X` binding check in `IOSMACS_APP_ELISP` and
  `iosmacs-app-commands-smoke-ok`.
- Ran `git diff --check`: passed.

Flutter iOS workspace-root and network parity:

- Starting root-native iOS parity work for two surfaces: user-selectable
  `/home/user` folders and Emacs network access.
- Added `EmacsBackend.selectWorkspaceRoot()` and
  `clearWorkspaceRootSelection()` to the Dart backend boundary, with native
  MethodChannel implementations and explicit placeholder/fake behavior on
  other backends.
- Added Workspace dialog actions: `Choose /home/user` opens the iOS folder
  picker, and `Use Default` clears the saved selection.
- Updated `FlutterNativeEmacsBridge` to store selected workspace folders as
  security-scoped bookmarks, start security-scoped access when resolving the
  workspace, and report the active workspace root path in diagnostics.
- Updated the default Flutter iOS workspace to prefer the app's iCloud ubiquity
  container `Documents/home/user` when available, falling back to app
  Documents. The smoke script now checks `Documents/home/user`, matching the
  Emacs-visible path.
- Linked the existing native `IOSMacsURLSessionBridge.swift` into the Flutter
  iOS Runner target so the Flutter app has the same URLSession-backed Emacs
  network bridge as the root iOS app.
- Reworked `iosmacs_host_url_retrieve()` to resolve
  `iosmacs_swift_url_retrieve` with `dlsym(RTLD_DEFAULT, ...)`; this avoids the
  old weak C fallback being called before the Swift bridge in the Flutter
  Runner.
- Verified the Flutter iOS debug dylib exports both
  `_iosmacs_host_url_retrieve` and `_iosmacs_swift_url_retrieve`.
- Ran focused Flutter tests for native backend, terminal screen, and input
  bridge: passed, 34 tests.
- Ran `make flutter-ios-native-smoke`: passed after updating the host-side
  smoke path to `Documents/home/user`.
- Ran a manual Flutter iOS Emacs network smoke with
  `(url-retrieve-synchronously "https://example.com" t t 20)`: passed and wrote
  `/home/user/iosmacs-flutter-network-smoke.marker` containing
  `iosmacs-flutter-network-ok`.
- Ran full `flutter test`: passed, 71 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `git diff --check`: passed.

Flutter paste newline normalization:

- Reproduced from the screenshot: multiline Elisp sent through the Flutter
  input row preserved LF bytes, and Emacs Lisp Interaction treated those bytes
  as `C-j`, which invoked `eval-print-last-sexp` and opened a Backtrace buffer.
- Changed `TerminalInputBridge.submitCommittedText()` and `pasteText()` to
  normalize text line endings to terminal carriage returns before forwarding
  bytes. Raw `TerminalView` output remains unchanged for hardware/control-key
  input.
- Added bridge tests for committed multiline text and pasted multiline text.
- Added a widget test proving the input-row Paste button normalizes multiline
  clipboard text before forwarding.
- Updated structure-check guards and paste documentation wording.
- Ran `flutter test test/terminal_input_bridge_test.dart test/terminal_screen_test.dart`:
  passed, 31 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `git diff --check`: passed.

Flutter iOS paste throughput:

- Investigated slow paste after the multiline newline fix. The Dart/Swift side
  already forwards each Paste as one `sendBytes` call, but the patched Emacs
  direct TTY path was reading the native input ring one byte at a time through
  `iosmacs_host_terminal_read_byte()`.
- Added `iosmacs_host_terminal_read()` / `iosmacs_os_terminal_read_available()`
  so Emacs can bulk-read available terminal input from the native ring.
- Updated the Emacs iOS build patch in `scripts/build-emacs-ios-probe.sh` so
  `emacs_intr_read` uses the bulk read path before waiting for more input.
- Added structure-check guards for the bulk terminal input read path.
- Rebuilt the Flutter iOS Emacs static archive with
  `IOSMACS_FORCE_EMACS_BUILD=1 make flutter-emacs-static`: passed. The
  generated `flutter/build/emacs-ios/source/src/sysdep.c` now calls
  `iosmacs_host_terminal_read (tty_buf, nbyte)`.
- Updated `scripts/run-flutter-ios-native-smoke.sh` to uninstall the simulator
  app before install so stale security-scoped workspace bookmarks do not move
  smoke markers out of `Documents/home/user`.
- Because clean installs take longer to reach full smoke markers, raised the
  default full native-smoke hold from 14 seconds to 25 seconds.
- Ran `flutter test test/terminal_input_bridge_test.dart test/terminal_screen_test.dart`:
  passed, 31 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `git diff --check`: passed.
- Ran `IOSMACS_FLUTTER_IOS_NATIVE_HOLD_SECONDS=25 make
  flutter-ios-native-smoke`: passed.

Flutter iOS Emacs O3 trial:

- Rebuilt the Flutter iOS Emacs static archive with
  `IOSMACS_FORCE_EMACS_BUILD=1 IOSMACS_EMACS_OPT_FLAGS="-O3 -g" make
  flutter-emacs-static`: passed.
- Verified `flutter/build/emacs-ios/nt/Makefile` contains `CFLAGS=... -O3 -g`.
- Verified `flutter/build/emacs-ios/iosmacs/libiosmacs-temacs.a` still exports
  `_iosmacs_emacs_main`, `_iosmacs_host_terminal_read`, and
  `_iosmacs_host_terminal_read_byte`.
- Ran `make flutter-ios-native-smoke` with the default 25 second hold: failed
  at relaunch persistence because the workspace smoke marker did not appear
  before timeout.
- Ran `IOSMACS_FLUTTER_IOS_NATIVE_HOLD_SECONDS=45 make
  flutter-ios-native-smoke`: passed.
- Conclusion: the current build tree now contains an O3 Emacs static archive
  and it is functional in the Flutter iOS Runner. The script default remains
  `-O0 -g` unless `IOSMACS_EMACS_OPT_FLAGS` is supplied, so making O3 permanent
  is still a separate decision.

Flutter iOS paste output drain throughput:

- The remaining paste delay looked too large for compiler optimization alone.
  The native backend was polling output every 50ms and the iOS bridge drained
  only 16KB per call, so large Emacs redisplay output could take many seconds
  or minutes to become visible even after the paste bytes reached Emacs.
- Changed `NativeEmacsBackend.sendBytes()` so it returns after native input is
  accepted and schedules output drain asynchronously instead of waiting for
  drain completion.
- Changed native output polling from 50ms to 16ms.
- Changed `_drainOutput()` to keep draining multiple native chunks in one pass
  and combine them into one stream event before writing to the terminal.
- Increased the Flutter iOS native `drainOutput` chunk from 16KB to 256KB.
- Added tests proving multi-chunk native output is emitted as one stream event
  and `sendBytes()` does not wait for native output drain to finish.
- Ran `flutter test test/native_emacs_backend_test.dart
  test/terminal_input_bridge_test.dart test/terminal_screen_test.dart`: passed,
  39 tests.
- Ran full `flutter test`: passed, 76 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `IOSMACS_FLUTTER_IOS_NATIVE_HOLD_SECONDS=45 make
  flutter-ios-native-smoke`: passed.
- Ran `git diff --check`: passed.

Flutter iOS native text input paste parity:

- Compared the root native iOS app implementation and found it does not read
  `UIPasteboard` from a separate app control. It keeps a transparent
  `UITextView` first responder and lets UIKit deliver committed text and paste
  through `insertText` / `textViewDidChange`.
- Reworked the Flutter iOS Runner to install the same style of transparent
  native `UITextView` over the Flutter view, keep it focused, and forward
  committed text directly into the native terminal input ring.
- Added a native `pasteSystemClipboard` MethodChannel path. Flutter's Paste
  button now asks the native text input view to run `paste(nil)` first; only
  non-native backends fall back to Dart `Clipboard.getData`.
- Removed Flutter `Cmd+V` shortcut handling so hardware paste can go to the
  native first responder instead of being intercepted by Dart.
- Verified with Simulator + computer-use that normal text enters through the
  native text-input path without polluting the terminal display.
- Verified a 740 byte paste after the iOS permission prompt produced one
  native terminal `push-input count=740` and one Emacs
  `read-available bytes=740`.
- Verified a 30,400 byte paste produced one native terminal
  `push-input count=30400`; Emacs then consumed it in 4095 byte reads over
  about 5.7 seconds. This confirms the previous long delay was not Flutter
  output drain after the native paste path, while remaining multi-second
  processing is inside Emacs input consumption/redisplay.

Flutter iOS fake tty bulk-read strengthening:

- Added `tty.md` as the focused TODO/checklist for making the Flutter iOS tty
  behave like a normal OS terminal path.
- Confirmed the desired shape is: Flutter/native input enters the shim-level
  tty path, Emacs blocks only on its own pthread, input push wakes the host
  waitpoint immediately, and output can still be drained on UI-friendly
  boundaries.
- Changed Flutter iOS native input forwarding to call
  `iosmacs_terminal_shim_push_input` instead of bypassing the shim through
  `iosmacs_os_terminal_push_input`.
- Removed per-byte debug marker writes from `iosmacs_os_terminal_read_byte` so
  stale byte-read paths cannot make paste catastrophically slow when terminal
  debug logging is enabled.
- Added a migration guard in `scripts/build-emacs-ios-probe.sh` so generated
  Emacs `sysdep.c` moves stale `iosmacs_host_terminal_read_byte()` loops to
  the bulk `iosmacs_host_terminal_read(tty_buf, nbyte)` path.
- Added a structure check that fails when an existing generated
  `build/emacs-ios-probe/source/src/sysdep.c` still contains the stale
  byte-at-a-time loop.
- Updated the current generated probe `sysdep.c` to the bulk-read block for
  local validation.
- Verified `flutter/build/emacs-ios/source/src/sysdep.c` was already on the
  bulk-read path.
- Ran `flutter test`: passed, 74 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `git diff --check`: passed.
- Ran `IOSMACS_FLUTTER_IOS_NATIVE_HOLD_SECONDS=30 make
  flutter-ios-native-smoke`: passed.
- Ran a native C bulk-read probe: 30,400 bytes pushed into the input ring were
  read back in one `iosmacs_host_terminal_read` call.

Flutter iOS native paste line endings:

- Investigated a manual Simulator paste of a 411 byte Lisp networking snippet
  that produced `( is undefined` and a later `(void-variable url)` debugger.
- The native debug marker showed one `push-input count=411` and one
  `read-available bytes=411` in the same monotonic millisecond, so the terminal
  input hot path was not the source of that failure.
- The pasted bytes contained raw `0a` line feeds. In terminal Emacs
  `*scratch*`, `LF` is `C-j` and runs `eval-print-last-sexp`, so the pasted
  Lisp was being evaluated while it was being pasted instead of inserted as
  inert multiline text.
- Changed the Flutter iOS native `UITextView` committed-text path to normalize
  `CRLF`/`CR`/`LF` to terminal `CR` before writing bytes through
  `iosmacs_terminal_shim_push_input`.
- Added a Flutter structure-check guard for the native line-ending
  normalization.
- Ran `make flutter-structure-check`: passed.
- Ran `flutter test`: passed, 74 tests.
- Ran `git diff --check`: passed.
- Ran `IOSMACS_FLUTTER_IOS_NATIVE_HOLD_SECONDS=15 make
  flutter-ios-native-smoke`: passed.

Flutter iOS native paste-stage instrumentation:

- A single-line Japanese paste still took around 20 seconds after bracketed
  paste and redisplay-suppressed slurping. Because the text has no line breaks,
  the remaining delay is not RET command processing.
- Current Runner logs show Pasteboard file-coordination reads, but did not show
  when the hidden `UITextView` paste delegate fires or when bytes are forwarded
  into the fake tty.
- Added native timing markers for `pasteSystemClipboard` start/return,
  hidden text view `paste(_:)` start/return/done, `textViewDidChange`, and
  `sendNativeCommittedText` byte counts / shim write completion.
- Ran `make flutter-structure-check`: passed.
- Ran `flutter test`: passed, 74 tests.
- Ran `git diff --check`: passed.
- Ran `IOSMACS_FLUTTER_IOS_NATIVE_HOLD_SECONDS=15 make
  flutter-ios-native-smoke`: passed.
- A screenshot from the user showed the `NSLog` instrumentation leaking into
  the Emacs terminal surface. Switched those markers to unified logging via
  `os_log` so they remain visible in Simulator logs without polluting the
  terminal buffer.
- Ran `make flutter-structure-check`: passed.
- Ran `flutter test`: passed, 74 tests.
- Ran `git diff --check`: passed.
- Ran `IOSMACS_FLUTTER_IOS_NATIVE_HOLD_SECONDS=15 make
  flutter-ios-native-smoke`: passed.

Flutter iOS native long-paste routing:

- The user reported a plain Japanese multiline paste taking about 30 seconds,
  which points away from network timeout and back toward terminal paste
  semantics.
- The native `UITextView` paste path was still forwarding normalized raw text,
  so a multiline paste entered terminal Emacs as many ordinary `RET` commands.
  In modes such as `*scratch*`, that can force per-line command processing,
  indentation, redisplay, and Japanese width work.
- Changed only native UIKit paste to wrap bytes in bracketed-paste markers
  (`ESC [ 200 ~` / `ESC [ 201 ~`) after line-ending normalization. Ordinary
  typing, hardware keys, delete, and IME commits remain raw terminal input.
- Added structure-check guards for native paste override and bracketed-paste
  routing.
- The user confirmed Emacs internal kill/yank of the same Japanese text is
  fast, which supports the diagnosis that the slow path is external paste being
  processed as ordinary terminal input events rather than buffer insertion or
  Japanese redisplay itself.
- Ran `make flutter-structure-check`: passed.
- Ran `flutter test`: passed, 74 tests.
- Ran `git diff --check`: passed.
- Ran `IOSMACS_FLUTTER_IOS_NATIVE_HOLD_SECONDS=15 make
  flutter-ios-native-smoke`: passed.

Flutter iOS direct native pasteboard path:

- The user reported the Japanese multiline paste was still taking a long time
  even after bracketed-paste routing, so the remaining likely stall was
  `UITextView.paste(nil)` inserting a large body into the hidden text view
  before our delegate could forward it.
- Changed `FlutterTerminalInputView.paste(_:)` to read
  `UIPasteboard.general.string` directly and forward that text as
  `textinput-paste`, bypassing hidden `UITextView` body insertion. If the
  pasteboard does not provide a nonempty string, the code falls back to the
  previous `super.paste` path.
- Added a structure-check guard for direct `UIPasteboard.general.string`
  routing.
- Ran `make flutter-structure-check`: passed.
- Ran `flutter test`: passed, 74 tests.
- Ran `git diff --check`: passed.
- Ran `IOSMACS_FLUTTER_IOS_NATIVE_HOLD_SECONDS=15 make
  flutter-ios-native-smoke`: passed.
- After manual testing, this direct pasteboard path made paste stop reaching
  Emacs and left the terminal unresponsive. The latest Runner log showed
  Pasteboard file-coordination reads but no following `push-input` or terminal
  output, so the direct `UIPasteboard.general.string` route was reverted.
- Terminated the stuck Simulator Runner and rebuilt the Flutter iOS app without
  the direct pasteboard route.
- Ran `make flutter-structure-check`: passed.
- Ran `flutter test`: passed, 74 tests.
- Ran `git diff --check`: passed.
- Ran `IOSMACS_FLUTTER_IOS_NATIVE_HOLD_SECONDS=15 make
  flutter-ios-native-smoke`: passed.

Flutter iOS bracketed paste slurp optimization:

- The user confirmed paste works again but remains slow. Emacs internal
  kill/yank of the same Japanese text is fast, so the likely remaining cost is
  external terminal paste ingestion rather than final buffer insertion.
- Inspected bundled `term/xterm.el`: `xterm--pasted-text` reads bracketed paste
  contents with a `read-event` loop until `ESC [ 201 ~`, then `xterm-paste`
  inserts via `yank` / `insert-for-yank`.
- Added an iOS runtime override of `xterm--pasted-text` that keeps the same
  logic but binds `inhibit-redisplay` and `inhibit-message` while slurping the
  paste payload.
- Added structure-check guards for this runtime paste optimization.
- Ran `make flutter-structure-check`: passed.
- Ran `flutter test`: passed, 74 tests.
- Ran `git diff --check`: passed.
- Ran `IOSMACS_FLUTTER_IOS_NATIVE_HOLD_SECONDS=15 make
  flutter-ios-native-smoke`: passed.

Flutter iOS Cmd+V paste routing:

- The user pasted the long Japanese string again and observed about a 20 second
  delay.
- Pulled Simulator logs through `xcrun simctl spawn booted log show`. The
  current Runner showed Pasteboard file-coordination reads at `23:48:06.722`
  and terminal output containing the pasted Japanese text at `23:48:26.153`,
  about 19.4 seconds later.
- The same log window did not contain the native hidden-text-view
  `textinput forward` markers for the current Runner PID, so this paste likely
  bypassed the native paste override and flowed through Flutter
  `TerminalView`/normal terminal text input instead.
- Added an app-level `Cmd+V` shortcut in Flutter that calls the same
  `_pasteClipboardText()` path as the toolbar Paste button. That path uses the
  native clipboard paste bridge when accepted and otherwise falls back to
  Dart-side bracketed paste bytes.
- Added widget coverage for `Cmd+V` bracketed paste and structure-check guards
  for the shortcut/test.
- Rebuilt and installed a normal non-smoke Simulator build with trace logging.
  The black-screen/workspace-smoke startup behavior disappeared and the app
  opened directly to `*scratch*`.
- Used Computer Use to click the Paste toolbar button. The first build still
  called native `UITextView.paste(nil)` first: `pasteSystemClipboard` returned
  accepted in about 4ms, but the pasted text appeared in terminal output about
  42 seconds later. This showed the hidden `UITextView` paste path can defer
  actual text delivery after returning accepted.
- Changed `_pasteClipboardText()` to prefer Flutter `Clipboard.getData` and
  direct `TerminalInputBridge.pasteText()` before using native
  `pasteSystemClipboard` as a fallback.
- Rebuilt and tested again. Flutter Clipboard paste pushed a 354 byte payload
  through `iosmacs-native-sendBytes` in 6ms (`00:02:18.745` start,
  `00:02:18.752` accepted), proving the front-end paste delay was removed.
- That bracketed payload did not redisplay in Emacs, so bracketed paste is not
  safe as the default for this fake tty path yet.
- Changed Flutter Paste/Cmd+V and native paste fallback to send normalized raw
  UTF-8 text, converting LF/CRLF to terminal CR and avoiding bracketed paste
  markers for now.
- Ran targeted paste tests: passed.
- Ran `make flutter-structure-check`: passed.
- Ran `git diff --check`: passed.
- Rebuilt and installed the raw-normalized paste build on the iPad Simulator.
  A 342 byte Japanese paste was accepted by native `sendBytes` in 6ms and first
  appeared in terminal output about 6.1 seconds later. The screen showed the
  pasted Japanese text in `*scratch*`.

Flutter iOS paste bottleneck instrumentation:

- Added a native terminal trace marker bridge. The Flutter iOS native bridge
  now sets `IOSMACS_WEB_TERMINAL_DEBUG_MARKER` to an app temporary file and
  forwards new C/Emacs trace lines into the Runner unified log as
  `iosmacs flutter native terminal-trace ...`.
- Added Swift native `sendBytes pushed` and native `drainOutput bytes` log
  markers.
- Added Dart-side `iosmacs-native-drainOutput: first` and `chunks`
  timestamps so MethodChannel drain timing and output-stream emission can be
  compared with native and Emacs markers without logging every empty 16ms poll.
- Added structure-check guards for the new timing markers.
- Rebuilt the instrumented Simulator app and pasted a 342 byte Japanese string.
  Native `sendBytes` started at `00:18:08.965`, accepted the bytes at
  `00:18:08.971`, and Dart first saw drained output at `00:18:15.218`.
- The shared terminal marker file split the delay further: `terminal
  push-input`, `terminal read-available bytes=342`, and `emacs sysdep tty-read
  bytes=342` all occurred in the same monotonic millisecond `t=20756506`.
- The first Emacs terminal output for that paste was `terminal write-output` at
  `t=20762751`, followed by native `terminal drain-output count=434` at
  `t=20762752`.
- Current conclusion: the approximately 6245ms gap is after Emacs' tty read
  already received the full paste and before Emacs emits redisplay output. It
  is not caused by Flutter clipboard reading, native send acceptance, fake tty
  wake/read, native output drain, or Dart terminal emission.

Flutter iOS paste A/B timing:

- Added environment-controlled Emacs startup A/B toggles:
  `IOSMACS_GC_THRESHOLD_MB`, `IOSMACS_LIGHT_XTERM_INIT`,
  `IOSMACS_SKIP_XTERM_INIT`, and `IOSMACS_DISABLE_TERMINFO`.
- Added gated Emacs hotpath markers for command-loop, redisplay,
  `garbage_collect`, `try_window`, and `display_line`. The gate is controlled
  by `IOSMACS_TRACE_EMACS_HOTPATH` and only emits after terminal input is
  pushed, so startup and idle tracing do not dominate the measurement.
- Measured the repeated Japanese paste payload at 1077 UTF-8 bytes. Baseline
  normal TERMINFO timing was `tty-read` to first `write-output` = 19754ms.
- `gc-cons-threshold=100MB`: 19794ms. No improvement; this is expected because
  the current iOS probe also sets `IOSMACS_NW_SKIP_GC`.
- Lightweight `terminal-init-xterm`: 20137ms. No improvement.
- Disabled `terminal-init-xterm`: 19725ms. No improvement.
- TERMINFO disabled with internal termcap objects: 19658ms, but the display
  regressed with literal terminal capability fragments, so this path is not
  usable without more terminal capability work.
- Hotpath split after removing the noisy `maybe_garbage_collect` marker:
  `terminal push-input count=1077`, `terminal read-available bytes=1077`, and
  `emacs sysdep tty-read bytes=1077` all occurred at `t=23633386`.
- Emacs then repeatedly ran 50ms `keyboard wait-before-gobble` /
  `keyboard gobble-input nread=0` checks until `emacs hotpath
  redisplay-internal entry` at `t=23653200`.
- First pasted-text `terminal write-output` followed immediately at
  `t=23653201`, and native `terminal drain-output count=1307` followed at
  `t=23653203`.
- Current conclusion: the next bottleneck is not TERMINFO, xterm init, GC,
  Flutter Clipboard, native send, fake tty read, output drain, or Dart stream
  emission. The remaining delay is Emacs-side post-read command-loop/redisplay
  scheduling after raw terminal paste input has already been consumed.

Flutter iOS paste waitpoint fix:

- Investigated the 1077 byte A/B trace and found the repeated 50ms waits were
  introduced by the iosmacs direct tty waitpoint in `read_char`, not by normal
  Emacs redisplay. The waitpoint ran before
  `read_decoded_event_from_main_queue` even when `gobble_input` had already
  filled Emacs' `kbd_buffer`.
- Changed the generated `keyboard.c` patch so the fake tty waitpoint only waits
  when `kbd_buffer_events_waiting()` is false. This preserves event-driven
  blocking while preventing already-buffered paste input from paying a 50ms
  sleep before each decoded event read.
- Rebuilt the Emacs static probe with `IOSMACS_EMACS_OPT_FLAGS='-O3 -g'`,
  rebuilt the Flutter iOS Simulator app, installed it, and pasted the same
  1077 byte Japanese payload through the toolbar Paste button.
- New trace: `terminal push-input count=1077` at `t=24209193`,
  `terminal read-available bytes=1077` and `emacs sysdep tty-read bytes=1077`
  at `t=24209194`, first `emacs hotpath redisplay-internal entry` at
  `t=24209217`, first `terminal write-output` at `t=24209219`, and
  `terminal drain-output count=1189` at `t=24209240`.
- The post-read-to-output delay dropped from about 19.8 seconds to 25ms. The
  trace contained one later `keyboard wait-before-gobble` instead of hundreds
  of 50ms waits during the pasted input.

Flutter iOS IME and C-SPC follow-up:

- Committed the completed tty/paste performance work first as
  `7247711 Improve Flutter iOS tty paste performance`.
- Starting fixes for the follow-up regressions: Japanese input no longer
  composing reliably, and `C-SPC` entering Emacs as a plain space.
- Added a Flutter shortcut binding for `Control+Space` that sends NUL
  (`0x00`), which is the terminal byte Emacs uses for `set-mark-command`.
- Updated the iOS native hidden `UITextView` key shim so `Control+Space` also
  sends NUL, while ordinary printable hardware keys are no longer intercepted
  in `pressesBegan`. Normal text and Japanese IME composition now stay on the
  UIKit text-input path and flush only after committed text is available.
- Added widget coverage that proves `Ctrl+Space` increases backend input by
  exactly one byte.
- Verified with `flutter test test/terminal_screen_test.dart
  test/terminal_input_bridge_test.dart`, `make flutter-structure-check`,
  `git diff --check`, and `flutter build ios --simulator --debug`.
- Installed and launched the built app on the booted iPad Simulator with
  `xcrun simctl install booted build/ios/iphonesimulator/Runner.app` and
  `xcrun simctl launch booted com.example.iosmacsFlutter`.

Flutter iOS inline Japanese IME:

- Investigating inline composition display after the user reported that
  Japanese input no longer shows inline while composing.
- Confirmed `xterm.dart`'s `TerminalView` already has a composing-text render
  path that paints the IME text at the terminal cursor. The Flutter app was
  preventing that path by focusing the hidden native `UITextView` during app
  startup, foreground activation, and every native MethodChannel call.
- Removed automatic native text-input focus from app startup, app activation,
  and generic native bridge handling. The hidden native input remains available
  only for the explicit `pasteSystemClipboard` fallback.
- Added a terminal-body widget test that sends a Japanese composing
  `TextEditingValue`, verifies no backend bytes are sent during composition,
  then commits `日本語` and verifies only the committed UTF-8 bytes are sent.
- Added structure-check guards so generic MethodChannel calls and app
  activation do not re-focus the hidden native input view.
- Verified with `flutter test test/terminal_screen_test.dart
  test/terminal_input_bridge_test.dart`, `make flutter-structure-check`,
  `git diff --check`, and `flutter build ios --simulator --debug`.
- Installed and launched the rebuilt app on the booted iPad Simulator with
  process id `35199`.

Flutter iOS Japanese IME candidates:

- Starting follow-up work after inline Japanese composition improved but the
  iOS Japanese conversion candidates were still not visible enough.
- Confirmed `TerminalView` defaults to `TextInputType.emailAddress`, while
  `xterm.dart`'s lower-level `CustomTextEdit` supports ordinary text input.
- Overrode the terminal body `TerminalView` to use `TextInputType.text` so iOS
  can use the normal Japanese IME candidate UI instead of the email-address
  keyboard profile.
- Added widget coverage that asserts the terminal body is configured with
  `TextInputType.text`.
- Added structure-check guards for the terminal keyboard type and candidate UI
  coverage.
- Verified with `flutter test test/terminal_screen_test.dart
  test/terminal_input_bridge_test.dart`, `make flutter-structure-check`,
  `git diff --check`, and `flutter build ios --simulator --debug`.
- Installed and launched the rebuilt app on the booted iPad Simulator with
  process id `62574`.

Flutter iOS platform log isolation:

- Starting cleanup after CoreText/Runner diagnostic lines appeared inside the
  Emacs terminal screen.
- Found that `iosmacs_terminal_shim_attach_stdio()` redirected process-level
  stdin, stdout, and stderr to the fake tty. That made app/framework stderr
  diagnostics indistinguishable from terminal output.
- Changed the fake tty stdio attachment to redirect only stdin/stdout. Stderr
  now remains on the normal app log stream, while Emacs terminal output still
  flows through stdout to the Flutter terminal.
- Added structure-check guards that fail if process stderr is redirected or
  classified as the Flutter terminal tty again.
- Verified with `make flutter-structure-check`, `git diff --check`, and
  `flutter build ios --simulator --debug`.
- Installed and launched the rebuilt app on the booted iPad Simulator with
  process id `96259`.

Flutter iOS key repeat boost:

- Starting work after the user asked for stronger key-repeat volume when
  holding a hardware key.
- Added a terminal-body `onKeyEvent` hook that only handles
  `KeyRepeatEvent`. The original repeat event is still passed through to
  xterm, and the app sends two extra copies directly to the backend for a
  total multiplier of three.
- The repeat boost maps common terminal/navigation keys, delete/backspace,
  enter/tab/space, printable ASCII, and control-letter repeats. Meta/command
  repeats and non-ASCII text are ignored so app shortcuts and Japanese IME
  composition are not amplified.
- Added widget coverage that holds `arrowDown`, sends one repeat event, and
  verifies the repeat contributes nine input bytes: one normal escape sequence
  plus two boosted copies.
- Added structure-check guards for the repeat multiplier, `KeyRepeatEvent`
  handling, and repeat widget coverage.
- Verified with `flutter test test/terminal_screen_test.dart
  test/terminal_input_bridge_test.dart`, `make flutter-structure-check`,
  `git diff --check`, and `flutter build ios --simulator --debug`.
- Installed and launched the rebuilt app on the booted iPad Simulator with
  process id `26809`.

Flutter iOS mouse reporting:

- Checked the current Flutter terminal mouse state after the user asked
  whether mouse support is already enabled.
- `xterm.dart` supports terminal mouse reporting through `TerminalController`
  pointer inputs, but the app was relying on the default controller, which only
  forwards tap events.
- Added an explicit `TerminalController(pointerInputs:
  const PointerInputs.all())` to the terminal body so tap, scroll, drag, and
  move events can be converted into xterm mouse-reporting sequences when Emacs
  enables mouse reporting.
- Added widget coverage that asserts the terminal body controller forwards all
  pointer input types.
- Added structure-check guards for `PointerInputs.all` and the mouse-reporting
  widget coverage.
- Verified with `flutter test test/terminal_screen_test.dart
  test/terminal_input_bridge_test.dart`, `make flutter-structure-check`,
  `git diff --check`, and `flutter build ios --simulator --debug`.
- Installed and launched the rebuilt app on the booted iPad Simulator with
  process id `60217`.

## 2026-06-27

Flutter macOS child-process backend:

- Starting work to bring the Flutter macOS backend closer to the current
  Flutter iOS native path instead of stopping at process-probe diagnostics.
- Replaced the macOS Runner's process-probe-only `start` path with a held GNU
  Emacs child process launched through `forkpty(3)` as `<emacs> --quick
  --no-splash -nw`.
- The macOS native bridge now keeps the child pid plus PTY master, drains PTY
  output into `NativeEmacsBackend.outputStream`, forwards `sendBytes` to the
  PTY master, forwards redraw as form feed, resizes the PTY with
  `ioctl(TIOCSWINSZ)`, and terminates the child process on `stop`.
- Fixed the `flutter run -d macos` launch-maintenance issue where
  `/usr/local/bin/emacs` could be selected, fail to find its app resources, and
  leave the UI in a fake running state. Host Emacs discovery now prefers
  Emacs.app candidates, verifies the child survives startup, and tries the
  next candidate on early exit.
- Disabled the macOS Runner app sandbox for this local host-Emacs backend;
  with sandbox enabled, Emacs could not open `/dev/tty` even when a PTY was
  allocated.
- Kept host Emacs discovery explicit through `IOSMACS_FLUTTER_EMACS`,
  Homebrew paths, and common Emacs.app locations, with the old batch probe
  retained only as diagnostic fallback when interactive startup cannot run.
- Updated backend capabilities, Dart tests, structure checks, macOS native
  smoke assertions, and Flutter docs so macOS no longer presents the old
  PTY/process-backend pending path as the current state.
- Verified with `make flutter-structure-check`, `dart format
  --set-exit-if-changed lib test`, `flutter analyze`, `flutter test`,
  `make flutter-macos-native-smoke`, `make flutter-macos-smoke`, `make
  flutter-backend-override-smoke`, `make flutter-ios-native-smoke`, `make
  flutter-web-smoke`, `make flutter-android-smoke`, and `git diff --check`.
- `make flutter-macos-native-smoke` captured
  `macOS interactive GNU Emacs process started:` and workspace-open input
  evidence in `/tmp` app logs.
- A full `make flutter-verify` pass was attempted. It reached iOS native smoke
  after structure, doctor, format, analyze, tests, and iOS launch smoke, then
  hit a transient `did not reach *scratch*` timing failure even though the log
  showed Emacs startup/file smoke activity. Re-running `make
  flutter-ios-native-smoke` by itself passed.
