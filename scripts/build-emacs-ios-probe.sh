#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_root="${IOSMACS_EMACS_SOURCE:-${repo_root}/wasmacs/vendor/emacs}"
build_root="${IOSMACS_BUILD_ROOT:-${repo_root}/build/emacs-ios-probe}"
source_work="${build_root}/source"
sdk="${IOSMACS_SDK:-iphonesimulator}"
arch="${IOSMACS_ARCH:-arm64}"
min_ios="${IOSMACS_MIN_IOS:-17.0}"
clang_arch="${IOSMACS_CLANG_ARCH:-${arch}}"
case "${arch}" in
  arm64) configure_arch=aarch64 ;;
  *) configure_arch="${arch}" ;;
esac
# Upstream Emacs rejects aarch64-apple-ios in configure today.  Keep the
# compiler target on iOS, but use the Darwin host triplet until iosmacs carries
# a small, explicit Emacs config.sub/configure port patch.
host="${IOSMACS_HOST:-${configure_arch}-apple-darwin}"
target="${IOSMACS_TARGET:-${clang_arch}-apple-ios${min_ios}-simulator}"
opt_flags="${IOSMACS_EMACS_OPT_FLAGS:--O0 -g}"

mkdir -p "${build_root}"
rsync -a --delete --exclude .git "${source_root}/" "${source_work}/"
configure_root="${source_work}"
if [[ ! -x "${configure_root}/configure" ]]; then
  if [[ -x "${configure_root}/autogen.sh" ]]; then
    (
      cd "${configure_root}"
      ./autogen.sh
    )
  else
    cat >&2 <<EOF
error: ${source_root}/configure is missing and autogen.sh is unavailable.
Run:
  git submodule update --init --recursive
EOF
  exit 1
fi
fi

cc="$(xcrun --sdk "${sdk}" --find clang)"
sysroot="$(xcrun --sdk "${sdk}" --show-sdk-path)"

cat >"${build_root}/probe.env" <<EOF
source_root=${source_root}
configure_root=${configure_root}
build_root=${build_root}
sdk=${sdk}
arch=${arch}
host=${host}
target=${target}
cc=${cc}
sysroot=${sysroot}
EOF

