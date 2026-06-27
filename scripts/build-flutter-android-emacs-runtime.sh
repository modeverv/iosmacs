#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_root="${IOSMACS_EMACS_SOURCE:-${repo_root}/wasmacs/vendor/emacs}"
sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}}"
abi="${IOSMACS_ANDROID_ABI:-arm64-v8a}"
api="${IOSMACS_ANDROID_API:-35}"
app_id="${IOSMACS_ANDROID_APP_ID:-com.example.iosmacs_flutter}"
build_root="${IOSMACS_ANDROID_EMACS_BUILD_ROOT:-${repo_root}/flutter/build/emacs-android/${abi}}"
source_copy="${build_root}/source"
tool_dir="${build_root}/tools"
out_dir="${build_root}/iosmacs"
status_file="${out_dir}/android-emacs-runtime.status"
configure_log="${out_dir}/configure.log"
build_log="${out_dir}/build.log"
host_generation_log="${out_dir}/host-generation.log"
jobs="${JOBS:-$(sysctl -n hw.ncpu 2>/dev/null || printf '4')}"
install_jobs="${IOSMACS_ANDROID_EMACS_INSTALL_JOBS:-1}"

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

run_make() {
  "${ndk_make}" "$@" \
    "AR=${android_ar}" \
    "RANLIB=${android_ranlib}" \
    "NM=${android_nm}"
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
  printf 'error: missing NDK LLVM toolchain under %s/toolchains/llvm/prebuilt\n' "${ndk_root}" >&2
  exit 1
fi

case "${abi}" in
  arm64-v8a)
    clang_target="aarch64-linux-android${api}-clang"
    ;;
  x86_64)
    clang_target="x86_64-linux-android${api}-clang"
    ;;
  armeabi-v7a)
    clang_target="armv7a-linux-androideabi${api}-clang"
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
android_ar="${AR:-${toolchain_root}/bin/llvm-ar}"
android_ranlib="${RANLIB:-${toolchain_root}/bin/llvm-ranlib}"
android_nm="${NM:-${toolchain_root}/bin/llvm-nm}"
if [[ ! -x "${android_ar}" || ! -x "${android_ranlib}" || ! -x "${android_nm}" ]]; then
  printf 'error: missing Android llvm binutils under %s/bin\n' "${toolchain_root}" >&2
  exit 1
fi

android_jar="${IOSMACS_ANDROID_JAR:-${sdk_root}/platforms/android-${api}/android.jar}"
if [[ ! -f "${android_jar}" ]]; then
  android_jar="$(newest_match "${sdk_root}/platforms/android-*/android.jar")"
fi
if [[ -z "${android_jar}" || ! -f "${android_jar}" ]]; then
  printf 'error: missing android.jar under %s/platforms\n' "${sdk_root}" >&2
  exit 1
fi

