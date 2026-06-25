SHELL := /bin/bash

IOSMACS_PROJECT ?= iosmacs.xcodeproj
IOSMACS_SCHEME ?= iosmacs
IOSMACS_CONFIGURATION ?= Debug
IOSMACS_SDK ?= iphonesimulator
IOSMACS_DESTINATION ?= generic/platform=iOS Simulator
IOSMACS_IPHONE_DESTINATION ?= platform=iOS Simulator,name=iPhone 17
IOSMACS_EMACS_SOURCE ?= wasmacs/vendor/emacs
IOSMACS_SIMULATOR_UDID ?= booted
IOSMACS_APP_BUNDLE_ID ?= local.iosmacs
JOBS ?= $(shell sysctl -n hw.ncpu 2>/dev/null || printf '4')

.DEFAULT_GOAL := help

.PHONY: help deps bootstrap emacs-source emacs-info emacs-probe emacs-temacs emacs-static \
	emacs-link-smoke emacs-batch-smoke emacs-nw-smoke emacs-pdmp app app-iphone xcode-build \
	app-installl smoke verify verify-iphone check clean distclean

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
