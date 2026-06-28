#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target_build_root="${IOSMACS_BUILD_ROOT:-${repo_root}/build/emacs-ios-probe}"
sdk="${IOSMACS_SDK:-iphonesimulator}"
arch="${IOSMACS_ARCH:-arm64}"
min_ios="${IOSMACS_MIN_IOS:-17.0}"
target="${IOSMACS_TARGET:-${arch}-apple-ios${min_ios}-simulator}"
smoke_dir="${target_build_root}/iosmacs"
smoke_c="${smoke_dir}/iosmacs-emacs-nw-smoke.c"
smoke_bin="${smoke_dir}/iosmacs-emacs-nw-smoke"
smoke_log="${smoke_dir}/iosmacs-emacs-nw-smoke.log"
ok_file="${smoke_dir}/iosmacs-emacs-nw-ok.marker"
network_smoke_el="${smoke_dir}/iosmacs-network-package-smoke.el"
input_ready_file="${smoke_dir}/iosmacs-emacs-nw-input-ready.marker"
input_injected_file="${smoke_dir}/iosmacs-emacs-nw-input-injected.marker"
workspace_root="${IOSMACS_WORKSPACE_ROOT:-${smoke_dir}/home/user}"
pdmp_dir="${smoke_dir}/nw-pdmp"
pdmp_log="${pdmp_dir}/iosmacs-emacs-nw-pdmp.log"
run_bin="${pdmp_dir}/emacs"
static_lib="${smoke_dir}/libiosmacs-temacs.a"
host_facade_c="${repo_root}/iosmacs/Host/iosmacs_host_facade.c"
terminal_shim_c="${repo_root}/iosmacs/Host/iosmacs_terminal_shim.c"
device="${IOSMACS_SIMULATOR_UDID:-booted}"
lisp_dir="${IOSMACS_EMACS_LISP_DIR:-${target_build_root}/source/lisp}"
etc_dir="${IOSMACS_EMACS_ETC_DIR:-${target_build_root}/source/etc}"
lib_src_dir="${IOSMACS_EMACS_EXEC_DIR:-${target_build_root}/lib-src}"
timeout_seconds="${IOSMACS_NW_SMOKE_TIMEOUT:-60}"
eval_elisp="${IOSMACS_NW_ELISP:-}"
input_hex="${IOSMACS_NW_INPUT_HEX:-}"
input_delay_ms="${IOSMACS_NW_INPUT_DELAY_MS:-}"
term_name="${IOSMACS_NW_TERM:-xterm-256color}"
dump_file="${IOSMACS_EMACS_DUMP_FILE:-}"
expect_input="${IOSMACS_NW_EXPECT_INPUT:-0}"
expect_command_input="${IOSMACS_NW_EXPECT_COMMAND_INPUT:-0}"
expect_japanese_input="${IOSMACS_NW_EXPECT_JAPANESE_INPUT:-0}"
expect_file_ops="${IOSMACS_NW_EXPECT_FILE_OPS:-0}"
expect_network="${IOSMACS_NW_EXPECT_NETWORK:-0}"
skip_term_init="${IOSMACS_NW_SKIP_TERM_INIT:-0}"
opt_flags="${IOSMACS_EMACS_OPT_FLAGS:--O0 -g}"
write_network_smoke_el=0
lisp_load_path="${lisp_dir}"
while IFS= read -r dir; do
  lisp_load_path="${lisp_load_path}:${dir}"
done < <(find "${lisp_dir}" -mindepth 1 -maxdepth 1 -type d | sort)
if [[ -z "${dump_file}" && "${IOSMACS_NW_USE_LOCAL_PDMP:-1}" = "1" ]]; then
  dump_file="${pdmp_dir}/emacs.pdmp"
fi
if [[ "${expect_input}" != "0" && -z "${input_hex}" ]]; then
  input_hex="78"
fi
if [[ "${expect_command_input}" != "0" && -z "${input_hex}" ]]; then
  input_hex="616263"
fi
if [[ "${expect_japanese_input}" != "0" && -z "${input_hex}" ]]; then
  input_hex="E38182"
