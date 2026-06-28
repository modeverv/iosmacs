#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target_build_root="${IOSMACS_BUILD_ROOT:-${repo_root}/build/emacs-ios-probe}"
sdk="${IOSMACS_SDK:-iphonesimulator}"
arch="${IOSMACS_ARCH:-arm64}"
min_ios="${IOSMACS_MIN_IOS:-17.0}"
target="${IOSMACS_TARGET:-${arch}-apple-ios${min_ios}-simulator}"
smoke_dir="${target_build_root}/iosmacs"
smoke_c="${smoke_dir}/iosmacs-static-link-smoke.c"
smoke_bin="${smoke_dir}/iosmacs-static-link-smoke"
static_lib="${smoke_dir}/libiosmacs-temacs.a"
opt_flags="${IOSMACS_EMACS_OPT_FLAGS:--O0 -g}"

"${repo_root}/scripts/build-emacs-ios-static-probe.sh"

mkdir -p "${smoke_dir}"
cat >"${smoke_c}" <<'C'
extern int iosmacs_emacs_main(int argc, char **argv);

int main(int argc, char **argv) {
  if (argc == -1) {
    return iosmacs_emacs_main(argc, argv);
  }
  return 0;
}
C

cc="$(xcrun --sdk "${sdk}" --find clang)"
sysroot="$(xcrun --sdk "${sdk}" --show-sdk-path)"

"${cc}" \
  -target "${target}" \
  -isysroot "${sysroot}" \
  ${opt_flags} \
  "${smoke_c}" \
  "${static_lib}" \
  -lncurses \
  -o "${smoke_bin}"

file "${smoke_bin}"
echo "Linked Emacs static archive smoke: ${smoke_bin}"
