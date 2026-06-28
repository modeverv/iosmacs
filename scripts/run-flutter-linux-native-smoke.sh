#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app_dir="${repo_root}"
bundle_dir="${app_dir}/build/linux/x64/debug/bundle"
app_executable="${bundle_dir}/fluttmacs"
bundled_emacs="${bundle_dir}/data/iosmacs-emacs/bin/emacs"
log_path="${TMPDIR:-/tmp}/iosmacs-flutter-linux-native-smoke.log"
hold_seconds="${IOSMACS_FLUTTER_LINUX_NATIVE_HOLD_SECONDS:-5}"

export PATH="${HOME}/work/flutter/bin:${PATH}"

if ! command -v flutter >/dev/null 2>&1; then
  echo "error: flutter command not found; install Flutter SDK under ~/work/flutter or add it to PATH" >&2
  exit 1
fi

emacs_runtime="${repo_root}/build/emacs-linux/runtime"
if [[ ! -x "${emacs_runtime}/bin/emacs" ]]; then
  echo "error: Linux Emacs runtime not built; run: make flutter-linux-emacs-runtime" >&2
  exit 1
fi

cd "${app_dir}"
flutter build linux --debug \
  --dart-define=IOSMACS_FLUTTER_AUTOSTART_NATIVE=true \
  --dart-define=IOSMACS_FLUTTER_MIRROR_TERMINAL_OUTPUT=true \
  --dart-define=IOSMACS_FLUTTER_CAPABILITIES_SMOKE=true \
  --dart-define=IOSMACS_FLUTTER_INPUT_SMOKE=true \
  --dart-define=IOSMACS_FLUTTER_RESIZE_SMOKE=true \
  --dart-define=IOSMACS_FLUTTER_REDRAW_SMOKE=true \
  --dart-define=IOSMACS_FLUTTER_STATUS_SMOKE=true \
  --dart-define=IOSMACS_FLUTTER_STOP_SMOKE=true \
  --dart-define=IOSMACS_FLUTTER_WORKSPACE_SMOKE=true

if [[ ! -x "${app_executable}" ]]; then
  echo "error: missing executable Flutter Linux app binary: ${app_executable}" >&2
  exit 1
fi

if [[ ! -x "${bundled_emacs}" ]]; then
  echo "error: missing bundled Emacs in Flutter Linux app bundle: ${bundled_emacs}" >&2
  exit 1
fi

rm -f "${log_path}"
if command -v xvfb-run >/dev/null 2>&1; then
  xvfb-run --auto-servernum "${app_executable}" >"${log_path}" 2>&1 &
else
  "${app_executable}" >"${log_path}" 2>&1 &
fi
app_pid=$!

sleep "${hold_seconds}"

check_log() {
  local pattern="$1"
  local msg="$2"
  if ! grep -Eq "${pattern}" "${log_path}"; then
    echo "error: ${msg}" >&2
    cat "${log_path}" >&2 || true
    kill -TERM "${app_pid}" 2>/dev/null || true
    wait "${app_pid}" >/dev/null 2>&1 || true
    exit 1
  fi
}

check_log_q() {
  local pattern="$1"
  local msg="$2"
  if ! grep -q "${pattern}" "${log_path}"; then
    echo "error: ${msg}" >&2
    cat "${log_path}" >&2 || true
    kill -TERM "${app_pid}" 2>/dev/null || true
    wait "${app_pid}" >/dev/null 2>&1 || true
    exit 1
  fi
}

check_log 'Linux Emacs process candidates' \
  "Linux process backend did not enumerate Emacs candidates"

check_log 'Linux interactive GNU Emacs process started: .*/data/iosmacs-emacs/bin/emacs' \
  "Linux native smoke did not start the bundled GNU Emacs process"

if grep -q 'Linux Emacs process exited 1:' "${log_path}"; then
  echo "error: Linux native smoke selected an Emacs process that exited during startup" >&2
  cat "${log_path}" >&2 || true
  kill -TERM "${app_pid}" 2>/dev/null || true
  wait "${app_pid}" >/dev/null 2>&1 || true
  exit 1
fi

if grep -Eq 'Could not open file: /dev/tty|exited during startup' "${log_path}"; then
  echo "error: Linux native smoke did not keep the bundled Emacs process alive at startup" >&2
  cat "${log_path}" >&2 || true
  kill -TERM "${app_pid}" 2>/dev/null || true
  wait "${app_pid}" >/dev/null 2>&1 || true
  exit 1
fi

check_log_q 'iosmacs-capabilities-smoke: id=platform-native-channel' \
  "Linux native smoke did not report selected backend capabilities"

check_log 'iosmacs-capabilities-smoke: .*supported=[1-9][0-9]* .*unsupported=[1-9][0-9]*' \
  "Linux native smoke did not report capability counts"

check_log_q 'iosmacs-status-smoke: id=platform-native-channel' \
  "Linux native smoke did not report status smoke backend id"

check_log 'iosmacs-status-smoke: .* lifecycle=[^ ]+ .*geometry=[1-9][0-9]*x[1-9][0-9]*' \
  "Linux native smoke did not report status smoke lifecycle/geometry"

check_log 'iosmacs-input-smoke: committed [1-9][0-9]* byte\(s\); backend input total [1-9][0-9]*' \
  "Linux native smoke did not report input smoke evidence"

check_log 'iosmacs-resize-smoke: requested [1-9][0-9]*x[1-9][0-9]*; backend geometry [1-9][0-9]*x[1-9][0-9]*' \
  "Linux native smoke did not report resize smoke evidence"

check_log 'iosmacs-redraw-smoke: message="[^"]+"' \
  "Linux native smoke did not report redraw smoke evidence"

check_log_q 'iosmacs-stop-smoke: lifecycle=stopped' \
  "Linux native smoke did not report stop smoke evidence"

check_log_q 'iosmacs-workspace-smoke: workspace listed' \
  "Linux workspace smoke did not list workspace entries"

if ! grep -q 'iosmacs-workspace-smoke: workspace export candidate(s):' "${log_path}"; then
  echo "error: Linux workspace smoke did not report export candidates" >&2
  cat "${log_path}" >&2 || true
  kill -TERM "${app_pid}" 2>/dev/null || true
  wait "${app_pid}" >/dev/null 2>&1 || true
  exit 1
fi

if ! grep -q 'iosmacs-workspace-smoke: workspace imported 1 item(s)' "${log_path}"; then
  echo "error: Linux workspace smoke did not import the smoke file" >&2
  cat "${log_path}" >&2 || true
  kill -TERM "${app_pid}" 2>/dev/null || true
  wait "${app_pid}" >/dev/null 2>&1 || true
  exit 1
fi

check_log_q 'iosmacs-workspace-smoke: workspace listed after import' \
  "Linux workspace smoke did not list workspace after import"

check_log 'iosmacs-workspace-smoke: workspace open requested: .+ \([1-9][0-9]* byte\(s\)\); backend input total [1-9][0-9]*' \
  "Linux workspace smoke did not report workspace open evidence"

if ! kill -0 "${app_pid}" 2>/dev/null; then
  echo "error: Flutter Linux app exited before clean termination" >&2
  cat "${log_path}" >&2 || true
  exit 1
fi

kill -TERM "${app_pid}" 2>/dev/null || true
wait "${app_pid}" >/dev/null 2>&1 || true

echo "flutter Linux native smoke ok: ${log_path}"
