#!/usr/bin/env bash
# Stage the MSYS2 pre-built Emacs package as the Flutter Windows runtime.
# Much faster than building from source (~2 min vs ~20 min).
#
# Prerequisites (run once in MSYS2 UCRT64 or MINGW64 shell):
#   pacman -S mingw-w64-ucrt-x86_64-emacs   # UCRT64
#   pacman -S mingw-w64-x86_64-emacs        # MINGW64
set -euo pipefail

runtime_root="${IOSMACS_WIN_RUNTIME_ROOT}"

# ---------------------------------------------------------------------------
# Detect active MSYS2 toolchain prefix
# ---------------------------------------------------------------------------
if [[ -x /ucrt64/bin/emacs.exe ]]; then
  MINGW_PREFIX="/ucrt64"
elif [[ -x /mingw64/bin/emacs.exe ]]; then
  MINGW_PREFIX="/mingw64"
else
  printf 'error: Emacs not found in MSYS2.\n' >&2
  printf 'Install it first:\n' >&2
  printf '  pacman -S mingw-w64-ucrt-x86_64-emacs\n' >&2
  exit 1
fi

printf 'Staging Emacs from MSYS2 prefix: %s\n' "${MINGW_PREFIX}"

# ---------------------------------------------------------------------------
# Find the installed Emacs version directory
# ---------------------------------------------------------------------------
version_dir=""
for d in "${MINGW_PREFIX}/share/emacs"/[0-9]*; do
  [[ -d "$d" ]] && version_dir="$d"
done

if [[ -z "${version_dir}" ]]; then
  printf 'error: cannot find versioned Emacs share directory under %s/share/emacs/\n' \
    "${MINGW_PREFIX}" >&2
  exit 1
fi

printf 'Emacs version dir: %s\n' "${version_dir}"

# ---------------------------------------------------------------------------
# Stage runtime layout expected by WindowsNativeEmacsBridge:
#   bin/emacs.exe          <- binary
#   lisp/loadup.el         <- lisp tree root
#   etc/charsets/README    <- data dir
#   libexec/               <- helper executables
# ---------------------------------------------------------------------------
rm -rf "${runtime_root}"
mkdir -p "${runtime_root}/bin" "${runtime_root}/libexec"

cp "${MINGW_PREFIX}/bin/emacs.exe" "${runtime_root}/bin/"

# Versioned emacs-X.Y.exe if present
for f in "${MINGW_PREFIX}/bin/emacs-"*.exe; do
  [[ -e "$f" ]] && cp "$f" "${runtime_root}/bin/"
done

# pdmp file if present
for f in "${MINGW_PREFIX}/bin/emacs"*.pdmp; do
  [[ -e "$f" ]] && cp "$f" "${runtime_root}/bin/"
done

# Lisp sources
cp -r "${version_dir}/lisp/." "${runtime_root}/lisp/"

# etc data
cp -r "${version_dir}/etc/." "${runtime_root}/etc/"

# libexec helper executables
for d in "${MINGW_PREFIX}/libexec/emacs"/*/*; do
  if [[ -d "$d" ]]; then
    cp -r "$d/." "${runtime_root}/libexec/"
    break
  fi
done

# ---------------------------------------------------------------------------
# Copy DLL dependencies (use ldd to find them automatically)
# ---------------------------------------------------------------------------
printf 'Copying DLL dependencies...\n'
ldd "${MINGW_PREFIX}/bin/emacs.exe" \
  | awk -v prefix="${MINGW_PREFIX}" 'tolower($3) ~ tolower(prefix) { print $3 }' \
  | sort -u \
  | while read -r dll; do
      cp "$dll" "${runtime_root}/bin/" 2>/dev/null && \
        printf '  %s\n' "$(basename "$dll")" || true
    done

# ---------------------------------------------------------------------------
# Verify
# ---------------------------------------------------------------------------
if [[ ! -x "${runtime_root}/bin/emacs.exe" ]]; then
  printf 'error: emacs.exe not staged\n' >&2; exit 1
fi
if [[ ! -f "${runtime_root}/lisp/loadup.el" ]]; then
  printf 'error: lisp/loadup.el not staged\n' >&2; exit 1
fi
if [[ ! -f "${runtime_root}/etc/charsets/README" ]]; then
  printf 'error: etc/charsets/README not staged\n' >&2; exit 1
fi

printf 'flutter Windows Emacs runtime ready: %s\n' "${runtime_root}"