build_tools="${SDK_BUILD_TOOLS:-$(newest_match "${sdk_root}/build-tools/*")}"
if [[ -z "${build_tools}" || ! -d "${build_tools}" ]]; then
  printf 'error: missing Android SDK build-tools under %s/build-tools\n' "${sdk_root}" >&2
  exit 1
fi

ndk_make="${IOSMACS_NDK_MAKE:-${ndk_root}/prebuilt/darwin-x86_64/bin/make}"
if [[ ! -x "${ndk_make}" ]]; then
  ndk_make="${ndk_root}/prebuilt/darwin-arm64/bin/make"
fi
if [[ ! -x "${ndk_make}" ]]; then
  ndk_make="$(command -v gmake || true)"
fi
if [[ -z "${ndk_make}" || ! -x "${ndk_make}" ]]; then
  printf 'error: missing GNU Make 4.x; NDK prebuilt make is preferred\n' >&2
  exit 1
fi

real_javac="${IOSMACS_REAL_JAVAC:-$(command -v javac || true)}"
if [[ -z "${real_javac}" ]]; then
  printf 'error: missing javac\n' >&2
  exit 1
fi
jar_tool="${IOSMACS_REAL_JAR:-$(command -v jar || true)}"
if [[ -z "${jar_tool}" ]]; then
  printf 'error: missing jar tool\n' >&2
  exit 1
fi
jarsigner="${JARSIGNER:-$(command -v jarsigner || true)}"

mkdir -p "${build_root}" "${tool_dir}" "${out_dir}"
rsync -a --delete --exclude .git "${source_root}/" "${source_copy}/"

for package_bound_java in \
  "${source_copy}/java/org/gnu/emacs/EmacsApplication.java" \
  "${source_copy}/java/org/gnu/emacs/EmacsNoninteractive.java"; do
  if [[ -f "${package_bound_java}" ]]; then
    perl -0pi -e "s/\"org\\.gnu\\.emacs\"/\"${app_id}\"/g" "${package_bound_java}"
  fi
done

loadup_el="${source_copy}/lisp/loadup.el"
if [[ -f "${loadup_el}" ]] \
  && ! grep -q 'IOSMACS_ANDROID_NW_PDUMP_OUTPUT' "${loadup_el}"; then
  perl -0pi -e '
s/\(dump-emacs-portable \(expand-file-name output invocation-directory\)\)/(dump-emacs-portable\n                     (or (cadr (member "--android-nw-pdump-output" command-line-args))\n                         (getenv "IOSMACS_ANDROID_NW_PDUMP_OUTPUT")\n                         (expand-file-name output invocation-directory)))/s
' "${loadup_el}"
  if grep -q 'IOSMACS_ANDROID_NW_PDUMP_OUTPUT' "${loadup_el}"; then
    printf 'patched lisp/loadup.el: Android NW pdump output override for asset use\n'
  else
    printf 'warning: loadup.el Android NW pdump output override patch not applied\n'
  fi
fi
if [[ -f "${loadup_el}" ]] \
  && ! grep -q 'iosmacs: Android NW without pdumper-stats' "${loadup_el}"; then
  perl -0pi -e '
s/\(and \(eq system-type '\''android\)\n         \(not \(pdumper-stats\)\)\)/(and (eq system-type '\''android)\n         ;; iosmacs: Android NW without pdumper-stats.\n         ;; The Flutter NW route can use --with-dumping=none while reusing\n         ;; these packaged Lisp assets, so pdumper functions may be absent.\n         (fboundp '\''pdumper-stats)\n         (not (pdumper-stats)))/s
' "${loadup_el}"
  if grep -q 'iosmacs: Android NW without pdumper-stats' "${loadup_el}"; then
    printf 'patched lisp/loadup.el: guarded Android pdumper-stats for NW asset use\n'
  else
    printf 'warning: loadup.el pdumper-stats patch not applied (pattern may have changed)\n'
  fi
fi

cat >"${tool_dir}/javac" <<EOF
#!/usr/bin/env bash
set -euo pipefail
real_javac="${real_javac}"
args=()
skip_next=0
for arg in "\$@"; do
  if [[ "\$skip_next" == 1 ]]; then
    skip_next=0
    continue
  fi
  case "\$arg" in
    -source|-target|--release)
      skip_next=1
      ;;
    *)
      args+=("\$arg")
      ;;
  esac
done
exec "\$real_javac" --release 8 "\${args[@]}"
EOF
chmod +x "${tool_dir}/javac"

host_emacs="${IOSMACS_ANDROID_HOST_EMACS:-${repo_root}/flutter/build/emacs-macos/runtime/bin/emacs}"
runtime_lisp="${IOSMACS_ANDROID_HOST_EMACS_LISP:-${repo_root}/flutter/build/emacs-macos/runtime/lisp}"
cat >"${tool_dir}/host-emacs-for-android" <<EOF
#!/usr/bin/env bash
set -euo pipefail
host_emacs="${host_emacs}"
runtime_lisp="${runtime_lisp}"
source_lisp="${source_copy}/lisp"
source_etc="${source_copy}/etc"
load_args=()
while IFS= read -r d; do
  load_args+=("-L" "\$d")
done < <(find "\$runtime_lisp" -type d | sort)
while IFS= read -r d; do
  load_args+=("-L" "\$d")
done < <(find "\$source_lisp" -type d | sort)
exec "\$host_emacs" \\
  "\${load_args[@]}" \\
  --eval "(setq lisp-directory \"\$source_lisp/\" data-directory \"\$source_etc/\")" \\
  "\$@"
EOF
chmod +x "${tool_dir}/host-emacs-for-android"

if [[ ! -x "${source_copy}/configure" ]]; then
  (
    cd "${source_copy}"
    ./autogen.sh
  )
fi

configure_needs_run=0
if [[ ! -f "${build_root}/config.status" ]]; then
  configure_needs_run=1
elif ! grep -q "AR=${android_ar}" "${build_root}/config.log" 2>/dev/null; then
  configure_needs_run=1
elif ! grep -q "ANDROID_CC=${android_cc}" "${build_root}/config.log" 2>/dev/null; then
  configure_needs_run=1
fi

if [[ "${configure_needs_run}" == "1" ]]; then
  (
    cd "${build_root}"
    PATH="${tool_dir}:${toolchain_root}/bin:${PATH}" \
      "${source_copy}/configure" \
        "--with-android=${android_jar}" \
        --without-android-debug \
        --with-gnutls=ifavailable \
        --without-native-compilation \
        --without-tree-sitter \
        --without-sqlite3 \
        --without-webp \
        --without-rsvg \
        --without-imagemagick \
        --without-lcms2 \
        --without-mailutils \
        "ANDROID_CC=${android_cc}" \
        "AR=${android_ar}" \
        "RANLIB=${android_ranlib}" \
        "NM=${android_nm}" \
        "SDK_BUILD_TOOLS=${build_tools}" \
        "JARSIGNER=${jarsigner}" \
        >"${configure_log}" 2>&1
  )
fi

cat >"${status_file}" <<EOF
configure=ok
android_abi=${abi}
android_api=${api}
android_app_id=${app_id}
android_jar=${android_jar}
android_cc=${android_cc}
android_ar=${android_ar}
android_ranlib=${android_ranlib}
android_nm=${android_nm}
sdk_build_tools=${build_tools}
ndk_make=${ndk_make}
javac_wrapper=${tool_dir}/javac
libemacs_so=${build_root}/java/install_temp/lib/${abi}/libemacs.so
libandroid_emacs_so=${build_root}/java/install_temp/lib/${abi}/libandroid-emacs.so
packaged_jni_lib_dir=${out_dir}/jniLibs/${abi}
java_bridge_jar=${out_dir}/emacs-android-java.jar
EOF

printf 'flutter Android Emacs configure ok: %s\n' "${build_root}"
printf 'status: %s\n' "${status_file}"

if [[ "${IOSMACS_ANDROID_EMACS_BUILD_LIBS:-0}" != "1" ]]; then
  exit 0
fi

if [[ ! -x "${host_emacs}" || ! -d "${runtime_lisp}" ]]; then
  printf 'error: missing host Emacs runtime for Android generated Lisp at %s\n' "${host_emacs}" >&2
  printf 'hint: run make flutter-macos-emacs-runtime or set IOSMACS_ANDROID_HOST_EMACS\n' >&2
  exit 1
fi

{
  printf 'host_emacs=%s\n' "${host_emacs}"
  printf 'runtime_lisp=%s\n' "${runtime_lisp}"
  printf 'android_api=%s\n' "${api}"
} >"${host_generation_log}"

# Android NDK r28 exposes SIG2STR_MAX before sig2str/str2sig are available
# to API 35 targets. Gnulib supplies the implementation, so keep its
# declarations visible when configure found HAVE_SIG2STR=0.
for sig2str_header in "${source_copy}/lib/sig2str.h" "${build_root}/cross/lib/sig2str.h"; do
  if [[ -f "${sig2str_header}" ]] \
    && ! grep -q 'Android API 35 exposes SIG2STR_MAX' "${sig2str_header}"; then
    perl -0pi -e 's|/\* Don.*?\n#ifndef SIG2STR_MAX\n\n# include "intprops.h"\n\n/\* Size of a buffer needed to hold a signal name like "HUP"\.  \*/\n# define SIG2STR_MAX \(sizeof "SIGRTMAX" \+ INT_STRLEN_BOUND \(int\) - 1\)\n\n#ifdef __cplusplus\nextern "C" \{\n#endif\n\nint sig2str \(int, char \*\);\nint str2sig \(char const \*, int \*\);\n\n#ifdef __cplusplus\n\}\n#endif\n\n#endif|/* Android API 35 exposes SIG2STR_MAX without sig2str/str2sig.  */\n#ifndef SIG2STR_MAX\n# include "intprops.h"\n# define SIG2STR_MAX (sizeof "SIGRTMAX" + INT_STRLEN_BOUND (int) - 1)\n#endif\n\n#if !HAVE_SIG2STR\n# ifdef __cplusplus\nextern "C" {\n# endif\nint sig2str (int, char *);\nint str2sig (char const *, int *);\n# ifdef __cplusplus\n}\n# endif\n#endif|s' "${sig2str_header}"
  fi