(
  cd "${build_root}"
  CC="${cc}" \
  CFLAGS="-target ${target} -isysroot ${sysroot} ${opt_flags}" \
  CPPFLAGS="-target ${target} -isysroot ${sysroot}" \
  LDFLAGS="-target ${target} -isysroot ${sysroot}" \
  ac_cv_func_fork=no \
  ac_cv_func_vfork=no \
  ac_cv_func_grantpt=no \
  ac_cv_func_pipe2=no \
  ac_cv_func_posix_openpt=no \
  ac_cv_func_posix_spawn=no \
  ac_cv_func_posix_spawn_file_actions_addchdir=no \
  ac_cv_func_posix_spawn_file_actions_addchdir_np=no \
  ac_cv_header_sys_socket_h=no \
  ac_cv_type_socklen_t=yes \
  emacs_cv_native_compilation=no \
  "${configure_root}/configure" \
    --host="${host}" \
    --build="$("${configure_root}/build-aux/config.guess")" \
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

sysdep_c="${configure_root}/src/sysdep.c"
if [[ -f "${sysdep_c}" ]] && ! grep -q "iosmacs: libproc is macOS-only" "${sysdep_c}"; then
  perl -0pi -e '
    s/#ifdef DARWIN_OS\n# include <libproc.h>\n#endif/#ifdef DARWIN_OS\n# if defined(__has_include)\n#  if __has_include(<libproc.h>)\n#   define IOSMACS_HAS_LIBPROC 1\n#  endif\n# endif\n# ifdef IOSMACS_HAS_LIBPROC\n#  include <libproc.h>\n# endif\n#endif\n\/\* iosmacs: libproc is macOS-only in current iOS SDK probes. *\//s
  ' "${sysdep_c}"
  perl -0pi -e '
    s/  char pathbuf\[PROC_PIDPATHINFO_MAXSIZE\];\n  char \*comm;\n\n  if \(proc_pidpath \(proc_id, pathbuf, sizeof\(pathbuf\)\) > 0\)\n    \{\n      if \(\(comm = strrchr \(pathbuf, \x27\/\x27\)\)\)\n        comm\+\+;\n      else\n        comm = pathbuf;\n    \}\n  else\n    comm = proc\.kp_proc\.p_comm;/  char *comm;\n\n#ifdef IOSMACS_HAS_LIBPROC\n  char pathbuf[PROC_PIDPATHINFO_MAXSIZE];\n  if (proc_pidpath (proc_id, pathbuf, sizeof(pathbuf)) > 0)\n    {\n      if ((comm = strrchr (pathbuf, \x27\/\x27)))\n        comm++;\n      else\n        comm = pathbuf;\n    }\n  else\n#endif\n    comm = proc.kp_proc.p_comm;/s
	  ' "${sysdep_c}"
fi

if [[ -f "${sysdep_c}" ]] && ! grep -q "iosmacs: direct tty facade fallback definitions" "${sysdep_c}"; then
  perl -0pi -e '
    s/(\/\* Read from FD to a buffer BUF with size NBYTE\.)/__attribute__ ((weak)) int\niosmacs_host_wait_for_input (int timeout_ms)\n{\n  (void) timeout_ms;\n  return 0;\n}\n\n__attribute__ ((weak)) int\niosmacs_host_terminal_input_available (void)\n{\n  return 0;\n}\n\n__attribute__ ((weak)) int\niosmacs_host_is_tty_fd (int fd)\n{\n  (void) fd;\n  return 0;\n}\n\n__attribute__ ((weak)) void\niosmacs_host_trace_event (const char *message)\n{\n  (void) message;\n}\n\n\/* iosmacs: direct tty facade fallback definitions. *\/\n\n$1/s
  ' "${sysdep_c}"
fi

emacs_c="${configure_root}/src/emacs.c"
if [[ -f "${emacs_c}" ]] && ! grep -q "iosmacs-main-before-recursive-edit" "${emacs_c}"; then
  perl -0pi -e '
    s/  \/\* Enter editor command loop\.  This never returns\.  \*\/\n  set_initial_minibuffer_mode \(\);\n  Frecursive_edit \(\);/  \/* Enter editor command loop.  This never returns.  *\/\n  if (getenv ("IOSMACS_NW_DEBUG_ERROR"))\n    fprintf (stderr, "iosmacs-main-before-recursive-edit\\n");\n  set_initial_minibuffer_mode ();\n  Frecursive_edit ();/s
  ' "${emacs_c}"
fi

if [[ -f "${emacs_c}" ]] && ! grep -q "iosmacs-main-before-init-display" "${emacs_c}"; then
  perl -0pi -e '
    s/  init_display \(\);\t\/\* Determine terminal type\.  Calls init_sys_modes\.  \*\//  if (getenv ("IOSMACS_NW_DEBUG_ERROR"))\n    fprintf (stderr, "iosmacs-main-before-init-display\\n");\n  init_display ();\t\/\* Determine terminal type.  Calls init_sys_modes.  *\/\n  if (getenv ("IOSMACS_NW_DEBUG_ERROR"))\n    fprintf (stderr, "iosmacs-main-after-init-display\\n");/s;
    s/  init_window \(\);/  if (getenv ("IOSMACS_NW_DEBUG_ERROR"))\n    fprintf (stderr, "iosmacs-main-before-init-window\\n");\n  init_window ();\n  if (getenv ("IOSMACS_NW_DEBUG_ERROR"))\n    fprintf (stderr, "iosmacs-main-after-init-window\\n");/s;
    s/  safe_run_hooks \(Qafter_pdump_load_hook\);/  if (getenv ("IOSMACS_NW_DEBUG_ERROR"))\n    fprintf (stderr, "iosmacs-main-before-after-pdump-load-hook\\n");\n  safe_run_hooks (Qafter_pdump_load_hook);\n  if (getenv ("IOSMACS_NW_DEBUG_ERROR"))\n    fprintf (stderr, "iosmacs-main-after-after-pdump-load-hook\\n");/s
  ' "${emacs_c}"
fi

data_c="${configure_root}/src/data.c"
if [[ -f "${data_c}" ]] && ! grep -q "iosmacs: avoid unstable forwarded values in the iOS tty probe" "${data_c}"; then
  perl -0pi -e '
    s/(find_symbol_value \(Lisp_Object symbol\)\n\{\n  struct Lisp_Symbol \*sym;\n\n  CHECK_SYMBOL \(symbol\);\n  sym = XSYMBOL \(symbol\);)/$1\n  if (getenv ("IOSMACS_NW_AVOID_FORWARDED_VALUES"))\n    {\n      const char *iosmacs_symbol_name = SSDATA (SYMBOL_NAME (symbol));\n      if (strcmp (iosmacs_symbol_name, "inhibit-quit") == 0\n          || strcmp (iosmacs_symbol_name, "window-system") == 0)\n        return Qnil;\n    }\n  \/* iosmacs: avoid unstable forwarded values in the iOS tty probe. *\//s
  ' "${data_c}"
fi

alloc_c="${configure_root}/src/alloc.c"
if [[ -f "${alloc_c}" ]] && ! grep -q "iosmacs: allow the iOS nw smoke to expose startup errors before GC" "${alloc_c}"; then
  perl -0pi -e '
    s/void\nmaybe_garbage_collect \(void\)\n\{\n  if \(bump_consing_until_gc \(gc_cons_threshold, Vgc_cons_percentage\) < 0\)\n    garbage_collect \(\);\n\}/void\nmaybe_garbage_collect (void)\n{\n  if (getenv ("IOSMACS_NW_SKIP_GC"))\n    {\n      bump_consing_until_gc (gc_cons_threshold, Vgc_cons_percentage);\n      \/* iosmacs: allow the iOS nw smoke to expose startup errors before GC. *\/\n      return;\n    }\n  if (bump_consing_until_gc (gc_cons_threshold, Vgc_cons_percentage) < 0)\n    garbage_collect ();\n}/s
  ' "${alloc_c}"
fi
if [[ -f "${alloc_c}" ]] && ! grep -q "iosmacs: suppress explicit GC in the iOS nw probe" "${alloc_c}"; then
  perl -0pi -e '
    s/void\ngarbage_collect \(void\)\n\{\n/void\ngarbage_collect (void)\n{\n  if (getenv ("IOSMACS_NW_SKIP_GC"))\n    {\n      \/* iosmacs: suppress explicit GC in the iOS nw probe. *\/\n      return;\n    }\n/s
  ' "${alloc_c}"
fi

keyboard_c="${configure_root}/src/keyboard.c"
if [[ -f "${keyboard_c}" ]] && ! grep -q "iosmacs: mirror command-loop startup errors for the iOS nw smoke" "${keyboard_c}"; then
  perl -0pi -e '
    s/  Vinhibit_quit = Qt;\n/  Vinhibit_quit = Qt;\n\n  if (getenv ("IOSMACS_NW_DEBUG_ERROR"))\n    {\n      fprintf (stderr, "\\niosmacs-nw-command-error\\n");\n      print_error_message (data, Qexternal_debugging_output,\n                           context ? context : "", Vsignaling_function);\n      Fterpri (Qexternal_debugging_output, Qnil);\n    }\n  \/* iosmacs: mirror command-loop startup errors for the iOS nw smoke. *\/\n/s
  ' "${keyboard_c}"
fi
if [[ -f "${keyboard_c}" ]] && ! grep -q "iosmacs-top-level-2-entry" "${keyboard_c}"; then
  perl -0pi -e '
    s/static Lisp_Object\ntop_level_2 \(void\)\n\{/static Lisp_Object\ntop_level_2 (void)\n{\n  if (getenv ("IOSMACS_NW_DEBUG_ERROR"))\n    fprintf (stderr, "iosmacs-top-level-2-entry\\n");/s;
    s/static Lisp_Object\ntop_level_1 \(Lisp_Object ignore\)\n\{/static Lisp_Object\ntop_level_1 (Lisp_Object ignore)\n{\n  if (getenv ("IOSMACS_NW_DEBUG_ERROR"))\n    fprintf (stderr, "iosmacs-top-level-1-entry\\n");/s;
    s/static Lisp_Object\ncommand_loop_1 \(void\)\n\{/static Lisp_Object\ncommand_loop_1 (void)\n{\n  if (getenv ("IOSMACS_NW_DEBUG_ERROR"))\n    fprintf (stderr, "iosmacs-command-loop-1-entry\\n");/s
  ' "${keyboard_c}"
fi

if [[ -f "${keyboard_c}" ]] && ! grep -q "iosmacs-top-level-vtop-level" "${keyboard_c}"; then
  perl -0pi -e '
    s/(fprintf \(stderr, "iosmacs-top-level-2-entry\\n"\);)/$1\n  if (getenv ("IOSMACS_NW_DEBUG_ERROR"))\n    {\n      fprintf (stderr, "iosmacs-top-level-vtop-level: ");\n      debug_print (Vtop_level);\n    }/s
  ' "${keyboard_c}"
fi
if [[ -f "${keyboard_c}" ]] && grep -q "debug_print (Vtop_level)" "${keyboard_c}"; then
  perl -0pi -e '
    s/  if \(getenv \("IOSMACS_NW_DEBUG_ERROR"\)\)\n    \{\n      fprintf \(stderr, "iosmacs-top-level-vtop-level: "\);\n      debug_print \(Vtop_level\);\n    \}/  if (getenv ("IOSMACS_NW_DEBUG_ERROR"))\n    fprintf (stderr, "iosmacs-top-level-vtop-level\\n");/s
  ' "${keyboard_c}"
fi

if [[ -f "${keyboard_c}" ]] && ! grep -q "iosmacs: direct tty waitpoint declarations" "${keyboard_c}"; then
  perl -0pi -e '
    s/(\/\* Read a character from the keyboard; call the redisplay if needed\.  \*\/)/extern int iosmacs_host_wait_for_input (int timeout_ms);\nextern int iosmacs_host_terminal_input_available (void);\nextern int iosmacs_host_is_tty_fd (int fd);\nextern void iosmacs_host_trace_event (const char *message);\nextern int gobble_input (void);\n\nstatic int\niosmacs_host_timeout_ms_until (struct timespec *end_time)\n{\n  struct timespec now;\n  struct timespec duration;\n  long nsec_ms;\n  long total_ms;\n\n  if (!end_time)\n    return 50;\n\n  now = current_timespec ();\n  if (timespec_cmp (*end_time, now) <= 0)\n    return 0;\n\n  duration = timespec_sub (*end_time, now);\n  if (duration.tv_sec > 60)\n    return 60000;\n\n  nsec_ms = (duration.tv_nsec + 999999L) \/ 1000000L;\n  total_ms = duration.tv_sec * 1000L + nsec_ms;\n  return total_ms > 0 ? (int) total_ms : 0;\n}\n\/* iosmacs: direct tty waitpoint declarations. *\/\n\n$1/s
  ' "${keyboard_c}"
fi

if [[ -f "${keyboard_c}" ]] && ! grep -q "iosmacs: direct tty waitpoint before decoded event read" "${keyboard_c}"; then
  perl -0pi -e '
    s/(  if \(NILP \(c\)\)\n    \{\n)(      c = read_decoded_event_from_main_queue)/$1      if (!noninteractive && iosmacs_host_is_tty_fd (0))\n        {\n          int iosmacs_timeout_ms = iosmacs_host_timeout_ms_until (end_time);\n          if (!end_time || iosmacs_timeout_ms > 0)\n            {\n              char iosmacs_trace[128];\n              int iosmacs_wait_result = iosmacs_host_wait_for_input (iosmacs_timeout_ms);\n              int iosmacs_available = iosmacs_host_terminal_input_available ();\n              int iosmacs_nread;\n              snprintf (iosmacs_trace, sizeof iosmacs_trace,\n                        "keyboard wait-before-gobble wait=%d timeout=%d available=%d",\n                        iosmacs_wait_result, iosmacs_timeout_ms,\n                        iosmacs_available);\n              iosmacs_host_trace_event (iosmacs_trace);\n              iosmacs_nread = gobble_input ();\n              snprintf (iosmacs_trace, sizeof iosmacs_trace,\n                        "keyboard gobble-input nread=%d wait=%d",\n                        iosmacs_nread, iosmacs_wait_result);\n              iosmacs_host_trace_event (iosmacs_trace);\n              if (getenv ("IOSMACS_NW_DEBUG_ERROR"))\n                fprintf (stderr, "iosmacs-keyboard-drain nread=%d wait=%d\\n",\n                         iosmacs_nread, iosmacs_wait_result);\n            }\n        }\n      \/* iosmacs: direct tty waitpoint before decoded event read. *\/\n\n$2/s
  ' "${keyboard_c}"
fi

fns_c="${configure_root}/src/fns.c"
if [[ -f "${fns_c}" ]] && ! grep -q "IOSMACS_PDMP_ALLOW_REQUIRE_DURING_DUMP" "${fns_c}"; then
  perl -0pi -e '
    s/if \(will_dump_p \(\) && !will_bootstrap_p \(\)\)/if (will_dump_p () && !will_bootstrap_p ()\n          \&\& !getenv ("IOSMACS_PDMP_ALLOW_REQUIRE_DURING_DUMP"))/s
  ' "${fns_c}"
fi

eval_c="${configure_root}/src/eval.c"
if [[ -f "${eval_c}" ]] && ! grep -q "IOSMACS_PDMP_ALLOW_REQUIRE_DURING_DUMP" "${eval_c}"; then
  perl -0pi -e '
    s/if \(will_dump_p \(\) && !will_bootstrap_p \(\)\)/if (will_dump_p () && !will_bootstrap_p ()\n      \&\& !getenv ("IOSMACS_PDMP_ALLOW_REQUIRE_DURING_DUMP"))/s
  ' "${eval_c}"
fi

bidi_c="${configure_root}/src/bidi.c"
if [[ -f "${bidi_c}" ]] && ! grep -q "iosmacs: fallback bidi tables for charprop-less iOS pdmp smoke" "${bidi_c}"; then
  perl -0pi -e '
    s/  bidi_type_table = uniprop_table \(intern \("bidi-class"\)\);\n  if \(NILP \(bidi_type_table\)\)\n    emacs_abort \(\);/  bidi_type_table = uniprop_table (intern ("bidi-class"));\n  if (NILP (bidi_type_table) && getenv ("IOSMACS_PDMP_FALLBACK_CHARPROP"))\n    bidi_type_table = Fmake_char_table (Qnil, make_fixnum (STRONG_L));\n  \/* iosmacs: fallback bidi tables for charprop-less iOS pdmp smoke. *\/\n  if (NILP (bidi_type_table))\n    emacs_abort ();/s;
    s/  bidi_mirror_table = uniprop_table \(intern \("mirroring"\)\);\n  if \(NILP \(bidi_mirror_table\)\)\n    emacs_abort \(\);/  bidi_mirror_table = uniprop_table (intern ("mirroring"));\n  if (NILP (bidi_mirror_table) && getenv ("IOSMACS_PDMP_FALLBACK_CHARPROP"))\n    bidi_mirror_table = Fmake_char_table (Qnil, Qnil);\n  if (NILP (bidi_mirror_table))\n    emacs_abort ();/s;
    s/  bidi_brackets_table = uniprop_table \(intern \("bracket-type"\)\);\n  if \(NILP \(bidi_brackets_table\)\)\n    emacs_abort \(\);/  bidi_brackets_table = uniprop_table (intern ("bracket-type"));\n  if (NILP (bidi_brackets_table) && getenv ("IOSMACS_PDMP_FALLBACK_CHARPROP"))\n    bidi_brackets_table = Fmake_char_table (Qnil, Qnil);\n  if (NILP (bidi_brackets_table))\n    emacs_abort ();/s
  ' "${bidi_c}"
fi

character_c="${configure_root}/src/character.c"
if [[ -f "${character_c}" ]] && ! grep -q "iosmacs: tolerate missing unicode category table in iOS pdmp smoke" "${character_c}"; then
  perl -0pi -e '
    s/bool\nalphabeticp \(int c\)\n\{\n  Lisp_Object category = CHAR_TABLE_REF \(Vunicode_category_table, c\);/bool\nalphabeticp (int c)\n{\n  if (! CHAR_TABLE_P (Vunicode_category_table))\n    return false;\n  \/* iosmacs: tolerate missing unicode category table in iOS pdmp smoke. *\/\n  Lisp_Object category = CHAR_TABLE_REF (Vunicode_category_table, c);/s;
    s/bool\nalphanumericp \(int c\)\n\{\n  Lisp_Object category = CHAR_TABLE_REF \(Vunicode_category_table, c\);/bool\nalphanumericp (int c)\n{\n  if (! CHAR_TABLE_P (Vunicode_category_table))\n    return false;\n  \/* iosmacs: tolerate missing unicode category table in iOS pdmp smoke. *\/\n  Lisp_Object category = CHAR_TABLE_REF (Vunicode_category_table, c);/s;
    s/bool\ngraphicp \(int c\)\n\{\n  Lisp_Object category = CHAR_TABLE_REF \(Vunicode_category_table, c\);/bool\ngraphicp (int c)\n{\n  if (! CHAR_TABLE_P (Vunicode_category_table))\n    return ! ASCII_CHAR_P (c);\n  \/* iosmacs: tolerate missing unicode category table in iOS pdmp smoke. *\/\n  Lisp_Object category = CHAR_TABLE_REF (Vunicode_category_table, c);/s;
    s/bool\nprintablep \(int c\)\n\{\n  Lisp_Object category = CHAR_TABLE_REF \(Vunicode_category_table, c\);/bool\nprintablep (int c)\n{\n  if (! CHAR_TABLE_P (Vunicode_category_table))\n    return ! ASCII_CHAR_P (c);\n  \/* iosmacs: tolerate missing unicode category table in iOS pdmp smoke. *\/\n  Lisp_Object category = CHAR_TABLE_REF (Vunicode_category_table, c);/s;
    s/bool\ngraphic_base_p \(int c\)\n\{\n  Lisp_Object category = CHAR_TABLE_REF \(Vunicode_category_table, c\);/bool\ngraphic_base_p (int c)\n{\n  if (! CHAR_TABLE_P (Vunicode_category_table))\n    return ! ASCII_CHAR_P (c);\n  \/* iosmacs: tolerate missing unicode category table in iOS pdmp smoke. *\/\n  Lisp_Object category = CHAR_TABLE_REF (Vunicode_category_table, c);/s;
    s/bool\nblankp \(int c\)\n\{\n  Lisp_Object category = CHAR_TABLE_REF \(Vunicode_category_table, c\);/bool\nblankp (int c)\n{\n  if (! CHAR_TABLE_P (Vunicode_category_table))\n    return false;\n  \/* iosmacs: tolerate missing unicode category table in iOS pdmp smoke. *\/\n  Lisp_Object category = CHAR_TABLE_REF (Vunicode_category_table, c);/s
  ' "${character_c}"
fi

dispnew_c="${configure_root}/src/dispnew.c"
if [[ -f "${dispnew_c}" ]] && ! grep -q "iosmacs: keep terminal-frame live after tty conversion" "${dispnew_c}"; then
  perl -0pi -e '
    s/    \/\* Delete the initial terminal\. \*\/\n    if \(--initial_terminal->reference_count == 0\n        && initial_terminal->delete_terminal_hook\)\n      \(\*initial_terminal->delete_terminal_hook\) \(initial_terminal\);\n\n    \/\* Update frame parameters to reflect the new type\. \*\//    \/* Delete the initial terminal. *\/\n    if (--initial_terminal->reference_count == 0\n        && initial_terminal->delete_terminal_hook)\n      (*initial_terminal->delete_terminal_hook) (initial_terminal);\n\n    Vterminal_frame = selected_frame;\n    \/* iosmacs: keep terminal-frame live after tty conversion. *\/\n\n    \/* Update frame parameters to reflect the new type. *\//s
  ' "${dispnew_c}"
fi
if [[ -f "${dispnew_c}" ]] && ! grep -q "iosmacs: avoid selected-frame tty lookup during tty conversion" "${dispnew_c}"; then
  perl -0pi -e '
    s/AUTO_FRAME_ARG \(tty_type_arg, Qtty_type, Ftty_type \(selected_frame\)\);/AUTO_FRAME_ARG (tty_type_arg, Qtty_type, build_string (t->display_info.tty->type));\n    \/* iosmacs: avoid selected-frame tty lookup during tty conversion. *\//s
  ' "${dispnew_c}"
fi
if [[ -f "${dispnew_c}" ]] && ! grep -q "iosmacs: keep converted tty frame live before parameter updates" "${dispnew_c}"; then
  perl -0pi -e '
    s/    \/\* Update frame parameters to reflect the new type\. \*\//    f->terminal = t;\n    f->output_method = t->type;\n    \/* iosmacs: keep converted tty frame live before parameter updates. *\/\n\n    \/* Update frame parameters to reflect the new type. *\//s
  ' "${dispnew_c}"
fi
if [[ -f "${dispnew_c}" ]] && ! grep -q "iosmacs: reset converted tty frame cost vectors" "${dispnew_c}"; then
  perl -0pi -e '
    s/    f->terminal = t;\n    f->output_method = t->type;\n    \/\* iosmacs: keep converted tty frame live before parameter updates\. \*\//    f->terminal = t;\n    f->output_method = t->type;\n    FRAME_INSERT_COST (f) = NULL;\n    FRAME_DELETE_COST (f) = NULL;\n    FRAME_INSERTN_COST (f) = NULL;\n    FRAME_DELETEN_COST (f) = NULL;\n    f->decode_mode_spec_buffer = NULL;\n    adjust_decode_mode_spec_buffer (f);\n    \/* iosmacs: reset converted tty frame cost vectors. *\/\n    \/* iosmacs: keep converted tty frame live before parameter updates. *\//s
  ' "${dispnew_c}"
fi
if [[ -f "${dispnew_c}" ]] && ! grep -q "iosmacs: restore root window buffer after tty conversion" "${dispnew_c}"; then
  perl -0pi -e '
    s/    \/\* Update frame parameters to reflect the new type\. \*\//    if (WINDOWP (FRAME_ROOT_WINDOW (f))\n        && !BUFFERP (XWINDOW (FRAME_ROOT_WINDOW (f))->contents))\n      set_window_buffer (FRAME_ROOT_WINDOW (f), Fcurrent_buffer (), 0, 0);\n    \/* iosmacs: restore root window buffer after tty conversion. *\/\n\n    \/* Update frame parameters to reflect the new type. *\//s
  ' "${dispnew_c}"
fi
if [[ -f "${dispnew_c}" ]] && ! grep -q "iosmacs: restore selected window buffer after tty conversion" "${dispnew_c}"; then
  perl -0pi -e '
    s/    \/\* iosmacs: restore root window buffer after tty conversion\. \*\//    if (!WINDOWP (FRAME_ROOT_WINDOW (f))\n        && WINDOWP (FRAME_SELECTED_WINDOW (f)))\n      fset_root_window (f, FRAME_SELECTED_WINDOW (f));\n    if (WINDOWP (FRAME_SELECTED_WINDOW (f))\n        && !BUFFERP (XWINDOW (FRAME_SELECTED_WINDOW (f))->contents))\n      set_window_buffer (FRAME_SELECTED_WINDOW (f), Fcurrent_buffer (), 0, 0);\n    if (WINDOWP (selected_window)\n        && !BUFFERP (XWINDOW (selected_window)->contents))\n      set_window_buffer (selected_window, Fcurrent_buffer (), 0, 0);\n    \/* iosmacs: restore selected window buffer after tty conversion. *\/\n    \/* iosmacs: restore root window buffer after tty conversion. *\//s
  ' "${dispnew_c}"
fi
if [[ -f "${dispnew_c}" ]] && ! grep -q "iosmacs: reselect live leaf window after tty conversion" "${dispnew_c}"; then
  perl -0pi -e '
    s/    \/\* iosmacs: restore root window buffer after tty conversion\. \*\//    if (WINDOWP (FRAME_ROOT_WINDOW (f)))\n      {\n        Lisp_Object live_window = FRAME_ROOT_WINDOW (f);\n        while (WINDOWP (live_window) && WINDOWP (XWINDOW (live_window)->contents))\n          live_window = XWINDOW (live_window)->contents;\n        if (WINDOWP (live_window)\n            && !BUFFERP (XWINDOW (live_window)->contents))\n          set_window_buffer (live_window, Fcurrent_buffer (), 0, 0);\n        if (WINDOWP (live_window) && BUFFERP (XWINDOW (live_window)->contents))\n          {\n            fset_selected_window (f, live_window);\n            selected_window = live_window;\n          }\n      }\n    \/* iosmacs: reselect live leaf window after tty conversion. *\/\n    \/* iosmacs: restore root window buffer after tty conversion. *\//s
  ' "${dispnew_c}"
fi
if [[ -f "${dispnew_c}" ]] && ! grep -q "iosmacs: defer deleting the bootstrap terminal in the iOS tty probe" "${dispnew_c}"; then
  perl -0pi -e '
    s/    \/\* Delete the initial terminal\. \*\/\n    if \(--initial_terminal->reference_count == 0\n        && initial_terminal->delete_terminal_hook\)\n      \(\*initial_terminal->delete_terminal_hook\) \(initial_terminal\);/    \/* iosmacs: defer deleting the bootstrap terminal in the iOS tty probe. *\//s
  ' "${dispnew_c}"
fi
if [[ -f "${dispnew_c}" ]] && ! grep -q "iosmacs-init-display-before-init-tty" "${dispnew_c}"; then
  perl -0pi -e '
    s/    \/\* Open a display on the controlling tty\. \*\/\n    t = init_tty \(0, terminal_type, 1\); \/\* Errors are fatal\. \*\//    \/* Open a display on the controlling tty. *\/\n    if (getenv ("IOSMACS_NW_DEBUG_ERROR"))\n      fprintf (stderr, "iosmacs-init-display-before-init-tty method=%d\\n", f->output_method);\n    t = init_tty (0, terminal_type, 1); \/* Errors are fatal. *\/\n    if (getenv ("IOSMACS_NW_DEBUG_ERROR"))\n      fprintf (stderr, "iosmacs-init-display-after-init-tty method=%d tty-type=%d\\n", f->output_method, t->type);/s
  ' "${dispnew_c}"
fi
if [[ -f "${dispnew_c}" ]] && ! grep -q "iosmacs: reuse pdumped tty frame during iOS nw startup" "${dispnew_c}"; then
  perl -0pi -e '
    s/    if \(f->output_method != output_initial\)\n      emacs_abort \(\);/    if (f->output_method != output_initial\n        && getenv ("IOSMACS_NW_DEBUG_ERROR"))\n      fprintf (stderr, "iosmacs-init-display-reusing-frame method=%d\\n", f->output_method);\n    \/* iosmacs: reuse pdumped tty frame during iOS nw startup. *\//s
  ' "${dispnew_c}"
fi
if [[ -f "${dispnew_c}" ]] && ! grep -q "iosmacs-init-display-before-frame-size" "${dispnew_c}"; then
  perl -0pi -e '
    s/    t->display_info\.tty->top_frame = selected_frame;\n    change_frame_size \(XFRAME \(selected_frame\),/    t->display_info.tty->top_frame = selected_frame;\n    if (getenv ("IOSMACS_NW_DEBUG_ERROR"))\n      fprintf (stderr, "iosmacs-init-display-before-frame-size rows=%d cols=%d\\n", FrameRows (t->display_info.tty), FrameCols (t->display_info.tty));\n    change_frame_size (XFRAME (selected_frame),/s;
    s/		       false, false, true\);/		       false, false, true);\n    if (getenv ("IOSMACS_NW_DEBUG_ERROR"))\n      fprintf (stderr, "iosmacs-init-display-after-frame-size\\n");/s
  ' "${dispnew_c}"
fi
if [[ -f "${dispnew_c}" ]] && ! grep -q "iosmacs-init-display-before-calculate-costs" "${dispnew_c}"; then
  perl -0pi -e '
    s/  calculate_costs \(XFRAME \(selected_frame\)\);/  if (getenv ("IOSMACS_NW_DEBUG_ERROR"))\n    fprintf (stderr, "iosmacs-init-display-before-calculate-costs\\n");\n  calculate_costs (XFRAME (selected_frame));\n  if (getenv ("IOSMACS_NW_DEBUG_ERROR"))\n    fprintf (stderr, "iosmacs-init-display-after-calculate-costs\\n");/s;
    s/    init_faces_initial \(\);/    {\n      if (getenv ("IOSMACS_NW_DEBUG_ERROR"))\n        fprintf (stderr, "iosmacs-init-display-before-init-faces\\n");\n      init_faces_initial ();\n      if (getenv ("IOSMACS_NW_DEBUG_ERROR"))\n        fprintf (stderr, "iosmacs-init-display-after-init-faces\\n");\n    }/s
  ' "${dispnew_c}"
fi

terminal_c="${configure_root}/src/terminal.c"
if [[ -f "${terminal_c}" ]] && ! grep -q "iosmacs: stale dead terminal frames fall back to selected_frame" "${terminal_c}"; then
  perl -0pi -e '
    s/static struct terminal \*\ndecode_terminal \(Lisp_Object terminal\)\n\{\n  struct terminal \*t;\n\n  if \(NILP \(terminal\)\)\n    terminal = selected_frame;/static struct terminal *\ndecode_terminal (Lisp_Object terminal)\n{\n  struct terminal *t;\n\n  if (FRAMEP (terminal) && !FRAME_LIVE_P (XFRAME (terminal)))\n    terminal = selected_frame;\n  \/* iosmacs: stale dead terminal frames fall back to selected_frame. *\/\n\n  if (NILP (terminal))\n    terminal = selected_frame;/s
  ' "${terminal_c}"
fi

term_c="${configure_root}/src/term.c"
if [[ -f "${term_c}" ]] && ! grep -q "iosmacs: reset terminal cost vector on first iOS probe calculation" "${term_c}"; then
  perl -0pi -e '
    s/  FRAME_COST_BAUD_RATE \(frame\) = baud_rate;\n\n#ifndef HAVE_ANDROID/  FRAME_COST_BAUD_RATE (frame) = baud_rate;\n\n#ifndef HAVE_ANDROID\n  static int iosmacs_cost_vector_reset;\n  if (!iosmacs_cost_vector_reset)\n    {\n      char_ins_del_vector = NULL;\n      max_frame_cols = 0;\n      iosmacs_cost_vector_reset = 1;\n    }\n  \/* iosmacs: reset terminal cost vector on first iOS probe calculation. *\//s
  ' "${term_c}"
fi
if [[ -f "${term_c}" ]] && ! grep -q "iosmacs: skip cursor motion cost init in the iOS tty probe" "${term_c}"; then
  perl -0pi -e '
    s/      cmcostinit \(FRAME_TTY \(frame\)\); \/\* set up cursor motion costs \*\//      \/* iosmacs: skip cursor motion cost init in the iOS tty probe. *\//s
  ' "${term_c}"
fi
if [[ -f "${term_c}" ]] && ! grep -q "iosmacs-init-tty-before-open" "${term_c}"; then
  perl -0pi -e '
    s/    int fd = emacs_open \(name, flags, 0\);/    if (getenv ("IOSMACS_NW_DEBUG_ERROR"))\n      fprintf (stderr, "iosmacs-init-tty-before-open name=%s\\n", name);\n    int fd = emacs_open (name, flags, 0);\n    if (getenv ("IOSMACS_NW_DEBUG_ERROR"))\n      fprintf (stderr, "iosmacs-init-tty-after-open fd=%d isatty=%d\\n", fd, fd >= 0 ? isatty (fd) : -1);/s;
    s/  status = tgetent \(tty->termcap_term_buffer, terminal_type\);/  if (getenv ("IOSMACS_NW_DEBUG_ERROR"))\n    fprintf (stderr, "iosmacs-init-tty-before-tgetent term=%s\\n", terminal_type);\n  status = tgetent (tty->termcap_term_buffer, terminal_type);\n  if (getenv ("IOSMACS_NW_DEBUG_ERROR"))\n    fprintf (stderr, "iosmacs-init-tty-after-tgetent status=%d\\n", status);/s;
    s/  if \(Wcm_init \(tty\) == -1\)/  if (getenv ("IOSMACS_NW_DEBUG_ERROR"))\n    fprintf (stderr, "iosmacs-init-tty-before-wcm-init rows=%d cols=%d\\n", FrameRows (tty), FrameCols (tty));\n  if (Wcm_init (tty) == -1)/s;
    s/  if \(FrameRows \(tty\) <= 0 \|\| FrameCols \(tty\) <= 0\)/  if (getenv ("IOSMACS_NW_DEBUG_ERROR"))\n    fprintf (stderr, "iosmacs-init-tty-after-wcm-init rows=%d cols=%d\\n", FrameRows (tty), FrameCols (tty));\n\n  if (FrameRows (tty) <= 0 || FrameCols (tty) <= 0)/s;
    s/  init_sys_modes \(tty\);/  if (getenv ("IOSMACS_NW_DEBUG_ERROR"))\n    fprintf (stderr, "iosmacs-init-tty-before-init-sys-modes\\n");\n  init_sys_modes (tty);\n  if (getenv ("IOSMACS_NW_DEBUG_ERROR"))\n    fprintf (stderr, "iosmacs-init-tty-after-init-sys-modes\\n");/s
  ' "${term_c}"
fi
xdisp_c="${configure_root}/src/xdisp.c"
if [[ -f "${xdisp_c}" ]] && ! grep -q "iosmacs: derive initial display windows from selected frame" "${xdisp_c}"; then
  perl -0pi -e '
    s/      struct window \*m = XWINDOW \(minibuf_window\);\n      Lisp_Object frame = m->frame;\n      struct frame \*f = XFRAME \(frame\);\n      Lisp_Object root = FRAME_ROOT_WINDOW \(f\);\n      struct window \*r = XWINDOW \(root\);/      Lisp_Object frame = selected_frame;\n      struct frame *f = XFRAME (frame);\n      Lisp_Object root = FRAME_ROOT_WINDOW (f);\n      Lisp_Object mini = FRAME_MINIBUF_WINDOW (f);\n      struct window *r = XWINDOW (root);\n      struct window *m = XWINDOW (mini);\n      minibuf_window = mini;\n      \/* iosmacs: derive initial display windows from selected frame. *\//s
  ' "${xdisp_c}"
fi
if [[ -f "${xdisp_c}" ]] && ! grep -q "iosmacs: skip initial window sizing when converted tty windows are unavailable" "${xdisp_c}"; then
  perl -0pi -e '
    s/      struct window \*r = XWINDOW \(root\);\n      struct window \*m = XWINDOW \(mini\);\n      minibuf_window = mini;\n      \/\* iosmacs: derive initial display windows from selected frame\. \*\/\n      int i;\n\n      r->top_line/      int i;\n\n      if (WINDOWP (root) && WINDOWP (mini))\n        {\n          struct window *r = XWINDOW (root);\n          struct window *m = XWINDOW (mini);\n          minibuf_window = mini;\n          \/* iosmacs: derive initial display windows from selected frame. *\/\n\n          r->top_line/s;
    s/      m->pixel_height = m->total_lines \* FRAME_LINE_HEIGHT \(f\);\n\n      scratch_glyph_row/      m->pixel_height = m->total_lines * FRAME_LINE_HEIGHT (f);\n        }\n      \/* iosmacs: skip initial window sizing when converted tty windows are unavailable. *\/\n\n      scratch_glyph_row/s
  ' "${xdisp_c}"
fi
if [[ -f "${xdisp_c}" ]] && ! grep -q "iosmacs: ignore load messages until the converted tty minibuffer is live" "${xdisp_c}"; then
  perl -0pi -e '
    s/      mini_window = FRAME_MINIBUF_WINDOW \(sf\);\n      f = XFRAME \(WINDOW_FRAME \(XWINDOW \(mini_window\)\)\);\n\n      \/\* Error messages get reported properly by cmd_error, so this must be\n\t just an informative message; if the frame hasn\x27t really been\n\t initialized yet, just toss it\.  \*\/\n      need_message = f->glyphs_initialized_p;/      mini_window = FRAME_MINIBUF_WINDOW (sf);\n      if (!WINDOWP (mini_window))\n        need_message = false;\n      else\n        {\n          f = XFRAME (WINDOW_FRAME (XWINDOW (mini_window)));\n\n          \/* Error messages get reported properly by cmd_error, so this must be\n             just an informative message; if the frame has not really been\n             initialized yet, just toss it.  *\/\n          need_message = f->glyphs_initialized_p;\n        }\n      \/* iosmacs: ignore load messages until the converted tty minibuffer is live. *\//s
  ' "${xdisp_c}"
fi

frame_c="${configure_root}/src/frame.c"
if [[ -f "${frame_c}" ]] && ! grep -q "iosmacs: do not reapply stale terminal frame parameters" "${frame_c}"; then
  perl -0pi -e '
    s/        terminal = XCDR \(terminal\);\n        t = decode_live_terminal \(terminal\);/        terminal = XCDR (terminal);\n        t = decode_live_terminal (terminal);\n        parms = Fdelq (Fassq (Qterminal, parms), parms);\n        \/* iosmacs: do not reapply stale terminal frame parameters. *\//s
  ' "${frame_c}"
fi

loadup_el="${configure_root}/lisp/loadup.el"
if [[ -f "${loadup_el}" ]] && ! grep -q '"bootstrap" "pbootstrap" "pdump"' "${loadup_el}"; then
  perl -0pi -e '
    s/\(member dump-mode '"'"'\("bootstrap" "pbootstrap"\)\)/(member dump-mode '"'"'("bootstrap" "pbootstrap" "pdump"))/s
  ' "${loadup_el}"
fi

if [[ -f "${loadup_el}" ]] && ! grep -q "iosmacs-pdmp-disable-hash-consing" "${loadup_el}"; then
  perl -0pi -e '
    s/\(if \(eq t purify-flag\)\n    ;; Hash consing saved around 11% of pure space in my tests\.\n    \(setq purify-flag \(make-hash-table :test #'"'"'equal :size 80000\)\)\)/$&\n\n;; iosmacs-pdmp-disable-hash-consing\n(setq purify-flag nil)/s
  ' "${loadup_el}"
fi

if [[ -f "${loadup_el}" ]] && ! grep -q "iosmacs-pdmp-load-source-macros-before-files" "${loadup_el}"; then
  perl -0pi -e '
    s/\(setq load-source-file-function #'"'"'load-with-code-conversion\)\n\(load "files"\)/(setq load-source-file-function #'"'"'load-with-code-conversion)\n;; iosmacs-pdmp-load-source-macros-before-files\n(load "emacs-lisp\/macroexp")\n(let ((macroexp--pending-eager-loads '"'"'(skip)))\n  (load "emacs-lisp\/pcase"))\n(load "emacs-lisp\/easy-mmode")\n(load "emacs-lisp\/rx")\n(load "emacs-lisp\/gv")\n(load "files")/s
  ' "${loadup_el}"
fi

if [[ -f "${loadup_el}" ]] && ! grep -q "iosmacs-pdmp-runtime-skip-eager" "${loadup_el}"; then
  perl -0pi -e '
    s/\(load "emacs-lisp\/macroexp"\)\n\(if \(compiled-function-p \(symbol-function '"'"'\'"'"''"'"'macroexpand-all\)\)/(load "emacs-lisp\/macroexp")\n;; iosmacs-pdmp-runtime-skip-eager\n(setq macroexp--pending-eager-loads '"'"'(skip))\n(if (compiled-function-p (symbol-function '"'"'\'"'"''"'"'macroexpand-all))/s
  ' "${loadup_el}"
fi

if [[ -f "${loadup_el}" ]] && ! grep -q "iosmacs-pdmp-skip-eager-loaddefs" "${loadup_el}"; then
  perl -0pi -e '
    s/\(condition-case nil\n    \(load "loaddefs"\)\n  \(file-error\n   \(load "ldefs-boot\.el"\)\)\)/(let ((macroexp--pending-eager-loads '"'"'(skip)))\n  ;; iosmacs-pdmp-skip-eager-loaddefs\n  (condition-case nil\n      (load "loaddefs")\n    (file-error\n     (load "ldefs-boot.el"))))/s
  ' "${loadup_el}"
fi

if [[ -f "${loadup_el}" ]] && ! grep -q "iosmacs-pdmp-skip-eager-cl-preloaded" "${loadup_el}"; then
  perl -0pi -e '
    s/\(load "emacs-lisp\/cl-preloaded"\)/(let ((macroexp--pending-eager-loads '"'"'(skip)))\n  ;; iosmacs-pdmp-skip-eager-cl-preloaded\n  (load "emacs-lisp\/cl-preloaded"))/s
  ' "${loadup_el}"
fi
if [[ -f "${loadup_el}" ]] && ! grep -q "iosmacs-pdmp-fallback-charprop" "${loadup_el}"; then
  perl -0pi -e '
    s/\(load "international\/charprop\.el" t\)\n\(if \(featurep \x27charprop\)\n    \(setq redisplay--inhibit-bidi nil\)\)/(load "international\/charprop.el" t)\n(unless (featurep (quote charprop))\n  ;; iosmacs-pdmp-fallback-charprop\n  (let ((bidi-class-table (make-char-table (quote char-code-property-table) (quote L)))\n        (mirroring-table (make-char-table (quote char-code-property-table) nil))\n        (bracket-type-table (make-char-table (quote char-code-property-table) nil)))\n    (set-char-table-extra-slot bidi-class-table 0 (quote bidi-class))\n    (set-char-table-extra-slot mirroring-table 0 (quote mirroring))\n    (set-char-table-extra-slot bracket-type-table 0 (quote bracket-type))\n    (define-char-code-property (quote bidi-class) bidi-class-table)\n    (define-char-code-property (quote mirroring) mirroring-table)\n    (define-char-code-property (quote bracket-type) bracket-type-table)))\n(if (or (featurep (quote charprop)) (getenv "IOSMACS_PDMP_FALLBACK_CHARPROP"))\n    (setq redisplay--inhibit-bidi nil))/s
  ' "${loadup_el}"
fi

startup_el="${configure_root}/lisp/startup.el"
if [[ -f "${startup_el}" ]] && ! grep -q "iosmacs-startup-before-command-line" "${startup_el}"; then
  perl -0pi -e '
    s/(\n\s*)\(command-line\)/$1(progn$1  (princ "iosmacs-startup-before-command-line\\n" (quote external-debugging-output))$1  (command-line))/s;
    s/(\n\s*)\(frame-initialize\)/$1(progn$1  (princ "iosmacs-startup-before-frame-initialize\\n" (quote external-debugging-output))$1  (frame-initialize)$1  (princ "iosmacs-startup-after-frame-initialize\\n" (quote external-debugging-output)))/s;
    s/(\n\s*)\(command-line-1 \(cdr command-line-args\)\)/$1(princ "iosmacs-startup-before-command-line-1\\n" (quote external-debugging-output))$1(command-line-1 (cdr command-line-args))/s;
    s/(\n\s*)\(eval expr t\)/$1(princ "iosmacs-startup-before-eval\\n" (quote external-debugging-output))$1(eval expr t)/s
  ' "${startup_el}"
fi
if [[ -f "${startup_el}" ]] && ! grep -q "iosmacs-nw-skip-terminal-init" "${startup_el}"; then
  perl -0pi -e '
    s/\(tty-run-terminal-initialization \(selected-frame\) nil t\)/(unless (getenv "IOSMACS_NW_SKIP_TERM_INIT")\n      ;; iosmacs-nw-skip-terminal-init\n      (tty-run-terminal-initialization (selected-frame) nil t))/s
  ' "${startup_el}"
fi

echo "Configured Emacs iOS probe in ${build_root}"