fi
if [[ -z "${input_delay_ms}" ]]; then
  if [[ "${expect_command_input}" != "0" || "${expect_japanese_input}" != "0" ]]; then
    input_delay_ms=500
  else
    input_delay_ms=1000
  fi
fi
if [[ -z "${eval_elisp}" && "${expect_input}" != "0" ]]; then
  eval_elisp="(progn (with-temp-file \"${input_ready_file}\" (insert \"ready\\n\")) (let ((event (read-char nil nil 10))) (with-temp-file \"${ok_file}\" (insert (if (characterp event) (format \"iosmacs-nw-input:%c/%S\\n\" event event) (format \"iosmacs-nw-input:%S\\n\" event)))) (princ (if (characterp event) (format \"iosmacs-nw-input:%c/%S\\n\" event event) (format \"iosmacs-nw-input:%S\\n\" event)) 'external-debugging-output) (kill-emacs (if (eq event ?x) 0 7))))"
elif [[ -z "${eval_elisp}" && "${expect_command_input}" != "0" ]]; then
  eval_elisp="(progn (with-temp-file \"${input_ready_file}\" (insert \"ready\\n\")) (run-at-time 3 nil (lambda () (let ((text (with-current-buffer \"*scratch*\" (buffer-string)))) (with-temp-file \"${ok_file}\" (insert (format \"iosmacs-nw-command-input:%S\\n\" text))) (princ (format \"iosmacs-nw-command-input:%S\\n\" text) 'external-debugging-output) (kill-emacs (if (string-match-p \"abc\" text) 0 7))))))"
elif [[ -z "${eval_elisp}" && "${expect_japanese_input}" != "0" ]]; then
  eval_elisp="(progn (set-terminal-coding-system 'utf-8-unix) (set-keyboard-coding-system 'utf-8-unix) (ignore-errors (set-input-meta-mode 8)) (with-temp-file \"${input_ready_file}\" (insert \"ready\\n\")) (run-at-time 3 nil (lambda () (let ((text (with-current-buffer \"*scratch*\" (buffer-string)))) (with-temp-file \"${ok_file}\" (insert (format \"iosmacs-nw-japanese-input:%S\\n\" text))) (princ (format \"iosmacs-nw-japanese-input:%S\\n\" text) 'external-debugging-output) (kill-emacs (if (string-match-p \"あ\" text) 0 7))))))"
elif [[ -z "${eval_elisp}" && "${expect_file_ops}" != "0" ]]; then
  eval_elisp="(progn (setq default-directory \"/home/user/\" command-line-default-directory \"/home/user/\") (require 'ls-lisp) (setq ls-lisp-use-insert-directory-program nil insert-directory-program nil dired-use-ls-dired nil) (require 'dired) (require 'dired-aux) (condition-case err (let* ((dir \"/home/user/notes/\") (file (concat dir \"iosmacs-file-smoke.txt\")) (text \"iosmacs-file-smoke\\n\")) (make-directory dir t) (find-file file) (erase-buffer) (insert text) (save-buffer) (kill-buffer (current-buffer)) (find-file file) (unless (string-match-p \"iosmacs-file-smoke\" (buffer-string)) (error \"reloaded file did not contain smoke text\")) (let ((dired-buffer (dired-noselect dir))) (with-current-buffer dired-buffer (goto-char (point-min)) (unless (search-forward \"iosmacs-file-smoke.txt\" nil t) (error \"dired did not list smoke file\")))) (with-temp-file \"${ok_file}\" (insert \"iosmacs-nw-file-ops-ok\\n\")) (princ \"iosmacs-nw-file-ops-ok\\n\" 'external-debugging-output) (kill-emacs 0)) (error (with-temp-file \"${ok_file}\" (insert (format \"iosmacs-nw-file-ops-error:%S\\n\" err))) (princ (format \"iosmacs-nw-file-ops-error:%S\\n\" err) 'external-debugging-output) (kill-emacs 9))))"
elif [[ -z "${eval_elisp}" && "${expect_network}" != "0" ]]; then
  write_network_smoke_el=1
  eval_elisp="(load \"${network_smoke_el}\")"
