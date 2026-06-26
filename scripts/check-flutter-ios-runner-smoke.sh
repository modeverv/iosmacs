#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app_dir="${repo_root}/flutter/iosmacs_flutter"
runner_app="${app_dir}/build/ios/iphonesimulator/Runner.app"
runner_dylib="${runner_app}/Runner.debug.dylib"

export PATH="${HOME}/work/flutter/bin:${PATH}"

if ! command -v flutter >/dev/null 2>&1; then
  echo "error: flutter command not found; install Flutter SDK under ~/work/flutter or add it to PATH" >&2
  exit 1
fi

cd "${app_dir}"
flutter build ios --simulator --debug

required_bundle_paths=(
  "${runner_app}/lisp"
  "${runner_app}/etc"
  "${runner_app}/lib-src"
  "${runner_app}/emacs.pdmp"
)

for path in "${required_bundle_paths[@]}"; do
  if [[ ! -e "${path}" ]]; then
    echo "error: missing Flutter iOS Runner bundle resource: ${path}" >&2
    exit 1
  fi
done

if [[ ! -f "${runner_dylib}" ]]; then
  echo "error: missing Flutter iOS Runner debug dylib: ${runner_dylib}" >&2
  exit 1
fi

if ! nm -gU "${runner_dylib}" | grep -q '_iosmacs_emacs_main'; then
  echo "error: Runner.debug.dylib does not resolve _iosmacs_emacs_main" >&2
  exit 1
fi

if ! nm -gU "${runner_dylib}" | grep -q '_iosmacs_emacs_core_link_available'; then
  echo "error: Runner.debug.dylib does not export _iosmacs_emacs_core_link_available" >&2
  exit 1
fi

echo "flutter iOS runner smoke ok"
