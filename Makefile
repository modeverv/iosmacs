SHELL := /bin/bash

FLUTTER_PATH := $(HOME)/work/flutter/bin:$(PATH)
FLUTTER_EMACS_BUILD_ROOT ?= $(abspath build/emacs-ios)
JOBS ?= $(shell sysctl -n hw.ncpu 2>/dev/null || printf '4')

.DEFAULT_GOAL := help

.PHONY: help bootstrap \
	flutter-doctor flutter-structure-check flutter-bootstrap \
	flutter-format-check flutter-analyze flutter-fake-smoke flutter-ios-smoke flutter-ios-launch-smoke flutter-macos-smoke \
	flutter-ios-native-smoke flutter-macos-native-smoke flutter-linux-smoke flutter-linux-native-smoke flutter-linux-emacs-runtime flutter-backend-override-smoke flutter-web-smoke flutter-android-smoke \
	flutter-android-emulator-smoke flutter-android-parity-smoke flutter-android-emacs-configure flutter-android-emacs-runtime \
	flutter-android-emacs-nw-configure flutter-android-emacs-nw-build flutter-android-emacs-nw-pdumper-build \
	flutter-emacs-static flutter-emacs-pdmp flutter-macos-emacs-runtime flutter-ipad-launch \
	flutter-windows-emacs-runtime flutter-windows-native-smoke \
	flutter-verify check clean distclean

help:
	@printf '%s\n' \
	  'Common targets:' \
	  '  make flutter-doctor    Run Flutter doctor with repo mise tools' \
	  '  make flutter-structure-check Check Flutter shell files without Flutter SDK' \
	  '  make flutter-bootstrap Generate Flutter platform runners when SDK is available' \
	  '  make flutter-format-check Check Dart formatting for Flutter sources and tests' \
	  '  make flutter-analyze   Run Flutter static analysis' \
	  '  make flutter-fake-smoke Run Flutter fake-backend tests when Flutter SDK is available' \
	  '  make flutter-ios-smoke Verify Flutter iOS Runner build resources and Emacs symbols' \
	  '  make flutter-ios-launch-smoke Install and launch Flutter iOS Runner on a booted simulator' \
	  '  make flutter-ios-native-smoke Capture Flutter iOS native backend runtime smoke logs' \
	  '  make flutter-emacs-static   Build Emacs static lib into build/emacs-ios (isolated)' \
	  '  make flutter-emacs-pdmp    Build Emacs pdmp into build/emacs-ios (isolated)' \
	  '  make flutter-linux-emacs-runtime Build bundled Linux Emacs runtime for Flutter' \
	  '  make flutter-macos-emacs-runtime Build bundled macOS Emacs runtime for Flutter' \
	  '  make flutter-windows-emacs-runtime Build bundled Windows Emacs runtime via MSYS2/MinGW' \
	  '  make flutter-ipad-launch    Build Flutter iOS app and launch on booted iPad simulator' \
	  '  make flutter-macos-smoke Build and launch Flutter macOS app briefly' \
	  '  make flutter-macos-native-smoke Autostart and verify Flutter macOS native probe' \
	  '  make flutter-linux-smoke Build and launch Flutter Linux app briefly' \
	  '  make flutter-linux-native-smoke Autostart and verify Flutter Linux native probe' \
	  '  make flutter-windows-native-smoke Build and verify Flutter Windows native Emacs bridge smoke' \
	  '  make flutter-backend-override-smoke Verify forced Flutter backend selection on macOS' \
	  '  make flutter-web-smoke   Build Flutter Web debug output' \
	  '  make flutter-android-smoke Build Flutter Android debug APK' \
	  '  make flutter-android-emulator-smoke Build, install, launch, and screenshot Android emulator app' \
	  '  make flutter-android-parity-smoke Require Android NW pdump, recovery, network, and relaunch evidence' \
	  '  make flutter-android-emacs-configure Configure GNU Emacs for Android NDK runtime work' \
	  '  make flutter-android-emacs-runtime Build GNU Emacs Android runtime and required host tools' \
	  '  make flutter-android-emacs-nw-configure Configure GNU Emacs NW text-terminal for Android' \
	  '  make flutter-android-emacs-nw-build Build GNU Emacs NW binary for Android (libemacs_nw.so)' \
	  '  make flutter-android-emacs-nw-pdumper-build Build Android NW binary with pdumper support' \
	  '  make flutter-verify      Run the Flutter workstream verification checks' \
	  '  make clean             Remove repo-local generated build outputs'