done

if [[ ! -f "${source_copy}/lisp/loaddefs.el" ]]; then
  "${tool_dir}/host-emacs-for-android" \
    --batch --no-site-file --no-site-lisp \
    --eval "(setq load-prefer-newer t byte-compile-warnings 'all)" \
    --eval "(setq org--inhibit-version-check t)" \
    -f batch-byte-compile \
    "${source_copy}/lisp/emacs-lisp/loaddefs-gen.el" \
    >>"${host_generation_log}" 2>&1

  subdirs=()
  while IFS= read -r subdir; do
    subdirs+=("${subdir}")
  done < <(find "${source_copy}/lisp" -type d \
    ! -path "${source_copy}/lisp/obsolete" \
    ! -path "${source_copy}/lisp/term" | sort)
  "${tool_dir}/host-emacs-for-android" \
    --batch --no-site-file --no-site-lisp \
    --eval "(setq load-prefer-newer t byte-compile-warnings 'all)" \
    --eval "(setq org--inhibit-version-check t)" \
    -l "${source_copy}/lisp/emacs-lisp/loaddefs-gen.elc" \
    -f loaddefs-generate--emacs-batch \
    "${subdirs[@]}" \
    >>"${host_generation_log}" 2>&1
fi

if [[ -d "${runtime_lisp}" ]]; then
  rsync -a --include='*/' --include='*.elc' --exclude='*' \
    "${runtime_lisp}/" "${source_copy}/lisp/"
