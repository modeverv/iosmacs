#!/usr/bin/env bash
# build-flutter-android-emacs-nw.sh — cross-compile GNU Emacs in NW
# (no-window-system, text-terminal) mode for Android ARM64.
#
# This build uses the Android NDK toolchain WITHOUT --with-android so the
# resulting binary has no HAVE_ANDROID restrictions and can run as a normal
# text-terminal process via forkpty on Android.
#
# Usage:
#   scripts/build-flutter-android-emacs-nw.sh          # configure only
#   IOSMACS_ANDROID_EMACS_NW_BUILD=1 \
#     scripts/build-flutter-android-emacs-nw.sh        # full build
#   IOSMACS_ANDROID_EMACS_NW_PDUMPER=1 \
#   IOSMACS_ANDROID_EMACS_NW_BUILD=1 \
#     scripts/build-flutter-android-emacs-nw.sh        # pdumper-capable build
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_root="${IOSMACS_EMACS_SOURCE:-${repo_root}/wasmacs/vendor/emacs}"
sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}}"
abi="${IOSMACS_ANDROID_ABI:-arm64-v8a}"
api="${IOSMACS_ANDROID_API:-35}"
pdumper_mode="${IOSMACS_ANDROID_EMACS_NW_PDUMPER:-0}"
if [[ "${pdumper_mode}" == "1" || "${pdumper_mode}" == "yes" || "${pdumper_mode}" == "true" ]]; then
  pdumper_enabled=1
  build_flavor="${abi}-pdumper"
else
  pdumper_enabled=0
  build_flavor="${abi}"
fi
build_root="${repo_root}/build/emacs-android-nw/${build_flavor}"
source_copy="${build_root}/source"
tool_dir="${build_root}/tools"
out_dir="${build_root}/iosmacs"
stub_dir="${build_root}/ncurses-stub"
status_file="${out_dir}/nw-build.status"
configure_log="${out_dir}/configure.log"
build_log="${out_dir}/build.log"
jobs="${JOBS:-$(sysctl -n hw.ncpu 2>/dev/null || printf '4')}"

if [[ ! -d "${source_root}/src" ]]; then
  printf 'error: missing Emacs source at %s\n' "${source_root}" >&2
  exit 1
fi
if [[ ! -d "${sdk_root}" ]]; then
  printf 'error: missing Android SDK root at %s\n' "${sdk_root}" >&2
  exit 1
fi

newest_match() {
  local pattern="$1"
  compgen -G "${pattern}" | sort -V | tail -1
}

ndk_root="${ANDROID_NDK_ROOT:-$(newest_match "${sdk_root}/ndk/*")}"
if [[ -z "${ndk_root}" || ! -d "${ndk_root}" ]]; then
  printf 'error: missing Android NDK under %s/ndk\n' "${sdk_root}" >&2
  exit 1
fi

toolchain_root="${ndk_root}/toolchains/llvm/prebuilt/darwin-x86_64"
if [[ ! -d "${toolchain_root}" ]]; then
  toolchain_root="${ndk_root}/toolchains/llvm/prebuilt/darwin-arm64"
fi
if [[ ! -d "${toolchain_root}" ]]; then
  printf 'error: missing NDK LLVM toolchain\n' >&2
  exit 1
fi

case "${abi}" in
  arm64-v8a)
    clang_target="aarch64-linux-android${api}-clang"
    host_triple="aarch64-linux-android"
    ;;
  *)
    printf 'error: unsupported IOSMACS_ANDROID_ABI: %s\n' "${abi}" >&2
    exit 1
    ;;
esac

android_cc="${ANDROID_CC:-${toolchain_root}/bin/${clang_target}}"
if [[ ! -x "${android_cc}" ]]; then
  printf 'error: missing Android clang at %s\n' "${android_cc}" >&2
  exit 1
fi
android_ar="${toolchain_root}/bin/llvm-ar"
android_ranlib="${toolchain_root}/bin/llvm-ranlib"
android_nm="${toolchain_root}/bin/llvm-nm"
android_strip="${toolchain_root}/bin/llvm-strip"

mkdir -p "${build_root}" "${tool_dir}" "${out_dir}" "${stub_dir}/include" "${stub_dir}/lib"

# ------------------------------------------------------------------ #
# Step 1: Build the minimal ncurses stub                              #
# ------------------------------------------------------------------ #

stub_header="${stub_dir}/include/curses.h"
if [[ ! -f "${stub_header}" ]]; then
  cat >"${stub_header}" <<'CURSES_H'
/* Minimal curses.h stub for GNU Emacs NW cross-build on Android.
   Provides just enough declarations for Emacs to compile without a real
   ncurses installation.  The implementation lives in iosmacs_ncurses_stub.c. */
