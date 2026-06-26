#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app_dir="${repo_root}/flutter/iosmacs_flutter"
app_bundle="${app_dir}/build/macos/Build/Products/Debug/iosmacs_flutter.app"
log_path="${TMPDIR:-/tmp}/iosmacs-flutter-macos-native-smoke.log"
hold_seconds="${IOSMACS_FLUTTER_MACOS_NATIVE_HOLD_SECONDS:-5}"

export PATH="${HOME}/work/flutter/bin:${PATH}"

if ! command -v flutter >/dev/null 2>&1; then
  echo "error: flutter command not found; install Flutter SDK under ~/work/flutter or add it to PATH" >&2
  exit 1
fi

cd "${app_dir}"
flutter build macos --debug \
  --dart-define=IOSMACS_FLUTTER_AUTOSTART_NATIVE=true \
  --dart-define=IOSMACS_FLUTTER_MIRROR_TERMINAL_OUTPUT=true \
  --dart-define=IOSMACS_FLUTTER_CAPABILITIES_SMOKE=true \
  --dart-define=IOSMACS_FLUTTER_INPUT_SMOKE=true \
  --dart-define=IOSMACS_FLUTTER_RESIZE_SMOKE=true \
  --dart-define=IOSMACS_FLUTTER_REDRAW_SMOKE=true \
  --dart-define=IOSMACS_FLUTTER_STATUS_SMOKE=true \
  --dart-define=IOSMACS_FLUTTER_STOP_SMOKE=true \
  --dart-define=IOSMACS_FLUTTER_WORKSPACE_SMOKE=true

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

rm -f "${log_path}"
"${app_executable}" >"${log_path}" 2>&1 &
app_pid=$!

sleep "${hold_seconds}"

if ! grep -q 'macOS Emacs process probe candidates' "${log_path}"; then
  echo "error: macOS process probe did not start" >&2
  cat "${log_path}" >&2 || true
  kill -TERM "${app_pid}" 2>/dev/null || true
  wait "${app_pid}" >/dev/null 2>&1 || true
  exit 1
fi

if ! grep -Eq 'iosmacs-macos-process-ok|macOS Emacs process probe unavailable' "${log_path}"; then
  echo "error: macOS process probe did not report success or explicit unavailability" >&2
  cat "${log_path}" >&2 || true
  kill -TERM "${app_pid}" 2>/dev/null || true
  wait "${app_pid}" >/dev/null 2>&1 || true
  exit 1
fi

if ! grep -q 'Interactive PTY GNU Emacs backend is pending' "${log_path}"; then
  echo "error: macOS native smoke did not preserve PTY pending diagnostic" >&2
  cat "${log_path}" >&2 || true
  kill -TERM "${app_pid}" 2>/dev/null || true
  wait "${app_pid}" >/dev/null 2>&1 || true
  exit 1
fi

if ! grep -q 'iosmacs-capabilities-smoke: id=platform-native-channel' "${log_path}"; then
  echo "error: macOS native smoke did not report selected backend capabilities" >&2
  cat "${log_path}" >&2 || true
  kill -TERM "${app_pid}" 2>/dev/null || true
  wait "${app_pid}" >/dev/null 2>&1 || true
  exit 1
fi

if ! grep -Eq 'iosmacs-capabilities-smoke: .*supported=[1-9][0-9]* .*unsupported=[1-9][0-9]*' "${log_path}"; then
  echo "error: macOS native smoke did not report capability counts" >&2
  cat "${log_path}" >&2 || true
  kill -TERM "${app_pid}" 2>/dev/null || true
  wait "${app_pid}" >/dev/null 2>&1 || true
  exit 1
fi

if ! grep -q 'iosmacs-status-smoke: id=platform-native-channel' "${log_path}"; then
  echo "error: macOS native smoke did not report status smoke backend id" >&2
  cat "${log_path}" >&2 || true
  kill -TERM "${app_pid}" 2>/dev/null || true
  wait "${app_pid}" >/dev/null 2>&1 || true
  exit 1
fi

