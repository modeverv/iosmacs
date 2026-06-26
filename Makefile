SHELL := /bin/bash

IOSMACS_PROJECT ?= iosmacs.xcodeproj
IOSMACS_SCHEME ?= iosmacs
IOSMACS_CONFIGURATION ?= Debug
IOSMACS_SDK ?= iphonesimulator
IOSMACS_DESTINATION ?= generic/platform=iOS Simulator
IOSMACS_IPHONE_DESTINATION ?= platform=iOS Simulator,name=iPhone 17
IOSMACS_IPAD_DESTINATION ?= platform=iOS Simulator,name=iPad (A16)
IOSMACS_EMACS_SOURCE ?= wasmacs/vendor/emacs
IOSMACS_SIMULATOR_UDID ?= booted
IOSMACS_APP_BUNDLE_ID ?= local.iosmacs
FLUTTER_PATH := $(HOME)/work/flutter/bin:$(PATH)
FLUTTER_EMACS_BUILD_ROOT ?= $(abspath flutter/build/emacs-ios)
JOBS ?= $(shell sysctl -n hw.ncpu 2>/dev/null || printf '4')

.DEFAULT_GOAL := help

.PHONY: help deps bootstrap emacs-source emacs-info emacs-probe emacs-temacs emacs-static \
	emacs-link-smoke emacs-batch-smoke emacs-nw-smoke emacs-pdmp app app-iphone xcode-build \
	app-installl smoke verify verify-iphone flutter-doctor flutter-structure-check flutter-bootstrap \
	flutter-format-check flutter-analyze flutter-fake-smoke flutter-ios-smoke flutter-ios-launch-smoke flutter-macos-smoke \
	flutter-ios-native-smoke flutter-macos-native-smoke flutter-backend-override-smoke flutter-web-smoke flutter-android-smoke \
	flutter-emacs-static flutter-emacs-pdmp flutter-ipad-launch flutter-verify check clean distclean

help:
	@printf '%s\n' \
	  'Common targets:' \
	  '  make deps              Fetch wasmacs and nested GNU Emacs submodules' \
	  '  make emacs-info        Print the pinned Emacs source remote, commit, and tag' \
	  '  make emacs-temacs      Build the iOS simulator temacs probe' \
	  '  make emacs-static      Build the app-linkable libiosmacs-temacs.a probe' \
	  '  make emacs-pdmp        Build the bundled emacs.pdmp through the -nw smoke path' \
	  '  make app               Build the iOS simulator app with xcodebuild' \
	  '  make app-iphone        Build the iPhone simulator app with xcodebuild' \
	  '  make app-installl      Build, reinstall, and launch the simulator app' \
	  '  make smoke             Run link and batch smoke checks' \
	  '  make verify            Fresh-checkout verification: deps, smoke, app build' \
	  '  make verify-iphone     Fresh-checkout verification for iPhone simulator' \
	  '  make flutter-doctor    Run Flutter doctor with repo mise tools' \
	  '  make flutter-structure-check Check Flutter shell files without Flutter SDK' \
	  '  make flutter-bootstrap Generate Flutter platform runners when SDK is available' \
	  '  make flutter-format-check Check Dart formatting for Flutter sources and tests' \
	  '  make flutter-analyze   Run Flutter static analysis' \
	  '  make flutter-fake-smoke Run Flutter fake-backend tests when Flutter SDK is available' \
	  '  make flutter-ios-smoke Verify Flutter iOS Runner build resources and Emacs symbols' \
	  '  make flutter-ios-launch-smoke Install and launch Flutter iOS Runner on a booted simulator' \
	  '  make flutter-ios-native-smoke Capture Flutter iOS native backend runtime smoke logs' \
	  '  make flutter-emacs-static   Build Emacs static lib into flutter/build/emacs-ios (isolated)' \
	  '  make flutter-emacs-pdmp    Build Emacs pdmp into flutter/build/emacs-ios (isolated)' \
	  '  make flutter-ipad-launch    Build Flutter iOS app and launch on booted iPad simulator' \
	  '  make flutter-macos-smoke Build and launch Flutter macOS app briefly' \
	  '  make flutter-macos-native-smoke Autostart and verify Flutter macOS native probe' \
	  '  make flutter-backend-override-smoke Verify forced Flutter backend selection on macOS' \
	  '  make flutter-web-smoke   Build Flutter Web debug output' \
	  '  make flutter-android-smoke Build Flutter Android debug APK' \
	  '  make flutter-verify      Run the Flutter workstream verification checks' \
	  '  make emacs-nw-smoke    Run the terminal -nw smoke check' \
	  '  make clean             Remove repo-local generated build outputs' \
	  '  make distclean         Also remove this project scheme from Xcode DerivedData'

