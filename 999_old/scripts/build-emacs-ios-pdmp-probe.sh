#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target_build_root="${IOSMACS_BUILD_ROOT:-${repo_root}/build/emacs-ios-probe}"
sdk="${IOSMACS_SDK:-iphonesimulator}"
arch="${IOSMACS_ARCH:-arm64}"
min_ios="${IOSMACS_MIN_IOS:-17.0}"
target="${IOSMACS_TARGET:-${arch}-apple-ios${min_ios}-simulator}"
smoke_dir="${target_build_root}/iosmacs"
pdmp_dir="${smoke_dir}/pdmp"
smoke_c="${pdmp_dir}/iosmacs-emacs-pdmp-smoke.c"
smoke_bin="${pdmp_dir}/emacs"
smoke_log="${pdmp_dir}/iosmacs-emacs-pdmp-smoke.log"
verify_log="${pdmp_dir}/iosmacs-emacs-pdmp-batch-smoke.log"
static_lib="${smoke_dir}/libiosmacs-temacs.a"
device="${IOSMACS_SIMULATOR_UDID:-booted}"
lisp_dir="${IOSMACS_EMACS_LISP_DIR:-${target_build_root}/source/lisp}"
etc_dir="${IOSMACS_EMACS_ETC_DIR:-${target_build_root}/source/etc}"
lib_src_dir="${IOSMACS_EMACS_EXEC_DIR:-${target_build_root}/lib-src}"
opt_flags="${IOSMACS_EMACS_OPT_FLAGS:--O0 -g}"
lisp_load_path="${lisp_dir}"
while IFS= read -r dir; do
  lisp_load_path="${lisp_load_path}:${dir}"
done < <(find "${lisp_dir}" -mindepth 1 -maxdepth 1 -type d | sort)
timeout_seconds="${IOSMACS_PDMP_SMOKE_TIMEOUT:-120}"

escape_c_string() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

lisp_load_path_c="$(escape_c_string "${lisp_load_path}")"
etc_dir_c="$(escape_c_string "${etc_dir}")"
lib_src_dir_c="$(escape_c_string "${lib_src_dir}")"
pdmp_dir_c="$(escape_c_string "${pdmp_dir}")"

"${repo_root}/scripts/build-emacs-ios-static-probe.sh"
make -C "${target_build_root}/src" ../etc/DOC

mkdir -p "${pdmp_dir}"
mkdir -p "${smoke_dir}/etc"
cp "${target_build_root}/etc/DOC" "${smoke_dir}/etc/DOC"
cat >"${smoke_c}" <<C
#include <signal.h>
#include <stdlib.h>
#include <sys/syscall.h>
#include <unistd.h>

extern int iosmacs_emacs_main(int argc, char **argv);

static void timeout_handler(int signo) {
  (void)signo;
  const char msg[] = "\\niosmacs-pdmp-timeout\\n";
  syscall(SYS_write, STDERR_FILENO, msg, sizeof(msg) - 1);
  _exit(124);
}

int main(int argc, char **process_argv) {
  (void)argc;
  signal(SIGALRM, timeout_handler);
  alarm(${timeout_seconds});
  setenv("LC_ALL", "C", 1);
  setenv("EMACSLOADPATH", "${lisp_load_path_c}", 1);
  setenv("EMACSDATA", "${etc_dir_c}", 1);
  setenv("EMACSDOC", "${etc_dir_c}", 1);
  setenv("EMACSPATH", "${lib_src_dir_c}", 1);
  setenv("TERM", "dumb", 1);
  setenv("IOSMACS_PDMP_DISABLE_HASH_CONSING", "1", 1);
  setenv("IOSMACS_PDMP_ALLOW_REQUIRE_DURING_DUMP", "1", 1);
  chdir("${pdmp_dir_c}");

  if (getenv("IOSMACS_PDMP_RUN_BATCH")) {
    char *argv[] = {
      process_argv[0],
      "--dump-file",
      "${pdmp_dir_c}/emacs.pdmp",
      "--batch",
      "--quick",
      "--no-site-file",
      "--no-site-lisp",
      "--eval",
      "(princ \\"iosmacs-pdmp-batch-ok\\\\n\\")",
      NULL
    };
    return iosmacs_emacs_main(9, argv);
  }

  char *argv[] = {
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
  return iosmacs_emacs_main(9, argv);
}
C

cc="$(xcrun --sdk "${sdk}" --find clang)"
sysroot="$(xcrun --sdk "${sdk}" --show-sdk-path)"

"${cc}" \
  -target "${target}" \
  -isysroot "${sysroot}" \
  -Wno-deprecated-declarations \
  ${opt_flags} \
  "${smoke_c}" \
  "${static_lib}" \
  -lncurses \
  -o "${smoke_bin}"

file "${smoke_bin}"
rm -f "${pdmp_dir}"/emacs*.pdmp "${pdmp_dir}"/emacs-[0-9]* "${smoke_log}"
xcrun simctl spawn "${device}" "${smoke_bin}" >"${smoke_log}" 2>&1
cat "${smoke_log}"

if [[ ! -f "${pdmp_dir}/emacs.pdmp" ]]; then
  echo "error: emacs.pdmp was not produced in ${pdmp_dir}" >&2
  exit 1
fi

if [[ "${IOSMACS_PDMP_VERIFY_BATCH:-1}" = "1" ]]; then
  SIMCTL_CHILD_IOSMACS_PDMP_RUN_BATCH=1 xcrun simctl spawn "${device}" "${smoke_bin}" >"${verify_log}" 2>&1
  cat "${verify_log}"
  if ! grep -q "iosmacs-pdmp-batch-ok" "${verify_log}"; then
    echo "error: generated emacs.pdmp did not run in the same executable" >&2
    exit 1
  fi
fi

echo "Built Emacs iOS pdmp probe: ${pdmp_dir}/emacs.pdmp"