fi

"${MAKE:-make}" -C "${build_root}/admin/unidata" all \
  "EMACS=${tool_dir}/host-emacs-for-android" \
  >>"${host_generation_log}" 2>&1
"${MAKE:-make}" -C "${build_root}/admin/charsets" all \
  >>"${host_generation_log}" 2>&1
mkdir -p "${source_copy}/info"

run_make -C "${build_root}/lib" libgnu.a -j"${jobs}" >"${out_dir}/libgnu.log" 2>&1
run_make -C "${build_root}/cross" lib/libgnu.a -j"${jobs}" >"${out_dir}/cross-libgnu.log" 2>&1

rm -f "${build_root}/exec"/*.o \
  "${build_root}/exec"/*.a \
  "${build_root}/exec"/exec1 \
  "${build_root}/exec"/loader \
  "${build_root}/exec"/*.s.s \
  "${build_root}/java/install_temp/lib/${abi}"/libemacs.so \
  "${build_root}/java/install_temp/lib/${abi}"/libandroid-emacs.so \
  2>/dev/null || true

if ! run_make -C "${build_root}/java" install_temp -j"${install_jobs}" >"${build_log}" 2>&1; then
  blocker='GNU Emacs Android native library build did not complete; inspect build_log.'
  if grep -q 'mktime_z' "${build_log}"; then
    blocker='GNU Emacs Android cross lib failed in nstrftime.c: undeclared mktime_z on Android.'
  elif grep -q 'lisp.mk' "${build_log}"; then
    blocker='GNU Emacs Android cross src failed in a parallel lisp.mk generation race.'
  elif grep -q 'str2sig' "${build_log}"; then
    blocker='GNU Emacs Android cross src failed because Android API exposed SIG2STR_MAX without sig2str/str2sig declarations.'
  elif grep -q 'loaddefs.el' "${build_log}"; then
    blocker='GNU Emacs Android cross src failed because generated Lisp loaddefs were missing.'
  elif grep -q 'charprop.el' "${build_log}"; then
    blocker='GNU Emacs Android cross src failed because generated Unicode Lisp files were missing.'
  elif grep -q 'source/info' "${build_log}"; then
    blocker='GNU Emacs Android install_temp failed because source/info was missing.'
  elif grep -q 'struct __timezone_t' "${build_log}"; then
    blocker='GNU Emacs Android cross lib failed in Android timezone replacement support.'
  elif grep -q 'undefined symbol: tracing_execve' "${build_log}"; then
    blocker='GNU Emacs Android exec helper failed to link; verify NDK llvm-ar/llvm-ranlib propagation.'
  fi
  {
    printf 'build=failed\n'
    printf 'build_log=%s\n' "${build_log}"
    printf 'blocker=%s\n' "${blocker}"
  } >>"${status_file}"
  printf 'error: Android Emacs native library build failed; see %s\n' "${build_log}" >&2
  grep -E 'error:|undefined symbol|No rule|No such file|failed' "${build_log}" | tail -20 >&2 || true
  tail -40 "${build_log}" >&2
  exit 1
fi

lib_dir="${build_root}/java/install_temp/lib/${abi}"
if [[ ! -f "${lib_dir}/libemacs.so" || ! -f "${lib_dir}/libandroid-emacs.so" ]]; then
  printf 'error: Android Emacs build did not produce libemacs.so and libandroid-emacs.so in %s\n' "${lib_dir}" >&2
  exit 1
fi
package_jni_lib_dir="${out_dir}/jniLibs/${abi}"
rm -rf "${package_jni_lib_dir}"
mkdir -p "${package_jni_lib_dir}"
cp -p \
  "${lib_dir}/libemacs.so" \
  "${lib_dir}/libandroid-emacs.so" \
  "${package_jni_lib_dir}/"

PATH="${tool_dir}:${toolchain_root}/bin:${PATH}" \
  run_make -C "${build_root}/java" classes.dex >"${out_dir}/java-bridge.log" 2>&1

java_classes_dir="${out_dir}/emacs-java-classes"
java_bridge_jar="${out_dir}/emacs-android-java.jar"
rm -rf "${java_classes_dir}"
mkdir -p "${java_classes_dir}"
for java_class_root in "${source_copy}/java" "${build_root}/java"; do
  if [[ -d "${java_class_root}/org" ]]; then
    while IFS= read -r class_file; do
      mkdir -p "${java_classes_dir}/$(dirname "${class_file}")"
      cp -p "${java_class_root}/${class_file}" \
        "${java_classes_dir}/${class_file}"
    done < <(cd "${java_class_root}" && find org -name '*.class' -type f | sort)
  fi
done
if [[ -z "$(find "${java_classes_dir}" -name '*.class' -type f -print -quit)" ]]; then
  printf 'error: Android Emacs Java bridge jar had no class files\n' >&2
  exit 1
fi
(
  cd "${java_classes_dir}"
  "${jar_tool}" cf "${java_bridge_jar}" .
)

{
  printf 'build=ok\n'
  printf 'build_log=%s\n' "${build_log}"
  printf 'host_generation_log=%s\n' "${host_generation_log}"
  printf 'packaged_jni_lib_dir=%s\n' "${package_jni_lib_dir}"
  printf 'java_bridge_log=%s\n' "${out_dir}/java-bridge.log"
  printf 'java_bridge_jar=%s\n' "${java_bridge_jar}"
} >>"${status_file}"

printf 'flutter Android Emacs runtime libs ready: %s\n' "${lib_dir}"
printf 'flutter Android Emacs packaged JNI libs ready: %s\n' "${package_jni_lib_dir}"
printf 'flutter Android Emacs Java bridge ready: %s\n' "${java_bridge_jar}"
