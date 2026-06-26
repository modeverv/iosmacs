#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app_dir="${repo_root}/flutter/iosmacs_flutter"
app_bundle="${app_dir}/build/macos/Build/Products/Debug/iosmacs_flutter.app"
hold_seconds="${IOSMACS_FLUTTER_BACKEND_OVERRIDE_HOLD_SECONDS:-2}"
backend_list="${IOSMACS_FLUTTER_BACKEND_SMOKE_BACKENDS:-fake android linux windows web-wasm}"

export PATH="${HOME}/work/flutter/bin:${PATH}"

if ! command -v flutter >/dev/null 2>&1; then
  echo "error: flutter command not found; install Flutter SDK under ~/work/flutter or add it to PATH" >&2
  exit 1
fi

expected_id_for_backend() {
  case "$1" in
    fake)
      printf 'fake\n'
      ;;
    android)
      printf 'android-placeholder\n'
      ;;
    linux)
      printf 'linux-placeholder\n'
      ;;
    windows|win)
      printf 'windows-placeholder\n'
      ;;
    web|web-wasm)
      printf 'web-wasm-placeholder\n'
      ;;
    *)
      echo "error: unsupported backend override smoke value: $1" >&2
      return 1
      ;;
  esac
}

run_backend_smoke() {
  local backend="$1"
  local expected_id
  expected_id="$(expected_id_for_backend "${backend}")"
  local log_path="${TMPDIR:-/tmp}/iosmacs-flutter-backend-override-${backend}.log"

  cd "${app_dir}"
  flutter build macos --debug \
    --dart-define=IOSMACS_FLUTTER_BACKEND="${backend}" \
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

  local executable_name
  executable_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "${app_bundle}/Contents/Info.plist")"
  local app_executable="${app_bundle}/Contents/MacOS/${executable_name}"
  if [[ ! -x "${app_executable}" ]]; then
    echo "error: missing executable Flutter macOS app binary: ${app_executable}" >&2
    exit 1
  fi

  rm -f "${log_path}"
  "${app_executable}" >"${log_path}" 2>&1 &
  local app_pid=$!

  sleep "${hold_seconds}"

  if ! grep -q "iosmacs-capabilities-smoke: id=${expected_id}" "${log_path}"; then
    echo "error: backend override ${backend} did not report ${expected_id}" >&2
    cat "${log_path}" >&2 || true
    kill -TERM "${app_pid}" 2>/dev/null || true
    wait "${app_pid}" >/dev/null 2>&1 || true
    exit 1
  fi

  if ! grep -Eq 'iosmacs-capabilities-smoke: .*supported=[1-9][0-9]* .*unsupported=[1-9][0-9]*' "${log_path}"; then
    echo "error: backend override ${backend} did not report capability counts" >&2
    cat "${log_path}" >&2 || true
    kill -TERM "${app_pid}" 2>/dev/null || true
    wait "${app_pid}" >/dev/null 2>&1 || true
    exit 1
  fi

  if ! grep -q "iosmacs-status-smoke: id=${expected_id}" "${log_path}"; then
    echo "error: backend override ${backend} did not report status smoke backend id" >&2
    cat "${log_path}" >&2 || true
    kill -TERM "${app_pid}" 2>/dev/null || true
    wait "${app_pid}" >/dev/null 2>&1 || true
    exit 1
  fi

  if ! grep -Eq 'iosmacs-status-smoke: .* lifecycle=[^ ]+ .*geometry=[1-9][0-9]*x[1-9][0-9]*' "${log_path}"; then
    echo "error: backend override ${backend} did not report status smoke lifecycle/geometry" >&2
    cat "${log_path}" >&2 || true
    kill -TERM "${app_pid}" 2>/dev/null || true
    wait "${app_pid}" >/dev/null 2>&1 || true
    exit 1
  fi

  if ! grep -Eq 'iosmacs-input-smoke: committed [1-9][0-9]* byte\(s\); backend input total [1-9][0-9]*' "${log_path}"; then
    echo "error: backend override ${backend} did not report input smoke evidence" >&2
    cat "${log_path}" >&2 || true
    kill -TERM "${app_pid}" 2>/dev/null || true
    wait "${app_pid}" >/dev/null 2>&1 || true
    exit 1
  fi

  if ! grep -Eq 'iosmacs-resize-smoke: requested [1-9][0-9]*x[1-9][0-9]*; backend geometry [1-9][0-9]*x[1-9][0-9]*' "${log_path}"; then
    echo "error: backend override ${backend} did not report resize smoke evidence" >&2
    cat "${log_path}" >&2 || true
    kill -TERM "${app_pid}" 2>/dev/null || true
    wait "${app_pid}" >/dev/null 2>&1 || true
    exit 1
  fi

  if ! grep -Eq 'iosmacs-redraw-smoke: message="[^"]+"' "${log_path}"; then
    echo "error: backend override ${backend} did not report redraw smoke evidence" >&2
    cat "${log_path}" >&2 || true
    kill -TERM "${app_pid}" 2>/dev/null || true
    wait "${app_pid}" >/dev/null 2>&1 || true
    exit 1
  fi

  if ! grep -q 'iosmacs-workspace-smoke: workspace listed' "${log_path}"; then
    echo "error: backend override ${backend} did not report workspace list evidence" >&2
    cat "${log_path}" >&2 || true
    kill -TERM "${app_pid}" 2>/dev/null || true
    wait "${app_pid}" >/dev/null 2>&1 || true
    exit 1
  fi

  if ! grep -Eq 'iosmacs-workspace-smoke: workspace imported [0-9]+ item\(s\)' "${log_path}"; then
    echo "error: backend override ${backend} did not report workspace import evidence" >&2
    cat "${log_path}" >&2 || true
    kill -TERM "${app_pid}" 2>/dev/null || true
    wait "${app_pid}" >/dev/null 2>&1 || true
    exit 1
  fi

  if ! grep -q 'iosmacs-workspace-smoke: workspace listed after import' "${log_path}"; then
    echo "error: backend override ${backend} did not report workspace list-after-import evidence" >&2
    cat "${log_path}" >&2 || true
    kill -TERM "${app_pid}" 2>/dev/null || true
    wait "${app_pid}" >/dev/null 2>&1 || true
    exit 1
  fi

  if ! grep -q 'iosmacs-workspace-smoke: workspace export candidate(s):' "${log_path}"; then
    echo "error: backend override ${backend} did not report workspace export evidence" >&2
    cat "${log_path}" >&2 || true
    kill -TERM "${app_pid}" 2>/dev/null || true
    wait "${app_pid}" >/dev/null 2>&1 || true
    exit 1
  fi

  if ! grep -Eq 'iosmacs-workspace-smoke: workspace open requested: .+ \([1-9][0-9]* byte\(s\)\); backend input total [1-9][0-9]*' "${log_path}"; then
    echo "error: backend override ${backend} did not report workspace open evidence" >&2
    cat "${log_path}" >&2 || true
    kill -TERM "${app_pid}" 2>/dev/null || true
    wait "${app_pid}" >/dev/null 2>&1 || true
    exit 1
  fi

  if ! grep -q 'iosmacs-stop-smoke: lifecycle=stopped' "${log_path}"; then
    echo "error: backend override ${backend} did not report stop smoke evidence" >&2
    cat "${log_path}" >&2 || true
    kill -TERM "${app_pid}" 2>/dev/null || true
    wait "${app_pid}" >/dev/null 2>&1 || true
    exit 1
  fi

  if ! kill -0 "${app_pid}" 2>/dev/null; then
    echo "error: backend override ${backend} app exited before clean termination" >&2
    cat "${log_path}" >&2 || true
    exit 1
  fi

  kill -TERM "${app_pid}" 2>/dev/null || true
  wait "${app_pid}" >/dev/null 2>&1 || true
  echo "flutter backend override smoke ok: ${backend} -> ${expected_id}"
}

for backend in ${backend_list}; do
  run_backend_smoke "${backend}"
done