elif [[ -z "${eval_elisp}" && "${expect_command_input}" = "0" ]]; then
  eval_elisp="(progn (with-temp-file \"${ok_file}\" (insert \"iosmacs-nw-ok\\n\")) (princ \"iosmacs-nw-ok\\n\" 'external-debugging-output) (kill-emacs 0))"
fi

escape_c_string() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

lisp_load_path_c="$(escape_c_string "${lisp_load_path}")"
etc_dir_c="$(escape_c_string "${etc_dir}")"
lib_src_dir_c="$(escape_c_string "${lib_src_dir}")"
pdmp_dir_c="$(escape_c_string "${pdmp_dir}")"
workspace_root_c="$(escape_c_string "${workspace_root}")"
eval_elisp_c="$(escape_c_string "${eval_elisp}")"
term_name_c="$(escape_c_string "${term_name}")"
dump_file_c="$(escape_c_string "${dump_file}")"
input_ready_file_c="$(escape_c_string "${input_ready_file}")"
input_injected_file_c="$(escape_c_string "${input_injected_file}")"
wait_input_ready_c=0
if [[ "${expect_input}" != "0" || "${expect_command_input}" != "0" || "${expect_japanese_input}" != "0" ]]; then
  wait_input_ready_c=1
fi
skip_term_init_c=0
if [[ "${skip_term_init}" != "0" ]]; then
  skip_term_init_c=1
fi
dump_argv_c=""
eval_argv_c=""
emacs_argc=6
if [[ -n "${dump_file}" ]]; then
  dump_argv_c="\"--dump-file\", \"${dump_file_c}\","
  emacs_argc=8
fi
if [[ -n "${eval_elisp}" ]]; then
  eval_argv_c="\"--eval\", \"${eval_elisp_c}\","
  emacs_argc=$((emacs_argc + 2))
fi

