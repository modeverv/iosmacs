SHELL := /bin/bash

IOSMACS_PROJECT ?= iosmacs.xcodeproj
IOSMACS_SCHEME ?= iosmacs
IOSMACS_CONFIGURATION ?= Debug
IOSMACS_SDK ?= iphonesimulator
IOSMACS_DESTINATION ?= generic/platform=iOS Simulator
IOSMACS_EMACS_SOURCE ?= wasmacs/vendor/emacs
JOBS ?= $(shell sysctl -n hw.ncpu 2>/dev/null || printf '4')

.DEFAULT_GOAL := help

.PHONY: help deps bootstrap emacs-source emacs-info emacs-probe emacs-temacs emacs-static \
	emacs-link-smoke emacs-batch-smoke emacs-nw-smoke app xcode-build smoke verify check clean

help:
	@printf '%s\n' \
	  'Common targets:' \
	  '  make deps              Fetch wasmacs and nested GNU Emacs submodules' \
	  '  make emacs-info        Print the pinned Emacs source remote, commit, and tag' \
	  '  make emacs-temacs      Build the iOS simulator temacs probe' \
	  '  make emacs-static      Build the app-linkable libiosmacs-temacs.a probe' \
	  '  make app               Build the iOS simulator app with xcodebuild' \
	  '  make smoke             Run link and batch smoke checks' \
	  '  make verify            Fresh-checkout verification: deps, smoke, app build' \
	  '  make emacs-nw-smoke    Run the terminal -nw smoke check' \
	  '  make clean             Remove generated build outputs'

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

smoke: emacs-link-smoke emacs-batch-smoke

verify: emacs-info smoke app

check: verify

app: emacs-static
	xcodebuild \
	  -project "$(IOSMACS_PROJECT)" \
	  -scheme "$(IOSMACS_SCHEME)" \
	  -configuration "$(IOSMACS_CONFIGURATION)" \
	  -sdk "$(IOSMACS_SDK)" \
	  -destination "$(IOSMACS_DESTINATION)" \
	  build

xcode-build: app

clean:
	rm -rf build