deps:
	git submodule update --init --recursive

bootstrap: deps emacs-info

emacs-source: deps
	@test -d "$(IOSMACS_EMACS_SOURCE)/src" || { \
	  printf 'error: missing Emacs source at %s\n' "$(IOSMACS_EMACS_SOURCE)" >&2; \
	  exit 1; \
	}
	@printf 'Emacs source ready: %s\n' "$(IOSMACS_EMACS_SOURCE)"

emacs-info: emacs-source
	@printf 'source path: %s\n' "$(IOSMACS_EMACS_SOURCE)"
	@printf 'remote: '
	@git -C "$(IOSMACS_EMACS_SOURCE)" remote get-url origin
	@printf 'commit: '
	@git -C "$(IOSMACS_EMACS_SOURCE)" rev-parse HEAD
	@printf 'tag: '
	@git -C "$(IOSMACS_EMACS_SOURCE)" describe --tags --exact-match HEAD

emacs-probe: emacs-source
	scripts/build-emacs-ios-probe.sh

emacs-temacs: emacs-source
	JOBS="$(JOBS)" scripts/build-emacs-ios-temacs-probe.sh

emacs-static: emacs-source
	JOBS="$(JOBS)" scripts/build-emacs-ios-static-probe.sh

emacs-link-smoke: emacs-static
	scripts/link-emacs-ios-static-smoke.sh

emacs-batch-smoke: emacs-static
	scripts/run-emacs-ios-batch-smoke.sh

emacs-nw-smoke: emacs-static
	scripts/run-emacs-ios-nw-smoke.sh

emacs-pdmp: emacs-nw-smoke

smoke: emacs-link-smoke emacs-batch-smoke

verify: emacs-info smoke app

verify-iphone: emacs-info smoke app-iphone

flutter-doctor:
	mise exec -- bash -lc 'PATH="$$HOME/work/flutter/bin:$$PATH"; flutter doctor -v'

flutter-structure-check:
	scripts/check-flutter-structure.sh

flutter-bootstrap:
	@PATH="$(FLUTTER_PATH)"; command -v flutter >/dev/null 2>&1 || { \
	  printf 'error: flutter command not found; install Flutter SDK or add it to PATH\n' >&2; \
	  exit 127; \
	}
	cd flutter/iosmacs_flutter && PATH="$(FLUTTER_PATH)" \
	  flutter create . \
	    --project-name iosmacs_flutter \
	    --platforms=ios,android,macos,linux,windows,web

flutter-format-check:
	@PATH="$(FLUTTER_PATH)"; command -v dart >/dev/null 2>&1 || { \
	  printf 'error: dart command not found; install Flutter SDK or add it to PATH\n' >&2; \
	  exit 127; \
	}
	cd flutter/iosmacs_flutter && PATH="$(FLUTTER_PATH)" dart format --set-exit-if-changed lib test

flutter-analyze:
	@PATH="$(FLUTTER_PATH)"; command -v flutter >/dev/null 2>&1 || { \
	  printf 'error: flutter command not found; install Flutter SDK or add it to PATH\n' >&2; \
	  exit 127; \
	}
	cd flutter/iosmacs_flutter && PATH="$(FLUTTER_PATH)" flutter pub get && PATH="$(FLUTTER_PATH)" flutter analyze