if [[ -n "${input_hex}" ]]; then
  if [[ ! "${input_hex}" =~ ^([[:xdigit:]]{2})+$ ]]; then
    echo "error: IOSMACS_NW_INPUT_HEX must contain an even number of hex digits" >&2
    exit 1
  fi
  input_bytes_c=""
  for ((i = 0; i < ${#input_hex}; i += 2)); do
    byte="${input_hex:i:2}"
    if [[ -n "${input_bytes_c}" ]]; then
      input_bytes_c+=", "
    fi
    input_bytes_c+="0x${byte}"
  done
  input_count=$(( ${#input_hex} / 2 ))
else
  input_bytes_c="0"
  input_count=0
fi

"${repo_root}/scripts/build-emacs-ios-static-probe.sh"
make -C "${target_build_root}/src" ../etc/DOC

mkdir -p "${smoke_dir}"
mkdir -p "${pdmp_dir}"
mkdir -p "${smoke_dir}/etc"
cp "${target_build_root}/etc/DOC" "${smoke_dir}/etc/DOC"
mkdir -p "${workspace_root}/notes"
rm -f "${ok_file}" "${input_ready_file}" "${input_injected_file}"
if [[ "${write_network_smoke_el}" != "0" ]]; then
  cat >"${network_smoke_el}" <<ELISP
(setq default-directory "/home/user/"
      command-line-default-directory "/home/user/"
      package-user-dir "/home/user/elpa"
      create-lockfiles nil
      make-backup-files nil)

(defun iosmacs-smoke-write-marker (text)
  (with-temp-file "${ok_file}"
    (insert text)))

(defun iosmacs-smoke-note (text)
  (iosmacs-smoke-write-marker (concat text "\n"))
  (princ (concat text "\n") 'external-debugging-output))

(defun iosmacs-smoke-download-elpa-tar (remote-address header-host path target)
  (let ((buffer (generate-new-buffer " *iosmacs-elpa-download*"))
        (event nil))
    (with-current-buffer buffer
      (set-buffer-multibyte nil))
    (unwind-protect
        (progn
          (iosmacs-smoke-note "iosmacs-nw-network-before-make-process")
          (let ((proc (make-network-process
                     :name "iosmacs-elpa"
                     :buffer buffer
                     :remote remote-address
                     :nowait t
                     :coding 'binary)))
          (iosmacs-smoke-note
           (format "iosmacs-nw-network-after-make-process:%S"
                   (process-status proc)))
          (set-process-query-on-exit-flag proc nil)
          (set-process-filter
           proc
           (lambda (process string)
             (with-current-buffer (process-buffer process)
               (goto-char (point-max))
               (insert string))))
          (set-process-sentinel
           proc
           (lambda (_process process-event)
             (setq event process-event)))
          (let ((deadline (+ (float-time) 20)))
            (while (and (eq (process-status proc) 'connect)
                        (< (float-time) deadline))
              (accept-process-output proc 1))
            (iosmacs-smoke-note
             (format "iosmacs-nw-network-after-connect-wait:%S/%S"
                     (process-status proc) event))
            (when (eq (process-status proc) 'connect)
              (delete-process proc)
              (error "network connect timed out"))
            (unless (memq (process-status proc) '(open run))
              (error "network connect failed: %S/%S"
                     (process-status proc) event)))
          (process-send-string
           proc
           (format "GET %s HTTP/1.0\r\nHost: %s\r\nUser-Agent: iosmacs-smoke\r\nConnection: close\r\n\r\n"
                   path header-host))
          (iosmacs-smoke-note "iosmacs-nw-network-after-http-send")
          (let ((deadline (+ (float-time) 45))
                (complete nil))
            (while (and (not complete) (< (float-time) deadline))
              (accept-process-output proc 1)
              (with-current-buffer buffer
                (save-excursion
                  (goto-char (point-min))
                  (when (search-forward "\r\n\r\n" nil t)
                    (let ((body-start (point))
                          (case-fold-search t)
                          content-length)
                      (goto-char (point-min))
                      (when (re-search-forward "^Content-Length:[ \t]*\\([0-9]+\\)\r?$" body-start t)
                        (setq content-length (string-to-number (match-string 1)))
                        (setq complete
                              (>= (- (point-max) body-start) content-length)))
                      (unless complete
                        (setq complete
                              (>= (- (point-max) body-start) 71680))))))))
            (iosmacs-smoke-note
             (format "iosmacs-nw-network-after-body-wait:complete=%S bytes=%d status=%S event=%S"
                     complete
                     (with-current-buffer buffer (buffer-size))
                     (process-status proc)
                     event))
            (unless complete
              (when (process-live-p proc)
                (delete-process proc))
              (error "network download timed out with %d bytes"
                     (with-current-buffer buffer (buffer-size))))
            (when (process-live-p proc)
              (delete-process proc)))
          (with-current-buffer buffer
            (goto-char (point-min))
            (unless (looking-at "HTTP/1\\.[01] 200")
              (error "unexpected HTTP status/event: %S/%s"
                     event
                     (if (eobp) "<empty>" (buffer-substring (point-min) (line-end-position)))))
            (unless (search-forward "\r\n\r\n" nil t)
              (error "HTTP response did not contain a body"))
            (let ((coding-system-for-write 'no-conversion))
              (write-region (point) (point-max) target nil 'silent))
            (iosmacs-smoke-note
             (format "iosmacs-nw-network-after-write:%d"
                     (file-attribute-size (file-attributes target)))))))
      (kill-buffer buffer))))

(iosmacs-smoke-note "iosmacs-nw-network-entered")

(condition-case err
    (progn
      (require 'cl-lib)
      (require 'cl-extra)
      (require 'package)
      (setq package-native-compile nil)
      (when (fboundp 'package--compile)
        (fset 'package--compile (lambda (_pkg-desc) nil)))
      (let ((tar-file "/home/user/a68-mode-1.3.tar")
            (package-dir "/home/user/elpa/a68-mode-1.3"))
        (when (file-directory-p package-dir)
          (delete-directory package-dir t))
        (when (file-exists-p tar-file)
          (delete-file tar-file))
        (when (file-exists-p "/home/user/.#a68-mode-1.3.tar")
          (delete-file "/home/user/.#a68-mode-1.3.tar"))
        (iosmacs-smoke-download-elpa-tar
         [209 51 188 89 80] "elpa.gnu.org" "/packages/a68-mode-1.3.tar" tar-file)
        (unless (> (file-attribute-size (file-attributes tar-file)) 1024)
          (error "downloaded package tar is too small"))
        (iosmacs-smoke-note "iosmacs-nw-network-before-package-initialize")
        (package-initialize)
        (iosmacs-smoke-note "iosmacs-nw-network-before-package-install-file")
        (package-install-file tar-file)
        (iosmacs-smoke-note "iosmacs-nw-network-after-package-install-file")
        (unless (package-installed-p 'a68-mode)
          (error "a68-mode did not install"))
        (iosmacs-smoke-note "iosmacs-nw-network-before-require")
        (require 'a68-mode)
        (iosmacs-smoke-write-marker "iosmacs-nw-network-package-ok\n")
        (princ "iosmacs-nw-network-package-ok\n" 'external-debugging-output)
        (kill-emacs 0)))
  (error
   (iosmacs-smoke-write-marker
    (format "iosmacs-nw-network-package-error:%S\n" err))
   (princ (format "iosmacs-nw-network-package-error:%S\n" err)
          'external-debugging-output)
   (kill-emacs 9)))
ELISP
fi
cat >"${smoke_c}" <<C
#include <fcntl.h>
#include <pthread.h>
#include <signal.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <sys/syscall.h>
#include <unistd.h>

#include "iosmacs_host_facade.h"
#include "iosmacs_terminal_shim.h"

extern int iosmacs_emacs_main(int argc, char **argv);

static const char opened_marker[] = "iosmacs-nw-opened-tty\\n";
static const char input_marker[] = "iosmacs-nw-injected-input\\n";
static const char ok_marker[] = "iosmacs-nw-ok\\n";
static const char input_ready_file[] = "${input_ready_file_c}";
static const char input_injected_file[] = "${input_injected_file_c}";
static const uint8_t injected_input[] = { ${input_bytes_c} };

static void timeout_handler(int signo) {
  (void)signo;
  const char msg[] = "\\niosmacs-nw-timeout\\n";
  syscall(SYS_write, STDERR_FILENO, msg, sizeof(msg) - 1);
  _exit(124);
}

static void *input_injector_main(void *arg) {
  (void)arg;
  if (${input_count} == 0) {
    return NULL;
  }

  while (!iosmacs_terminal_shim_is_open()) {
    usleep(10000);
  }
  while (${wait_input_ready_c} && input_ready_file[0] != '\\0' && access(input_ready_file, F_OK) != 0) {
    usleep(10000);
  }
  usleep(${input_delay_ms} * 1000);
  iosmacs_os_terminal_push_input(injected_input, ${input_count});
  if (input_injected_file[0] != '\\0') {
    int fd = open(input_injected_file, O_CREAT | O_TRUNC | O_WRONLY, 0600);
    if (fd >= 0) {
      write(fd, input_marker, sizeof(input_marker) - 1);
      close(fd);
    }
  }
  syscall(SYS_write, STDERR_FILENO, input_marker, sizeof(input_marker) - 1);
  return NULL;
}

int main(int argc, char **process_argv) {
  (void)argc;
  pthread_t input_injector_thread;
  signal(SIGALRM, timeout_handler);
  alarm(${timeout_seconds});

  setenv("EMACSLOADPATH", "${lisp_load_path_c}", 1);
  setenv("EMACSDATA", "${etc_dir_c}", 1);
  setenv("EMACSDOC", "${etc_dir_c}", 1);
  setenv("EMACSPATH", "${lib_src_dir_c}", 1);
  setenv("IOSMACS_NW_DEBUG_ERROR", "1", 1);
  setenv("IOSMACS_NW_SKIP_GC", "1", 1);
  setenv("IOSMACS_PDMP_DISABLE_HASH_CONSING", "1", 1);
  setenv("IOSMACS_PDMP_ALLOW_REQUIRE_DURING_DUMP", "1", 1);
  setenv("IOSMACS_PDMP_FALLBACK_CHARPROP", "1", 1);
  setenv("IOSMACS_TERMINAL_AUTO_XTERM_REPLIES", "1", 1);
  setenv("IOSMACS_WORKSPACE_ROOT", "${workspace_root_c}", 1);
  setenv("HOME", "/home/user", 1);
  setenv("USER", "user", 1);
  setenv("LOGNAME", "user", 1);
  if (${skip_term_init_c}) {
    setenv("IOSMACS_NW_SKIP_TERM_INIT", "1", 1);
  }

  if (getenv("IOSMACS_NW_BUILD_PDMP")) {
    chdir("${pdmp_dir_c}");
    setenv("TERM", "dumb", 1);
    char *dump_argv[] = {
      process_argv[0],
      "--batch",
      "-l",
      "loadup",
      "--temacs=pdump",
      "--bin-dest",
      "not-set",
      "--eln-dest",
      "not-set",
      NULL
    };
    return iosmacs_emacs_main(9, dump_argv);
  }

  setenv("TERM", "${term_name_c}", 1);
  chdir("/home/user");
  iosmacs_terminal_shim_enable();
  int mirror_fd = dup(STDERR_FILENO);
  iosmacs_terminal_shim_set_mirror_fd(mirror_fd >= 0 ? mirror_fd : STDERR_FILENO);
  if (iosmacs_terminal_shim_attach_stdio() != 0) {
    const char msg[] = "iosmacs-nw-attach-stdio-failed\\n";
    syscall(SYS_write, mirror_fd >= 0 ? mirror_fd : STDERR_FILENO, msg, sizeof(msg) - 1);
    return 125;
  }
  pthread_create(&input_injector_thread, NULL, input_injector_main, NULL);

  char *argv[] = {
    process_argv[0],
    ${dump_argv_c}
    "--quick",
    "--no-site-file",
    "--no-site-lisp",
    "--no-splash",
    "-nw",
    ${eval_argv_c}
    NULL
  };
  int status = iosmacs_emacs_main(${emacs_argc}, argv);
  if (status == 0) {
    syscall(SYS_write, mirror_fd >= 0 ? mirror_fd : STDERR_FILENO, ok_marker, sizeof(ok_marker) - 1);
  }
  if (iosmacs_terminal_shim_is_open()) {
    syscall(SYS_write, STDERR_FILENO, opened_marker, sizeof(opened_marker) - 1);
  }
  return status;
}
C

cc="$(xcrun --sdk "${sdk}" --find clang)"
sysroot="$(xcrun --sdk "${sdk}" --show-sdk-path)"

"${cc}" \
  -target "${target}" \
  -isysroot "${sysroot}" \
  -Wno-deprecated-declarations \
  ${opt_flags} \
  -I"${repo_root}/iosmacs/Host" \
  "${smoke_c}" \
  "${host_facade_c}" \
  "${terminal_shim_c}" \
  "${static_lib}" \
  -lncurses \
  -o "${smoke_bin}"

file "${smoke_bin}"
cp "${smoke_bin}" "${run_bin}"
file "${run_bin}"
if [[ -n "${dump_file}" && "${IOSMACS_NW_USE_LOCAL_PDMP:-1}" = "1" && "${dump_file}" = "${pdmp_dir}/emacs.pdmp" ]]; then
  rm -f "${pdmp_dir}"/emacs*.pdmp "${pdmp_dir}"/emacs-[0-9]* "${pdmp_log}"
  set +e
  SIMCTL_CHILD_IOSMACS_NW_BUILD_PDMP=1 xcrun simctl spawn "${device}" "${run_bin}" >"${pdmp_log}" 2>&1
  pdmp_status=$?
  set -e
  cat "${pdmp_log}"
  if (( pdmp_status != 0 )); then
    echo "error: Emacs -nw local pdmp generation failed (status ${pdmp_status})" >&2
    exit 1
  fi
  if [[ ! -f "${dump_file}" ]]; then
    echo "error: Emacs -nw local pdmp was not produced in ${pdmp_dir}" >&2
    exit 1
  fi
fi

set +e
xcrun simctl spawn "${device}" "${run_bin}" >"${smoke_log}" 2>&1 &
smoke_pid=$!
smoke_status=0
command_input_success=0
deadline=$((SECONDS + timeout_seconds))
while kill -0 "${smoke_pid}" 2>/dev/null; do
  if [ "${expect_command_input}" != "0" ] \
    && grep -q "iosmacs-nw-injected-input" "${input_injected_file}" 2>/dev/null \
    && grep -aq "abc" "${smoke_log}"; then
    pkill -TERM -P "${smoke_pid}" 2>/dev/null || true
    pkill -TERM -f "${smoke_bin}" 2>/dev/null || true
    kill -TERM "${smoke_pid}" 2>/dev/null || true
    command_input_success=1
    smoke_status=0
    break
  fi
  if (( SECONDS >= deadline )); then
    pkill -TERM -P "${smoke_pid}" 2>/dev/null || true
    pkill -TERM -f "${smoke_bin}" 2>/dev/null || true
    kill -TERM "${smoke_pid}" 2>/dev/null || true
    smoke_status=124
    break
  fi
  sleep 1
done
if (( smoke_status == 0 )); then
  wait "${smoke_pid}"
  smoke_status=$?
else
  wait "${smoke_pid}" >/dev/null 2>&1 || true
fi
set -e

cat "${smoke_log}"

if [ "${expect_network}" = "0" ] \
  && (grep -q "iosmacs-nw-ok" "${smoke_log}" || grep -q "iosmacs-nw-ok" "${ok_file}" 2>/dev/null); then
  echo "Ran Emacs iOS -nw smoke to evaluated Lisp marker: ${smoke_bin}"
  exit 0
fi

if [ "${expect_input}" != "0" ] && grep -q "iosmacs-nw-input:x/" "${ok_file}" 2>/dev/null; then
  echo "Ran Emacs iOS -nw smoke to input event marker: ${smoke_bin}"
  exit 0
fi

if [ "${expect_command_input}" != "0" ] \
  && grep -q "iosmacs-nw-command-input:" "${ok_file}" 2>/dev/null \
  && grep -q "abc" "${ok_file}" 2>/dev/null; then
  echo "Ran Emacs iOS -nw smoke to command-loop input redraw: ${smoke_bin}"
  exit 0
fi

if [ "${expect_command_input}" != "0" ] \
  && grep -q "iosmacs-nw-injected-input" "${input_injected_file}" 2>/dev/null \
  && grep -aq "abc" "${smoke_log}"; then
  echo "Ran Emacs iOS -nw smoke to command-loop input redraw: ${smoke_bin}"
  exit 0
fi

if [ "${expect_japanese_input}" != "0" ] \
  && grep -q "iosmacs-nw-japanese-input:" "${ok_file}" 2>/dev/null \
  && grep -q "あ" "${ok_file}" 2>/dev/null; then
  echo "Ran Emacs iOS -nw smoke to Japanese command-loop input: ${smoke_bin}"
  exit 0
fi

if [ "${expect_japanese_input}" != "0" ]; then
  echo "error: Emacs iOS -nw Japanese command-loop input did not reach marker with あ" >&2
  exit 1
fi

if [ "${expect_file_ops}" != "0" ] && grep -q "iosmacs-nw-file-ops-ok" "${ok_file}" 2>/dev/null; then
  echo "Ran Emacs iOS -nw smoke through /home/user file operations: ${smoke_bin}"
  exit 0
fi

if [ "${expect_network}" != "0" ] && grep -q "iosmacs-nw-network-package-ok" "${ok_file}" 2>/dev/null; then
  echo "Ran Emacs iOS -nw smoke through package.el network install: ${smoke_bin}"
  exit 0
fi

if ! grep -q "iosmacs-nw-opened-tty" "${smoke_log}"; then
  echo "error: Emacs -nw did not open the iosmacs fake tty" >&2
  exit 1
fi

if [ "${IOSMACS_NW_EXPECT_FULL:-0}" = "1" ]; then
  echo "error: Emacs -nw opened the fake tty but did not reach iosmacs-nw-ok (status ${smoke_status})" >&2
  exit 1
fi

echo "Reached Emacs iOS -nw tty initialization: ${smoke_bin}"
echo "Full interactive startup marker is still pending (status ${smoke_status}); set IOSMACS_NW_EXPECT_FULL=1 to require it."