#ifndef _CURSES_H
#define _CURSES_H 1

typedef struct { int dummy; } TERMINAL;
extern TERMINAL *cur_term;

/* termcap API */
extern int    tgetent  (char *bp, const char *name);
extern char  *tgetstr  (const char *id, char **area);
extern int    tgetnum  (const char *id);
extern int    tgetflag (const char *id);
extern int    tputs    (const char *str, int affcnt, int (*putcf)(int));

/* terminfo API */
extern int    setupterm  (const char *term, int fd, int *errret);
extern char  *tigetstr   (const char *capname);
extern int    tigetflag  (const char *capname);
extern int    tigetnum   (const char *capname);
extern int    putp       (const char *str);
extern TERMINAL *set_curterm (TERMINAL *nterm);
extern int    del_curterm (TERMINAL *oterm);

/* Global termcap variables */
extern char  PC;
extern char *BC;
extern char *UP;
extern short ospeed;

/* Convenience for code that includes <ncurses.h> or <term.h>.  */
#define NCURSES_EXPORT(type) type
#define HAVE_CURSES_H 1
#define NCURSES_CONST const

#endif /* _CURSES_H */
CURSES_H
  # ncurses.h → curses.h alias
  cp "${stub_header}" "${stub_dir}/include/ncurses.h"
  # term.h stub (Emacs includes this for TERMINAL type and ospeed)
  cat >"${stub_dir}/include/term.h" <<'TERM_H'
#ifndef _TERM_H
#define _TERM_H 1
#include "curses.h"
#endif
TERM_H
fi

stub_lib="${stub_dir}/lib/libncurses.a"
if [[ ! -f "${stub_lib}" ]]; then
  stub_obj="${stub_dir}/iosmacs_ncurses_stub.o"
  "${android_cc}" -c \
    -O2 -fPIC \
    -o "${stub_obj}" \
    "${repo_root}/scripts/iosmacs_ncurses_stub.c"
  "${android_ar}" rcs "${stub_lib}" "${stub_obj}"
  printf 'ncurses stub built: %s\n' "${stub_lib}"
fi
# Provide libtinfo.a as an alias (configure sometimes looks for tinfo)
if [[ ! -f "${stub_dir}/lib/libtinfo.a" ]]; then
  cp "${stub_lib}" "${stub_dir}/lib/libtinfo.a"
fi

# ------------------------------------------------------------------ #
# Step 2: Prepare source copy                                         #
# ------------------------------------------------------------------ #

rsync -a --delete --exclude .git "${source_root}/" "${source_copy}/"

# Apply SIG2STR_MAX patch (same as in the Android HAVE_ANDROID build).
for sig2str_header in "${source_copy}/lib/sig2str.h" "${build_root}/cross/lib/sig2str.h"; do
  if [[ -f "${sig2str_header}" ]] \
    && ! grep -q 'Android API 35 exposes SIG2STR_MAX' "${sig2str_header}"; then
    perl -0pi -e 's|/\* Don.*?\n#ifndef SIG2STR_MAX\n\n# include "intprops.h"\n\n/\* Size of a buffer needed to hold a signal name like "HUP"\.  \*/\n# define SIG2STR_MAX \(sizeof "SIGRTMAX" \+ INT_STRLEN_BOUND \(int\) - 1\)\n\n#ifdef __cplusplus\nextern "C" \{\n#endif\n\nint sig2str \(int, char \*\);\nint str2sig \(char const \*, int \*\);\n\n#ifdef __cplusplus\n\}\n#endif\n\n#endif|/* Android API 35 exposes SIG2STR_MAX without sig2str/str2sig.  */\n#ifndef SIG2STR_MAX\n# include "intprops.h"\n# define SIG2STR_MAX (sizeof "SIGRTMAX" + INT_STRLEN_BOUND (int) - 1)\n#endif\n\n#if !HAVE_SIG2STR\n# ifdef __cplusplus\nextern "C" {\n# endif\nint sig2str (int, char *);\nint str2sig (char const *, int *);\n# ifdef __cplusplus\n}\n# endif\n#endif|s' "${sig2str_header}"
  fi
