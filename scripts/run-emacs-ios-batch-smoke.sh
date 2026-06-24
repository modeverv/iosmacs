#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target_build_root="${IOSMACS_BUILD_ROOT:-${repo_root}/build/emacs-ios-probe}"
sdk="${IOSMACS_SDK:-iphonesimulator}"
arch="${IOSMACS_ARCH:-arm64}"
min_ios="${IOSMACS_MIN_IOS:-17.0}"
target="${IOSMACS_TARGET:-${arch}-apple-ios${min_ios}-simulator}"
smoke_dir="${target_build_root}/iosmacs"
smoke_c="${smoke_dir}/iosmacs-emacs-batch-smoke.c"
smoke_bin="${smoke_dir}/iosmacs-emacs-batch-smoke"
smoke_log="${smoke_dir}/iosmacs-emacs-batch-smoke.log"
static_lib="${smoke_dir}/libiosmacs-temacs.a"
device="${IOSMACS_SIMULATOR_UDID:-booted}"
lisp_dir="${IOSMACS_EMACS_LISP_DIR:-${target_build_root}/source/lisp}"
etc_dir="${IOSMACS_EMACS_ETC_DIR:-${target_build_root}/source/etc}"
lib_src_dir="${IOSMACS_EMACS_EXEC_DIR:-${target_build_root}/lib-src}"
dump_file="${IOSMACS_EMACS_DUMP_FILE:-}"

escape_c_string() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

dump_file_c="$(escape_c_string "${dump_file}")"
dump_argv_c=""
emacs_argc=7
if [[ -n "${dump_file}" ]]; then
  dump_argv_c="\"--dump-file\", \"${dump_file_c}\","
  emacs_argc=9
fi

"${repo_root}/scripts/build-emacs-ios-static-probe.sh"

mkdir -p "${smoke_dir}"
cat >"${smoke_c}" <<C
#include <stdlib.h>

extern int iosmacs_emacs_main(int argc, char **argv);

int main(int argc, char **process_argv) {
  (void)argc;
  setenv("EMACSLOADPATH", "${lisp_dir}", 1);
  setenv("EMACSDATA", "${etc_dir}", 1);
  setenv("EMACSDOC", "${etc_dir}", 1);
  setenv("EMACSPATH", "${lib_src_dir}", 1);
  setenv("TERM", "dumb", 1);
  char *argv[] = {
    process_argv[0],
    ${dump_argv_c}
    "--batch",
    "--quick",
    "--no-site-file",
    "--no-site-lisp",
    "--eval",
    "(princ \"iosmacs-emacs-batch-ok\\n\")",
    NULL
  };
  return iosmacs_emacs_main(${emacs_argc}, argv);
}
C

cc="$(xcrun --sdk "${sdk}" --find clang)"
sysroot="$(xcrun --sdk "${sdk}" --show-sdk-path)"

"${cc}" \
  -target "${target}" \
  -isysroot "${sysroot}" \
  -O0 \
  -g \
  "${smoke_c}" \
  "${static_lib}" \
  -lncurses \
  -o "${smoke_bin}"

file "${smoke_bin}"
xcrun simctl spawn "${device}" "${smoke_bin}" >"${smoke_log}" 2>&1
cat "${smoke_log}"

if ! grep -q "iosmacs-emacs-batch-ok" "${smoke_log}"; then
  echo "error: Emacs batch smoke marker was not produced" >&2
  exit 1
fi

echo "Ran Emacs iOS batch smoke: ${smoke_bin}"
