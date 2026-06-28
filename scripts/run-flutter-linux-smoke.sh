#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app_dir="${repo_root}"
app_executable="${app_dir}/build/linux/x64/debug/bundle/fluttmacs"
hold_seconds="${IOSMACS_FLUTTER_LINUX_LAUNCH_HOLD_SECONDS:-3}"

export PATH="${HOME}/work/flutter/bin:${PATH}"

if ! command -v flutter >/dev/null 2>&1; then
  echo "error: flutter command not found; install Flutter SDK under ~/work/flutter or add it to PATH" >&2
  exit 1
fi

cd "${app_dir}"
flutter build linux --debug

if [[ ! -x "${app_executable}" ]]; then
  echo "error: missing executable Flutter Linux app binary: ${app_executable}" >&2
  exit 1
fi

# Run with XVFB or directly in background (since we are in a GUI environment or headless testing)
# Using xvfb-run if available is safer for GUI apps on headless servers, but let's check xvfb-run or run directly.
if command -v xvfb-run >/dev/null 2>&1; then
  xvfb-run --auto-servernum "${app_executable}" >/tmp/iosmacs-flutter-linux-smoke.log 2>&1 &
else
  "${app_executable}" >/tmp/iosmacs-flutter-linux-smoke.log 2>&1 &
fi
app_pid=$!

sleep "${hold_seconds}"

if ! kill -0 "${app_pid}" 2>/dev/null; then
  echo "error: Flutter Linux app exited before clean termination" >&2
  cat /tmp/iosmacs-flutter-linux-smoke.log >&2 || true
  exit 1
fi

kill -TERM "${app_pid}" 2>/dev/null || true
wait "${app_pid}" >/dev/null 2>&1 || true

echo "flutter Linux smoke ok: ${app_executable}"