bootstrap: flutter-bootstrap

flutter-doctor:
	mise exec -- bash -lc 'PATH="$$HOME/work/flutter/bin:$$PATH"; flutter doctor -v'

flutter-structure-check:
	scripts/check-flutter-structure.sh

flutter-bootstrap:
	@PATH="$(FLUTTER_PATH)"; command -v flutter >/dev/null 2>&1 || { \
	  printf 'error: flutter command not found; install Flutter SDK or add it to PATH\n' >&2; \
	  exit 127; \
	}
	PATH="$(FLUTTER_PATH)" \
	  flutter create . \
	    --project-name fluttmacs \
	    --platforms=ios,android,macos,linux,windows,web

flutter-format-check:
	@PATH="$(FLUTTER_PATH)"; command -v dart >/dev/null 2>&1 || { \
	  printf 'error: dart command not found; install Flutter SDK or add it to PATH\n' >&2; \
	  exit 127; \
	}
	PATH="$(FLUTTER_PATH)" dart format --set-exit-if-changed lib test

flutter-analyze:
	@PATH="$(FLUTTER_PATH)"; command -v flutter >/dev/null 2>&1 || { \
	  printf 'error: flutter command not found; install Flutter SDK or add it to PATH\n' >&2; \
	  exit 127; \
	}
	PATH="$(FLUTTER_PATH)" flutter pub get && PATH="$(FLUTTER_PATH)" flutter analyze

flutter-fake-smoke:
	@PATH="$(FLUTTER_PATH)"; command -v flutter >/dev/null 2>&1 || { \
	  printf 'error: flutter command not found; install Flutter SDK or add it to PATH\n' >&2; \
	  exit 127; \
	}
	PATH="$(FLUTTER_PATH)" flutter pub get && PATH="$(FLUTTER_PATH)" flutter test

flutter-ios-smoke:
	scripts/check-flutter-ios-runner-smoke.sh

flutter-emacs-static:
	IOSMACS_BUILD_ROOT="$(FLUTTER_EMACS_BUILD_ROOT)" JOBS="$(JOBS)" \
	  scripts/build-emacs-ios-static-probe.sh

flutter-emacs-pdmp: flutter-emacs-static
	IOSMACS_BUILD_ROOT="$(FLUTTER_EMACS_BUILD_ROOT)" JOBS="$(JOBS)" \
	  scripts/run-emacs-ios-nw-smoke.sh

flutter-linux-emacs-runtime:
	JOBS="$(JOBS)" scripts/build-flutter-linux-emacs-runtime.sh

flutter-macos-emacs-runtime:
	JOBS="$(JOBS)" scripts/build-flutter-macos-emacs-runtime.sh

flutter-windows-emacs-runtime:
	powershell.exe -ExecutionPolicy Bypass -File scripts/build-emacs-windows-runtime.ps1

flutter-windows-native-smoke:
	powershell.exe -ExecutionPolicy Bypass -File scripts/run-flutter-windows-native-smoke.ps1

flutter-ios-launch-smoke:
	scripts/run-flutter-ios-launch-smoke.sh

flutter-ios-native-smoke:
	IOSMACS_FLUTTER_IOS_EXPECT_SCRATCH=1 \
	IOSMACS_FLUTTER_IOS_EXPECT_INPUT_INSERTION=1 \
	IOSMACS_FLUTTER_IOS_EXPECT_COMMAND_MARKER=1 \
	IOSMACS_FLUTTER_IOS_EXPECT_FILE_OPS=1 \
	IOSMACS_FLUTTER_IOS_EXPECT_COMMANDS=1 \
	IOSMACS_FLUTTER_IOS_EXPECT_RELAUNCH_PERSISTENCE=1 \
	  scripts/run-flutter-ios-native-smoke.sh