if ! grep -Eq 'iosmacs-status-smoke: .* lifecycle=[^ ]+ .*geometry=[1-9][0-9]*x[1-9][0-9]*' "${log_path}"; then
  echo "error: macOS native smoke did not report status smoke lifecycle/geometry" >&2
  cat "${log_path}" >&2 || true
  kill -TERM "${app_pid}" 2>/dev/null || true
  wait "${app_pid}" >/dev/null 2>&1 || true
  exit 1
fi

if ! grep -Eq 'iosmacs-input-smoke: committed [1-9][0-9]* byte\(s\); backend input total [1-9][0-9]*' "${log_path}"; then
  echo "error: macOS native smoke did not report input smoke evidence" >&2
  cat "${log_path}" >&2 || true
  kill -TERM "${app_pid}" 2>/dev/null || true
  wait "${app_pid}" >/dev/null 2>&1 || true
  exit 1
fi

if ! grep -q 'iosmacs-resize-smoke: requested 100x30; backend geometry 100x30' "${log_path}"; then
  echo "error: macOS native smoke did not report resize smoke evidence" >&2
  cat "${log_path}" >&2 || true
  kill -TERM "${app_pid}" 2>/dev/null || true
  wait "${app_pid}" >/dev/null 2>&1 || true
  exit 1
fi

if ! grep -Eq 'iosmacs-redraw-smoke: message="[^"]+"' "${log_path}"; then
  echo "error: macOS native smoke did not report redraw smoke evidence" >&2
  cat "${log_path}" >&2 || true
  kill -TERM "${app_pid}" 2>/dev/null || true
  wait "${app_pid}" >/dev/null 2>&1 || true
  exit 1
fi

if ! grep -q 'iosmacs-stop-smoke: lifecycle=stopped' "${log_path}"; then
  echo "error: macOS native smoke did not report stop smoke evidence" >&2
  cat "${log_path}" >&2 || true
  kill -TERM "${app_pid}" 2>/dev/null || true
  wait "${app_pid}" >/dev/null 2>&1 || true
  exit 1
fi

if ! grep -q 'iosmacs-workspace-smoke: workspace listed' "${log_path}"; then
  echo "error: macOS workspace smoke did not list workspace entries" >&2
  cat "${log_path}" >&2 || true
  kill -TERM "${app_pid}" 2>/dev/null || true
  wait "${app_pid}" >/dev/null 2>&1 || true
  exit 1
fi

if ! grep -q 'iosmacs-workspace-smoke: workspace export candidate(s):' "${log_path}"; then
  echo "error: macOS workspace smoke did not report export candidates" >&2
  cat "${log_path}" >&2 || true
  kill -TERM "${app_pid}" 2>/dev/null || true
  wait "${app_pid}" >/dev/null 2>&1 || true
  exit 1
fi

if ! grep -q 'iosmacs-workspace-smoke: workspace imported 1 item(s)' "${log_path}"; then
  echo "error: macOS workspace smoke did not import the smoke file" >&2
  cat "${log_path}" >&2 || true
  kill -TERM "${app_pid}" 2>/dev/null || true
  wait "${app_pid}" >/dev/null 2>&1 || true
  exit 1
fi

if ! grep -q 'iosmacs-workspace-smoke: workspace listed after import' "${log_path}"; then
  echo "error: macOS workspace smoke did not list workspace after import" >&2
  cat "${log_path}" >&2 || true
  kill -TERM "${app_pid}" 2>/dev/null || true
  wait "${app_pid}" >/dev/null 2>&1 || true
  exit 1
fi

if ! grep -Eq 'iosmacs-workspace-smoke: workspace open requested: .+ \([1-9][0-9]* byte\(s\)\); backend input total [1-9][0-9]*' "${log_path}"; then
  echo "error: macOS workspace smoke did not report workspace open evidence" >&2
  cat "${log_path}" >&2 || true
  kill -TERM "${app_pid}" 2>/dev/null || true
  wait "${app_pid}" >/dev/null 2>&1 || true
  exit 1
fi

if ! kill -0 "${app_pid}" 2>/dev/null; then
  echo "error: Flutter macOS app exited before clean termination" >&2
  cat "${log_path}" >&2 || true
  exit 1
fi

kill -TERM "${app_pid}" 2>/dev/null || true
wait "${app_pid}" >/dev/null 2>&1 || true

echo "flutter macOS native smoke ok: ${log_path}"
