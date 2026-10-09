#!/bin/bash
set -euo pipefail

# No credentials in flags, environment variables, temporary files, or shell history.
if [[ -n "${CI:-}" ]]; then
  echo "Live testing is disabled in CI." >&2
  exit 1
fi
if [[ ! -t 0 || ! -t 1 || ! -t 2 ]]; then
  echo "Run this launcher directly in an interactive terminal; do not pipe or redirect it." >&2
  exit 1
fi
if [[ $# -ne 1 ]]; then
  echo "Usage: bash scripts/test-live.sh terminal-check|upnp|cloud|compare|household-upnp|household-cloud|household-compare" >&2
  exit 1
fi

case "$1" in
  terminal-check) export MULTIROOMKIT_LIVE_TERMINAL=1; task_test=testTerminalInteraction ;;
  upnp) export MULTIROOMKIT_LIVE_UPNP=1; task_test=testUPnP ;;
  cloud) export MULTIROOMKIT_LIVE_CLOUD=1; task_test=testControlAPI ;;
  compare) export MULTIROOMKIT_LIVE_COMPARE=1; task_test=testPairedSnapshotsForManualAppComparison ;;
  household-upnp) export MULTIROOMKIT_LIVE_HOUSEHOLD_UPNP=1; task_test=testUPnPMatchesHousehold ;;
  household-cloud) export MULTIROOMKIT_LIVE_HOUSEHOLD_CLOUD=1; task_test=testControlAPIMatchesHousehold ;;
  household-compare) export MULTIROOMKIT_LIVE_HOUSEHOLD_COMPARE=1; task_test=testBothTransportsMatchHousehold ;;
  *) echo "Unknown live-test mode. Run without arguments for usage." >&2; exit 1 ;;
esac

task_repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$task_repo_root"
# A dedicated native build produces one XCTest bundle. Execute the host directly
# in the foreground rather than asking SwiftPM's test launcher to handle stdin.
# The native backend is currently supported but deprecated in Swift 6.4.
task_build_options=(--build-system native --scratch-path .build-live)
# For Codex's nested filesystem sandbox only; ordinary terminal runs leave this unset.
if [[ "${MULTIROOMKIT_DISABLE_BUILD_SANDBOX:-0}" == "1" ]]; then
  task_build_options+=(--disable-sandbox)
fi
swift build --build-tests "${task_build_options[@]}"
task_bin_path=$(swift build --show-bin-path "${task_build_options[@]}")
exec xcrun xctest -XCTest "MultiroomKitLiveTests.LiveTests/$task_test" \
  "$task_bin_path/MultiroomKitPackageTests.xctest"
