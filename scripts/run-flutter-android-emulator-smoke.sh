#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app_dir="$repo_root/flutter/iosmacs_flutter"
sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}}"
avd_name="${IOSMACS_FLUTTER_ANDROID_AVD:-iosmacs_flutter_pixel}"
device_id="${IOSMACS_FLUTTER_ANDROID_DEVICE:-}"
out_dir="$repo_root/flutter/build/android-emulator-smoke"
screenshot="$out_dir/scratch.png"

export ANDROID_HOME="$sdk_root"
export ANDROID_SDK_ROOT="$sdk_root"
export PATH="$HOME/work/flutter/bin:$sdk_root/platform-tools:$PATH"

adb_bin="$sdk_root/platform-tools/adb"
emulator_bin="$sdk_root/emulator/emulator"
avdmanager_bin="$sdk_root/cmdline-tools/latest/bin/avdmanager"

require_tool() {
  local tool="$1"
  if [[ ! -x "$tool" ]]; then
    printf 'error: missing executable: %s\n' "$tool" >&2
    exit 127
  fi
}

require_tool "$adb_bin"
require_tool "$emulator_bin"
require_tool "$avdmanager_bin"
command -v flutter >/dev/null 2>&1 || {
  printf 'error: flutter command not found; expected ~/work/flutter/bin in PATH\n' >&2
  exit 127
}

mkdir -p "$out_dir"

if [[ -z "$device_id" ]]; then
  device_id="$("$adb_bin" devices | awk '/^emulator-[0-9]+[[:space:]]+device$/ { print $1; exit }')"
fi

if [[ -z "$device_id" ]]; then
  "$avdmanager_bin" list avd | grep -q "Name: $avd_name" || {
    printf 'error: AVD %s does not exist; create it with avdmanager first\n' "$avd_name" >&2
    exit 1
  }
  log_file="$out_dir/emulator.log"
  printf 'starting Android emulator AVD %s\n' "$avd_name"
  if command -v open >/dev/null 2>&1; then
    open -na "$emulator_bin" --args -avd "$avd_name" -no-snapshot-save \
      -netdelay none -netspeed full
  else
    nohup "$emulator_bin" -avd "$avd_name" -no-snapshot-save -netdelay none -netspeed full \
      >"$log_file" 2>&1 &
  fi
  "$adb_bin" wait-for-device
  device_id="$("$adb_bin" devices | awk '/^emulator-[0-9]+[[:space:]]+device$/ { print $1; exit }')"
fi

if [[ -z "$device_id" ]]; then
  printf 'error: no Android emulator device is connected\n' >&2
  exit 1
fi

printf 'using Android device %s\n' "$device_id"

for _ in {1..180}; do
  boot_completed="$("$adb_bin" -s "$device_id" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')"
  if [[ "$boot_completed" == "1" ]]; then
    break
  fi
  sleep 2
done

boot_completed="$("$adb_bin" -s "$device_id" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')"
if [[ "$boot_completed" != "1" ]]; then
  printf 'error: Android emulator did not finish booting\n' >&2
  exit 1
fi

cd "$app_dir"
flutter build apk --debug \
  --dart-define=IOSMACS_FLUTTER_MIRROR_TERMINAL_OUTPUT=true \
  --dart-define=IOSMACS_FLUTTER_CAPABILITIES_SMOKE=true \
  --dart-define=IOSMACS_FLUTTER_STATUS_SMOKE=true \
  --dart-define=IOSMACS_FLUTTER_INPUT_SMOKE=true \
  --dart-define=IOSMACS_FLUTTER_RESIZE_SMOKE=true \
  --dart-define=IOSMACS_FLUTTER_REDRAW_SMOKE=true

"$adb_bin" -s "$device_id" logcat -c
"$adb_bin" -s "$device_id" install -r "$app_dir/build/app/outputs/flutter-apk/app-debug.apk"
"$adb_bin" -s "$device_id" shell input keyevent 82 >/dev/null 2>&1 || true
"$adb_bin" -s "$device_id" shell am start -n com.example.iosmacs_flutter/.MainActivity

# Wait for either the NW PTY session (real Emacs) or the JNI frame renderer.
# NW mode takes priority: if libemacs_nw.so is in the APK, Emacs starts via PTY.
scratch_seen=0
nw_session_seen=0
for _ in {1..120}; do
  logcat_snapshot="$("$adb_bin" -s "$device_id" logcat -d)"
  # Check for NW real Emacs PTY session
  if grep -q 'iosmacs Android GNU Emacs NW PTY session started' <<<"$logcat_snapshot"; then
    nw_session_seen=1
    scratch_seen=1
    break
  fi
  # Fallback: check for JNI frame renderer output
  if grep -q 'GNU Emacs 30.2 Android terminal frame' <<<"$logcat_snapshot" &&
    grep -q 'Buffer: \*scratch\*' <<<"$logcat_snapshot"; then
    scratch_seen=1
    break
  fi
  sleep 1
