#!/usr/bin/env bash
# Build real arm64 device IPAs on a Mac. No signing secrets are needed for the unsigned artifacts.
set -euo pipefail
ios_dir="$(cd "$(dirname "$0")/.." && pwd)"
out_dir="${1:-$ios_dir/build/artifacts}"
mkdir -p "$out_dir"
out_dir="$(cd "$out_dir" && pwd)"
build_dir="$(mktemp -d "${TMPDIR:-/tmp}/clash-timers-build.XXXXXXXX")"
trap 'rm -rf "$build_dir"' EXIT
cd "$ios_dir"
command -v xcodebuild >/dev/null || { echo 'This script requires macOS with Xcode. On Windows, run the iOS build workflow.' >&2; exit 1; }

for scheme in ClashTimersStandalone ClashTimers; do
    derived="$build_dir/$scheme"
    xcodebuild build -project ClashTimers.xcodeproj -scheme "$scheme" -configuration Release \
        -destination 'generic/platform=iOS' -derivedDataPath "$derived" CODE_SIGNING_ALLOWED=NO
    app="$derived/Build/Products/Release-iphoneos/$scheme.app"
    test -x "$app/$scheme"
    if [[ "$scheme" == 'ClashTimers' ]]; then
        test -x "$app/PlugIns/ClashTimersWidget.appex/ClashTimersWidget"
    else
        test ! -d "$app/PlugIns/ClashTimersWidget.appex"
    fi
    stage="$build_dir/package-$scheme"
    mkdir -p "$stage/Payload"
    ditto "$app" "$stage/Payload/$scheme.app"
    # Write a new zip rather than update an existing one and leave stale files in it.
    (cd "$stage" && /usr/bin/zip -yqr "$stage/device.ipa" Payload)
    mv "$stage/device.ipa" "$out_dir/$scheme-unsigned.ipa"
    unzip -tq "$out_dir/$scheme-unsigned.ipa"
done
(cd "$out_dir" && shasum -a 256 ClashTimersStandalone-unsigned.ipa ClashTimers-unsigned.ipa > SHA256SUMS.txt)
