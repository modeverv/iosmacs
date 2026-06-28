#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_root="${IOSMACS_EMACS_SOURCE:-${repo_root}/wasmacs/vendor/emacs}"
target_build_root="${IOSMACS_BUILD_ROOT:-${repo_root}/build/emacs-ios-probe}"
native_root="${IOSMACS_NATIVE_HELPER_ROOT:-${repo_root}/build/emacs-native-helpers}"
native_source="${native_root}/source"
native_build="${native_root}/build"
jobs="${JOBS:-$(sysctl -n hw.ncpu 2>/dev/null || printf '4')}"

"${repo_root}/scripts/build-emacs-ios-probe.sh"

make -C "${target_build_root}/lib" all -j"${jobs}"

if [[ ! -x "${native_build}/lib-src/make-docfile" ]] \
   || [[ ! -x "${native_build}/lib-src/make-fingerprint" ]]; then
  mkdir -p "${native_root}"
  rsync -a --delete --exclude .git "${source_root}/" "${native_source}/"
  if [[ ! -x "${native_source}/configure" ]]; then
    (
      cd "${native_source}"
      ./autogen.sh
    )
  fi
  mkdir -p "${native_build}"
  (
    cd "${native_build}"
    "${native_source}/configure" \
      --without-all \
      --without-x \
      --without-ns \
      --without-dbus \
      --without-gconf \
      --without-gsettings \
      --without-imagemagick \
      --without-native-compilation \
      --without-pop \
      --without-sound \
      --without-threads \
      --without-tree-sitter \
      --with-modules=no
    make -C lib all -j"${jobs}"
    make -C lib-src make-docfile make-fingerprint -j"${jobs}"
  )
fi

cp "${native_build}/lib-src/make-docfile" "${target_build_root}/lib-src/make-docfile"
cp "${native_build}/lib-src/make-fingerprint" "${target_build_root}/lib-src/make-fingerprint"
touch "${target_build_root}/lib-src/make-docfile" "${target_build_root}/lib-src/make-fingerprint"

make -C "${target_build_root}/src" temacs -j"${jobs}"