flutter-fake-smoke:
	@PATH="$(FLUTTER_PATH)"; command -v flutter >/dev/null 2>&1 || { \
	  printf 'error: flutter command not found; install Flutter SDK or add it to PATH\n' >&2; \
	  exit 127; \
	}
	cd flutter/iosmacs_flutter && PATH="$(FLUTTER_PATH)" flutter pub get && PATH="$(FLUTTER_PATH)" flutter test

flutter-ios-smoke:
	scripts/check-flutter-ios-runner-smoke.sh

flutter-emacs-static:
	IOSMACS_BUILD_ROOT="$(FLUTTER_EMACS_BUILD_ROOT)" JOBS="$(JOBS)" \
	  scripts/build-emacs-ios-static-probe.sh

flutter-emacs-pdmp: flutter-emacs-static
	IOSMACS_BUILD_ROOT="$(FLUTTER_EMACS_BUILD_ROOT)" JOBS="$(JOBS)" \
	  scripts/run-emacs-ios-nw-smoke.sh

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
	cd flutter/iosmacs_flutter && PATH="$(FLUTTER_PATH)" \
	  flutter run --device-id "$$ipad_udid" --debug

flutter-macos-smoke:
	scripts/run-flutter-macos-smoke.sh

flutter-macos-native-smoke:
	scripts/run-flutter-macos-native-smoke.sh

flutter-backend-override-smoke:
	scripts/run-flutter-backend-override-smoke.sh

flutter-web-smoke:
	cd flutter/iosmacs_flutter && PATH="$(FLUTTER_PATH)" flutter build web --debug

flutter-android-smoke:
	cd flutter/iosmacs_flutter && PATH="$(FLUTTER_PATH)" flutter build apk --debug

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
	$(MAKE) flutter-backend-override-smoke
	$(MAKE) flutter-web-smoke
	$(MAKE) flutter-android-smoke

check: verify

app: emacs-static emacs-pdmp
	xcodebuild \
	  -project "$(IOSMACS_PROJECT)" \
	  -scheme "$(IOSMACS_SCHEME)" \
	  -configuration "$(IOSMACS_CONFIGURATION)" \
	  -sdk "$(IOSMACS_SDK)" \
	  -destination "$(IOSMACS_DESTINATION)" \
	  build

app-iphone: emacs-static emacs-pdmp
	xcodebuild \
	  -project "$(IOSMACS_PROJECT)" \
	  -scheme "$(IOSMACS_SCHEME)" \
	  -configuration "$(IOSMACS_CONFIGURATION)" \
	  -sdk "$(IOSMACS_SDK)" \
	  -destination "$(IOSMACS_IPHONE_DESTINATION)" \
	  build

xcode-build: app

app-install: app
	@set -euo pipefail; \
	app_path="$$(xcodebuild \
	  -project "$(IOSMACS_PROJECT)" \
	  -scheme "$(IOSMACS_SCHEME)" \
	  -configuration "$(IOSMACS_CONFIGURATION)" \
	  -sdk "$(IOSMACS_SDK)" \
	  -destination "$(IOSMACS_DESTINATION)" \
	  -showBuildSettings 2>/dev/null | \
	  awk -F'= ' '\
	    / TARGET_BUILD_DIR = / { target_build_dir = $$2 } \
	    / WRAPPER_NAME = / { wrapper_name = $$2 } \
	    END { if (target_build_dir && wrapper_name) print target_build_dir "/" wrapper_name }')"; \
	if [[ -z "$$app_path" || ! -d "$$app_path" ]]; then \
	  printf 'error: built app not found: %s\n' "$$app_path" >&2; \
	  exit 1; \
	fi; \
	xcrun simctl terminate "$(IOSMACS_SIMULATOR_UDID)" "$(IOSMACS_APP_BUNDLE_ID)" >/dev/null 2>&1 || true; \
	xcrun simctl install "$(IOSMACS_SIMULATOR_UDID)" "$$app_path"; \
	xcrun simctl launch "$(IOSMACS_SIMULATOR_UDID)" "$(IOSMACS_APP_BUNDLE_ID)"

clean:
	rm -rf build

distclean: clean
	rm -rf "$${HOME}/Library/Developer/Xcode/DerivedData/$(IOSMACS_SCHEME)-"*