done

if [[ ! -x "${source_copy}/configure" ]]; then
  (cd "${source_copy}" && ./autogen.sh)
fi

# Patch sys_faccessat in sysdep.c: Android's system faccessat returns EINVAL
# for AT_EACCESS inside the app sandbox.  The gnulib rpl_faccessat wrapper
# has #if 0 guarding its redefinition of faccessat→rpl_faccessat, so sys_faccessat
# in sysdep.c calls the system faccessat directly.  Add an EINVAL fallback.
sysdep_c="${source_copy}/src/sysdep.c"
if [[ -f "${sysdep_c}" ]] && ! grep -q 'iosmacs: AT_EACCESS returns EINVAL' "${sysdep_c}"; then
  perl -0pi -e '
s|(int\nsys_faccessat \(int fd, const char \*pathname, int mode, int flags\)\n\{.*?)(  return faccessat \(fd, pathname, mode, flags\);)|$1  int result = faccessat (fd, pathname, mode, flags);\n  \/* iosmacs: AT_EACCESS returns EINVAL on Android; retry without the flag.  *\/\n  if (result == -1 \&\& errno == EINVAL \&\& flags == AT_EACCESS \&\& fd == AT_FDCWD)\n    result = faccessat (fd, pathname, mode, 0);\n  return result;|s
' "${sysdep_c}"
  if grep -q 'iosmacs: AT_EACCESS returns EINVAL' "${sysdep_c}"; then
    printf 'patched src/sysdep.c: sys_faccessat AT_EACCESS EINVAL fallback added\n'
  else
    printf 'warning: sysdep.c patch not applied (pattern may have changed)\n'
  fi
fi

lread_c="${source_copy}/src/lread.c"
if [[ -f "${lread_c}" ]] && ! grep -q 'IOSMACS_ANDROID_NW_PDUMP_USE_EMACSLOADPATH' "${lread_c}"; then
  perl -0pi -e '
s/bool use_loadpath = !will_dump_p \(\);/bool use_loadpath = !will_dump_p ()\n    || (will_dump_p () \&\& getenv ("IOSMACS_ANDROID_NW_PDUMP_USE_EMACSLOADPATH"));/s
' "${lread_c}"
  if grep -q 'IOSMACS_ANDROID_NW_PDUMP_USE_EMACSLOADPATH' "${lread_c}"; then
    printf 'patched src/lread.c: allow EMACSLOADPATH during Android NW pdump\n'
  else
    printf 'warning: lread.c Android NW pdump load-path patch not applied\n'
  fi
fi
if [[ -f "${lread_c}" ]] && ! grep -q 'iosmacs: Android NW pdump app lisp root' "${lread_c}"; then
  perl -0pi -e '
s/  if \(will_dump_p \(\)\)\n    \/\* PATH_DUMPLOADSEARCH is the lisp dir in the source directory\.\n       We used to add \.\.\/lisp \(ie the lisp dir in the build\n       directory\) at the front here, but that should not be\n       necessary, since in out of tree builds lisp\/ is empty, save\n       for Makefile\.  \*\/\n    return decode_env_path \(0, PATH_DUMPLOADSEARCH, 0\);/  if (will_dump_p ())\n    {\n#ifdef __ANDROID__\n      \/* iosmacs: Android NW pdump app lisp root.  *\/\n      return decode_env_path (0,\n                              "\/data\/user\/0\/com.example.fluttmacs\/files\/iosmacs\/emacs-data\/lisp",\n                              0);\n#endif\n      \/* PATH_DUMPLOADSEARCH is the lisp dir in the source directory.\n         We used to add ..\/lisp (ie the lisp dir in the build\n         directory) at the front here, but that should not be\n         necessary, since in out of tree builds lisp\/ is empty, save\n         for Makefile.  *\/\n      return decode_env_path (0, PATH_DUMPLOADSEARCH, 0);\n    }/s
' "${lread_c}"
  if grep -q 'iosmacs: Android NW pdump app lisp root' "${lread_c}"; then
    printf 'patched src/lread.c: Android NW pdump app Lisp root fallback added\n'
  else
    printf 'warning: lread.c Android NW pdump app Lisp root patch not applied\n'
  fi
fi

fns_c="${source_copy}/src/fns.c"
if [[ -f "${fns_c}" ]] && ! grep -q 'IOSMACS_PDMP_ALLOW_REQUIRE_DURING_DUMP' "${fns_c}"; then
  perl -0pi -e '
    s/if \(will_dump_p \(\) && !will_bootstrap_p \(\)\)/if (will_dump_p () && !will_bootstrap_p ()\n          \&\& !getenv ("IOSMACS_PDMP_ALLOW_REQUIRE_DURING_DUMP"))/s
  ' "${fns_c}"
  printf 'patched src/fns.c: allow guarded require during Android NW pdump\n'
fi

eval_c="${source_copy}/src/eval.c"
if [[ -f "${eval_c}" ]] && ! grep -q 'IOSMACS_PDMP_ALLOW_REQUIRE_DURING_DUMP' "${eval_c}"; then
  perl -0pi -e '
    s/if \(will_dump_p \(\) && !will_bootstrap_p \(\)\)/if (will_dump_p () && !will_bootstrap_p ()\n      \&\& !getenv ("IOSMACS_PDMP_ALLOW_REQUIRE_DURING_DUMP"))/s
  ' "${eval_c}"
  printf 'patched src/eval.c: allow guarded autoload during Android NW pdump\n'
fi

loadup_el="${source_copy}/lisp/loadup.el"
if [[ -f "${loadup_el}" ]] \
  && ! grep -q 'iosmacs: add Android NW pdump subdirs' "${loadup_el}"; then
  perl -0pi -e '
s/\(if \(or \(member dump-mode '\''\("bootstrap" "pbootstrap"\)\)/(if (or (member dump-mode '\''("bootstrap" "pbootstrap"))\n        ;; iosmacs: add Android NW pdump subdirs.\n        (and (eq system-type '\''android) (equal dump-mode "pdump"))/s
' "${loadup_el}"
  if grep -q 'iosmacs: add Android NW pdump subdirs' "${loadup_el}"; then
    printf 'patched lisp/loadup.el: add subdirectories during Android NW pdump\n'
  else
    printf 'warning: loadup.el Android NW pdump subdir patch not applied\n'
  fi
fi
if [[ -f "${loadup_el}" ]] \
  && ! grep -q 'IOSMACS_ANDROID_NW_PDUMP_OUTPUT' "${loadup_el}"; then
  perl -0pi -e '
s/\(dump-emacs-portable \(expand-file-name output invocation-directory\)\)/(dump-emacs-portable\n                     (or (cadr (member "--android-nw-pdump-output" command-line-args))\n                         (getenv "IOSMACS_ANDROID_NW_PDUMP_OUTPUT")\n                         (expand-file-name output invocation-directory)))/s
' "${loadup_el}"
  if grep -q 'IOSMACS_ANDROID_NW_PDUMP_OUTPUT' "${loadup_el}"; then
    printf 'patched lisp/loadup.el: Android NW pdump output override added\n'
  else
    printf 'warning: loadup.el Android NW pdump output override patch not applied\n'
  fi
fi
if [[ -f "${loadup_el}" ]] \
  && ! grep -q 'iosmacs: Android NW without pdumper-stats' "${loadup_el}"; then
  perl -0pi -e '
s/\(and \(eq system-type '\''android\)\n         \(not \(pdumper-stats\)\)\)/(and (eq system-type '\''android)\n         ;; iosmacs: Android NW without pdumper-stats.\n         ;; This build uses --with-dumping=none, so pdumper functions are not\n         ;; linked.  Guard the Android repository-version helper accordingly.\n         (fboundp '\''pdumper-stats)\n         (not (pdumper-stats)))/s
' "${loadup_el}"
  if grep -q 'iosmacs: Android NW without pdumper-stats' "${loadup_el}"; then
    printf 'patched lisp/loadup.el: guarded Android pdumper-stats for NW build\n'
  else
    printf 'warning: loadup.el pdumper-stats patch not applied (pattern may have changed)\n'
  fi
fi

# ------------------------------------------------------------------ #
# Step 3: Configure (without --with-android)                          #
# ------------------------------------------------------------------ #

configure_needs_run=0
if [[ ! -f "${build_root}/config.status" ]]; then
  configure_needs_run=1
elif ! grep -q "nw-for-android" "${build_root}/config.log" 2>/dev/null; then
  configure_needs_run=1
fi

if [[ "${configure_needs_run}" == "1" ]]; then
  printf 'configuring GNU Emacs NW for %s Android (no HAVE_ANDROID)...\n' "${host_triple}"
  pdumper_configure_arg=""
  if [[ "${pdumper_enabled}" == "1" ]]; then
    pdumper_configure_arg="--with-pdumper=yes"
  fi
  (
    cd "${build_root}"
    # NOTE: We intentionally omit --with-android so HAVE_ANDROID is not defined.
    # The host triple aarch64-linux-android gives opsys=android for MB_CUR_MAX
    # compatibility only; the full Android GUI restrictions are not activated.
    PATH="${tool_dir}:${toolchain_root}/bin:${PATH}" \
      "${source_copy}/configure" \
        --host="${host_triple}" \
        --build=x86_64-apple-darwin \
        --without-x \
        --without-gconf \
        --without-gsettings \
        --without-dbus \
        --without-sound \
        --without-xaw3d \
        --without-gpm \
        --without-jpeg \
        --without-png \
        --without-gif \
        --without-tiff \
        --without-xpm \
        --without-xml2 \
        --without-imagemagick \
        --without-lcms2 \
        --without-rsvg \
        --without-webp \
        --without-native-compilation \
        --without-tree-sitter \
        --without-sqlite3 \
        --without-mailutils \
        --with-gnutls=no \
        --without-zlib \
        --without-toolkit-scroll-bars \
        --without-xft \
        --without-harfbuzz \
        --without-otf \
        --without-m17n-flt \
        ${pdumper_configure_arg:+${pdumper_configure_arg}} \
        --with-dumping=none \
        "CC=${android_cc}" \
        "AR=${android_ar}" \
        "RANLIB=${android_ranlib}" \
        "NM=${android_nm}" \
        "CFLAGS=-O2 -fPIE -fstack-protector-strong -DHAVE_PTY_H=1" \
        "LDFLAGS=-fPIE -pie -L${stub_dir}/lib" \
        "CPPFLAGS=-I${stub_dir}/include -Dtermcap=1" \
        "LIBS=-lncurses" \
        >"${configure_log}" 2>&1 || {
          printf 'error: configure failed; see %s\n' "${configure_log}" >&2
          tail -30 "${configure_log}" >&2
          exit 1
        }
    # Verify HAVE_ANDROID is NOT defined in config.h
    if grep -q "define HAVE_ANDROID" "${build_root}/src/config.h" 2>/dev/null; then
      printf 'error: HAVE_ANDROID is defined; configure picked up Android build mode unexpectedly\n' >&2
      exit 1
    fi
    printf '# nw-for-android configure marker\n' >> "${build_root}/config.log"
  )

  # Patch the generated src/Makefile so LIBS_TERMCAP links our ncurses stub.
  # The Emacs Makefile intentionally ignores LIBS in the link step and uses
  # LIBS_TERMCAP instead. Configure sets LIBS_TERMCAP="" when tputs is found
  # via the pre-set LIBS variable, so we must restore it here.
  nw_src_makefile="${build_root}/src/Makefile"
  if [[ -f "${nw_src_makefile}" ]] && grep -q '^LIBS_TERMCAP=$' "${nw_src_makefile}"; then
    sed -i '' 's|^LIBS_TERMCAP=$|LIBS_TERMCAP=-lncurses|' "${nw_src_makefile}"
    printf 'patched src/Makefile: LIBS_TERMCAP=-lncurses\n'
  fi
fi

{
  printf 'configure=ok\n'
  printf 'android_abi=%s\n' "${abi}"
  printf 'android_api=%s\n' "${api}"
  printf 'pdumper_enabled=%s\n' "${pdumper_enabled}"
  printf 'android_cc=%s\n' "${android_cc}"
  printf 'ncurses_stub=%s\n' "${stub_lib}"
  printf 'nw_emacs_binary=%s\n' "${build_root}/src/emacs"
  printf 'nw_jni_lib=%s\n' "${out_dir}/jniLibs/${abi}/libemacs_nw.so"
} >"${status_file}"

printf 'flutter Android Emacs NW configure ok: %s\n' "${build_root}"
printf 'status: %s\n' "${status_file}"

if [[ "${IOSMACS_ANDROID_EMACS_NW_BUILD:-0}" != "1" ]]; then
  exit 0
fi

# ------------------------------------------------------------------ #
# Step 4: Reuse .elc files from macOS or Android host build           #
# ------------------------------------------------------------------ #

android_lisp="${repo_root}/build/emacs-android/${abi}/java/install_temp/assets/lisp"
macos_lisp="${repo_root}/build/emacs-macos/runtime/lisp"

if [[ -d "${macos_lisp}" ]]; then
  rsync -a --include='*/' --include='*.elc' --exclude='*' \
    "${macos_lisp}/" "${source_copy}/lisp/"
  printf 'synced .elc files from macOS Emacs runtime\n'
elif [[ -d "${android_lisp}" ]]; then
  rsync -a --include='*/' --include='*.elc' --exclude='*' \
    "${android_lisp}/" "${source_copy}/lisp/"
  printf 'synced .elc files from Android Emacs assets\n'
fi

# Make sure info dir exists (make install_temp expects it)
mkdir -p "${source_copy}/info"

# ------------------------------------------------------------------ #
# Step 5: Build the emacs binary                                      #
# ------------------------------------------------------------------ #

printf 'building GNU Emacs NW binary for Android %s...\n' "${abi}"

# ------------------------------------------------------------------ #
# Native host tools: temacs (bootstrap-emacs) + make-docfile         #
# ------------------------------------------------------------------ #
# Both are built from the Emacs C source on the host (macOS) — no
# system or pre-installed Emacs is required.  Results are cached in
# build/emacs-native-helpers/; subsequent runs skip the native build.
#
# With --with-dumping=none the resulting temacs loads lisp from
# EMACSLOADPATH at runtime, so we redirect it to the Android source
# tree via env vars (set in bootstrap_wrapper below).

_native_dir="${repo_root}/build/emacs-native-helpers"
_native_build="${_native_dir}/build"
_native_emacs="${_native_build}/src/temacs"
_native_make_docfile="${_native_build}/lib-src/make-docfile"

# Explicit overrides: project macOS build or user-supplied binary take priority.
if [[ -n "${IOSMACS_ANDROID_HOST_EMACS:-}" ]]; then
  host_emacs="${IOSMACS_ANDROID_HOST_EMACS}"
elif [[ -x "${repo_root}/build/emacs-macos/runtime/bin/emacs" ]]; then
  host_emacs="${repo_root}/build/emacs-macos/runtime/bin/emacs"
elif [[ -x "${_native_emacs}" ]]; then
  host_emacs="${_native_emacs}"
else
  host_emacs=""
fi

host_make_docfile=""
for _mdf in \
  "${repo_root}/build/emacs-macos/build/lib-src/make-docfile" \
  "${_native_make_docfile}" \
  "${repo_root}/build/emacs-ios-probe/lib-src/make-docfile"; do
  if [[ -x "${_mdf}" ]]; then
    host_make_docfile="${_mdf}"
    break
  fi
done

if [[ -z "${host_emacs}" || ! -x "${host_emacs}" || -z "${host_make_docfile}" ]]; then
  printf 'native host tools not cached; building from Emacs source (first run only)...\n'
  mkdir -p "${_native_build}"

  if [[ ! -f "${_native_build}/Makefile" ]]; then
    printf 'configuring native Emacs (no X, no NS, no GnuTLS)...\n'
    (
      cd "${_native_build}"
      "${source_copy}/configure" \
        --without-x --without-ns --without-gconf --without-gsettings \
        --without-dbus --without-sound \
        --without-jpeg --without-png --without-gif --without-tiff --without-xpm \
        --without-xml2 --without-imagemagick --without-lcms2 --without-rsvg \
        --without-webp --without-native-compilation --without-tree-sitter \
        --without-sqlite3 --with-gnutls=no --without-zlib \
        --with-dumping=none \
        >"${_native_dir}/configure.log" 2>&1
    ) || {
      printf 'error: native configure failed; see %s\n' "${_native_dir}/configure.log" >&2
      tail -20 "${_native_dir}/configure.log" >&2
      exit 1
    }
    printf 'native configure ok\n'
  fi

  printf 'building native lib...\n'
  "${MAKE:-make}" -C "${_native_build}/lib" libgnu.a \
    -j"${jobs}" >"${_native_dir}/build-lib.log" 2>&1 || {
    printf 'error: native lib build failed; see %s\n' "${_native_dir}/build-lib.log" >&2
    tail -20 "${_native_dir}/build-lib.log" >&2
    exit 1
  }

  printf 'building native make-docfile + make-fingerprint...\n'
  "${MAKE:-make}" -C "${_native_build}/lib-src" make-docfile \
    -j"${jobs}" >"${_native_dir}/build-libsrc.log" 2>&1 || {
    printf 'error: native lib-src build failed; see %s\n' "${_native_dir}/build-libsrc.log" >&2
    tail -20 "${_native_dir}/build-libsrc.log" >&2
    exit 1
  }
  "${MAKE:-make}" -C "${_native_build}/lib-src" make-fingerprint \
    -j"${jobs}" >>"${_native_dir}/build-libsrc.log" 2>&1 || true

  printf 'building native temacs (pure C, may take a few minutes)...\n'
  "${MAKE:-make}" -C "${_native_build}/src" temacs \
    -j"${jobs}" >"${_native_dir}/build-temacs.log" 2>&1 || {
    printf 'error: native temacs build failed; see %s\n' "${_native_dir}/build-temacs.log" >&2
    tail -20 "${_native_dir}/build-temacs.log" >&2
    exit 1
  }

  [[ -x "${_native_emacs}" ]] || {
    printf 'error: native temacs not found at %s after build\n' "${_native_emacs}" >&2
    exit 1
  }
  [[ -x "${_native_make_docfile}" ]] || {
    printf 'error: native make-docfile not found at %s after build\n' "${_native_make_docfile}" >&2
    exit 1
  }

  host_emacs="${_native_emacs}"
  host_make_docfile="${_native_make_docfile}"
  printf 'native host tools built ok\n'
fi

printf 'using host Emacs (temacs): %s\n' "${host_emacs}"

# Create bootstrap-emacs wrapper.  EMACSDATA and EMACSLOADPATH env vars
# take effect at C startup (before charsets are loaded), avoiding
# .app-bundle relative-path issues and system Emacs path assumptions.
bootstrap_wrapper="${tool_dir}/bootstrap-emacs"
cat >"${bootstrap_wrapper}" <<BOOTSTRAP_EOF
#!/usr/bin/env bash
set -eo pipefail
host_emacs="${host_emacs}"
source_lisp="${source_copy}/lisp"
source_etc="${source_copy}/etc"
# Build EMACSLOADPATH from all subdirs of the source lisp tree.
# We rely on EMACSDATA / EMACSLOADPATH env vars (C-level, processed before
# charsets are loaded) rather than --eval, which runs too late for data-dir.
load_path="\${source_lisp}"
while IFS= read -r d; do
  load_path="\${load_path}:\${d}"
done < <(find "\${source_lisp}" -mindepth 1 -type d | sort)
exec env LANG=C LC_ALL=C \\
  EMACSDATA="\${source_etc}" \\
  EMACSLOADPATH="\${load_path}" \\
  "\$host_emacs" \\
  --eval "(setq lisp-directory \"\${source_lisp}/\" data-directory \"\${source_etc}/\")" \\
  "\$@"
BOOTSTRAP_EOF
chmod +x "${bootstrap_wrapper}"

printf 'using host make-docfile:   %s\n' "${host_make_docfile}"

if ! "${MAKE:-make}" -C "${build_root}/lib" libgnu.a \
  "AR=${android_ar}" "RANLIB=${android_ranlib}" "NM=${android_nm}" \
  -j"${jobs}" >"${out_dir}/libgnu.log" 2>&1; then
  printf 'error: libgnu.a build failed; see %s\n' "${out_dir}/libgnu.log" >&2
  tail -20 "${out_dir}/libgnu.log" >&2
  exit 1
fi

# Create a shell-script wrapper for make-docfile that delegates to the macOS
# native binary.  This wrapper will be placed in lib-src/make-docfile so the
# Emacs src/ Makefile can run it on macOS even though it was cross-compiled.
make_docfile_wrapper="${build_root}/lib-src/make-docfile"
cat >"${make_docfile_wrapper}" <<MDFEOF
#!/usr/bin/env bash
exec "${host_make_docfile}" "\$@"
MDFEOF
chmod +x "${make_docfile_wrapper}"

# Similarly wrap make-fingerprint.
host_make_fingerprint="${host_make_docfile%make-docfile}make-fingerprint"
if [[ -x "${host_make_fingerprint}" ]]; then
  make_fingerprint_wrapper="${build_root}/lib-src/make-fingerprint"
  cat >"${make_fingerprint_wrapper}" <<MDFEOF
#!/usr/bin/env bash
exec "${host_make_fingerprint}" "\$@"
MDFEOF
  chmod +x "${make_fingerprint_wrapper}"
fi
printf 'installed make-docfile / make-fingerprint wrappers\n'

# Build bootstrap-emacs (the lisp sub-make needs it to byte-compile .el files).
# We first let make produce the ARM64 binary, then replace with the macOS wrapper.
"${MAKE:-make}" -C "${build_root}/src" bootstrap-emacs \
  "AR=${android_ar}" "RANLIB=${android_ranlib}" "NM=${android_nm}" \
  --old-file="${make_docfile_wrapper}" \
  -j"${jobs}" >>"${out_dir}/lib-src.log" 2>&1 || true
cp -f "${bootstrap_wrapper}" "${build_root}/src/bootstrap-emacs"
chmod +x "${build_root}/src/bootstrap-emacs"
printf 'installed bootstrap-emacs wrapper\n'

# Build src/emacs — with DUMPING=none, this just copies temacs to emacs.
# Use --old-file so make doesn't rebuild our shell-script wrappers.
if ! "${MAKE:-make}" -C "${build_root}/src" emacs \
  "AR=${android_ar}" "RANLIB=${android_ranlib}" "NM=${android_nm}" \
  --old-file="${make_docfile_wrapper}" \
  --old-file="${build_root}/src/bootstrap-emacs" \
  -j"${jobs}" >"${build_log}" 2>&1; then
  printf 'error: Emacs NW build failed; see %s\n' "${build_log}" >&2
  grep -E 'error:|undefined|No such' "${build_log}" | tail -30 >&2
  # If temacs build failed, show the actual error lines
  grep -v "^  " "${build_log}" | grep -E "error:|undefined|cannot" | head -30 >&2 || true
  tail -40 "${build_log}" >&2
  printf 'build=failed\nbuild_log=%s\n' "${build_log}" >>"${status_file}"
  exit 1
fi

# With --with-dumping=none, temacs IS the emacs binary.
nw_binary="${build_root}/src/emacs"
if [[ ! -f "${nw_binary}" ]]; then
  nw_binary="${build_root}/src/temacs"
fi
if [[ ! -f "${nw_binary}" ]]; then
  printf 'error: emacs/temacs binary not produced under %s/src/\n' "${build_root}" >&2
  exit 1
fi
printf 'using NW binary: %s\n' "${nw_binary}"

# ------------------------------------------------------------------ #
# Step 6: Package as libemacs_nw.so for APK jniLibs                  #
# ------------------------------------------------------------------ #
# Name it .so so Android's jniLibs mechanism extracts it to
# nativeLibraryDir where it can be executed by the JNI code.
# We use useLegacyPackaging=true in Gradle to ensure extraction.

jni_lib_dir="${out_dir}/jniLibs/${abi}"
mkdir -p "${jni_lib_dir}"
cp -p "${nw_binary}" "${jni_lib_dir}/libemacs_nw.so"

# Copy to the SHARED jniLibs directory used by Gradle (same as the Android
# HAVE_ANDROID build) so no Gradle source-set changes are needed.
shared_jni_dir="${repo_root}/build/emacs-android/${abi}/iosmacs/jniLibs/${abi}"
if [[ -d "${shared_jni_dir}" ]]; then
  cp -p "${jni_lib_dir}/libemacs_nw.so" "${shared_jni_dir}/libemacs_nw.so"
  printf 'copied libemacs_nw.so to shared jniLibs: %s\n' "${shared_jni_dir}"
fi
shared_assets_dir="${repo_root}/build/emacs-android/${abi}/java/install_temp/assets"
if [[ -d "${shared_assets_dir}" ]]; then
  if [[ "${pdumper_enabled}" == "1" ]]; then
    printf '1\n' >"${shared_assets_dir}/iosmacs-nw-pdumper-enabled"
    printf 'wrote Android NW pdumper asset marker\n'
  else
    rm -f "${shared_assets_dir}/iosmacs-nw-pdumper-enabled"
  fi
fi

{
  printf 'build=ok\n'
  printf 'build_log=%s\n' "${build_log}"
  printf 'pdumper_enabled=%s\n' "${pdumper_enabled}"
  printf 'nw_binary=%s\n' "${nw_binary}"
  printf 'nw_jni_lib=%s\n' "${jni_lib_dir}/libemacs_nw.so"
} >>"${status_file}"

printf 'flutter Android Emacs NW binary ready: %s\n' "${nw_binary}"
printf 'flutter Android Emacs NW JNI lib ready: %s\n' "${jni_lib_dir}/libemacs_nw.so"