flutter-ipad-launch: flutter-emacs-pdmp
	@PATH="$(FLUTTER_PATH)"; command -v flutter >/dev/null 2>&1 || { \
	  printf 'error: flutter command not found; install Flutter SDK under ~/work/flutter or add it to PATH\n' >&2; \
	  exit 127; \
	}
	@if ! xcrun simctl list devices booted | grep -qi "ipad"; then \
	  printf 'error: no booted iPad simulator found; open Simulator.app and boot an iPad device\n' >&2; \
	  exit 1; \
	fi
	@ipad_udid="$$(xcrun simctl list devices booted | grep -i ipad | grep -oE '[0-9A-F-]{36}' | head -1)"; \
	if [[ -z "$$ipad_udid" ]]; then \
	  printf 'error: could not resolve booted iPad UDID\n' >&2; \
	  exit 1; \
	fi; \
	PATH="$(FLUTTER_PATH)" \
	  flutter run --device-id "$$ipad_udid" --debug

flutter-macos-smoke:
	scripts/run-flutter-macos-smoke.sh

flutter-macos-native-smoke:
	scripts/run-flutter-macos-native-smoke.sh

flutter-linux-smoke:
	scripts/run-flutter-linux-smoke.sh

flutter-linux-native-smoke:
	scripts/run-flutter-linux-native-smoke.sh

flutter-backend-override-smoke:
	scripts/run-flutter-backend-override-smoke.sh

flutter-web-smoke:
	PATH="$(FLUTTER_PATH)" flutter build web --debug

flutter-android-smoke:
	PATH="$(FLUTTER_PATH)" flutter build apk --debug

flutter-android-emulator-smoke:
	scripts/run-flutter-android-emulator-smoke.sh

flutter-android-parity-smoke:
	IOSMACS_ANDROID_EXPECT_PDUMP=1 \
	  IOSMACS_ANDROID_EXPECT_PDUMP_REUSE=1 \
	  IOSMACS_ANDROID_EXPECT_PDUMP_RECOVERY=1 \
	  IOSMACS_ANDROID_EXPECT_NETWORK=1 \
	  scripts/run-flutter-android-emulator-smoke.sh

flutter-android-emacs-configure:
	scripts/build-flutter-android-emacs-runtime.sh

flutter-android-emacs-runtime:
	IOSMACS_ANDROID_EMACS_BUILD_LIBS=1 scripts/build-flutter-android-emacs-runtime.sh

flutter-android-emacs-nw-configure:
	scripts/build-flutter-android-emacs-nw.sh

flutter-android-emacs-nw-build:
	IOSMACS_ANDROID_EMACS_NW_BUILD=1 scripts/build-flutter-android-emacs-nw.sh

flutter-android-emacs-nw-pdumper-build:
	IOSMACS_ANDROID_EMACS_NW_PDUMPER=1 IOSMACS_ANDROID_EMACS_NW_BUILD=1 \
	  scripts/build-flutter-android-emacs-nw.sh

flutter-verify:
	$(MAKE) flutter-structure-check
	$(MAKE) flutter-doctor
	$(MAKE) flutter-format-check
	$(MAKE) flutter-analyze
	$(MAKE) flutter-fake-smoke
	$(MAKE) flutter-ios-launch-smoke
	$(MAKE) flutter-ios-native-smoke
	$(MAKE) flutter-macos-smoke
	$(MAKE) flutter-macos-native-smoke
	$(MAKE) flutter-linux-smoke
	$(MAKE) flutter-linux-native-smoke
	$(MAKE) flutter-backend-override-smoke
	$(MAKE) flutter-web-smoke
	$(MAKE) flutter-android-smoke

check: flutter-verify

clean:
	rm -rf build

distclean: clean
