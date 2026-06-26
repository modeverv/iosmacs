#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app_dir="${repo_root}/flutter/iosmacs_flutter"
app_bundle="${app_dir}/build/macos/Build/Products/Debug/iosmacs_flutter.app"
hold_seconds="${IOSMACS_FLUTTER_MACOS_LAUNCH_HOLD_SECONDS:-3}"

export PATH="${HOME}/work/flutter/bin:${PATH}"

if ! command -v flutter >/dev/null 2>&1; then
  echo "error: flutter command not found; install Flutter SDK under ~/work/flutter or add it to PATH" >&2
  exit 1
fi

cd "${app_dir}"
flutter build macos --debug

if [[ ! -d "${app_bundle}" ]]; then
  echo "error: missing Flutter macOS app bundle: ${app_bundle}" >&2
  exit 1
fi

executable_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "${app_bundle}/Contents/Info.plist")"
app_executable="${app_bundle}/Contents/MacOS/${executable_name}"
if [[ ! -x "${app_executable}" ]]; then
  echo "error: missing executable Flutter macOS app binary: ${app_executable}" >&2
  exit 1
fi

"${app_executable}" >/tmp/iosmacs-flutter-macos-smoke.log 2>&1 &
app_pid=$!

sleep "${hold_seconds}"

if ! kill -0 "${app_pid}" 2>/dev/null; then
  echo "error: Flutter macOS app exited before clean termination" >&2
  cat /tmp/iosmacs-flutter-macos-smoke.log >&2 || true
  exit 1
fi

kill -TERM "${app_pid}" 2>/dev/null || true
wait "${app_pid}" >/dev/null 2>&1 || true

echo "flutter macOS smoke ok: ${app_executable}"
