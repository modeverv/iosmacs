#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app_dir="${repo_root}/flutter/iosmacs_flutter"
runner_app="${app_dir}/build/ios/iphonesimulator/Runner.app"
device="${IOSMACS_SIMULATOR_UDID:-booted}"
hold_seconds="${IOSMACS_FLUTTER_IOS_NATIVE_HOLD_SECONDS:-8}"
log_path="${TMPDIR:-/tmp}/iosmacs-flutter-ios-native-smoke.log"
expect_scratch="${IOSMACS_FLUTTER_IOS_EXPECT_SCRATCH:-0}"
expect_input_insertion="${IOSMACS_FLUTTER_IOS_EXPECT_INPUT_INSERTION:-0}"
expect_command_marker="${IOSMACS_FLUTTER_IOS_EXPECT_COMMAND_MARKER:-0}"
expect_file_ops="${IOSMACS_FLUTTER_IOS_EXPECT_FILE_OPS:-0}"
expect_relaunch_persistence="${IOSMACS_FLUTTER_IOS_EXPECT_RELAUNCH_PERSISTENCE:-0}"
expect_commands="${IOSMACS_FLUTTER_IOS_EXPECT_COMMANDS:-0}"
command_marker_name="iosmacs-flutter-command-smoke.marker"
command_marker_logical="/home/user/${command_marker_name}"
file_marker_name="iosmacs-flutter-file-smoke.marker"
file_marker_logical="/home/user/${file_marker_name}"
commands_marker_name="iosmacs-flutter-commands-smoke.marker"
commands_marker_logical="/home/user/${commands_marker_name}"
relaunch_hold_seconds="${IOSMACS_FLUTTER_IOS_RELAUNCH_HOLD_SECONDS:-5}"

if [[ "${expect_command_marker}" != "0" \
  || "${expect_file_ops}" != "0" \
  || "${expect_relaunch_persistence}" != "0" \
  || "${expect_commands}" != "0" ]] \
  && [[ -z "${IOSMACS_FLUTTER_IOS_NATIVE_HOLD_SECONDS:-}" ]]; then
  hold_seconds=25
fi

export PATH="${HOME}/work/flutter/bin:${PATH}"

if ! command -v flutter >/dev/null 2>&1; then
  echo "error: flutter command not found; install Flutter SDK under ~/work/flutter or add it to PATH" >&2
  exit 1
fi

if ! xcrun simctl list devices booted | grep -q "(Booted)"; then
  echo "error: no booted simulator is available for Flutter iOS native smoke" >&2
  exit 1
fi

cd "${app_dir}"
flutter build ios --simulator --debug \
  --dart-define=IOSMACS_FLUTTER_AUTOSTART_NATIVE=true \
  --dart-define=IOSMACS_FLUTTER_MIRROR_TERMINAL_OUTPUT=true \
  --dart-define=IOSMACS_FLUTTER_CAPABILITIES_SMOKE=true \
  --dart-define=IOSMACS_FLUTTER_INPUT_SMOKE=true \
  --dart-define=IOSMACS_FLUTTER_RESIZE_SMOKE=true \
  --dart-define=IOSMACS_FLUTTER_REDRAW_SMOKE=true \
  --dart-define=IOSMACS_FLUTTER_STATUS_SMOKE=true \
  --dart-define=IOSMACS_FLUTTER_WORKSPACE_SMOKE=true

if [[ ! -d "${runner_app}" ]]; then
  echo "error: missing Flutter iOS Runner app bundle: ${runner_app}" >&2
  exit 1
fi

bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${runner_app}/Info.plist")"
if [[ -z "${bundle_id}" ]]; then
  echo "error: could not read Flutter Runner bundle identifier" >&2
  exit 1
fi

rm -f "${log_path}"

xcrun simctl spawn "${device}" log stream \
  --style compact \
  --predicate 'process == "Runner" OR eventMessage CONTAINS "iosmacs-" OR eventMessage CONTAINS "GNU Emacs"' \
  >"${log_path}" 2>&1 &
log_pid=$!

