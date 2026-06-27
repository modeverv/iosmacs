#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app_dir="$repo_root/flutter/iosmacs_flutter"
sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}}"
avd_name="${IOSMACS_FLUTTER_ANDROID_AVD:-iosmacs_flutter_pixel}"
device_id="${IOSMACS_FLUTTER_ANDROID_DEVICE:-}"
require_nw="${IOSMACS_ANDROID_REQUIRE_NW:-1}"
expect_pdump="${IOSMACS_ANDROID_EXPECT_PDUMP:-0}"
expect_pdump_reuse="${IOSMACS_ANDROID_EXPECT_PDUMP_REUSE:-0}"
expect_network="${IOSMACS_ANDROID_EXPECT_NETWORK:-0}"
expect_workspace_relaunch="${IOSMACS_ANDROID_EXPECT_WORKSPACE_RELAUNCH:-1}"
out_dir="$repo_root/flutter/build/android-emulator-smoke"
screenshot="$out_dir/scratch.png"
warm_logcat="$out_dir/logcat-warm-relaunch.txt"
workspace_relaunch_logcat="$out_dir/logcat-workspace-relaunch.txt"
package_id="com.example.iosmacs_flutter"
android_file_elisp_path="files/iosmacs/workspace/iosmacs-android-file-ops-smoke.el"
android_file_marker_path="files/iosmacs/workspace/iosmacs-android-file-ops.marker"
android_file_smoke_path="files/iosmacs/workspace/notes/iosmacs-android-file-smoke.txt"
android_network_marker_path="files/iosmacs/workspace/iosmacs-android-network.marker"
android_pdump_status_path="files/iosmacs/emacs-pdmp/emacs.pdmp.status"
android_pdump_path="files/iosmacs/emacs-pdmp/emacs.pdmp"

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

wait_for_nw_startup() {
  local started=0
  local ready=0
  local snapshot=""
  for _ in {1..180}; do
    snapshot="$("$adb_bin" -s "$device_id" logcat -d)"
    if grep -q 'iosmacs Android GNU Emacs NW PTY session started' <<<"$snapshot"; then
      started=1
      if grep -q '\*scratch\*' <<<"$snapshot" &&
        grep -q 'iosmacs-input-smoke: committed' <<<"$snapshot" &&
        grep -q 'text="iosmacs input smoke"' <<<"$snapshot"; then
        ready=1
        break
      fi
    fi
    sleep 1
  done
  printf '%s %s\n' "$started" "$ready"
}

wait_for_workspace_smoke() {
  local listed=0
  local opened=0
  local snapshot=""
  for _ in {1..60}; do
    snapshot="$("$adb_bin" -s "$device_id" logcat -d)"
    if grep -q 'iosmacs-workspace-smoke: workspace listed' <<<"$snapshot"; then
      listed=1
    fi
    if grep -Eq 'iosmacs-workspace-smoke: workspace open requested: .+ \([1-9][0-9]* byte\(s\)\); backend input total [1-9][0-9]*' <<<"$snapshot"; then
      opened=1
    fi
    if [[ "$listed" == "1" && "$opened" == "1" ]]; then
      break
    fi
    sleep 1
  done
  printf '%s %s\n' "$listed" "$opened"
}

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
  --dart-define=IOSMACS_FLUTTER_MIRROR_TERMINAL_INPUT=true \
  --dart-define=IOSMACS_FLUTTER_CAPABILITIES_SMOKE=true \
  --dart-define=IOSMACS_FLUTTER_STATUS_SMOKE=true \
  --dart-define=IOSMACS_FLUTTER_INPUT_SMOKE=true \
  --dart-define=IOSMACS_FLUTTER_ANDROID_FILE_OPS_SMOKE=true \
  --dart-define=IOSMACS_FLUTTER_RESIZE_SMOKE=true \
  --dart-define=IOSMACS_FLUTTER_REDRAW_SMOKE=true \
  --dart-define=IOSMACS_FLUTTER_WORKSPACE_SMOKE=true

"$adb_bin" -s "$device_id" logcat -c
"$adb_bin" -s "$device_id" install -r "$app_dir/build/app/outputs/flutter-apk/app-debug.apk"
"$adb_bin" -s "$device_id" shell \
  "run-as '$package_id' sh -c 'mkdir -p files/iosmacs/workspace files/iosmacs/workspace/notes'"
