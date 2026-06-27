#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app_dir="${repo_root}/flutter/iosmacs_flutter"
app_bundle="${app_dir}/build/macos/Build/Products/Debug/iosmacs_flutter.app"
bundled_emacs="${app_bundle}/Contents/Resources/iosmacs-emacs/bin/emacs"
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
if [[ ! -x "${bundled_emacs}" ]]; then
  echo "error: missing bundled Flutter macOS Emacs executable: ${bundled_emacs}" >&2
  exit 1
fi
runtime_root="${app_bundle}/Contents/Resources/iosmacs-emacs"
runtime_eval_check='(progn
  (when (boundp '\''read-extended-command-predicate)
    (setq read-extended-command-predicate nil))
  (when (fboundp '\''execute-extended-command)
    (global-set-key (kbd "M-X") #'\''execute-extended-command))
  (autoload '\''dired "dired" nil t)
  (autoload '\''tetris "tetris" nil t)
  (unless (eq (key-binding (kbd "M-X")) '\''execute-extended-command)
    (error "M-X is not bound to execute-extended-command"))
  (unless (commandp '\''tetris)
    (error "tetris is not commandp"))
  (princ "iosmacs-macos-mx-tetris-ok\n"))'
if ! EMACSLOADPATH="${runtime_root}/lisp" \
    EMACSDATA="${runtime_root}/etc" \
    EMACSDOC="${runtime_root}/etc" \
    EMACSPATH="${runtime_root}/libexec" \
    "${bundled_emacs}" --batch --quick --eval "${runtime_eval_check}" \
    | grep -q 'iosmacs-macos-mx-tetris-ok'; then
  echo "error: bundled Flutter macOS Emacs did not pass the M-X/tetris smoke" >&2
  exit 1
fi

rm -f "${log_path}"
"${app_executable}" >"${log_path}" 2>&1 &
app_pid=$!

sleep "${hold_seconds}"

if ! grep -q 'macOS Emacs process candidates' "${log_path}"; then
  echo "error: macOS process backend did not enumerate Emacs candidates" >&2
  cat "${log_path}" >&2 || true
  kill -TERM "${app_pid}" 2>/dev/null || true
  wait "${app_pid}" >/dev/null 2>&1 || true
  exit 1
fi

if ! grep -Fq "macOS bundled GNU Emacs runtime: ${app_bundle}/Contents/Resources/iosmacs-emacs" "${log_path}"; then
  echo "error: macOS native smoke did not report the bundled Emacs runtime" >&2
  cat "${log_path}" >&2 || true
  kill -TERM "${app_pid}" 2>/dev/null || true
  wait "${app_pid}" >/dev/null 2>&1 || true
  exit 1
fi

if ! grep -Fq "macOS interactive GNU Emacs process started: ${bundled_emacs}" "${log_path}"; then
  echo "error: macOS native smoke did not start the bundled GNU Emacs process" >&2
  cat "${log_path}" >&2 || true
  kill -TERM "${app_pid}" 2>/dev/null || true
  wait "${app_pid}" >/dev/null 2>&1 || true
  exit 1
fi

if grep -Eq '/Applications/Emacs|/opt/homebrew/bin/emacs|/usr/local/bin/emacs' "${log_path}"; then
  echo "error: macOS native smoke unexpectedly used a system Emacs candidate" >&2
  cat "${log_path}" >&2 || true
  kill -TERM "${app_pid}" 2>/dev/null || true
  wait "${app_pid}" >/dev/null 2>&1 || true
  exit 1
fi

if grep -q 'macOS Emacs process exited 1:' "${log_path}"; then
  echo "error: macOS native smoke selected an Emacs process that exited during startup" >&2
  cat "${log_path}" >&2 || true
  kill -TERM "${app_pid}" 2>/dev/null || true
  wait "${app_pid}" >/dev/null 2>&1 || true
  exit 1
fi

if grep -Eq 'Could not open file: /dev/tty|exited during startup' "${log_path}"; then
  echo "error: macOS native smoke did not keep the selected Emacs process alive at startup" >&2
  cat "${log_path}" >&2 || true
  kill -TERM "${app_pid}" 2>/dev/null || true
  wait "${app_pid}" >/dev/null 2>&1 || true
  exit 1
fi

if grep -q 'Interactive PTY GNU Emacs backend is pending' "${log_path}"; then
  echo "error: macOS native smoke regressed to the old PTY pending diagnostic" >&2
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

if ! grep -Eq 'iosmacs-resize-smoke: requested [1-9][0-9]*x[1-9][0-9]*; backend geometry [1-9][0-9]*x[1-9][0-9]*' "${log_path}"; then
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
