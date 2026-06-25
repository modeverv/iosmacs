#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target_build_root="${IOSMACS_BUILD_ROOT:-${repo_root}/build/emacs-ios-probe}"
src_build="${target_build_root}/src"
sdk="${IOSMACS_SDK:-iphonesimulator}"
out_dir="${target_build_root}/iosmacs"
out_lib="${out_dir}/libiosmacs-temacs.a"
out_symbols="${out_dir}/libiosmacs-temacs.nm"
entry_obj="${src_build}/iosmacs-emacs-entry.o"
shim_makefile="${target_build_root}/iosmacs-static.mk"
runtime_lisp="${IOSMACS_EMACS_LISP_DIR:-${target_build_root}/source/lisp}"

verify_static_probe() {
  [[ -f "${out_lib}" ]] || return 1
  nm -g "${out_lib}" >"${out_symbols}"
  grep -q ' _iosmacs_emacs_main$' "${out_symbols}" || return 1
  ! grep -q ' _main$' "${out_symbols}" || return 1
}

verify_runtime_lisp() {
  [[ -d "${runtime_lisp}" ]] || return 1
  [[ "$(find "${runtime_lisp}" -type f -name '*.elc' | head -1)" ]] || return 1
  [[ "$(find "${runtime_lisp}" -type f -name '*loaddefs.el' | head -1)" ]] || return 1
  [[ -f "${runtime_lisp}/iosmacs-grep.el" ]] || return 1
  cmp -s "${repo_root}/iosmacs/Emacs/iosmacs-grep.el" "${runtime_lisp}/iosmacs-grep.el" || return 1
}

if [[ "${IOSMACS_FORCE_EMACS_BUILD:-0}" != "1" ]] && verify_static_probe && verify_runtime_lisp; then
  echo "Using existing linkable Emacs static probe: ${out_lib}"
  exit 0
fi

"${repo_root}/scripts/build-emacs-ios-temacs-probe.sh"
"${repo_root}/scripts/prepare-emacs-ios-runtime-lisp.sh"

cat >"${shim_makefile}" <<'MAKE'
iosmacs-print-%:
	@printf '%s\n' "$($*)"

iosmacs-emacs-entry.o: $(srcdir)/emacs.c globals.h
	$(AM_V_CC)$(CC) -c $(CPPFLAGS) $(ALL_CFLAGS) $(PROFILING_CFLAGS) \
	  -Dmain=iosmacs_emacs_main -o $@ $<
MAKE

rm -f "${entry_obj}"
make -C "${src_build}" -f Makefile -f "${shim_makefile}" iosmacs-emacs-entry.o

allobjs="$(
  make -C "${src_build}" --no-print-directory \
    -f Makefile -f "${shim_makefile}" iosmacs-print-ALLOBJS
)"

mkdir -p "${out_dir}"
objects=()
for obj in ${allobjs}; do
  if [[ "${obj}" == "emacs.o" ]]; then
    continue
  fi
  objects+=("${src_build}/${obj}")
done
objects+=("${entry_obj}")

libtool_path="$(xcrun --sdk "${sdk}" --find libtool 2>/dev/null || xcrun --find libtool)"
rm -f "${out_lib}"
"${libtool_path}" -static -o "${out_lib}" \
  "${objects[@]}" \
  "${target_build_root}/lib/libgnu.a"

if ! verify_static_probe; then
  echo "error: ${out_lib} does not define iosmacs_emacs_main" >&2
  exit 1
fi

echo "Built linkable Emacs static probe: ${out_lib}"