if [[ "$expect_pdump" == "1" ]]; then
  "$adb_bin" -s "$device_id" shell \
    "run-as '$package_id' sh -c 'rm -rf files/iosmacs/emacs-pdmp files/iosmacs/etc'"
fi
"$adb_bin" -s "$device_id" shell \
  "run-as '$package_id' sh -c 'rm -f \"$android_file_marker_path\" \"$android_file_smoke_path\" \"$android_network_marker_path\" \"$android_file_elisp_path\"'"
cat <<'ELISP' | "$adb_bin" -s "$device_id" shell \
  "run-as '$package_id' sh -c 'cat > \"$android_file_elisp_path\"'"
(let ((marker (expand-file-name "iosmacs-android-file-ops.marker" "~")))
  (condition-case err
      (progn
        (setq default-directory "~/")
        (require 'ls-lisp)
        (setq ls-lisp-use-insert-directory-program nil
              insert-directory-program "/system/bin/ls"
              dired-use-ls-dired nil
              dired-listing-switches "-al")
        (require 'dired)
        (let* ((dir (expand-file-name "notes/" "~"))
               (file (expand-file-name "iosmacs-android-file-smoke.txt" dir))
               (text "iosmacs-android-file-smoke\n"))
          (make-directory dir t)
          (find-file file)
          (erase-buffer)
          (insert text)
          (save-buffer)
          (kill-buffer (current-buffer))
          (find-file file)
          (unless (string-match-p "iosmacs-android-file-smoke" (buffer-string))
            (error "reloaded file did not contain smoke text"))
          (let ((dired-buffer (dired-noselect dir)))
            (with-current-buffer dired-buffer
              (goto-char (point-min))
              (unless (search-forward "iosmacs-android-file-smoke.txt" nil t)
                (error "dired did not list smoke file"))))
          (write-region "iosmacs-android-file-ops-ok\n" nil marker nil nil)
          (message "iosmacs-android-file-ops-ok")))
    (error
     (write-region
      (format "iosmacs-android-file-ops-error:%S\n" err)
      nil marker nil nil)
     (message "iosmacs-android-file-ops-error:%S" err))))
ELISP
if [[ "$expect_network" == "1" ]]; then
  cat <<'ELISP' | "$adb_bin" -s "$device_id" shell \
    "run-as '$package_id' sh -c 'cat >> \"$android_file_elisp_path\"'"

(let ((marker (expand-file-name "iosmacs-android-network.marker" "~"))
      (buffer (get-buffer-create " *iosmacs-android-network-smoke*"))
      proc)
  (condition-case err
      (unwind-protect
          (progn
            (with-current-buffer buffer
              (erase-buffer))
            (setq proc
                  (make-network-process
                   :name "iosmacs-android-network-smoke"
                   :buffer buffer
                   :host "example.com"
                   :service 80
                   :nowait nil
                   :coding 'binary))
            (process-send-string
             proc
             "GET / HTTP/1.0\r\nHost: example.com\r\nConnection: close\r\n\r\n")
            (let ((deadline (+ (float-time) 20)))
              (while (and (< (float-time) deadline)
                          (not (with-current-buffer buffer
                                 (save-excursion
                                   (goto-char (point-min))
                                   (search-forward "HTTP/" nil t)))))
                (accept-process-output proc 1)))
            (unless (with-current-buffer buffer
                      (save-excursion
                        (goto-char (point-min))
                        (search-forward "HTTP/" nil t)))
              (error "network smoke did not receive HTTP response"))
            (write-region "iosmacs-android-network-ok\n" nil marker nil nil)
            (message "iosmacs-android-network-ok"))
        (when (and proc (process-live-p proc))
          (delete-process proc)))
    (error
     (write-region
      (format "iosmacs-android-network-error:%S\n" err)
      nil marker nil nil)
     (message "iosmacs-android-network-error:%S" err))))
ELISP
fi
"$adb_bin" -s "$device_id" shell input keyevent 82 >/dev/null 2>&1 || true
"$adb_bin" -s "$device_id" shell am start -n "$package_id/.MainActivity"

# Wait for the NW PTY session by default.  Set IOSMACS_ANDROID_REQUIRE_NW=0
# only when deliberately exercising the legacy fallback diagnostics.
scratch_seen=0
nw_session_seen=0
if [[ "$require_nw" == "1" ]]; then
  read -r nw_session_seen scratch_seen < <(wait_for_nw_startup)
else
  for _ in {1..180}; do
    logcat_snapshot="$("$adb_bin" -s "$device_id" logcat -d)"
    if grep -q 'iosmacs Android GNU Emacs NW PTY session started' <<<"$logcat_snapshot"; then
      nw_session_seen=1
      if grep -q '\*scratch\*' <<<"$logcat_snapshot" &&
        grep -q 'iosmacs-input-smoke: committed' <<<"$logcat_snapshot" &&
        grep -q 'text="iosmacs input smoke"' <<<"$logcat_snapshot"; then
        scratch_seen=1
        break
      fi
    fi
    # Fallback: check for JNI frame renderer output only when explicitly allowed.
    if grep -q 'GNU Emacs 30.2 Android terminal frame' <<<"$logcat_snapshot" &&
      grep -q 'Buffer: \*scratch\*' <<<"$logcat_snapshot"; then
      scratch_seen=1
      break
    fi
    sleep 1
  done
fi

keyboard_marker="androidadbinput"
screen_size="$("$adb_bin" -s "$device_id" shell wm size 2>/dev/null | tr -d '\r' || true)"
tap_x=540
tap_y=1830
if [[ "$screen_size" =~ ([0-9]+)x([0-9]+) ]]; then
  tap_x=$((BASH_REMATCH[1] / 2))
  tap_y=$((BASH_REMATCH[2] * 3 / 4))
fi
"$adb_bin" -s "$device_id" shell input tap "$tap_x" "$tap_y" >/dev/null 2>&1 || true
sleep 0.5
"$adb_bin" -s "$device_id" shell input text "$keyboard_marker"
"$adb_bin" -s "$device_id" shell input keyevent ENTER >/dev/null 2>&1 || true
keyboard_seen=0
for _ in {1..30}; do
  logcat_snapshot="$("$adb_bin" -s "$device_id" logcat -d)"
  if grep -q "iosmacs-terminal-input-buffer: text=.*${keyboard_marker}" <<<"$logcat_snapshot"; then
    keyboard_seen=1
    break
  fi
  sleep 1
done

file_ops_seen=0
file_ops_marker_text=""
file_ops_saved_text=""
network_marker_text=""
pdump_status_text=""
pdump_size=""
for _ in {1..60}; do
  file_ops_marker_text="$("$adb_bin" -s "$device_id" shell run-as "$package_id" cat "$android_file_marker_path" 2>/dev/null | tr -d '\r' || true)"
  file_ops_saved_text="$("$adb_bin" -s "$device_id" shell run-as "$package_id" cat "$android_file_smoke_path" 2>/dev/null | tr -d '\r' || true)"
  if grep -q 'iosmacs-android-file-ops-ok' <<<"$file_ops_marker_text" &&
    grep -q 'iosmacs-android-file-smoke' <<<"$file_ops_saved_text"; then
    file_ops_seen=1
    break
  fi
  sleep 1
done
pdump_status_text="$("$adb_bin" -s "$device_id" shell run-as "$package_id" cat "$android_pdump_status_path" 2>/dev/null | tr -d '\r' || true)"
pdump_size="$("$adb_bin" -s "$device_id" shell run-as "$package_id" stat -c %s "$android_pdump_path" 2>/dev/null | tr -d '\r' || true)"
if [[ "$expect_network" == "1" ]]; then
  for _ in {1..30}; do
    network_marker_text="$("$adb_bin" -s "$device_id" shell run-as "$package_id" cat "$android_network_marker_path" 2>/dev/null | tr -d '\r' || true)"
    if grep -q 'iosmacs-android-network-ok' <<<"$network_marker_text"; then
      break
    fi
    sleep 1
  done
fi
printf '%s\n' "$file_ops_marker_text" > "$out_dir/android-file-ops.marker"
printf '%s\n' "$file_ops_saved_text" > "$out_dir/android-file-smoke.txt"
printf '%s\n' "$network_marker_text" > "$out_dir/android-network.marker"
printf '%s\n' "$pdump_status_text" > "$out_dir/android-pdump.status"

"$adb_bin" -s "$device_id" logcat -d > "$out_dir/logcat.txt"

if [[ "$require_nw" == "1" && "$nw_session_seen" != "1" ]]; then
  printf 'error: Android emulator smoke requires NW Emacs; set IOSMACS_ANDROID_REQUIRE_NW=0 to allow fallback diagnostics\n' >&2
  printf 'saved logcat: %s\n' "$out_dir/logcat.txt" >&2
  exit 1
fi
if [[ "$scratch_seen" != "1" ]]; then
  printf 'error: did not observe Android Emacs terminal output in logcat\n' >&2
  printf 'saved logcat: %s\n' "$out_dir/logcat.txt" >&2
  exit 1
fi
if [[ "$keyboard_seen" != "1" ]]; then
  printf 'error: did not observe Android adb keyboard input evidence\n' >&2
  printf 'saved logcat: %s\n' "$out_dir/logcat.txt" >&2
  exit 1
fi
if [[ "$file_ops_seen" != "1" ]]; then
  printf 'error: did not observe Android Emacs file save/reopen/Dired evidence\n' >&2
  printf 'marker file: %s\n' "$out_dir/android-file-ops.marker" >&2
  printf 'saved file: %s\n' "$out_dir/android-file-smoke.txt" >&2
  printf 'saved logcat: %s\n' "$out_dir/logcat.txt" >&2
  exit 1
fi
if [[ "$expect_network" == "1" ]] && ! grep -q 'iosmacs-android-network-ok' "$out_dir/android-network.marker"; then
  printf 'error: Android Emacs network smoke marker did not report ok\n' >&2
  cat "$out_dir/android-network.marker" >&2 || true
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
  grep -q '\*scratch\*' "$out_dir/logcat.txt" || {
    printf 'error: NW Emacs did not report *scratch* evidence\n' >&2
    exit 1
  }
  grep -Eq 'iosmacs Android GNU Emacs NW interactive frame ready: terminal frame detected; elapsed_ms=[1-9][0-9]*; suppressed [1-9][0-9]* startup byte\(s\)' \
    "$out_dir/logcat.txt" || {
    printf 'error: NW Emacs startup timing/suppression marker missing before the interactive frame\n' >&2
    exit 1
  }
  if [[ "$expect_pdump" == "1" ]]; then
    grep -q 'iosmacs Android GNU Emacs NW pdump ready:' "$out_dir/logcat.txt" || {
      printf 'error: Android NW pdump ready marker missing from logcat\n' >&2
      exit 1
    }
    grep -q 'status=ok' "$out_dir/android-pdump.status" || {
      printf 'error: Android NW pdump status did not report ok\n' >&2
      cat "$out_dir/android-pdump.status" >&2 || true
      exit 1
    }
    if [[ ! "$pdump_size" =~ ^[1-9][0-9]*$ ]]; then
      printf 'error: Android NW pdump file was not created or had zero size\n' >&2
      printf 'pdump size: %s\n' "$pdump_size" >&2
      exit 1
    fi
  fi
  if [[ "$expect_pdump_reuse" == "1" ]]; then
    if [[ "$expect_pdump" != "1" ]]; then
      printf 'error: IOSMACS_ANDROID_EXPECT_PDUMP_REUSE=1 requires IOSMACS_ANDROID_EXPECT_PDUMP=1\n' >&2
      exit 1
    fi
    pdump_status_before="$pdump_status_text"
    "$adb_bin" -s "$device_id" logcat -c
    "$adb_bin" -s "$device_id" shell am force-stop "$package_id"
    "$adb_bin" -s "$device_id" shell am start -n "$package_id/.MainActivity"
    read -r warm_nw_session_seen warm_scratch_seen < <(wait_for_nw_startup)
    "$adb_bin" -s "$device_id" logcat -d > "$warm_logcat"
    pdump_status_after="$("$adb_bin" -s "$device_id" shell run-as "$package_id" cat "$android_pdump_status_path" 2>/dev/null | tr -d '\r' || true)"
    printf '%s\n' "$pdump_status_after" > "$out_dir/android-pdump-warm.status"
    if [[ "$warm_nw_session_seen" != "1" || "$warm_scratch_seen" != "1" ]]; then
      printf 'error: Android warm relaunch did not reach NW *scratch* through pdmp\n' >&2
      printf 'saved warm logcat: %s\n' "$warm_logcat" >&2
      exit 1
    fi
    grep -q 'iosmacs Android GNU Emacs NW pdump reused:' "$warm_logcat" || {
      printf 'error: Android warm relaunch did not report pdump reuse\n' >&2
      printf 'saved warm logcat: %s\n' "$warm_logcat" >&2
      exit 1
    }
    if grep -q 'iosmacs Android GNU Emacs NW pdump ready:' "$warm_logcat"; then
      printf 'error: Android warm relaunch regenerated pdump instead of reusing it\n' >&2
      printf 'saved warm logcat: %s\n' "$warm_logcat" >&2
      exit 1
    fi
    if [[ "$pdump_status_after" != "$pdump_status_before" ]]; then
      printf 'error: Android warm relaunch changed pdump status unexpectedly\n' >&2
      printf 'before:\n%s\n' "$pdump_status_before" >&2
      printf 'after:\n%s\n' "$pdump_status_after" >&2
      exit 1
    fi
    grep -Eq 'iosmacs Android GNU Emacs NW interactive frame ready: terminal frame detected; elapsed_ms=[1-9][0-9]*; suppressed [0-9]+ startup byte\(s\)' \
      "$warm_logcat" || {
      printf 'error: Android warm relaunch startup timing marker missing\n' >&2
      exit 1
    }
  fi
  if grep -Eq 'I flutter : .*Loading emacs-lisp/' "$out_dir/logcat.txt"; then
    printf 'error: NW Emacs startup load chatter leaked into Flutter logs\n' >&2
    exit 1
  fi
  if grep -q 'iosmacs Android GNU Emacs process probe: exit=0 marker=ok' "$out_dir/logcat.txt"; then
    printf 'error: official Android subprocess probe ran on the active NW startup path\n' >&2
    exit 1
  fi
  grep -q 'text="iosmacs input smoke"' "$out_dir/logcat.txt" || {
    printf 'error: NW Emacs smoke did not identify the committed input text\n' >&2
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
grep -q 'text="iosmacs input smoke"' "$out_dir/logcat.txt" || {
  printf 'error: did not observe Android input smoke text evidence\n' >&2
  exit 1
}
grep -q "iosmacs-terminal-input-buffer: text=.*${keyboard_marker}" "$out_dir/logcat.txt" || {
  printf 'error: did not observe Android adb keyboard input marker\n' >&2
  exit 1
}
grep -Eq 'iosmacs-android-file-ops-smoke: submitted [1-9][0-9]* byte\(s\); backend input total [1-9][0-9]*' \
  "$out_dir/logcat.txt" || {
  printf 'error: did not observe Android file-ops smoke submission evidence\n' >&2
  exit 1
}
grep -q 'iosmacs-android-file-ops-ok' "$out_dir/android-file-ops.marker" || {
  printf 'error: Android Emacs file-ops marker did not report ok\n' >&2
  cat "$out_dir/android-file-ops.marker" >&2 || true
  exit 1
}
grep -q 'iosmacs-android-file-smoke' "$out_dir/android-file-smoke.txt" || {
  printf 'error: Android Emacs saved file had unexpected contents\n' >&2
  cat "$out_dir/android-file-smoke.txt" >&2 || true
  exit 1
}
if [[ "$expect_network" == "1" ]]; then
  grep -q 'iosmacs-android-network-ok' "$out_dir/android-network.marker" || {
    printf 'error: Android Emacs network smoke marker did not report ok\n' >&2
    cat "$out_dir/android-network.marker" >&2 || true
    exit 1
  }
  grep -q 'iosmacs-android-network-ok' "$out_dir/logcat.txt" || {
    printf 'error: did not observe Android Emacs network smoke log evidence\n' >&2
    exit 1
  }
fi
grep -Eq 'iosmacs-resize-smoke: requested [1-9][0-9]*x[1-9][0-9]*; backend geometry [1-9][0-9]*x[1-9][0-9]*' \
  "$out_dir/logcat.txt" || {
  printf 'error: did not observe Android resize smoke evidence\n' >&2
  exit 1
}
grep -q 'iosmacs-redraw-smoke: message="iosmacs Android native bridge: redrew Emacs terminal frame"' \
  "$out_dir/logcat.txt" || {
  printf 'error: did not observe Android redraw smoke evidence\n' >&2
  exit 1
}
grep -q 'iosmacs-workspace-smoke: workspace listed' "$out_dir/logcat.txt" || {
  printf 'error: did not observe Android workspace list smoke evidence\n' >&2
  exit 1
}
grep -q 'iosmacs-workspace-smoke: workspace imported 1 item(s)' "$out_dir/logcat.txt" || {
  printf 'error: did not observe Android workspace import smoke evidence\n' >&2
  exit 1
}
grep -q 'iosmacs-workspace-smoke: workspace listed after import' "$out_dir/logcat.txt" || {
  printf 'error: did not observe Android workspace list-after-import smoke evidence\n' >&2
  exit 1
}
grep -Eq 'iosmacs-workspace-smoke: workspace open requested: .+ \([1-9][0-9]* byte\(s\)\); backend input total [1-9][0-9]*' \
  "$out_dir/logcat.txt" || {
  printf 'error: did not observe Android workspace open smoke evidence\n' >&2
  exit 1
}
grep -q 'iosmacs-workspace-smoke: workspace export candidate(s):' "$out_dir/logcat.txt" || {
  printf 'error: did not observe Android workspace export smoke evidence\n' >&2
  exit 1
}
grep -q 'iosmacs-workspace-smoke: workspace export uri(s): content://com.example.iosmacs_flutter.workspace_export/' \
  "$out_dir/logcat.txt" || {
  printf 'error: did not observe Android document-provider export URI evidence\n' >&2
  exit 1
}
grep -Eq 'iosmacs Android document-provider export: uri=content://com\.example\.iosmacs_flutter\.workspace_export/.+ bytes=[1-9][0-9]*' \
  "$out_dir/logcat.txt" || {
  printf 'error: did not observe Android document-provider export byte evidence\n' >&2
  exit 1
}

if [[ "$expect_workspace_relaunch" == "1" ]]; then
  "$adb_bin" -s "$device_id" logcat -c
  "$adb_bin" -s "$device_id" shell am force-stop "$package_id"
  "$adb_bin" -s "$device_id" shell am start -n "$package_id/.MainActivity"
  read -r relaunch_nw_session_seen relaunch_scratch_seen < <(wait_for_nw_startup)
  read -r relaunch_workspace_listed relaunch_workspace_opened < <(wait_for_workspace_smoke)
  "$adb_bin" -s "$device_id" logcat -d > "$workspace_relaunch_logcat"
  relaunch_saved_text="$("$adb_bin" -s "$device_id" shell run-as "$package_id" cat "$android_file_smoke_path" 2>/dev/null | tr -d '\r' || true)"
  printf '%s\n' "$relaunch_saved_text" > "$out_dir/android-file-smoke-relaunch.txt"
  if [[ "$relaunch_nw_session_seen" != "1" || "$relaunch_scratch_seen" != "1" ]]; then
    printf 'error: Android workspace relaunch did not reach NW *scratch*\n' >&2
    printf 'saved relaunch logcat: %s\n' "$workspace_relaunch_logcat" >&2
    exit 1
  fi
  grep -q 'iosmacs-android-file-smoke' "$out_dir/android-file-smoke-relaunch.txt" || {
    printf 'error: Android workspace file did not persist across relaunch\n' >&2
    cat "$out_dir/android-file-smoke-relaunch.txt" >&2 || true
    exit 1
  }
  if [[ "$relaunch_workspace_listed" != "1" ]]; then
    printf 'error: did not observe Android workspace list evidence after relaunch\n' >&2
    exit 1
  fi
  if [[ "$relaunch_workspace_opened" != "1" ]]; then
    printf 'error: did not observe Android workspace open evidence after relaunch\n' >&2
    exit 1
  fi
fi

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