cleanup() {
  kill -TERM "${log_pid}" 2>/dev/null || true
  wait "${log_pid}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

xcrun simctl uninstall "${device}" "${bundle_id}" >/dev/null 2>&1 || true
xcrun simctl install "${device}" "${runner_app}"
app_data_container="$(xcrun simctl get_app_container "${device}" "${bundle_id}" data)"
workspace_host_root="${app_data_container}/Documents/home/user"
command_marker_host="${workspace_host_root}/${command_marker_name}"
file_marker_host="${workspace_host_root}/${file_marker_name}"
file_smoke_host="${workspace_host_root}/notes/iosmacs-file-smoke.txt"
commands_marker_host="${workspace_host_root}/${commands_marker_name}"
rm -f "${command_marker_host}"
rm -f "${file_marker_host}" "${file_smoke_host}"
rm -f "${commands_marker_host}"

launch_environment=()
if [[ "${expect_command_marker}" != "0" ]]; then
  launch_environment+=(
    "SIMCTL_CHILD_IOSMACS_APP_SMOKE_MARKER=${command_marker_logical}"
    "SIMCTL_CHILD_IOSMACS_APP_SMOKE_EXPECT=iosmacs input smoke"
  )
fi
if [[ "${expect_file_ops}" != "0" ]]; then
  launch_environment+=(
    "SIMCTL_CHILD_IOSMACS_APP_FILE_SMOKE_MARKER=${file_marker_logical}"
  )
fi
if [[ "${expect_commands}" != "0" ]]; then
  command_eval="(run-at-time 5 nil (lambda () (condition-case err (let ((read-extended-command-predicate nil)) (unless (eq (key-binding (kbd \"M-X\")) 'execute-extended-command) (error \"M-X is not bound to execute-extended-command\")) (unless (commandp 'dired) (error \"dired is not commandp\")) (unless (commandp 'tetris) (error \"tetris is not commandp\")) (unless (member \"dired\" (all-completions \"dired\" obarray #'commandp)) (error \"dired is not in M-x completions\")) (unless (member \"tetris\" (all-completions \"tetris\" obarray #'commandp)) (error \"tetris is not in M-x completions\")) (write-region \"iosmacs-app-commands-smoke-ok\\n\" nil \"${commands_marker_logical}\" nil nil) (princ \"iosmacs-app-commands-smoke-ok\\n\" 'external-debugging-output)) (error (write-region (format \"iosmacs-app-commands-smoke-error:%S\\n\" err) nil \"${commands_marker_logical}\" nil nil) (princ (format \"iosmacs-app-commands-smoke-error:%S\\n\" err) 'external-debugging-output)))))"
  launch_environment+=(
    "SIMCTL_CHILD_IOSMACS_APP_ELISP=${command_eval}"
  )
fi
env "${launch_environment[@]}" \
  xcrun simctl launch --terminate-running-process "${device}" "${bundle_id}"

sleep "${hold_seconds}"

xcrun simctl terminate "${device}" "${bundle_id}" >/dev/null 2>&1 || true
cleanup
trap - EXIT

if ! grep -q 'iosmacs-capabilities-smoke: id=platform-native-channel' "${log_path}"; then
  echo "error: Flutter iOS native smoke did not report selected native backend" >&2
  cat "${log_path}" >&2 || true
  exit 1
fi

if ! grep -q 'iosmacs-status-smoke: id=platform-native-channel' "${log_path}"; then
  echo "error: Flutter iOS native smoke did not report native backend status" >&2
  cat "${log_path}" >&2 || true
  exit 1
fi

if ! grep -Eq 'iosmacs-input-smoke: committed [1-9][0-9]* byte\(s\); backend input total [1-9][0-9]*' "${log_path}"; then
  echo "error: Flutter iOS native smoke did not report input smoke evidence" >&2
  cat "${log_path}" >&2 || true
  exit 1
fi

if ! grep -Eq 'iosmacs-resize-smoke: requested [1-9][0-9]*x[1-9][0-9]*; backend geometry [1-9][0-9]*x[1-9][0-9]*' "${log_path}"; then
  echo "error: Flutter iOS native smoke did not report resize smoke evidence" >&2
  cat "${log_path}" >&2 || true
  exit 1
fi

if ! grep -Eq 'iosmacs-redraw-smoke: message="[^"]+"' "${log_path}"; then
  echo "error: Flutter iOS native smoke did not report redraw smoke evidence" >&2
  cat "${log_path}" >&2 || true
  exit 1
fi

if ! grep -q 'iosmacs-workspace-smoke: workspace listed' "${log_path}"; then
  echo "error: Flutter iOS native smoke did not list workspace entries" >&2
  cat "${log_path}" >&2 || true
  exit 1
fi

if ! grep -q 'iosmacs-workspace-smoke: workspace export candidate(s):' "${log_path}"; then
  echo "error: Flutter iOS native smoke did not report workspace export candidates" >&2
  cat "${log_path}" >&2 || true
  exit 1
fi

if ! grep -Eq 'iosmacs-terminal-output: .*GNU Emacs|Flutter MethodChannel started linked GNU Emacs on iOS' "${log_path}"; then
  echo "error: Flutter iOS native smoke did not report linked GNU Emacs output" >&2
  cat "${log_path}" >&2 || true
  exit 1
fi

if grep -q 'diagnostic fallback is running' "${log_path}"; then
  echo "error: Flutter iOS native smoke fell back to diagnostic backend" >&2
  cat "${log_path}" >&2 || true
  exit 1
fi

if [[ "${expect_scratch}" != "0" ]]; then
  if ! grep -q '\*scratch\*' "${log_path}"; then
    echo "error: Flutter iOS native smoke did not reach *scratch*" >&2
    cat "${log_path}" >&2 || true
    exit 1
  fi
  if ! grep -q 'Lisp Interaction' "${log_path}"; then
    echo "error: Flutter iOS native smoke did not report Lisp Interaction mode" >&2
    cat "${log_path}" >&2 || true
    exit 1
  fi
fi

if [[ "${expect_input_insertion}" != "0" ]]; then
  if ! grep -q 'iosmacs input smoke' "${log_path}"; then
    echo "error: Flutter iOS native smoke did not show input insertion text" >&2
    cat "${log_path}" >&2 || true
    exit 1
  fi
  if ! grep -q '\*scratch\*' "${log_path}"; then
    echo "error: Flutter iOS native smoke inserted input before *scratch* proof" >&2
    cat "${log_path}" >&2 || true
    exit 1
  fi
fi

if [[ "${expect_command_marker}" != "0" ]]; then
  if [[ ! -f "${command_marker_host}" ]]; then
    echo "error: Flutter iOS native smoke did not write command-loop marker: ${command_marker_host}" >&2
    cat "${log_path}" >&2 || true
    exit 1
  fi
  if ! grep -q 'iosmacs-app-smoke-ok' "${command_marker_host}"; then
    echo "error: Flutter iOS native smoke command-loop marker did not report ok" >&2
    cat "${command_marker_host}" >&2 || true
    cat "${log_path}" >&2 || true
    exit 1
  fi
  if ! grep -q 'iosmacs input smoke' "${command_marker_host}"; then
    echo "error: Flutter iOS native smoke command-loop marker did not contain inserted input" >&2
    cat "${command_marker_host}" >&2 || true
    cat "${log_path}" >&2 || true
    exit 1
  fi
fi

if [[ "${expect_file_ops}" != "0" ]]; then
  if [[ ! -f "${file_marker_host}" ]]; then
    echo "error: Flutter iOS native smoke did not write file-ops marker: ${file_marker_host}" >&2
    cat "${log_path}" >&2 || true
    exit 1
  fi
  if ! grep -q 'iosmacs-app-file-smoke-ok' "${file_marker_host}"; then
    echo "error: Flutter iOS native smoke file-ops marker did not report ok" >&2
    cat "${file_marker_host}" >&2 || true
    cat "${log_path}" >&2 || true
    exit 1
  fi
  if [[ ! -f "${file_smoke_host}" ]]; then
    echo "error: Flutter iOS native smoke did not leave saved workspace file: ${file_smoke_host}" >&2
    cat "${log_path}" >&2 || true
    exit 1
  fi
  if ! grep -q 'iosmacs-file-smoke' "${file_smoke_host}"; then
    echo "error: Flutter iOS native smoke saved workspace file had unexpected contents" >&2
    cat "${file_smoke_host}" >&2 || true
    cat "${log_path}" >&2 || true
    exit 1
  fi
fi

if [[ "${expect_commands}" != "0" ]]; then
  if [[ ! -f "${commands_marker_host}" ]]; then
    echo "error: Flutter iOS native smoke did not write commands marker: ${commands_marker_host}" >&2
    cat "${log_path}" >&2 || true
    exit 1
  fi
  if ! grep -q 'iosmacs-app-commands-smoke-ok' "${commands_marker_host}"; then
    echo "error: Flutter iOS native smoke commands marker did not report ok" >&2
    cat "${commands_marker_host}" >&2 || true
    cat "${log_path}" >&2 || true
    exit 1
  fi
fi

if [[ "${expect_relaunch_persistence}" != "0" ]]; then
  if [[ ! -f "${file_smoke_host}" ]]; then
    echo "error: Flutter iOS relaunch persistence requires saved smoke file: ${file_smoke_host}" >&2
    cat "${log_path}" >&2 || true
    exit 1
  fi

  workspace_list_count_before="$(grep -c 'iosmacs-workspace-smoke: workspace listed' "${log_path}" || true)"
  xcrun simctl spawn "${device}" log stream \
    --style compact \
    --predicate 'process == "Runner" OR eventMessage CONTAINS "iosmacs-" OR eventMessage CONTAINS "GNU Emacs"' \
    >>"${log_path}" 2>&1 &
  log_pid=$!
  trap cleanup EXIT

  xcrun simctl launch --terminate-running-process "${device}" "${bundle_id}"
  sleep "${relaunch_hold_seconds}"
  xcrun simctl terminate "${device}" "${bundle_id}" >/dev/null 2>&1 || true
  cleanup
  trap - EXIT

  if [[ ! -f "${file_smoke_host}" ]]; then
    echo "error: Flutter iOS relaunch did not preserve saved smoke file: ${file_smoke_host}" >&2
    cat "${log_path}" >&2 || true
    exit 1
  fi
  if ! grep -q 'iosmacs-file-smoke' "${file_smoke_host}"; then
    echo "error: Flutter iOS relaunch preserved file with unexpected contents" >&2
    cat "${file_smoke_host}" >&2 || true
    cat "${log_path}" >&2 || true
    exit 1
  fi

  workspace_list_count_after="$(grep -c 'iosmacs-workspace-smoke: workspace listed' "${log_path}" || true)"
  if (( workspace_list_count_after <= workspace_list_count_before )); then
    echo "error: Flutter iOS relaunch did not rerun workspace smoke" >&2
    cat "${log_path}" >&2 || true
    exit 1
  fi
fi

echo "flutter iOS native smoke ok: ${log_path}"
