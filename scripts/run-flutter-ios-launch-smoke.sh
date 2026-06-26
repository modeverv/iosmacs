#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app_dir="${repo_root}/flutter/iosmacs_flutter"
runner_app="${app_dir}/build/ios/iphonesimulator/Runner.app"
device="${IOSMACS_SIMULATOR_UDID:-booted}"
hold_seconds="${IOSMACS_FLUTTER_IOS_LAUNCH_HOLD_SECONDS:-3}"

"${repo_root}/scripts/check-flutter-ios-runner-smoke.sh"

if ! xcrun simctl list devices booted | grep -q "(Booted)"; then
  echo "error: no booted simulator is available for Flutter iOS launch smoke" >&2
  exit 1
fi

bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${runner_app}/Info.plist")"
if [[ -z "${bundle_id}" ]]; then
  echo "error: could not read Flutter Runner bundle identifier" >&2
  exit 1
fi

xcrun simctl install "${device}" "${runner_app}"
launch_output="$(xcrun simctl launch --terminate-running-process "${device}" "${bundle_id}")"
echo "${launch_output}"

sleep "${hold_seconds}"

if ! xcrun simctl terminate "${device}" "${bundle_id}"; then
  echo "error: Flutter iOS Runner was not alive for clean termination" >&2
  exit 1
fi

echo "flutter iOS launch smoke ok: ${bundle_id}"