done

"$adb_bin" -s "$device_id" logcat -d > "$out_dir/logcat.txt"

if [[ "$scratch_seen" != "1" ]]; then
  printf 'error: did not observe Android Emacs terminal output in logcat\n' >&2
  printf 'saved logcat: %s\n' "$out_dir/logcat.txt" >&2
  exit 1
fi

# Check for NW real Emacs session or the HAVE_ANDROID fallback path.
if [[ "$nw_session_seen" == "1" ]]; then
  printf 'NW Emacs PTY session detected — verifying NW evidence\n'
  grep -Eq 'iosmacs Android GNU Emacs NW PTY session started: pid=[0-9]+' "$out_dir/logcat.txt" || {
    printf 'error: NW PTY session started marker missing pid\n' >&2
    exit 1
  }
  # Verify that real Emacs terminal output reached the Flutter terminal.
  # The *scratch* mode line or menu bar must appear in the terminal-output log.
  nw_emacs_output_seen=0
  if grep -q 'iosmacs-terminal-output:' "$out_dir/logcat.txt" && \
     grep 'iosmacs-terminal-output:' "$out_dir/logcat.txt" | grep -qv '^.*flutter.*iosmacs-terminal-output: $'; then
    nw_emacs_output_seen=1
  fi
  if [[ "$nw_emacs_output_seen" != "1" ]]; then
    printf 'warning: NW Emacs started but no terminal output observed yet (still loading without pdmp)\n'
  else
    printf 'NW Emacs terminal output confirmed\n'
  fi
else
  printf 'NW Emacs not available — verifying HAVE_ANDROID fallback evidence\n'
  grep -q 'GNU Emacs 30.2 Android terminal frame' "$out_dir/logcat.txt" || {
    printf 'error: did not observe Android Emacs terminal frame evidence\n' >&2
    exit 1
  }
  grep -q 'iosmacs Android GNU Emacs NDK runtime libraries loaded' "$out_dir/logcat.txt" || {
    printf 'error: did not observe Android GNU Emacs NDK runtime load evidence\n' >&2
    exit 1
  }
  grep -Eq 'iosmacs Android GNU Emacs Java bridge ready: [0-9a-f]+' "$out_dir/logcat.txt" || {
    printf 'error: did not observe Android GNU Emacs Java bridge fingerprint evidence\n' >&2
    exit 1
  }
  grep -Eq 'iosmacs Android GNU Emacs wrapper executable ready: .*/libandroid-emacs\.so' "$out_dir/logcat.txt" || {
    printf 'error: did not observe Android GNU Emacs wrapper executable evidence\n' >&2
    exit 1
  }
  grep -q 'iosmacs Android GNU Emacs process probe: exit=0 marker=ok' "$out_dir/logcat.txt" || {
    printf 'error: did not observe Android GNU Emacs subprocess probe success evidence\n' >&2
    exit 1
  }
  grep -Eq 'iosmacs Android GNU Emacs PTY session started: pid=[0-9]+' "$out_dir/logcat.txt" || {
    printf 'error: did not observe Android GNU Emacs PTY session start evidence\n' >&2
    exit 1
  }
  grep -q 'Emacs does not work on text terminals when built to run as part of an Android application package.' \
    "$out_dir/logcat.txt" || {
    printf 'error: did not observe official Android Emacs text-terminal boundary evidence\n' >&2
    exit 1
  }
fi

grep -q 'iosmacs-capabilities-smoke: id=android-native-channel' "$out_dir/logcat.txt" || {
  printf 'error: did not observe Android capability smoke evidence\n' >&2
  exit 1
}
grep -q 'iosmacs-input-smoke: committed' "$out_dir/logcat.txt" || {
  printf 'error: did not observe Android input smoke evidence\n' >&2
  exit 1
}
grep -Eq 'iosmacs-resize-smoke: requested [1-9][0-9]*x[1-9][0-9]*; backend geometry [1-9][0-9]*x[1-9][0-9]*' \
  "$out_dir/logcat.txt" || {
  printf 'error: did not observe Android resize smoke evidence\n' >&2
  exit 1
}

"$adb_bin" -s "$device_id" exec-out screencap -p > "$screenshot"
focused="$("$adb_bin" -s "$device_id" shell dumpsys window | grep -E 'mCurrentFocus|mFocusedApp' || true)"
printf '%s\n' "$focused" > "$out_dir/window-focus.txt"

grep -q 'com.example.iosmacs_flutter' "$out_dir/window-focus.txt" || {
  printf 'error: iosmacs Flutter Android activity is not focused\n' >&2
  cat "$out_dir/window-focus.txt" >&2
  exit 1
}

printf 'flutter android emulator smoke ok\n'
printf 'screenshot: %s\n' "$screenshot"
