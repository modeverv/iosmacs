#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_root="${IOSMACS_EMACS_SOURCE:-${repo_root}/wasmacs/vendor/emacs}"
build_root="${IOSMACS_FLUTTER_MACOS_EMACS_BUILD_ROOT:-${repo_root}/build/emacs-macos}"
source_copy="${build_root}/source"
build_dir="${build_root}/build"
runtime_root="${build_root}/runtime"
runtime_name="${IOSMACS_FLUTTER_MACOS_EMACS_RUNTIME_NAME:-iosmacs-emacs}"
destination="${IOSMACS_FLUTTER_MACOS_EMACS_DEST:-}"
jobs="${JOBS:-$(sysctl -n hw.ncpu 2>/dev/null || printf '4')}"

if [[ ! -d "${source_root}/src" ]]; then
  printf 'error: missing Emacs source at %s\n' "${source_root}" >&2
  exit 1
fi

runtime_is_ready() {
  [[ -x "${runtime_root}/bin/emacs" ]] \
    && [[ -f "${runtime_root}/bin/emacs.pdmp" ]] \
    && [[ -f "${runtime_root}/lisp/loadup.el" ]] \
    && [[ -f "${runtime_root}/etc/charsets/README" ]]
}

if ! runtime_is_ready; then
  mkdir -p "${build_root}"
  rsync -a --delete --exclude .git "${source_root}/" "${source_copy}/"

  if [[ ! -x "${source_copy}/configure" ]]; then
    (
      cd "${source_copy}"
      ./autogen.sh
    )
  fi

  mkdir -p "${build_dir}"
  if [[ ! -f "${build_dir}/config.status" ]]; then
    (
      cd "${build_dir}"
      "${source_copy}/configure" \
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
    )
  fi

  make -C "${build_dir}" -j"${jobs}"

  if [[ ! -x "${build_dir}/src/emacs" ]]; then
    printf 'error: macOS Emacs build did not produce %s\n' "${build_dir}/src/emacs" >&2
    exit 1
  fi

  rm -rf "${runtime_root}"
  mkdir -p "${runtime_root}/bin" "${runtime_root}/libexec"
  cp "${build_dir}/src/emacs" "${runtime_root}/bin/emacs"
  cp "${build_dir}/src/emacs.pdmp" "${runtime_root}/bin/emacs.pdmp"
  if compgen -G "${build_dir}/src/emacs-*.pdmp" >/dev/null; then
    cp "${build_dir}"/src/emacs-*.pdmp "${runtime_root}/bin/"
  fi
  if compgen -G "${build_dir}/src/emacs-[0-9]*" >/dev/null; then
    cp "${build_dir}"/src/emacs-[0-9]* "${runtime_root}/bin/"
  fi
  if [[ -d "${build_dir}/lib-src" ]]; then
    rsync -a "${build_dir}/lib-src/" "${runtime_root}/libexec/"
  fi
  rsync -a --delete \
    --exclude '*.tmp' \
    --exclude '*.log' \
    "${source_copy}/lisp/" "${runtime_root}/lisp/"
  rsync -a --delete "${source_copy}/etc/" "${runtime_root}/etc/"
  if [[ -d "${source_copy}/leim" ]]; then
    rsync -a --delete "${source_copy}/leim/" "${runtime_root}/leim/"
  fi
fi

if [[ -n "${destination}" ]]; then
  rm -rf "${destination}/${runtime_name}"
  mkdir -p "${destination}"
  rsync -a --delete "${runtime_root}/" "${destination}/${runtime_name}/"
fi

printf 'flutter macOS Emacs runtime ready: %s\n' "${runtime_root}"
