#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_root="${IOSMACS_EMACS_SOURCE:-${repo_root}/wasmacs/vendor/emacs}"
build_root="${IOSMACS_FLUTTER_LINUX_EMACS_BUILD_ROOT:-${repo_root}/build/emacs-linux}"
source_copy="${build_root}/source"
build_dir="${build_root}/build"
runtime_root="${build_root}/runtime"
runtime_name="${IOSMACS_FLUTTER_LINUX_EMACS_RUNTIME_NAME:-iosmacs-emacs}"
destination="${IOSMACS_FLUTTER_LINUX_EMACS_DEST:-}"
jobs="${JOBS:-$(nproc 2>/dev/null || printf '4')}"

if [[ ! -d "${source_root}/src" ]]; then
  printf 'error: missing Emacs source at %s\n' "${source_root}" >&2
  exit 1
fi

runtime_is_ready() {
  [[ -x "${runtime_root}/bin/emacs" ]] \
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

  # Create a stub makeinfo so configure does not fail on missing texinfo.
  # We do not need info manuals for the headless bundled runtime.
  fake_tool_dir="${build_root}/fake_tools"
  mkdir -p "${fake_tool_dir}"
  cat >"${fake_tool_dir}/makeinfo" <<'MAKEINFO_EOF'
#!/bin/sh
if [ "$1" = "--version" ]; then
  echo "makeinfo (GNU texinfo) 7.1"
  exit 0
fi
exit 0
MAKEINFO_EOF
  chmod +x "${fake_tool_dir}/fake_tools/makeinfo" 2>/dev/null || true
  chmod +x "${fake_tool_dir}/makeinfo"

  mkdir -p "${build_dir}"
  if [[ ! -f "${build_dir}/config.status" ]]; then
    # Remove any stale configure cache so MAKEINFO env var is not overridden
    rm -f "${build_dir}/config.cache"
    (
      cd "${build_dir}"
      MAKEINFO="${fake_tool_dir}/makeinfo" "${source_copy}/configure" \
        --without-all \
        --without-x \
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
    printf 'error: Linux Emacs build did not produce %s\n' "${build_dir}/src/emacs" >&2
    exit 1
  fi

  rm -rf "${runtime_root}"
  mkdir -p "${runtime_root}/bin" "${runtime_root}/libexec"
  cp "${build_dir}/src/emacs" "${runtime_root}/bin/emacs"
  if [[ -f "${build_dir}/src/emacs.pdmp" ]]; then
    cp "${build_dir}/src/emacs.pdmp" "${runtime_root}/bin/emacs.pdmp"
  fi
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
    "${source_copy}/lisp/" "${runtime_root}/lisp/" || true
  rsync -a --delete "${source_copy}/etc/" "${runtime_root}/etc/" || true
  if [[ -d "${source_copy}/leim" ]]; then
    rsync -a --delete "${source_copy}/leim/" "${runtime_root}/leim/" || true
  fi
fi

if [[ -n "${destination}" ]]; then
  rm -rf "${destination}/${runtime_name}"
  mkdir -p "${destination}"
  rsync -a --delete "${runtime_root}/" "${destination}/${runtime_name}/"
fi

printf 'flutter Linux Emacs runtime ready: %s\n' "${runtime_root}"
